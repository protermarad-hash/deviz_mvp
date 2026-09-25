'use strict';

// Teste unitare pentru persistarea server-side a metadatei facturii +
// liniilor in Firestore (FAZA "persist invoice metadata server-side" —
// elimina crash-ul nativ cloud_firestore.runTransaction() confirmat pe
// Windows, mutand tranzactia din client in parseSupplierInvoiceXml).
//
// Foloseste un Firestore FAKE, in memorie — nu exista emulator Firestore
// disponibil pentru acest codebase (acelasi motiv ca la
// supplier_invoice_source_persistence.test.js). Fake-ul implementeaza
// EXACT interfata minima folosita de persistInvoiceMetadataIfNeeded:
// db.collection(...).doc(...), db.runTransaction(fn) cu
// transaction.get/set, si citiri simple .collection().orderBy().get().

const test = require('node:test');
const assert = require('node:assert/strict');

const { persistInvoiceMetadataIfNeeded } = require('../supplier_invoice_parse')._internal;

function createFakeFirestore() {
  const docs = new Map(); // path -> data
  let autoCounter = 0;

  function makeDocRef(path) {
    return {
      path,
      id: path.split('/').pop(),
      collection(name) {
        return makeCollectionRef(`${path}/${name}`);
      },
    };
  }

  function makeCollectionRef(path) {
    const collectionApi = {
      path,
      doc(id) {
        const docId = id || `auto-${++autoCounter}`;
        return makeDocRef(`${path}/${docId}`);
      },
      async get() {
        const prefix = `${path}/`;
        const matches = [];
        for (const [p, data] of docs.entries()) {
          if (p.startsWith(prefix) && !p.slice(prefix.length).includes('/')) {
            matches.push({ id: p.slice(prefix.length), data: () => data });
          }
        }
        return { docs: matches, empty: matches.length === 0 };
      },
      orderBy(field) {
        return {
          async get() {
            const result = await collectionApi.get();
            result.docs.sort((a, b) => (a.data()[field] ?? 0) - (b.data()[field] ?? 0));
            return result;
          },
        };
      },
    };
    return collectionApi;
  }

  return {
    collection(name) {
      return makeCollectionRef(name);
    },
    async runTransaction(updateFn) {
      const transaction = {
        async get(ref) {
          const exists = docs.has(ref.path);
          const data = docs.get(ref.path);
          return { exists, id: ref.id, data: () => data };
        },
        set(ref, data) {
          docs.set(ref.path, data);
        },
      };
      return updateFn(transaction);
    },
    _docs: docs,
  };
}

function syntheticLines(count) {
  return Array.from({ length: count }, (_, i) => ({
    lineIndex: i,
    sourceLineId: `${i + 1}`,
    rawName: `Material sintetic ${i}`,
    supplierProductCode: null,
    unit: 'MTR',
    quantity: i + 1,
    unitPriceNoVat: 10 + i,
    unitPriceDerived: false,
    vatRate: 19,
    lineTotalNoVat: (i + 1) * (10 + i),
    currency: 'RON',
    warnings: [],
  }));
}

const HEADER = {
  supplierName: 'Furnizor Test SRL',
  supplierTaxId: 'RO12345678',
  invoiceNumber: 'F-TEST-1',
  invoiceDate: '2026-09-01',
  currency: 'RON',
  totalWithoutVat: 100,
  totalVat: 19,
};

test('1. create invoice nou -> document creat + toate liniile persistate', async () => {
  const db = createFakeFirestore();
  const lines = syntheticLines(3);
  const result = await persistInvoiceMetadataIfNeeded({
    db, invoiceId: 'inv-1', uid: 'uid-1', header: HEADER, lines,
    storagePath: 'supplier_invoices/uid-1/inv-1/source.xml',
  });

  assert.equal(result.created, true);
  assert.equal(result.lineDocIds.length, 3);

  const invoiceDoc = db._docs.get('supplier_invoices/inv-1');
  assert.ok(invoiceDoc, 'documentul factura trebuie sa existe');
  assert.equal(invoiceDoc.supplierName, 'Furnizor Test SRL');
  assert.equal(invoiceDoc.status, 'parsed');
  assert.deepEqual(invoiceDoc.linkedJobIds, []);
});

test('2/3. liniile persistate au schema corecta (compatibila cu SupplierInvoicePreviewLine.fromMap)', async () => {
  const db = createFakeFirestore();
  const lines = syntheticLines(1);
  const result = await persistInvoiceMetadataIfNeeded({
    db, invoiceId: 'inv-2', uid: 'uid-1', header: HEADER, lines,
    storagePath: 'x',
  });
  const lineDoc = db._docs.get(`supplier_invoices/inv-2/lines/${result.lineDocIds[0]}`);
  assert.ok(lineDoc);
  assert.equal(lineDoc.lineIndex, 0);
  assert.equal(lineDoc.sourceLineId, '1');
  assert.equal(lineDoc.rawName, 'Material sintetic 0');
  assert.equal(lineDoc.unit, 'MTR');
  assert.equal(lineDoc.quantity, 1);
  assert.equal(lineDoc.unitPriceNoVat, 10);
  assert.equal(lineDoc.vatRate, 19);
  assert.equal(lineDoc.currency, 'RON');
});

test('4. reimport aceeasi factura (acelasi invoiceId) -> NU se creeaza duplicat, created=false', async () => {
  const db = createFakeFirestore();
  const lines = syntheticLines(2);
  const first = await persistInvoiceMetadataIfNeeded({
    db, invoiceId: 'inv-4', uid: 'uid-1', header: HEADER, lines,
    storagePath: 'x',
  });
  const second = await persistInvoiceMetadataIfNeeded({
    db, invoiceId: 'inv-4', uid: 'uid-1', header: HEADER, lines,
    storagePath: 'x',
  });

  assert.equal(first.created, true);
  assert.equal(second.created, false);
  // Numarul de documente linie NU s-a dublat.
  const linesCount = [...db._docs.keys()].filter((p) =>
    p.startsWith('supplier_invoices/inv-4/lines/')).length;
  assert.equal(linesCount, 2);
});

test('5. line IDs deterministe la reimport — al doilea apel returneaza EXACT aceleasi lineDocIds ca primul', async () => {
  const db = createFakeFirestore();
  const lines = syntheticLines(3);
  const first = await persistInvoiceMetadataIfNeeded({
    db, invoiceId: 'inv-5', uid: 'uid-1', header: HEADER, lines,
    storagePath: 'x',
  });
  const second = await persistInvoiceMetadataIfNeeded({
    db, invoiceId: 'inv-5', uid: 'uid-1', header: HEADER, lines,
    storagePath: 'x',
  });
  assert.deepEqual(second.lineDocIds, first.lineDocIds);
});

test('6. linkedJobIds existent NU este resetat la reimport', async () => {
  const db = createFakeFirestore();
  const lines = syntheticLines(1);
  await persistInvoiceMetadataIfNeeded({
    db, invoiceId: 'inv-6', uid: 'uid-1', header: HEADER, lines,
    storagePath: 'x',
  });
  // Simuleaza alocarea facturii intr-o lucrare (markInvoiceAllocated,
  // client-side, neschimbat de aceasta faza).
  const invoiceDoc = db._docs.get('supplier_invoices/inv-6');
  invoiceDoc.linkedJobIds = ['job-abc'];
  invoiceDoc.status = 'hasAllocations';

  await persistInvoiceMetadataIfNeeded({
    db, invoiceId: 'inv-6', uid: 'uid-1', header: HEADER, lines,
    storagePath: 'x',
  });

  const afterReimport = db._docs.get('supplier_invoices/inv-6');
  assert.deepEqual(afterReimport.linkedJobIds, ['job-abc'],
    'linkedJobIds nu trebuie resetat la reimport');
});

test('7. status existent NU este resetat la reimport', async () => {
  const db = createFakeFirestore();
  const lines = syntheticLines(1);
  await persistInvoiceMetadataIfNeeded({
    db, invoiceId: 'inv-7', uid: 'uid-1', header: HEADER, lines,
    storagePath: 'x',
  });
  const invoiceDoc = db._docs.get('supplier_invoices/inv-7');
  invoiceDoc.status = 'hasAllocations';

  await persistInvoiceMetadataIfNeeded({
    db, invoiceId: 'inv-7', uid: 'uid-1', header: HEADER, lines,
    storagePath: 'x',
  });

  assert.equal(db._docs.get('supplier_invoices/inv-7').status, 'hasAllocations');
});

test('9. document Firestore exista, dar dupa un istoric de retry -> reimport ramane consistent (nu duplica, nu creeaza al doilea set de linii)', async () => {
  const db = createFakeFirestore();
  const lines = syntheticLines(5);
  await persistInvoiceMetadataIfNeeded({
    db, invoiceId: 'inv-9', uid: 'uid-1', header: HEADER, lines,
    storagePath: 'x',
  });
  // 3 retry-uri succesive (ex. utilizatorul reincearca importul de mai
  // multe ori dupa un esec anterior undeva mai jos in flux, client-side).
  for (let i = 0; i < 3; i++) {
    await persistInvoiceMetadataIfNeeded({
      db, invoiceId: 'inv-9', uid: 'uid-1', header: HEADER, lines,
      storagePath: 'x',
    });
  }
  const linesCount = [...db._docs.keys()].filter((p) =>
    p.startsWith('supplier_invoices/inv-9/lines/')).length;
  assert.equal(linesCount, 5, 'niciun retry nu trebuie sa adauge linii suplimentare');
});

test('13/14. esec de tranzactie Firestore se propaga (nu e inghitit silentios) — apelantul (parseSupplierInvoiceXml) se bazeaza pe asta ca sa NU raporteze invoicePersisted:true la esec', async () => {
  const brokenDb = {
    collection() {
      return { doc: () => ({ path: 'x', id: 'x' }) };
    },
    async runTransaction() {
      throw new Error('simulated Firestore transaction failure');
    },
  };
  await assert.rejects(
    () => persistInvoiceMetadataIfNeeded({
      db: brokenDb, invoiceId: 'inv-13', uid: 'uid-1', header: HEADER,
      lines: syntheticLines(1), storagePath: 'x',
    }),
    /simulated Firestore transaction failure/,
  );
});
