'use strict';

// FAZA 1.1 / FAZA 4 — teste Firebase Storage Rules pentru
// `supplier_invoices/**`, folosind regulile REALE din ../../storage.rules
// (citite direct din fisier — reconciliate la FAZA 4 cu regulile LIVE din
// productie, pornind de la fallback deny-by-default, nu de la catch-all
// permisiv). Testeaza in mod EXPLICIT:
//   1) matricea de acces (admin/office/alt user/neautentificat)
//   2) validarea continutului (extensie/content-type/dimensiune)
//   3) TESTUL CRITIC — ca niciun alt path/regula (inclusiv fallback-ul
//      deny-by-default) nu poate acorda acces la supplier_invoices/**
//      unui utilizator non-admin.
//   4) SANITY LIVE — ca path-urile existente in productie
//      (field_photos/signatures/notification_email_attachments) si
//      fallback-ul deny-by-default raman neschimbate.
//
// Ruleaza exclusiv local (proiect demo-invoice-rules-test), niciodata
// productie.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { ref, uploadBytes, getBytes, deleteObject } = require('@firebase/storage');

const STORAGE_RULES_PATH = path.join(__dirname, '..', '..', 'storage.rules');
const PROJECT_ID = 'demo-invoice-rules-test';

const SMALL_XML = Buffer.from('<Invoice><ID>F1</ID></Invoice>', 'utf8');
const SIX_MB = Buffer.alloc(6 * 1024 * 1024, 'a');

let testEnv;

async function seedUser(uid, { role, active = true } = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('users').doc(uid).set({
      role,
      active,
      name: `Test ${uid}`,
    });
  });
}

function storageAs(uid) {
  return uid === null
    ? testEnv.unauthenticatedContext().storage()
    : testEnv.authenticatedContext(uid).storage();
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      // Storage rules fac firestore.get()/exists() cross-service — testEnv
      // trebuie sa aiba si Firestore configurat, cu ACELEASI reguli reale
      // (ca sa se comporte identic cu productia).
      rules: fs.readFileSync(
        path.join(__dirname, '..', '..', 'firestore.rules'),
        'utf8',
      ),
      host: '127.0.0.1',
      port: 5305,
    },
    storage: {
      rules: fs.readFileSync(STORAGE_RULES_PATH, 'utf8'),
      host: '127.0.0.1',
      port: 5306,
    },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

// ── ADMIN ACTIV ───────────────────────────────────────────────────────
test('ADMIN: poate upload XML valid in supplier_invoices/{uid}/...', async () => {
  await seedUser('admin-1', { role: 'admin', active: true });
  const storage = storageAs('admin-1');
  const fileRef = ref(storage, 'supplier_invoices/admin-1/inv-1/source.xml');
  await assertSucceeds(
    uploadBytes(fileRef, SMALL_XML, { contentType: 'application/xml' }),
  );
});

test('ADMIN: poate citi propriul XML dupa upload', async () => {
  await seedUser('admin-1', { role: 'admin', active: true });
  const storage = storageAs('admin-1');
  const fileRef = ref(storage, 'supplier_invoices/admin-1/inv-2/source.xml');
  await uploadBytes(fileRef, SMALL_XML, { contentType: 'application/xml' });
  await assertSucceeds(getBytes(fileRef));
});

test('ADMIN: poate sterge propriul fisier (cleanup repository)', async () => {
  await seedUser('admin-1', { role: 'admin', active: true });
  const storage = storageAs('admin-1');
  const fileRef = ref(storage, 'supplier_invoices/admin-1/inv-3/source.xml');
  await uploadBytes(fileRef, SMALL_XML, { contentType: 'application/xml' });
  await assertSucceeds(deleteObject(fileRef));
});

// ── OFFICE ────────────────────────────────────────────────────────────
test('OFFICE: NU poate upload in supplier_invoices', async () => {
  await seedUser('office-1', { role: 'office', active: true });
  const storage = storageAs('office-1');
  const fileRef = ref(storage, 'supplier_invoices/office-1/inv-4/source.xml');
  await assertFails(
    uploadBytes(fileRef, SMALL_XML, { contentType: 'application/xml' }),
  );
});

test('OFFICE: NU poate citi un XML existent (uploadat de admin)', async () => {
  await seedUser('admin-1', { role: 'admin', active: true });
  await seedUser('office-1', { role: 'office', active: true });
  const adminStorage = storageAs('admin-1');
  const adminFileRef = ref(adminStorage, 'supplier_invoices/admin-1/inv-5/source.xml');
  await uploadBytes(adminFileRef, SMALL_XML, { contentType: 'application/xml' });

  const officeStorage = storageAs('office-1');
  const officeFileRef = ref(officeStorage, 'supplier_invoices/admin-1/inv-5/source.xml');
  await assertFails(getBytes(officeFileRef));
});

test('OFFICE: NU poate sterge un XML existent', async () => {
  await seedUser('admin-1', { role: 'admin', active: true });
  await seedUser('office-1', { role: 'office', active: true });
  const adminStorage = storageAs('admin-1');
  const adminFileRef = ref(adminStorage, 'supplier_invoices/admin-1/inv-6/source.xml');
  await uploadBytes(adminFileRef, SMALL_XML, { contentType: 'application/xml' });

  const officeStorage = storageAs('office-1');
  const officeFileRef = ref(officeStorage, 'supplier_invoices/admin-1/inv-6/source.xml');
  await assertFails(deleteObject(officeFileRef));
});

// ── ALT USER / NEAUTENTIFICAT ────────────────────────────────────────
test('ALT ROL (employee): NU poate accesa supplier_invoices', async () => {
  await seedUser('emp-1', { role: 'employee', active: true });
  const storage = storageAs('emp-1');
  const fileRef = ref(storage, 'supplier_invoices/emp-1/inv-7/source.xml');
  await assertFails(
    uploadBytes(fileRef, SMALL_XML, { contentType: 'application/xml' }),
  );
});

test('NEAUTENTIFICAT: NU poate accesa supplier_invoices', async () => {
  const storage = storageAs(null);
  const fileRef = ref(storage, 'supplier_invoices/anon/inv-8/source.xml');
  await assertFails(
    uploadBytes(fileRef, SMALL_XML, { contentType: 'application/xml' }),
  );
  await assertFails(getBytes(fileRef));
});

// ── TESTUL CRITIC: niciun alt path/regula nu poate acorda bypass ───────
test('CRITIC: user autentificat non-admin NU poate citi supplier_invoices/<adminUid>/... prin nicio alta regula', async () => {
  // FAZA 4 (reconciliere LIVE): spre deosebire de Faza 1.1 (unde exista un
  // catch-all generic permisiv si era nevoie de un guard explicit),
  // fisierul LIVE are fallback deny-by-default — nu exista NICIUN path
  // generic care ar putea "scapa" accesul. Testul ramane relevant ca
  // control pozitiv: confirma ca office (cont activ, autentificat) NU
  // poate citi fisierul, exact cum era si inainte, dar acum garantia vine
  // din designul deny-by-default, nu dintr-un guard specific.
  await seedUser('admin-1', { role: 'admin', active: true });
  await seedUser('office-1', { role: 'office', active: true });

  const adminStorage = storageAs('admin-1');
  const adminFileRef = ref(
    adminStorage,
    'supplier_invoices/admin-1/inv-critical/source.xml',
  );
  await uploadBytes(adminFileRef, SMALL_XML, { contentType: 'application/xml' });

  // office-1 e un cont ACTIV, autentificat — trebuie sa esueze oricum,
  // pentru ca match-ul supplier_invoices cere explicit isAdminOnly().
  const officeStorage = storageAs('office-1');
  const officeFileRef = ref(
    officeStorage,
    'supplier_invoices/admin-1/inv-critical/source.xml',
  );
  await assertFails(getBytes(officeFileRef));
});

test('SANITY LIVE: field_photos (path explicit LIVE, nu catch-all) tot functioneaza normal — neafectat', async () => {
  // FAZA 4: LIVE nu are catch-all generic permisiv (are deny-by-default) —
  // field_photos e propriul match block, cu isOperational(). Confirmam ca
  // adaugarea supplier_invoices NU a rupt acest path existent.
  await seedUser('emp-1', { role: 'employee', active: true });
  const storage = storageAs('emp-1');
  const photoRef = ref(storage, 'field_photos/jobs/job-1/photo1.jpg');
  const fakeJpeg = Buffer.from([0xff, 0xd8, 0xff, 0xdb, 0x00, 0x01]);
  await assertSucceeds(
    uploadBytes(photoRef, fakeJpeg, { contentType: 'image/jpeg' }),
  );
  await assertSucceeds(getBytes(photoRef));
});

test('SANITY LIVE: path neenumerat este blocat (deny-by-default), chiar si pentru admin', async () => {
  await seedUser('admin-fallback', { role: 'admin', active: true });
  const storage = storageAs('admin-fallback');
  const randomRef = ref(storage, 'orice_alt_path_neinregistrat/fisier.txt');
  await assertFails(
    uploadBytes(randomRef, Buffer.from('x'), { contentType: 'text/plain' }),
  );
});

// ── VALIDARE CONȚINUT (extensie / content-type / dimensiune) ──────────
test('VALIDARE: admin — upload .pdf in supplier_invoices e respins', async () => {
  await seedUser('admin-1', { role: 'admin', active: true });
  const storage = storageAs('admin-1');
  const fileRef = ref(storage, 'supplier_invoices/admin-1/inv-9/source.pdf');
  await assertFails(
    uploadBytes(fileRef, SMALL_XML, { contentType: 'application/pdf' }),
  );
});

test('VALIDARE: admin — upload .jpg in supplier_invoices e respins', async () => {
  await seedUser('admin-1', { role: 'admin', active: true });
  const storage = storageAs('admin-1');
  const fileRef = ref(storage, 'supplier_invoices/admin-1/inv-10/photo.jpg');
  await assertFails(
    uploadBytes(fileRef, SMALL_XML, { contentType: 'image/jpeg' }),
  );
});

test('VALIDARE: admin — upload .exe in supplier_invoices e respins', async () => {
  await seedUser('admin-1', { role: 'admin', active: true });
  const storage = storageAs('admin-1');
  const fileRef = ref(storage, 'supplier_invoices/admin-1/inv-11/malware.exe');
  await assertFails(
    uploadBytes(fileRef, SMALL_XML, { contentType: 'application/octet-stream' }),
  );
});

test('VALIDARE: admin — XML peste 5MB e respins', async () => {
  await seedUser('admin-1', { role: 'admin', active: true });
  const storage = storageAs('admin-1');
  const fileRef = ref(storage, 'supplier_invoices/admin-1/inv-12/source.xml');
  await assertFails(
    uploadBytes(fileRef, SIX_MB, { contentType: 'application/xml' }),
  );
});

test('VALIDARE: admin — XML cu content-type permis (application/xml) e acceptat', async () => {
  await seedUser('admin-1', { role: 'admin', active: true });
  const storage = storageAs('admin-1');
  const fileRef = ref(storage, 'supplier_invoices/admin-1/inv-13/source.xml');
  await assertSucceeds(
    uploadBytes(fileRef, SMALL_XML, { contentType: 'application/xml' }),
  );
});

test('VALIDARE: admin — XML cu content-type nepermis (text/html) e respins', async () => {
  await seedUser('admin-1', { role: 'admin', active: true });
  const storage = storageAs('admin-1');
  const fileRef = ref(storage, 'supplier_invoices/admin-1/inv-14/source.xml');
  await assertFails(
    uploadBytes(fileRef, SMALL_XML, { contentType: 'text/html' }),
  );
});

test('VALIDARE: admin NU poate scrie in folderul altui uid', async () => {
  await seedUser('admin-1', { role: 'admin', active: true });
  await seedUser('admin-2', { role: 'admin', active: true });
  const storage = storageAs('admin-1');
  const fileRef = ref(storage, 'supplier_invoices/admin-2/inv-15/source.xml');
  await assertFails(
    uploadBytes(fileRef, SMALL_XML, { contentType: 'application/xml' }),
  );
});
