'use strict';

// FAZA 1 — Import materiale din factura: parser XML e-Factura (UBL Invoice).
//
// Modul IZOLAT. NU scrie in `jobs`, NU scrie in `materials`, NU scrie in
// catalogul de produse.
//
// FAZA A-E/1-13 (crash nativ firebase_storage pe Windows) + FAZA
// "persist invoice metadata server-side" (crash nativ cloud_firestore
// .runTransaction() pe Windows, confirmat separat prin harness izolat) —
// acest modul persista ACUM COMPLET sursa facturii server-side, prin
// Admin SDK (bypaseaza firestore.rules/storage.rules — de aceea
// autorizarea admin-only ramane STRICT server-side, vezi
// requireAdminForInvoices mai jos, neschimbata):
//   1. XML-ul sursa, in Firebase Storage (persistSourceXmlIfNeeded);
//   2. Documentul `supplier_invoices/{invoiceId}` + subcolectia `lines`,
//      in Firestore (persistInvoiceMetadataIfNeeded).
// Motiv, in ambele cazuri: pluginul FlutterFire pe Windows desktop are un
// defect structural confirmat (inspectie sursa + harness izolat de
// reproducere) — atat `storageRef.putData(...)` cat si
// `FirebaseFirestore.runTransaction(...)` trimit mesaje pe canalul
// Flutter dintr-un thread nativ gresit al SDK-ului C++ Firebase, ceea ce
// doboara procesul INAINTE ca importul sa ajunga la persistarea
// materialelor. Mutand toata persistarea facturii server-side, clientul
// Windows nu mai executa deloc `putData`/`runTransaction` pentru acest
// feature — vezi supplier_invoice_repository.dart (functia
// `persistNewInvoice`, care facea exact tranzactia Firestore afectata, a
// fost eliminata complet).
//
// invoiceId = SHA-256(xmlContent) calculat AICI (canonic, server-side) —
// acelasi ID e folosit ca nume de document Firestore si ca segment de
// path in Storage. Path-ul Storage e construit EXCLUSIV server-side din
// (uid autentificat, invoiceId calculat) — clientul NU poate influenta
// path-ul in niciun fel (nu exista niciun camp de input citit in acest
// scop).
//
// IDEMPOTENTA / campuri immutable vs mutable: daca documentul factura
// exista deja, `persistInvoiceMetadataIfNeeded` NU il atinge deloc — NU
// suprascrie `linkedJobIds`/`status` (mutate ulterior de fluxul de
// alocare in lucrare, vezi lucrare_detalii_page.dart /
// repairInvoiceImportMetadata) si NU recreeaza liniile. Header-ul si
// liniile intoarse in raspuns provin INTOTDEAUNA din parsarea curenta
// (`result.header`/`result.lines`), nu din documentul Firestore existent
// — sigur prin constructie, pentru ca acelasi invoiceId implica
// determinist acelasi continut XML, deci acelasi rezultat de parsare;
// singurul lucru citit efectiv din Firestore in cazul de reutilizare sunt
// ID-urile liniilor deja create (`lineDocId`), ca sa nu se creeze linii
// noi/duplicate la reimport.

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const crypto = require('crypto');
const { XMLParser, XMLValidator } = require('fast-xml-parser');

// Limita de dimensiune a continutului XML acceptat — coerenta cu limita de
// 5MB definita in storage.rules pentru path-ul supplier_invoices/**.
const MAX_XML_BYTES = 5 * 1024 * 1024;

const DECIMAL_RE = /^-?\d+(\.\d+)?$/;

const xmlParser = new XMLParser({
  removeNSPrefix: true,
  ignoreAttributes: false,
  attributeNamePrefix: '@_',
  // IMPORTANT: valorile raman text brut (nu auto-convertite de biblioteca).
  // Conversiile numerice se fac explicit mai jos, controlat, ca sa nu se
  // piarda zerouri semnificative din coduri (ex. cod furnizor "00789") si
  // ca sa nu se "ghiceasca" reprezentari numerice pentru sume monetare.
  parseTagValue: false,
  parseAttributeValue: false,
  trimValues: true,
  isArray: (name) =>
    ['InvoiceLine', 'TaxTotal', 'TaxSubtotal'].includes(name),
});

/**
 * Extrage textul unui nod, indiferent daca a fost parsat ca string simplu
 * sau ca obiect `{ '#text': ..., '@_attr': ... }` (cazul in care elementul
 * are si atribute si continut text). Nu inventeaza valori: intoarce `null`
 * daca nu exista text.
 */
function textOf(node) {
  if (node === undefined || node === null) return null;
  if (typeof node === 'string') {
    const t = node.trim();
    return t === '' ? null : t;
  }
  if (typeof node === 'object' && '#text' in node) {
    const t = node['#text'];
    if (typeof t !== 'string') return null;
    const trimmed = t.trim();
    return trimmed === '' ? null : trimmed;
  }
  return null;
}

function attrOf(node, attrName) {
  if (node && typeof node === 'object') {
    const v = node['@_' + attrName];
    return typeof v === 'string' && v.trim() !== '' ? v.trim() : null;
  }
  return null;
}

/**
 * Parseaza un numar zecimal STRICT (format XML xs:decimal: punct, nu
 * virgula). Intoarce `null` daca textul nu e un numar valid — NU incearca
 * sa "ghiceasca" formatul, per cerinta "nu inventa valori".
 */
function parseDecimal(str) {
  if (typeof str !== 'string') return null;
  const s = str.trim();
  if (!DECIMAL_RE.test(s)) return null;
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

function firstOfMaybeArray(value) {
  if (Array.isArray(value)) return value.length > 0 ? value[0] : undefined;
  return value;
}

function extractHeader(invoice) {
  const supplierParty = invoice.AccountingSupplierParty
    ? invoice.AccountingSupplierParty.Party || {}
    : {};
  const partyName = supplierParty.PartyName
    ? textOf(supplierParty.PartyName.Name)
    : null;
  const legalEntity = supplierParty.PartyLegalEntity || {};
  const taxScheme = supplierParty.PartyTaxScheme || {};

  const legalTotal = invoice.LegalMonetaryTotal || {};
  const taxTotalNode = firstOfMaybeArray(invoice.TaxTotal);

  return {
    invoiceNumber: textOf(invoice.ID),
    invoiceDate: textOf(invoice.IssueDate),
    currency: textOf(invoice.DocumentCurrencyCode),
    supplierName: partyName || textOf(legalEntity.RegistrationName),
    supplierTaxId: textOf(taxScheme.CompanyID) || textOf(legalEntity.CompanyID),
    totalWithoutVat: parseDecimal(textOf(legalTotal.TaxExclusiveAmount)),
    totalVat: taxTotalNode ? parseDecimal(textOf(taxTotalNode.TaxAmount)) : null,
  };
}

function extractLine(lineNode, lineIndex) {
  const item = lineNode.Item || {};
  const price = lineNode.Price || {};
  const warnings = [];

  // ID-ul declarat de furnizor pe linie (cbc:ID din InvoiceLine, ex. "1",
  // "2"...) — distinct de `lineIndex` (pozitia 0-based in document, folosita
  // intern pentru ordonare/id-uri de linie). Gasit lipsa la validarea pe
  // factura reala Romstal (FAZA 1 nu il extragea, desi era in specificatia
  // initiala "PENTRU FIECARE InvoiceLine: - ID").
  const sourceLineId = textOf(lineNode.ID);

  const qtyNode = lineNode.InvoicedQuantity;
  const quantity = parseDecimal(textOf(qtyNode));
  const unit = attrOf(qtyNode, 'unitCode');

  const lineExtNode = lineNode.LineExtensionAmount;
  const lineTotalNoVat = parseDecimal(textOf(lineExtNode));

  const priceAmount = parseDecimal(textOf(price.PriceAmount));
  const hasBaseQuantity = Object.prototype.hasOwnProperty.call(price, 'BaseQuantity');
  const baseQuantity = hasBaseQuantity ? parseDecimal(textOf(price.BaseQuantity)) : 1;

  let unitPriceNoVat = null;
  let unitPriceDerived = false;

  if (priceAmount !== null) {
    if (baseQuantity !== null && baseQuantity !== 0) {
      // UBL: Price/PriceAmount este pretul PENTRU BaseQuantity unitati, nu
      // neaparat pretul pe unitate fizica — vezi cerinta explicita FAZA 1
      // pct. 10: "daca Price/BaseQuantity e diferit de 1, nu presupune ca
      // PriceAmount este automat pretul per unitate fizica".
      unitPriceNoVat = priceAmount / baseQuantity;
      if (hasBaseQuantity && baseQuantity !== 1) {
        warnings.push(
          `Price/BaseQuantity=${baseQuantity} (diferit de 1) — pretul unitar a fost calculat ca PriceAmount / BaseQuantity.`,
        );
      }
    } else {
      warnings.push('Price/BaseQuantity invalid sau zero — pretul unitar nu a putut fi calculat din Price/PriceAmount.');
    }
  } else if (lineTotalNoVat !== null && quantity !== null && quantity !== 0) {
    // Fallback determinist: derivare din LineExtensionAmount / InvoicedQuantity
    // NUMAI cand Price/PriceAmount lipseste complet din XML.
    unitPriceNoVat = lineTotalNoVat / quantity;
    unitPriceDerived = true;
    warnings.push('Pret unitar derivat din LineExtensionAmount / InvoicedQuantity (Price/PriceAmount lipseste din XML).');
  } else {
    warnings.push('Pretul unitar fara TVA nu a putut fi determinat din XML.');
  }

  let vatRate = parseDecimal(textOf((item.ClassifiedTaxCategory || {}).Percent));
  if (vatRate === null) {
    const lineTaxTotal = firstOfMaybeArray(lineNode.TaxTotal);
    const subtotal = lineTaxTotal ? firstOfMaybeArray(lineTaxTotal.TaxSubtotal) : undefined;
    const taxCategory = subtotal ? subtotal.TaxCategory || {} : {};
    vatRate = parseDecimal(textOf(taxCategory.Percent));
  }
  if (vatRate === null) {
    warnings.push('Cota TVA nu a putut fi determinata din XML — camp lasat necompletat, nu a fost presupusa nicio valoare.');
  }

  const supplierProductCode =
    textOf((item.SellersItemIdentification || {}).ID) ||
    textOf((item.StandardItemIdentification || {}).ID) ||
    null;

  const rawName = textOf(item.Name);
  if (!rawName) {
    warnings.push('Denumirea produsului (Item/Name) lipseste din XML pentru aceasta linie.');
  }

  return {
    lineIndex,
    sourceLineId,
    rawName: rawName || '',
    supplierProductCode,
    unit,
    quantity,
    unitPriceNoVat,
    unitPriceDerived,
    vatRate,
    lineTotalNoVat,
    currency: attrOf(lineExtNode, 'currencyID'),
    warnings,
  };
}

/**
 * Parseaza un XML UBL Invoice (e-Factura) si intoarce header + linii.
 * Arunca `HttpsError('invalid-argument', ...)` pentru orice XML invalid sau
 * fara structura minima asteptata (nu incearca sa recupereze partial).
 */
function parseUblInvoiceXml(xmlText) {
  const validation = XMLValidator.validate(xmlText, { allowBooleanAttributes: true });
  if (validation !== true) {
    const detail = validation && validation.err ? validation.err.msg : 'format necunoscut';
    throw new HttpsError('invalid-argument', `XML invalid: ${detail}`);
  }

  let parsed;
  try {
    parsed = xmlParser.parse(xmlText);
  } catch (error) {
    throw new HttpsError('invalid-argument', `XML nu a putut fi parsat: ${error.message}`);
  }

  const invoice = parsed ? parsed.Invoice : null;
  if (!invoice || typeof invoice !== 'object') {
    throw new HttpsError(
      'invalid-argument',
      'Documentul nu este o factura UBL valida (element radacina asteptat: Invoice).',
    );
  }

  const rawLines = Array.isArray(invoice.InvoiceLine) ? invoice.InvoiceLine : [];
  if (rawLines.length === 0) {
    throw new HttpsError('invalid-argument', 'Factura nu contine nicio linie (InvoiceLine).');
  }

  const header = extractHeader(invoice);
  const lines = rawLines.map((lineNode, index) => extractLine(lineNode, index));

  return { header, lines };
}

/**
 * Functie PURA (fara acces Firestore) care decide autorizarea, pornind de
 * la datele deja citite. Separata de `requireAdminForInvoices`
 * special ca sa poata fi testata unitar (cazurile "neautentificat" /
 * "fara rol administrativ") fara Firebase Admin SDK / emulator.
 */
function evaluateInvoiceAuthorization({ hasAuth, uid, userExists, userData }) {
  if (!hasAuth || !uid) {
    return { authorized: false, code: 'unauthenticated', message: 'Autentificare necesara.' };
  }
  if (!userExists) {
    return { authorized: false, code: 'permission-denied', message: 'Cont inexistent sau inactiv.' };
  }
  const data = userData || {};
  const active = !('active' in data) || data.active === true;
  if (!active) {
    return { authorized: false, code: 'permission-denied', message: 'Cont inexistent sau inactiv.' };
  }
  const role = (data.role || '').toString().trim().toLowerCase();
  // STRICT ADMIN — FAZA 1.1 pct. 2: facturile furnizorilor si costurile
  // reale de achizitie sunt accesibile DOAR administratorului, nu si
  // rolului "office" (decizie explicita, diferita de restul categoriei A
  // din firestore.rules care e admin/office).
  if (role !== 'admin') {
    return {
      authorized: false,
      code: 'permission-denied',
      message: 'Doar administratorul poate importa facturi de la furnizori.',
    };
  }
  return { authorized: true, uid, role };
}

/**
 * Hash SHA-256 CANONIC al continutului XML — determina atat `invoiceId`
 * (numele documentului Firestore `supplier_invoices/{id}`, vezi
 * SupplierInvoiceRepository) cat si segmentul de path in Storage. Continut
 * diferit => hash diferit => path diferit, prin constructie (nu exista
 * cale prin care doua continuturi diferite sa ajunga la acelasi
 * invoiceId, in afara unei coliziuni SHA-256 — practic imposibil).
 */
function computeSourceFileHash(xmlContent) {
  return crypto.createHash('sha256').update(xmlContent, 'utf8').digest('hex');
}

/**
 * Path-ul Storage pentru XML-ul sursa — determinist, construit EXCLUSIV
 * din `uid` (din request.auth, verificat de requireAdminForInvoices) si
 * `invoiceId` (calculat de computeSourceFileHash mai sus). NU accepta
 * niciun input de la client pentru acest path.
 */
function buildSourceStoragePath(uid, invoiceId) {
  return `supplier_invoices/${uid}/${invoiceId}/source.xml`;
}

/**
 * Persista XML-ul sursa in Storage prin Admin SDK, IDEMPOTENT: daca
 * fisierul exista deja la path-ul determinist (aceeasi factura, reimportata
 * sau reparsata), NU il rescrie — doar confirma ca poate continua. `bucket`
 * e primit ca parametru (nu `admin.storage().bucket()` direct) special ca
 * sa poata fi inlocuit cu un fake in memorie la teste, fara emulator
 * Storage.
 */
async function persistSourceXmlIfNeeded({ bucket, storagePath, xmlContent }) {
  const file = bucket.file(storagePath);
  const [exists] = await file.exists();
  if (exists) {
    return { created: false, storagePath };
  }
  await file.save(Buffer.from(xmlContent, 'utf8'), {
    contentType: 'application/xml',
    resumable: false,
  });
  return { created: true, storagePath };
}

/**
 * Persista metadata facturii (`supplier_invoices/{invoiceId}`) + liniile
 * (subcolectia `lines`) in Firestore prin Admin SDK, IDEMPOTENT, intr-o
 * SINGURA tranzactie server-side (Admin SDK — NU e afectat de bug-ul
 * client-plugin `runTransaction()` pe Windows).
 *
 * Daca documentul exista deja: NU scrie nimic — citeste doar ID-urile
 * liniilor deja create (ordonate dupa `lineIndex`, deci in ACEEASI ordine
 * ca `lines` primit ca parametru — vezi nota de determinism din
 * header-ul fisierului) si le intoarce, ca sa poata fi asociate cu
 * liniile proaspat parsate de apelant. `linkedJobIds`/`status` raman
 * exact cum au fost lasate de fluxul de alocare in lucrare.
 *
 * Daca NU exista: creeaza documentul + toate liniile, atomic.
 */
async function persistInvoiceMetadataIfNeeded({
  db,
  invoiceId,
  uid,
  header,
  lines,
  storagePath,
}) {
  const invoiceRef = db.collection('supplier_invoices').doc(invoiceId);

  return db.runTransaction(async (transaction) => {
    const existingSnap = await transaction.get(invoiceRef);
    if (existingSnap.exists) {
      const linesSnap = await invoiceRef
        .collection('lines')
        .orderBy('lineIndex')
        .get();
      return {
        created: false,
        lineDocIds: linesSnap.docs.map((doc) => doc.id),
      };
    }

    transaction.set(invoiceRef, {
      id: invoiceId,
      supplierName: header.supplierName,
      supplierTaxId: header.supplierTaxId,
      invoiceNumber: header.invoiceNumber,
      invoiceDate: header.invoiceDate,
      sourceType: 'xmlEInvoice',
      sourceFileStoragePath: storagePath,
      sourceFileHash: invoiceId,
      importedByUserId: uid,
      importedAt: admin.firestore.FieldValue.serverTimestamp(),
      currency: header.currency,
      totalWithoutVat: header.totalWithoutVat,
      totalVat: header.totalVat,
      status: 'parsed',
      linkedJobIds: [],
    });

    const linesRef = invoiceRef.collection('lines');
    const lineDocIds = [];
    for (const line of lines) {
      const lineDoc = linesRef.doc();
      lineDocIds.push(lineDoc.id);
      const lineData = {
        id: lineDoc.id,
        lineIndex: line.lineIndex,
        rawName: line.rawName,
        supplierProductCode: line.supplierProductCode,
        unit: line.unit,
        quantity: line.quantity,
        unitPriceNoVat: line.unitPriceNoVat,
        unitPriceDerived: line.unitPriceDerived,
        vatRate: line.vatRate,
        lineTotalNoVat: line.lineTotalNoVat,
        currency: line.currency,
      };
      if (line.sourceLineId !== null && line.sourceLineId !== undefined) {
        lineData.sourceLineId = line.sourceLineId;
      }
      transaction.set(lineDoc, lineData);
    }

    return { created: true, lineDocIds };
  });
}

async function requireAdminForInvoices(request) {
  const auth = request && request.auth ? request.auth : null;
  const uid = auth ? (auth.uid || '').toString().trim() : '';
  const hasAuth = Boolean(auth && uid);

  let userExists = false;
  let userData = {};
  if (hasAuth) {
    // Citire directa users/{uid} — acelasi document pe care se bazeaza
    // isAdminOrOffice() din firestore.rules. Nu introduce un RBAC nou.
    const snap = await admin.firestore().collection('users').doc(uid).get();
    userExists = snap.exists;
    userData = snap.exists ? snap.data() || {} : {};
  }

  const result = evaluateInvoiceAuthorization({ hasAuth, uid, userExists, userData });
  if (!result.authorized) {
    throw new HttpsError(result.code, result.message);
  }
  return { uid: result.uid, role: result.role };
}

exports.parseSupplierInvoiceXml = onCall(
  { region: 'europe-west1' },
  async (request) => {
    const startedAtMs = Date.now();
    const { uid } = await requireAdminForInvoices(request);

    const data = request.data || {};
    const xmlContent = data.xmlContent;

    if (typeof xmlContent !== 'string' || xmlContent.trim() === '') {
      throw new HttpsError('invalid-argument', 'xmlContent (text XML) este obligatoriu.');
    }

    const byteLength = Buffer.byteLength(xmlContent, 'utf8');
    if (byteLength > MAX_XML_BYTES) {
      throw new HttpsError(
        'invalid-argument',
        `Fisierul XML depaseste limita permisa de ${MAX_XML_BYTES} bytes.`,
      );
    }

    let result;
    try {
      result = parseUblInvoiceXml(xmlContent);
    } catch (error) {
      const durationMs = Date.now() - startedAtMs;
      // NU logam continutul XML-ului, denumiri de produse, CUI sau alte
      // date fiscale — doar informatii tehnice (cerinta FAZA 1 pct. 18).
      logger.warn('parseSupplierInvoiceXml failed', {
        durationMs,
        errorCode: error instanceof HttpsError ? error.code : 'internal',
      });
      throw error;
    }

    // FAZA A-E/1-13 — persistare server-side a XML-ului sursa in Storage,
    // DUPA parsare cu succes. invoiceId/path sunt calculate exclusiv aici
    // (vezi computeSourceFileHash/buildSourceStoragePath) — clientul NU
    // trimite si NU poate influenta path-ul. Esec de persistare => eroare
    // fatala (NU intoarcem un rezultat de parsare "de succes" care ar duce
    // clientul sa creada gresit ca sursa e salvata in Storage).
    const invoiceId = computeSourceFileHash(xmlContent);
    const storagePath = buildSourceStoragePath(uid, invoiceId);
    try {
      await persistSourceXmlIfNeeded({
        bucket: admin.storage().bucket(),
        storagePath,
        xmlContent,
      });
    } catch (storageError) {
      logger.error('parseSupplierInvoiceXml: persist source.xml failed', {
        durationMs: Date.now() - startedAtMs,
        invoiceId,
        errorMessage: storageError && storageError.message,
      });
      throw new HttpsError(
        'internal',
        'Nu am putut salva factura sursa. Incearca din nou.',
      );
    }

    // FAZA "persist invoice metadata server-side" — dupa ce sursa e
    // confirmat persistata in Storage (pasul de mai sus, mereu executat
    // primul — vezi nota de ordine din header-ul fisierului), persistam
    // metadata facturii + liniile in Firestore. Esec => eroare fatala
    // (NU intoarcem un rezultat "de succes" care ar lasa clientul sa
    // creada gresit ca factura/liniile exista in Firestore).
    let metadataResult;
    try {
      metadataResult = await persistInvoiceMetadataIfNeeded({
        db: admin.firestore(),
        invoiceId,
        uid,
        header: result.header,
        lines: result.lines,
        storagePath,
      });
    } catch (firestoreError) {
      logger.error('parseSupplierInvoiceXml: persist invoice metadata failed', {
        durationMs: Date.now() - startedAtMs,
        invoiceId,
        errorMessage: firestoreError && firestoreError.message,
      });
      throw new HttpsError(
        'internal',
        'Nu am putut salva metadata facturii. Incearca din nou.',
      );
    }

    // Header-ul/liniile raspunsului vin din parsarea CURENTA — determinist
    // identice cu ce e stocat (acelasi invoiceId => acelasi continut, vezi
    // header-ul fisierului) — doar `lineDocId` provine din rezultatul
    // persistarii (nou creat sau deja existent).
    const linesWithDocIds = result.lines.map((line, index) => ({
      ...line,
      lineDocId: metadataResult.lineDocIds[index],
    }));

    const durationMs = Date.now() - startedAtMs;
    logger.info('parseSupplierInvoiceXml succeeded', {
      durationMs,
      lineCount: result.lines.length,
      invoiceId,
      invoiceCreated: metadataResult.created,
    });

    return {
      ok: true,
      header: result.header,
      lines: linesWithDocIds,
      invoiceId,
      storagePath,
      sourcePersisted: true,
      invoicePersisted: true,
    };
  },
);

// Exportate separat pentru teste unitare (node:test) — nu sunt inregistrate
// ca Cloud Functions.
exports._internal = {
  parseUblInvoiceXml,
  parseDecimal,
  textOf,
  attrOf,
  evaluateInvoiceAuthorization,
  MAX_XML_BYTES,
  computeSourceFileHash,
  buildSourceStoragePath,
  persistSourceXmlIfNeeded,
  persistInvoiceMetadataIfNeeded,
};
