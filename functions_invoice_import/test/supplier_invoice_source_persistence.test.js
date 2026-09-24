'use strict';

// Teste unitare pentru persistarea server-side a XML-ului sursa in Storage
// (FAZA A-E/1-13 — elimina crash-ul nativ firebase_storage confirmat pe
// Windows, mutand upload-ul din client in parseSupplierInvoiceXml).
//
// Foloseste un bucket FAKE, in memorie — nu exista emulator Storage
// disponibil pentru acest codebase (spre deosebire de tooling/rules_tests,
// care are emulator Firestore/Storage; aici testele ruleaza cu
// `node --test`, fara emulator). Fake-ul implementeaza EXACT interfata
// minima folosita de persistSourceXmlIfNeeded: bucket.file(path).exists()
// si .save(buffer, opts).

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  computeSourceFileHash,
  buildSourceStoragePath,
  persistSourceXmlIfNeeded,
} = require('../supplier_invoice_parse')._internal;

function createFakeBucket() {
  const files = new Map();
  return {
    _files: files,
    file(path) {
      return {
        async exists() {
          return [files.has(path)];
        },
        async save(buffer, opts) {
          files.set(path, {
            content: Buffer.from(buffer),
            contentType: opts && opts.contentType,
            resumable: opts && opts.resumable,
            saveCallCount: (files.get(path)?.saveCallCount || 0) + 1,
          });
        },
      };
    },
  };
}

// ── invoiceId / path canonic ────────────────────────────────────────────

test('computeSourceFileHash: acelasi continut -> acelasi hash, determinist', () => {
  const xml = '<Invoice><ID>F1</ID></Invoice>';
  const h1 = computeSourceFileHash(xml);
  const h2 = computeSourceFileHash(xml);
  assert.equal(h1, h2);
  assert.match(h1, /^[0-9a-f]{64}$/);
});

test('9. continut diferit -> invoiceId diferit', () => {
  const h1 = computeSourceFileHash('<Invoice><ID>F1</ID></Invoice>');
  const h2 = computeSourceFileHash('<Invoice><ID>F2</ID></Invoice>');
  assert.notEqual(h1, h2);
});

test('6. path exact: supplier_invoices/{uid}/{invoiceId}/source.xml', () => {
  const path = buildSourceStoragePath('uid-abc', 'hash-xyz');
  assert.equal(path, 'supplier_invoices/uid-abc/hash-xyz/source.xml');
});

test('10. path-ul e construit EXCLUSIV din (uid, invoiceId) — functia nu accepta niciun alt parametru de la care un client ar putea injecta un path arbitrar', () => {
  assert.equal(buildSourceStoragePath.length, 2);
});

// ── persistare idempotenta ──────────────────────────────────────────────

test('5. XML valid -> persist reuseste success (fisier nou creat)', async () => {
  const bucket = createFakeBucket();
  const xmlContent = '<Invoice><ID>F1</ID></Invoice>';
  const storagePath = buildSourceStoragePath('uid-1', computeSourceFileHash(xmlContent));

  const result = await persistSourceXmlIfNeeded({ bucket, storagePath, xmlContent });

  assert.equal(result.created, true);
  assert.equal(result.storagePath, storagePath);
  const stored = bucket._files.get(storagePath);
  assert.ok(stored, 'fisierul trebuie sa fie prezent in bucket dupa persistare');
  assert.equal(stored.content.toString('utf8'), xmlContent);
});

test('7. contentType application/xml setat explicit la persistare', async () => {
  const bucket = createFakeBucket();
  const xmlContent = '<Invoice><ID>F1</ID></Invoice>';
  const storagePath = buildSourceStoragePath('uid-1', computeSourceFileHash(xmlContent));

  await persistSourceXmlIfNeeded({ bucket, storagePath, xmlContent });

  const stored = bucket._files.get(storagePath);
  assert.equal(stored.contentType, 'application/xml');
});

test('8. reimport acelasi XML -> idempotent, nu rescrie fisierul existent', async () => {
  const bucket = createFakeBucket();
  const xmlContent = '<Invoice><ID>F1</ID></Invoice>';
  const storagePath = buildSourceStoragePath('uid-1', computeSourceFileHash(xmlContent));

  const first = await persistSourceXmlIfNeeded({ bucket, storagePath, xmlContent });
  const second = await persistSourceXmlIfNeeded({ bucket, storagePath, xmlContent });

  assert.equal(first.created, true);
  assert.equal(second.created, false, 'a doua persistare NU trebuie sa recreeze fisierul');
  const stored = bucket._files.get(storagePath);
  assert.equal(stored.saveCallCount, 1, 'save() trebuie apelat o singura data, nu de doua ori');
});

test('9b. doua facturi cu continut diferit -> doua fisiere Storage distincte, ambele persistate', async () => {
  const bucket = createFakeBucket();
  const xmlA = '<Invoice><ID>F1</ID></Invoice>';
  const xmlB = '<Invoice><ID>F2</ID></Invoice>';
  const pathA = buildSourceStoragePath('uid-1', computeSourceFileHash(xmlA));
  const pathB = buildSourceStoragePath('uid-1', computeSourceFileHash(xmlB));

  await persistSourceXmlIfNeeded({ bucket, storagePath: pathA, xmlContent: xmlA });
  await persistSourceXmlIfNeeded({ bucket, storagePath: pathB, xmlContent: xmlB });

  assert.notEqual(pathA, pathB);
  assert.equal(bucket._files.get(pathA).content.toString('utf8'), xmlA);
  assert.equal(bucket._files.get(pathB).content.toString('utf8'), xmlB);
});

test('bytes UTF-8 pastrate exact (diacritice romanesti) — nu se altereaza continutul la persistare', async () => {
  const bucket = createFakeBucket();
  const xmlContent = '<Invoice><ID>F1</ID><Name>Țeavă cupru â î ș</Name></Invoice>';
  const storagePath = buildSourceStoragePath('uid-1', computeSourceFileHash(xmlContent));

  await persistSourceXmlIfNeeded({ bucket, storagePath, xmlContent });

  const stored = bucket._files.get(storagePath);
  assert.equal(stored.content.toString('utf8'), xmlContent);
});
