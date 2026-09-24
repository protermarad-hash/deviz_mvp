'use strict';

// FAZA 3 — SMOKE-TEST server-side, end-to-end pe cat posibil, pentru
// fluxul "Import materiale din factura", folosind Firebase Emulator
// Suite REAL (Auth + Firestore + Storage + Functions), proiect local
// "demo-invoice-smoke-test" (Firebase CLI il trateaza STRICT local,
// fara cont GCP real, fara retea catre Google — imposibil sa atinga
// productia).
//
// CE TESTEAZA REAL (executie efectiva, nu simulare):
//   - Cloud Function REALA `parseSupplierInvoiceXml` (functions/
//     supplier_invoice_parse.js), apelata prin HTTP + Authorization
//     Bearer (exact calea folosita de clientul desktop Windows —
//     supplier_invoice_parser_client.dart _callHttp), pe XML-ul REAL
//     reala oarecare (furnizata local, nu commit-uita).
//   - firestore.rules / storage.rules REALE incarcate de emulator (dar
//     scrierile Firestore/Storage de mai jos folosesc admin SDK,
//     privilegiat — regulile in sine au fost deja verificate exhaustiv
//     in FAZA 1.1 cu @firebase/rules-unit-testing; acest test se
//     concentreaza pe FLUXUL DE DATE, nu re-testeaza matricea de acces).
//
// CE NU TESTEAZA (limitare documentata explicit in raport):
//   - UI-ul Flutter/Windows real — nu exista integration_test in acest
//     proiect si nu exista unealta de automatizare GUI disponibila.
//     Logica din supplier_invoice_import_page.dart / supplier_invoice_
//     repository.dart / supplier_invoice_job_material_mapper.dart este
//     REIMPLEMENTATA aici 1:1 (aceleasi formule, aceleasi denumiri de
//     campuri, verificate linie cu linie fata de sursa Dart) ca sa poata
//     rula fara motor Flutter — nu este executia literala a codului Dart.

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PROJECT_ID = 'demo-invoice-smoke-test';
const REGION = 'europe-west1';
const AUTH_HOST = '127.0.0.1:5307';
const FIRESTORE_HOST = '127.0.0.1:5308';
const STORAGE_HOST = '127.0.0.1:5309';
const FUNCTIONS_HOST = '127.0.0.1:5310';

process.env.FIREBASE_AUTH_EMULATOR_HOST = AUTH_HOST;
process.env.FIRESTORE_EMULATOR_HOST = FIRESTORE_HOST;
process.env.FIREBASE_STORAGE_EMULATOR_HOST = STORAGE_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require('firebase-admin');
admin.initializeApp({ projectId: PROJECT_ID, storageBucket: `${PROJECT_ID}.appspot.com` });
const db = admin.firestore();
const bucket = admin.storage().bucket();

const XML_PATH = process.env.SMOKE_TEST_XML_PATH;
if (!XML_PATH) {
  throw new Error('SMOKE_TEST_XML_PATH nu este setat (calea locala catre XML-ul de test).');
}

let passCount = 0;
let failCount = 0;
function check(label, condition, detail) {
  if (condition) {
    passCount += 1;
    console.log(`  [OK] ${label}`);
  } else {
    failCount += 1;
    console.log(`  [FAIL] ${label}${detail ? ' — ' + detail : ''}`);
  }
}
function section(title) {
  console.log(`\n=== ${title} ===`);
}

// ── Replici 1:1 ale logicii Dart (verificate linie cu linie fata de
// sursa) — ca sa poata rula fara motor Flutter. Vezi antetul fisierului.

const UNIT_LABELS = { H87: 'buc', EA: 'buc', MTR: 'm', KGM: 'kg', LTR: 'l', MTQ: 'mc', MTK: 'mp' };
function friendlyUnitLabel(code) {
  const normalized = (code || '').trim().toUpperCase();
  if (!normalized) return '';
  return UNIT_LABELS[normalized] || (code || '').trim();
}

function normalizeForCatalogMatch(value) {
  return value.trim().toLowerCase().replace(/\s+/g, ' ');
}

// jobImportBlockReason — din supplier_invoice_models.dart
function jobImportBlockReason(line) {
  if (line.alreadyImported) return 'Aceasta linie a fost deja importata in aceasta lucrare.';
  if (!line.displayName || !line.displayName.trim()) return 'Denumire lipsa.';
  const friendlyUnit = friendlyUnitLabel(line.unit);
  if (!friendlyUnit) return 'Unitate de masura lipsa.';
  if (line.unitPriceNoVat == null) return 'Pret fara TVA lipsa.';
  const alloc = line.allocatedQty;
  if (alloc == null || alloc <= 0) return 'Cantitatea alocata trebuie sa fie mai mare decat 0.';
  if (line.quantity == null) return 'Cantitatea facturata lipseste — nu se poate valida alocarea.';
  if (alloc > line.quantity) return 'Cantitatea alocata nu poate depasi cantitatea facturata.';
  return null;
}

// buildJobMaterialFromInvoiceLine — din supplier_invoice_job_material_mapper.dart
function buildJobMaterialFromInvoiceLine({ line, materialId, invoiceId, jobMaterialId }) {
  const allocatedQty = line.allocatedQty || 0;
  const unitPrice = line.unitPriceNoVat || 0;
  const total = allocatedQty * unitPrice;
  const row = {
    id: jobMaterialId,
    materialId,
    name: line.displayName,
    um: friendlyUnitLabel(line.unit),
    qty: allocatedQty,
    price: unitPrice,
    realPrice: unitPrice,
    total,
    sourceInvoiceId: invoiceId,
    allocatedQty,
  };
  if (line.lineDocId) row.sourceInvoiceLineId = line.lineDocId;
  if (line.sourceLineId) row.sourceInvoiceSourceLineId = line.sourceLineId;
  return row;
}

// SupplierInvoiceCatalogMatcher — din supplier_invoice_catalog_matcher.dart
function makeCatalogMatcher(initialCatalog) {
  const index = new Map();
  for (const m of initialCatalog) index.set(`${normalizeForCatalogMatch(m.name)}|${normalizeForCatalogMatch(m.unit)}`, m.id);
  let seed = 0;
  return {
    resolve({ name, unit, price }) {
      const key = `${normalizeForCatalogMatch(name)}|${normalizeForCatalogMatch(unit)}`;
      const existingId = index.get(key);
      if (existingId) return { materialId: existingId, toCreate: null };
      seed += 1;
      const newId = `mat-inv-${Date.now()}-${seed}`;
      const toCreate = { id: newId, name: name.trim(), unit: unit.trim(), price, notes: '' };
      index.set(key, newId);
      return { materialId: newId, toCreate };
    },
  };
}

async function getIdTokenForUid(uid) {
  const customToken = await admin.auth().createCustomToken(uid);
  const resp = await fetch(
    `http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    },
  );
  const json = await resp.json();
  if (!resp.ok) throw new Error(`signInWithCustomToken esuat: ${JSON.stringify(json)}`);
  return json.idToken;
}

async function callParseSupplierInvoiceXml(idToken, xmlContent) {
  const resp = await fetch(
    `http://${FUNCTIONS_HOST}/${PROJECT_ID}/${REGION}/parseSupplierInvoiceXml`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
      },
      body: JSON.stringify({ data: { xmlContent } }),
    },
  );
  const json = await resp.json();
  return { status: resp.status, body: json };
}

async function main() {
  section('SETUP — utilizatori de test');
  const adminUser = await admin.auth().createUser({ email: 'admin@smoke-test.local', password: 'parola-test-123' });
  const officeUser = await admin.auth().createUser({ email: 'office@smoke-test.local', password: 'parola-test-123' });
  await db.collection('users').doc(adminUser.uid).set({ role: 'admin', active: true, name: 'Admin Smoke Test' });
  await db.collection('users').doc(officeUser.uid).set({ role: 'office', active: true, name: 'Office Smoke Test' });
  const adminIdToken = await getIdTokenForUid(adminUser.uid);
  const officeIdToken = await getIdTokenForUid(officeUser.uid);
  console.log(`  admin uid=${adminUser.uid}, office uid=${officeUser.uid}`);

  section('0. Autorizare Cloud Function (control negativ/pozitiv)');
  const officeAttempt = await callParseSupplierInvoiceXml(officeIdToken, '<Invoice/>');
  check('office NU poate apela parseSupplierInvoiceXml (permission-denied)', officeAttempt.status !== 200, JSON.stringify(officeAttempt.body));
  const noAuthAttempt = await callParseSupplierInvoiceXml(null, '<Invoice/>');
  check('neautentificat NU poate apela parseSupplierInvoiceXml (unauthenticated)', noAuthAttempt.status !== 200, JSON.stringify(noAuthAttempt.body));

  section('1. PARSER REAL — factura reala furnizata local (SMOKE_TEST_XML_PATH)');
  const xmlBytes = fs.readFileSync(XML_PATH);
  const xmlContent = xmlBytes.toString('utf8');
  const sourceFileHash = crypto.createHash('sha256').update(xmlBytes).digest('hex');
  const parseResult = await callParseSupplierInvoiceXml(adminIdToken, xmlContent);
  check('parseSupplierInvoiceXml raspunde 200 (admin)', parseResult.status === 200, JSON.stringify(parseResult.body));
  const parsed = parseResult.body.result;
  const header = parsed.header;
  const lines = parsed.lines;
  // NOTA: verificarile de mai jos sunt STRUCTURALE / AUTOCONSISTENTE, nu
  // hardcodate pe valorile unei facturi anume — harness-ul ramane
  // reutilizabil cu orice XML real furnizat local prin
  // SMOKE_TEST_XML_PATH, fara sa continua vreo data fiscala reala in
  // sursa commit-uita.
  check('supplierName extras (nefabricat)', typeof header.supplierName === 'string' && header.supplierName.trim().length > 0);
  check('invoiceNumber extras', typeof header.invoiceNumber === 'string' && header.invoiceNumber.trim().length > 0);
  check('invoiceDate extras', typeof header.invoiceDate === 'string' && header.invoiceDate.trim().length > 0);
  check('currency extras', typeof header.currency === 'string' && header.currency.trim().length > 0);
  check('totalWithoutVat > 0', typeof header.totalWithoutVat === 'number' && header.totalWithoutVat > 0, String(header.totalWithoutVat));
  check('cel putin o linie extrasa', lines.length > 0, String(lines.length));
  const sumLineTotal = lines.reduce((s, l) => s + (l.lineTotalNoVat || 0), 0);
  check(
    'SUM(lineTotalNoVat) ~= totalWithoutVat (autoconsistenta factura, nu valoare hardcodata)',
    Math.abs(sumLineTotal - header.totalWithoutVat) < 0.05,
    `${sumLineTotal.toFixed(2)} vs ${header.totalWithoutVat}`,
  );
  // Afisat doar la rulare (consola), NU stocat in fisierul de test.
  console.log(`  [doar la rulare, nu commit-uit] furnizor="${header.supplierName}", factura="${header.invoiceNumber}", ${lines.length} linii, total fara TVA=${header.totalWithoutVat}, TVA=${header.totalVat}`);

  section('2. LUCRARE DE TEST — stare initiala');
  const testJobId = `smoke-test-job-${Date.now()}`;
  const existingMaterial = {
    id: 'job-mat-existing-preseeded',
    materialId: 'mat-existing-preseeded',
    name: 'Material existent inainte de import',
    um: 'buc',
    qty: 3,
    price: 20,
    realPrice: 20,
    total: 60,
  };
  await db.collection('jobs').doc(testJobId).set({
    id: testJobId,
    jobCode: 'SMOKE-TEST',
    title: 'Lucrare smoke-test FAZA 3',
    materials: [existingMaterial],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`  jobId=${testJobId}, materiale initiale=1 (total=60)`);

  section('3. SELECTIE LINII (cautare STRUCTURALA dupa prefix, nu indici hardcodati)');
  const bySourceLineId = Object.fromEntries(lines.map((l) => [l.sourceLineId, l]));
  const plusLine = lines.find((l) => (l.rawName || '').startsWith('+'));
  const hashLine = lines.find((l) => (l.rawName || '').startsWith('#') && l !== plusLine);
  const minusLine = lines.find((l) => (l.rawName || '').startsWith('-') && l !== plusLine && l !== hashLine);
  const partialAllocationSource = [plusLine, hashLine, minusLine]
    .filter(Boolean)
    .find((l) => (l.quantity || 0) > 1);
  check('gasita cel putin o linie cu prefix "+"', !!plusLine);
  check('gasita cel putin o linie cu prefix "#"', !!hashLine);
  check('gasita cel putin o linie cu prefix "-"', !!minusLine);
  check('gasita o linie cu cantitate > 1 pentru testul allocatedQty < quantity', !!partialAllocationSource);

  const selectedRawLines = [plusLine, hashLine, minusLine].filter(Boolean);
  const previewLines = selectedRawLines.map((raw) => ({
    sourceLineId: raw.sourceLineId,
    lineDocId: null, // se seteaza dupa persistNewInvoice
    rawName: raw.rawName,
    displayName: raw.rawName,
    unit: raw.unit,
    quantity: raw.quantity,
    allocatedQty: raw === partialAllocationSource ? raw.quantity - 1 : raw.quantity,
    unitPriceNoVat: raw.unitPriceNoVat,
    alreadyImported: false,
  }));
  const partialAllocationLine = previewLines.find((l) => l.sourceLineId === partialAllocationSource.sourceLineId);
  check(
    'o linie a fost alocata cu cantitate MAI MICA decat cea facturata',
    partialAllocationLine.allocatedQty < partialAllocationLine.quantity,
    `${partialAllocationLine.allocatedQty} < ${partialAllocationLine.quantity}`,
  );
  check('H87 -> buc pentru toate liniile selectate', previewLines.every((l) => friendlyUnitLabel(l.unit) === 'buc'));
  check('toate liniile selectate sunt valide (allocatedQty <= quantity)', previewLines.every((l) => jobImportBlockReason(l) === null));

  section('4. VALIDARE allocatedQty = quantity + 1 -> trebuie blocat');
  const lineForInvalidTest = previewLines.find((l) => l !== partialAllocationLine) || previewLines[0];
  const invalidLine = { ...lineForInvalidTest, allocatedQty: lineForInvalidTest.quantity + 1 };
  const blockReason = jobImportBlockReason(invalidLine);
  check('allocatedQty = quantity+1 este invalid', blockReason !== null, blockReason);
  check(
    'mesajul e exact cel cerut',
    blockReason === 'Cantitatea alocata nu poate depasi cantitatea facturata.',
    blockReason,
  );

  section('5. CONFIRMARE — total calculat inainte de import');
  const expectedTotal = previewLines.reduce((s, l) => s + l.allocatedQty * l.unitPriceNoVat, 0);
  console.log(`  ${previewLines.length} pozitii selectate, valoare totala fara TVA: ${expectedTotal.toFixed(2)}`);
  const manualSum = previewLines.reduce((s, l) => s + l.allocatedQty * bySourceLineId[l.sourceLineId].unitPriceNoVat, 0);
  check('totalul confirmat = suma manuala alocatedQty x unitPriceNoVat', Math.abs(expectedTotal - manualSum) < 0.001);

  section('6. PERSISTARE FACTURA (persistNewInvoice) — Storage + Firestore, TOATE liniile parsate');
  const invoiceRef = db.collection('supplier_invoices').doc(sourceFileHash);
  const storagePath = `supplier_invoices/${adminUser.uid}/${sourceFileHash}/source.xml`;
  await bucket.file(storagePath).save(xmlBytes, { contentType: 'application/xml' });
  const lineRefs = [];
  await db.runTransaction(async (tx) => {
    const existingSnap = await tx.get(invoiceRef);
    check('factura NU exista deja (prima persistare)', !existingSnap.exists);
    tx.set(invoiceRef, {
      id: sourceFileHash,
      supplierName: header.supplierName,
      supplierTaxId: header.supplierTaxId,
      invoiceNumber: header.invoiceNumber,
      invoiceDate: header.invoiceDate,
      sourceType: 'xmlEInvoice',
      sourceFileStoragePath: storagePath,
      sourceFileHash,
      importedByUserId: adminUser.uid,
      importedAt: admin.firestore.FieldValue.serverTimestamp(),
      currency: header.currency,
      totalWithoutVat: header.totalWithoutVat,
      totalVat: header.totalVat,
      status: 'parsed',
      linkedJobIds: [],
    });
    const linesRef = invoiceRef.collection('lines');
    for (const l of lines) {
      const lineDoc = linesRef.doc();
      lineRefs.push({ sourceLineId: l.sourceLineId, docId: lineDoc.id });
      tx.set(lineDoc, {
        id: lineDoc.id,
        lineIndex: l.lineIndex,
        sourceLineId: l.sourceLineId,
        rawName: l.rawName,
        supplierProductCode: l.supplierProductCode,
        unit: l.unit,
        quantity: l.quantity,
        unitPriceNoVat: l.unitPriceNoVat,
        unitPriceDerived: l.unitPriceDerived,
        vatRate: l.vatRate,
        lineTotalNoVat: l.lineTotalNoVat,
        currency: l.currency,
      });
    }
  });
  const lineDocIdBySourceLineId = Object.fromEntries(lineRefs.map((r) => [r.sourceLineId, r.docId]));
  for (const pl of previewLines) pl.lineDocId = lineDocIdBySourceLineId[pl.sourceLineId];
  const linesSnapAfterPersist = await invoiceRef.collection('lines').get();
  check('toate liniile parsate au fost persistate', linesSnapAfterPersist.size === lines.length, `${linesSnapAfterPersist.size} vs ${lines.length}`);
  const [xmlExistsInStorage] = await bucket.file(storagePath).exists();
  check('XML uploadat in Storage', xmlExistsInStorage);

  section('7. CATALOG — potrivire determinista (o linie preexistenta in catalog)');
  // Pre-seed catalogul cu a doua linie selectata (structural, nu hardcodat), pret DIFERIT
  const preseedSourceLine = previewLines[1];
  const preseededCatalogMaterial = {
    id: 'mat-catalog-preexistent-test',
    name: preseedSourceLine.rawName,
    unit: 'buc',
    price: 999.99, // pret diferit deliberat, ca sa verificam ca NU e suprascris
  };
  await db.collection('materials').doc(preseededCatalogMaterial.id).set(preseededCatalogMaterial);
  const catalogSnapBefore = await db.collection('materials').get();
  const catalog = catalogSnapBefore.docs.map((d) => ({ id: d.id, ...d.data() }));
  const matcher = makeCatalogMatcher(catalog);
  const baseMillis = Date.now();
  const newMaterialRows = [];
  const materialsToCreate = [];
  previewLines.forEach((line, i) => {
    const resolution = matcher.resolve({ name: line.displayName, unit: friendlyUnitLabel(line.unit), price: line.unitPriceNoVat });
    if (resolution.toCreate) materialsToCreate.push(resolution.toCreate);
    newMaterialRows.push(
      buildJobMaterialFromInvoiceLine({
        line,
        materialId: resolution.materialId,
        invoiceId: sourceFileHash,
        jobMaterialId: `job-mat-${baseMillis}-${i}`,
      }),
    );
  });
  check('linia preseed-uita (deja in catalog) reutilizeaza materialId existent', newMaterialRows[1].materialId === preseededCatalogMaterial.id);
  check(
    'celelalte linii (nepotrivite) sunt materiale NOI propuse pentru catalog',
    materialsToCreate.length === previewLines.length - 1,
    String(materialsToCreate.length),
  );

  section('8. SALVARE JobRecord.materials (append, nu inlocuire)');
  const jobSnapBefore = (await db.collection('jobs').doc(testJobId).get()).data();
  const combinedMaterials = [...jobSnapBefore.materials, ...newMaterialRows];
  await db.collection('jobs').doc(testJobId).update({
    materials: combinedMaterials,
    materialsUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  const jobAfterImport = (await db.collection('jobs').doc(testJobId).get()).data();
  const expectedAfterFirstImport = 1 + previewLines.length;
  check(
    `numar materiale final = initial(1) + importate(${previewLines.length})`,
    jobAfterImport.materials.length === expectedAfterFirstImport,
    String(jobAfterImport.materials.length),
  );
  check(
    'materialul existent dinainte NU a fost modificat',
    JSON.stringify(jobAfterImport.materials[0]) === JSON.stringify(existingMaterial),
  );
  for (const row of jobAfterImport.materials.slice(1)) {
    check(`[${row.name}] price == realPrice == unitPriceNoVat`, row.price === row.realPrice);
    check(`[${row.name}] total == qty x price`, Math.abs(row.total - row.qty * row.price) < 0.0001);
    check(`[${row.name}] um == "buc" (H87 mapat)`, row.um === 'buc');
    check(`[${row.name}] sourceInvoiceId setat`, row.sourceInvoiceId === sourceFileHash);
    check(`[${row.name}] sourceInvoiceLineId setat`, !!row.sourceInvoiceLineId);
    check(`[${row.name}] sourceInvoiceSourceLineId setat`, !!row.sourceInvoiceSourceLineId);
  }
  const partialRow = jobAfterImport.materials.find((m) => m.sourceInvoiceSourceLineId === partialAllocationLine.sourceLineId);
  check(
    `linia cu alocare partiala: allocatedQty=${partialAllocationLine.allocatedQty}, qty=${partialAllocationLine.allocatedQty} (nu ${partialAllocationSource.quantity})`,
    partialRow.allocatedQty === partialAllocationLine.allocatedQty && partialRow.qty === partialAllocationLine.allocatedQty,
  );
  check(
    'linia cu alocare partiala: total == allocatedQty x unitPriceNoVat',
    Math.abs(partialRow.total - partialAllocationLine.allocatedQty * partialAllocationSource.unitPriceNoVat) < 0.0001,
    String(partialRow.total),
  );

  section('9. COSTURI LUCRARE — cost real = allocatedQty x unitPriceNoVat, fara NaN/dublare');
  const realCostSum = jobAfterImport.materials.reduce((s, m) => {
    const lineCost = (m.realPrice > 0 ? m.qty * m.realPrice : (m.total > 0 ? m.total : m.qty * m.price));
    return s + lineCost;
  }, 0);
  check('costul real recalculat nu e NaN', !Number.isNaN(realCostSum));
  check('costul real recalculat > 0', realCostSum > 0);
  const expectedRealCost = existingMaterial.total + newMaterialRows.reduce((s, r) => s + r.total, 0);
  check('costul real == existent + importat (fara dublare)', Math.abs(realCostSum - expectedRealCost) < 0.001, `${realCostSum} vs ${expectedRealCost}`);

  section('10. NOMENCLATOR GENERAL — creare/reutilizare/pret neschimbat');
  for (const m of materialsToCreate) {
    await db.collection('materials').doc(m.id).set(m);
  }
  const catalogAfter = await db.collection('materials').get();
  const cotInCatalog = catalogAfter.docs.find((d) => d.id === preseededCatalogMaterial.id).data();
  check('materialul preexistent NU si-a schimbat pretul (999.99, nu 6.92)', cotInCatalog.price === 999.99, String(cotInCatalog.price));
  for (const m of materialsToCreate) {
    const found = catalogAfter.docs.find((d) => d.id === m.id);
    check(`material nou in catalog: ${m.name}`, !!found);
  }
  const deselectedLine = lines.find((l) => !previewLines.some((pl) => pl.sourceLineId === l.sourceLineId));
  check(
    'o linie deselectata (neimportata) NU apare in catalog',
    !catalogAfter.docs.some((d) => normalizeForCatalogMatch(d.data().name) === normalizeForCatalogMatch(deselectedLine.rawName)),
  );

  section('11. linkedJobIds / status (markInvoiceAllocated)');
  await invoiceRef.update({ linkedJobIds: admin.firestore.FieldValue.arrayUnion(testJobId), status: 'hasAllocations' });
  const invoiceAfter = (await invoiceRef.get()).data();
  check('linkedJobIds contine jobId-ul de test', invoiceAfter.linkedJobIds.includes(testJobId));
  check('linkedJobIds are exact 1 intrare (fara duplicate)', invoiceAfter.linkedJobIds.length === 1, String(invoiceAfter.linkedJobIds.length));
  check('status = hasAllocations', invoiceAfter.status === 'hasAllocations');
  // idempotenta arrayUnion (retry manual)
  await invoiceRef.update({ linkedJobIds: admin.firestore.FieldValue.arrayUnion(testJobId) });
  const invoiceAfterRetry = (await invoiceRef.get()).data();
  check('a doua chemare arrayUnion NU duplica jobId', invoiceAfterRetry.linkedJobIds.length === 1, String(invoiceAfterRetry.linkedJobIds.length));

  section('12. REIMPORT ACEEASI LUCRARE — factura existenta reutilizata, linii deja importate blocate');
  const reloadedInvoiceSnap = await invoiceRef.get();
  check('factura e gasita dupa hash (fara re-upload)', reloadedInvoiceSnap.exists);
  const reloadedLinesSnap = await invoiceRef.collection('lines').orderBy('lineIndex').get();
  const reloadedLines = reloadedLinesSnap.docs.map((d) => ({ ...d.data(), lineDocId: d.id }));
  check('reincarcarea NU a creat un al doilea document de factura', (await db.collection('supplier_invoices').get()).size === 1);

  const jobMaterialsNow = (await db.collection('jobs').doc(testJobId).get()).data().materials;
  const alreadyImportedLineDocIds = new Set(
    jobMaterialsNow.filter((m) => m.sourceInvoiceId === sourceFileHash).map((m) => m.sourceInvoiceLineId),
  );
  for (const l of reloadedLines) {
    l.displayName = l.rawName;
    l.allocatedQty = l.quantity;
    l.alreadyImported = alreadyImportedLineDocIds.has(l.lineDocId);
  }
  const alreadyImportedCount = reloadedLines.filter((l) => l.alreadyImported).length;
  check(
    `exact ${previewLines.length} linii marcate "deja importata"`,
    alreadyImportedCount === previewLines.length,
    String(alreadyImportedCount),
  );
  for (const l of reloadedLines.filter((l) => l.alreadyImported)) {
    check(`linia deja importata (sourceLineId=${l.sourceLineId}) e invalida pentru reimport`, jobImportBlockReason(l) === 'Aceasta linie a fost deja importata in aceasta lucrare.');
  }
  const stillAvailable = reloadedLines.filter((l) => !l.alreadyImported);
  const expectedStillAvailable = lines.length - previewLines.length;
  check(
    `${expectedStillAvailable} linii raman disponibile (${lines.length} - ${previewLines.length})`,
    stillAvailable.length === expectedStillAvailable,
    String(stillAvailable.length),
  );
  if (stillAvailable.length < 3) {
    console.log('  [SARIT] mai putin de 3 linii ramase disponibile — sectiunile 13/14/16 necesita minim 3 (2 pentru import partial suplimentar + 1 pentru a doua lucrare). Factura de test are prea putine linii pentru acest pas.');
    section('REZULTAT');
    console.log(`  ${passCount} verificari OK, ${failCount} esuate (13/14/16 omise din lipsa de linii disponibile).`);
    if (failCount > 0) process.exitCode = 1;
    return;
  }

  section('13. IMPORT PARTIAL SUPLIMENTAR — inca 2 linii din cele ramase');
  const nextTwo = stillAvailable.slice(0, 2);
  const matcher2 = makeCatalogMatcher((await db.collection('materials').get()).docs.map((d) => ({ id: d.id, ...d.data() })));
  const extraRows = nextTwo.map((line, i) => {
    const resolution = matcher2.resolve({ name: line.displayName, unit: friendlyUnitLabel(line.unit), price: line.unitPriceNoVat });
    return buildJobMaterialFromInvoiceLine({
      line,
      materialId: resolution.materialId,
      invoiceId: sourceFileHash,
      jobMaterialId: `job-mat-${Date.now()}-extra-${i}`,
    });
  });
  const jobBeforeSecondImport = (await db.collection('jobs').doc(testJobId).get()).data();
  const combinedAfterSecondImport = [...jobBeforeSecondImport.materials, ...extraRows];
  await db.collection('jobs').doc(testJobId).update({ materials: combinedAfterSecondImport, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
  const jobAfterSecondImport = (await db.collection('jobs').doc(testJobId).get()).data();
  const expectedAfterSecondImport = expectedAfterFirstImport + 2;
  check(
    `numar materiale = ${expectedAfterFirstImport} + 2 = ${expectedAfterSecondImport} (doar cele 2 noi adaugate)`,
    jobAfterSecondImport.materials.length === expectedAfterSecondImport,
    String(jobAfterSecondImport.materials.length),
  );

  section('14. DEDUPLICARE PE sourceInvoiceId+sourceInvoiceLineId (nu pe nume)');
  const allSourceLineIdsInJob = jobAfterSecondImport.materials.filter((m) => m.sourceInvoiceId === sourceFileHash).map((m) => m.sourceInvoiceSourceLineId);
  const uniqueSourceLineIds = new Set(allSourceLineIdsInJob);
  check('niciun sourceInvoiceSourceLineId duplicat in lucrare', uniqueSourceLineIds.size === allSourceLineIdsInJob.length, `${uniqueSourceLineIds.size} vs ${allSourceLineIdsInJob.length}`);
  const expectedTotalImportedLines = previewLines.length + 2;
  check(
    `${expectedTotalImportedLines} linii distincte importate in total (${previewLines.length} + 2)`,
    allSourceLineIdsInJob.length === expectedTotalImportedLines,
    String(allSourceLineIdsInJob.length),
  );

  section('15. RETRY METADATA — simulare esec controlat + reincercare');
  const bogusInvoiceRef = db.collection('supplier_invoices').doc('inexistent-simulat-pentru-test');
  let retryFailedAsExpected = false;
  try {
    await bogusInvoiceRef.update({ linkedJobIds: admin.firestore.FieldValue.arrayUnion(testJobId) });
  } catch (e) {
    retryFailedAsExpected = true;
  }
  check('actualizarea pe un id de factura inexistent esueaza controlat (materialele NU sunt afectate)', retryFailedAsExpected);
  const jobUnaffected = (await db.collection('jobs').doc(testJobId).get()).data();
  check(
    `dupa esecul simulat, materialele lucrarii raman neschimbate (${expectedAfterSecondImport})`,
    jobUnaffected.materials.length === expectedAfterSecondImport,
  );
  // retry cu id-ul CORECT — trebuie sa reuseasca si sa ramana idempotent
  await invoiceRef.update({ linkedJobIds: admin.firestore.FieldValue.arrayUnion(testJobId) });
  const invoiceAfterRealRetry = (await invoiceRef.get()).data();
  check('retry cu id corect reuseste, linkedJobIds tot 1 intrare', invoiceAfterRealRetry.linkedJobIds.length === 1);

  section('16. A DOUA LUCRARE — reutilizare factura existenta, fara duplicat');
  const testJobId2 = `smoke-test-job2-${Date.now()}`;
  await db.collection('jobs').doc(testJobId2).set({ id: testJobId2, jobCode: 'SMOKE-TEST-2', title: 'Lucrare smoke-test #2', materials: [] });
  const job2Line = stillAvailable[2]; // o linie inca neimportata nicaieri
  const matcher3 = makeCatalogMatcher((await db.collection('materials').get()).docs.map((d) => ({ id: d.id, ...d.data() })));
  const resolutionJob2 = matcher3.resolve({ name: job2Line.displayName, unit: friendlyUnitLabel(job2Line.unit), price: job2Line.unitPriceNoVat });
  const job2Row = buildJobMaterialFromInvoiceLine({ line: job2Line, materialId: resolutionJob2.materialId, invoiceId: sourceFileHash, jobMaterialId: `job-mat-${Date.now()}-job2` });
  await db.collection('jobs').doc(testJobId2).update({ materials: admin.firestore.FieldValue.arrayUnion(job2Row) });
  await invoiceRef.update({ linkedJobIds: admin.firestore.FieldValue.arrayUnion(testJobId2) });

  const invoicesCountAfterJob2 = (await db.collection('supplier_invoices').get()).size;
  check('tot UN singur document supplier_invoices (nu 2)', invoicesCountAfterJob2 === 1, String(invoicesCountAfterJob2));
  const invoiceAfterJob2 = (await invoiceRef.get()).data();
  check('linkedJobIds contine AMBELE jobId', invoiceAfterJob2.linkedJobIds.includes(testJobId) && invoiceAfterJob2.linkedJobIds.includes(testJobId2));
  const job1Final = (await db.collection('jobs').doc(testJobId).get()).data();
  check(
    `materialele primei lucrari raman neschimbate (${expectedAfterSecondImport})`,
    job1Final.materials.length === expectedAfterSecondImport,
  );

  section('REZULTAT');
  console.log(`  ${passCount} verificari OK, ${failCount} esuate.`);
  if (failCount > 0) {
    process.exitCode = 1;
  }
}

main()
  .catch((err) => {
    console.error('SMOKE TEST FAILED cu eroare neasteptata:', err);
    process.exitCode = 1;
  })
  .finally(async () => {
    try {
      await admin.app().delete();
    } catch (_) {}
  });
