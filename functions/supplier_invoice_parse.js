'use strict';

// FAZA 1 — Import materiale din factura: parser XML e-Factura (UBL Invoice).
//
// Modul IZOLAT, NOU. NU scrie in `jobs`, NU scrie in `materials`, NU scrie
// in catalogul de produse. NU persista nimic in Firestore/Storage — este
// STATELESS: primeste text XML, intoarce JSON structurat cu antetul si
// liniile facturii, pentru afisare intr-un ecran de verificare in aplicatie.
// Persistarea facturii (dupa ce utilizatorul verifica/editeaza in preview)
// se face separat, client-side, prin scriere Firestore directa in
// `supplier_invoices` (protejata de firestore.rules, vezi acel fisier).
//
// De ce STATELESS: o parsare esuata sau anulata de utilizator nu trebuie sa
// lase niciun document partial in Firestore care ar necesita curatare
// manuala ulterior. Singurul lucru care poate esua aici este intoarcerea
// unei erori catre client — nu exista nicio scriere de curatat.

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
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
    await requireAdminForInvoices(request);

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

    const durationMs = Date.now() - startedAtMs;
    logger.info('parseSupplierInvoiceXml succeeded', {
      durationMs,
      lineCount: result.lines.length,
    });

    return {
      ok: true,
      header: result.header,
      lines: result.lines,
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
};
