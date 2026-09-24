'use strict';

// FAZA 1.1 — teste Firestore Rules pentru `supplier_invoices` (+ `lines`)
// folosind Firebase Emulator Suite REAL, cu regulile REALE din
// ../../firestore.rules (citite direct din fisier, nu duplicate/rescrise
// aici). Ruleaza exclusiv local, pe proiectul demo-invoice-rules-test
// ("demo-" = Firebase CLI il trateaza STRICT local, fara cont GCP real,
// fara retea catre Google — imposibil sa scrie/citeasca productie).
//
// Rulare: npm test (din acest folder) — porneste automat emulatoarele
// Firestore+Storage prin `firebase emulators:exec`.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

const FIRESTORE_RULES_PATH = path.join(__dirname, '..', '..', 'firestore.rules');
const PROJECT_ID = 'demo-invoice-rules-test';

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

function dbAs(uid) {
  return uid === null
    ? testEnv.unauthenticatedContext().firestore()
    : testEnv.authenticatedContext(uid).firestore();
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(FIRESTORE_RULES_PATH, 'utf8'),
      host: '127.0.0.1',
      port: 5305,
    },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

// ── A. ADMIN ACTIV ────────────────────────────────────────────────────
test('A. admin activ poate citi supplier_invoices', async () => {
  await seedUser('admin-1', { role: 'admin', active: true });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context
      .firestore()
      .collection('supplier_invoices')
      .doc('inv-1')
      .set({ supplierName: 'X', invoiceNumber: 'F1' });
  });
  const db = dbAs('admin-1');
  await assertSucceeds(db.collection('supplier_invoices').doc('inv-1').get());
});

test('A. admin activ poate crea supplier_invoices', async () => {
  await seedUser('admin-1', { role: 'admin', active: true });
  const db = dbAs('admin-1');
  await assertSucceeds(
    db.collection('supplier_invoices').doc('inv-new').set({
      supplierName: 'Furnizor SRL',
      invoiceNumber: 'F-100',
      status: 'pendingReview',
    }),
  );
});

test('A. admin activ poate actualiza supplier_invoices', async () => {
  await seedUser('admin-1', { role: 'admin', active: true });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context
      .firestore()
      .collection('supplier_invoices')
      .doc('inv-2')
      .set({ status: 'pendingReview' });
  });
  const db = dbAs('admin-1');
  await assertSucceeds(
    db.collection('supplier_invoices').doc('inv-2').update({ status: 'parsed' }),
  );
});

test('A. admin activ poate citi si scrie lines', async () => {
  await seedUser('admin-1', { role: 'admin', active: true });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('supplier_invoices').doc('inv-3').set({});
  });
  const db = dbAs('admin-1');
  const lineRef = db
    .collection('supplier_invoices')
    .doc('inv-3')
    .collection('lines')
    .doc('line-1');
  await assertSucceeds(lineRef.set({ rawName: 'Teava cupru', quantity: 10 }));
  await assertSucceeds(lineRef.get());
});

// ── B. OFFICE ACTIV ───────────────────────────────────────────────────
test('B. office activ NU poate citi supplier_invoices', async () => {
  await seedUser('office-1', { role: 'office', active: true });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('supplier_invoices').doc('inv-4').set({});
  });
  const db = dbAs('office-1');
  await assertFails(db.collection('supplier_invoices').doc('inv-4').get());
});

test('B. office activ NU poate scrie supplier_invoices', async () => {
  await seedUser('office-1', { role: 'office', active: true });
  const db = dbAs('office-1');
  await assertFails(
    db.collection('supplier_invoices').doc('inv-5').set({ supplierName: 'X' }),
  );
});

test('B. office activ NU poate citi/scrie lines', async () => {
  await seedUser('office-1', { role: 'office', active: true });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('supplier_invoices').doc('inv-6').set({});
    await context
      .firestore()
      .collection('supplier_invoices')
      .doc('inv-6')
      .collection('lines')
      .doc('line-1')
      .set({ rawName: 'X' });
  });
  const db = dbAs('office-1');
  const lineRef = db
    .collection('supplier_invoices')
    .doc('inv-6')
    .collection('lines')
    .doc('line-1');
  await assertFails(lineRef.get());
  await assertFails(lineRef.set({ rawName: 'Y' }));
});

// ── C. ALT ROL ACTIV ──────────────────────────────────────────────────
test('C. rol "employee" activ NU poate accesa supplier_invoices', async () => {
  await seedUser('emp-1', { role: 'employee', active: true });
  const db = dbAs('emp-1');
  await assertFails(
    db.collection('supplier_invoices').doc('inv-7').set({ supplierName: 'X' }),
  );
  await assertFails(db.collection('supplier_invoices').doc('inv-7').get());
});

test('C. rol "team_lead" activ NU poate accesa supplier_invoices', async () => {
  await seedUser('lead-1', { role: 'team_lead', active: true });
  const db = dbAs('lead-1');
  await assertFails(
    db.collection('supplier_invoices').doc('inv-8').set({ supplierName: 'X' }),
  );
});

// ── D. NEAUTENTIFICAT ─────────────────────────────────────────────────
test('D. utilizator neautentificat NU poate accesa supplier_invoices', async () => {
  const db = dbAs(null);
  await assertFails(
    db.collection('supplier_invoices').doc('inv-9').set({ supplierName: 'X' }),
  );
  await assertFails(db.collection('supplier_invoices').doc('inv-9').get());
});

// ── E. ADMIN INACTIV ──────────────────────────────────────────────────
test('E. admin cu active=false NU poate accesa supplier_invoices', async () => {
  await seedUser('admin-inactive-1', { role: 'admin', active: false });
  const db = dbAs('admin-inactive-1');
  await assertFails(
    db.collection('supplier_invoices').doc('inv-10').set({ supplierName: 'X' }),
  );
  await assertFails(db.collection('supplier_invoices').doc('inv-10').get());
});

// ── Sanity check: regulile existente (categoria C — jobs) NU sunt
// afectate de aceasta schimbare. `jobs` ramane accesibil oricarui cont
// ACTIV (nu doar admin) — office/employee trebuie sa poata in continuare
// citi/scrie jobs, exact ca inainte de FAZA 1.1.
test('SANITY: office activ tot poate citi/scrie jobs (neafectat de FAZA 1.1)', async () => {
  await seedUser('office-2', { role: 'office', active: true });
  const db = dbAs('office-2');
  await assertSucceeds(
    db.collection('jobs').doc('job-1').set({ title: 'Lucrare test' }),
  );
  await assertSucceeds(db.collection('jobs').doc('job-1').get());
});

test('SANITY: employee activ tot poate citi/scrie jobs (neafectat de FAZA 1.1)', async () => {
  await seedUser('emp-2', { role: 'employee', active: true });
  const db = dbAs('emp-2');
  await assertSucceeds(
    db.collection('jobs').doc('job-2').set({ title: 'Lucrare test 2' }),
  );
});

test('SANITY: office activ tot poate citi materials (catalog, neafectat)', async () => {
  await seedUser('office-3', { role: 'office', active: true });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('materials').doc('mat-1').set({ name: 'X' });
  });
  const db = dbAs('office-3');
  await assertSucceeds(db.collection('materials').doc('mat-1').get());
});
