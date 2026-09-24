'use strict';

// FAZA 1.1 — teste Firebase Storage Rules pentru `supplier_invoices/**`,
// folosind regulile REALE din ../../storage.rules (citite direct din
// fisier). Testeaza in mod EXPLICIT:
//   1) matricea de acces (admin/office/alt user/neautentificat)
//   2) validarea continutului (extensie/content-type/dimensiune)
//   3) TESTUL CRITIC — ca regula genericA `match /{allPaths=**}` NU poate
//      acorda acces (bypass) la supplier_invoices/**, chiar daca in mod
//      normal ar permite acel tip de operatie pe orice alt path.
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

// ── TESTUL CRITIC: regula generica NU poate acorda bypass ──────────────
test('CRITIC: user autentificat non-admin NU poate citi supplier_invoices/<adminUid>/... prin regula generica', async () => {
  // Confirmare directa a cerintei FAZA 1.1 pct. 4: un fisier care AR fi
  // permis de catch-all-ul generic (orice autentificat, orice tip permis)
  // TREBUIE sa ramana blocat sub supplier_invoices/**, pentru ca guard-ul
  // `allPaths[0] != 'supplier_invoices'` scoate acest prefix din
  // domeniul catch-all-ului.
  await seedUser('admin-1', { role: 'admin', active: true });
  await seedUser('office-1', { role: 'office', active: true });

  const adminStorage = storageAs('admin-1');
  const adminFileRef = ref(
    adminStorage,
    'supplier_invoices/admin-1/inv-critical/source.xml',
  );
  await uploadBytes(adminFileRef, SMALL_XML, { contentType: 'application/xml' });

  // office-1 e un cont ACTIV, autentificat — daca ar exista bypass prin
  // catch-all, acest read AR reusi (catch-all-ul original permitea orice
  // autentificat sa citeasca orice path). Trebuie sa esueze.
  const officeStorage = storageAs('office-1');
  const officeFileRef = ref(
    officeStorage,
    'supplier_invoices/admin-1/inv-critical/source.xml',
  );
  await assertFails(getBytes(officeFileRef));
});

test('SANITY: catch-all-ul generic tot functioneaza normal pe alt path (field_photos) — neafectat', async () => {
  // Confirma ca guard-ul adaugat NU a rupt accesul existent la alte
  // functii (poze/atasamente) — orice autentificat activ poate in
  // continuare scrie/citi pe orice alt path in afara de
  // supplier_invoices/**.
  await seedUser('emp-1', { role: 'employee', active: true });
  const storage = storageAs('emp-1');
  const photoRef = ref(storage, 'field_photos/jobs/job-1/photo1.jpg');
  const fakeJpeg = Buffer.from([0xff, 0xd8, 0xff, 0xdb, 0x00, 0x01]);
  await assertSucceeds(
    uploadBytes(photoRef, fakeJpeg, { contentType: 'image/jpeg' }),
  );
  await assertSucceeds(getBytes(photoRef));
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
