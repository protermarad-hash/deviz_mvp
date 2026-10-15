'use strict';

// RC 120 — teste pentru regulile PROPUSE (etapa M3) cu revizie obligatorie pe
// clients/offers/jobs. Firebase Emulator Suite local, proiect demo- (fara acces
// la productie). Regulile se citesc din firestore.rc120.proposed.rules.
//
// Rulare (din radacina repo-ului):
//   firebase emulators:exec --project demo-rc120-rules --config firebase.rules-rc120-test.json \
//     "node --test --test-concurrency=1 tooling/rules_tests/rc120/firestore.rc120.rules.test.js"

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

const PROPOSED = path.join(__dirname, 'firestore.rc120.proposed.rules');
const LIVE = path.join(__dirname, '..', '..', '..', 'firestore.rules');
const PROJECT_ID = 'demo-rc120-rules';
const COLLECTIONS = ['clients', 'offers', 'jobs'];

let testEnv;

const dbAs = (uid) => testEnv.authenticatedContext(uid).firestore();

async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

async function serverDoc(col, id) {
  let data;
  await seed(async (db) => {
    const snap = await db.collection(col).doc(id).get();
    data = snap.exists ? snap.data() : null;
  });
  return data;
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: fs.readFileSync(PROPOSED, 'utf8'), host: '127.0.0.1', port: 5307 },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await seed(async (db) => {
    for (const uid of ['devA', 'devB']) {
      await db.collection('users').doc(uid).set({ role: 'office', active: true, name: uid });
    }
    await db.collection('users').doc('inactive').set({ role: 'office', active: false, name: 'x' });
  });
});

test('R1 propunerea = regulile live + DOAR revizia pe clients/offers/jobs (fara deriva)', () => {
  const norm = (s) => s.replace(/\r/g, '');
  let proposed = norm(fs.readFileSync(PROPOSED, 'utf8'));
  const live = norm(fs.readFileSync(LIVE, 'utf8'));
  proposed = proposed
    .split('\n').slice(2).join('\n') // antetul propunerii
    .replace(/\n {4}\/\/ ── RC 120: revizie obligatorie[\s\S]*?resource\.data\.get\('_rev', 0\) \+ 1;\n {4}\}\n\n/, '\n');
  for (const col of COLLECTIONS) {
    const expanded = new RegExp(
      `match /${col}/\\{docId\\} \\{\\n\\s*allow read: if isOperational\\(\\);\\n\\s*allow create: if isOperational\\(\\) && revOnCreate\\(\\);\\n\\s*allow update: if isOperational\\(\\) && revOnUpdate\\(\\);\\n\\s*allow delete: if isOperational\\(\\);\\n\\s*\\}`,
    );
    assert.match(proposed, expanded, `bloc ${col}`);
    proposed = proposed.replace(expanded, `match /${col}/{docId} { allow read, write: if isOperational(); }`);
  }
  assert.equal(proposed, live);
});

for (const col of COLLECTIONS) {
  test(`R2 ${col}: creare doar cu _rev = 1`, async () => {
    const db = dbAs('devA');
    await assertFails(db.collection(col).doc('x1').set({ name: 'fara rev' }));
    await assertFails(db.collection(col).doc('x2').set({ name: 'rev 2', _rev: 2 }));
    await assertFails(db.collection(col).doc('x3').set({ name: 'rev text', _rev: '1' }));
    await assertSucceeds(db.collection(col).doc('x4').set({ name: 'ok', _rev: 1 }));
  });

  test(`R3 ${col}: scrierea oarba a aplicatiei vechi este respinsa; doar _rev + 1 trece`, async () => {
    await seed((db) => db.collection(col).doc('d').set({ name: 'v1', _rev: 1 }));
    const db = dbAs('devA');
    const ref = db.collection(col).doc('d');
    await assertFails(ref.set({ name: 'veche merge' }, { merge: true })); // 113/118/119
    await assertFails(ref.set({ name: 'veche full' })); // set complet: _rev dispare
    await assertFails(ref.update({ name: 'veche update' }));
    await assertFails(ref.set({ name: 'acelasi rev', _rev: 1 }, { merge: true }));
    await assertFails(ref.set({ name: 'salt', _rev: 3 }, { merge: true }));
    await assertSucceeds(ref.set({ name: 'v2', _rev: 2 }, { merge: true }));
    assert.equal((await serverDoc(col, 'd')).name, 'v2');
  });

  test(`R4 ${col}: document existent fara _rev (migrare) -> prima scriere 120 cu _rev = 1`, async () => {
    await seed((db) => db.collection(col).doc('vechi').set({ name: 'din 119' }));
    const ref = dbAs('devA').collection(col).doc('vechi');
    await assertFails(ref.set({ name: 'veche' }, { merge: true }));
    await assertFails(ref.set({ name: 'rev 0', _rev: 0 }, { merge: true }));
    await assertFails(ref.set({ name: 'rev 2', _rev: 2 }, { merge: true }));
    await assertSucceeds(ref.set({ name: 'migrat', _rev: 1 }, { merge: true }));
  });
}

test('R5 cursa: A citeste rev 1, B scrie rev 2, A scrie rev 2 (citire->scriere Windows) -> A RESPINS', async () => {
  await seed((db) => db.collection('clients').doc('c').set({ name: 'v1', _rev: 1 }));
  const a = dbAs('devA').collection('clients').doc('c');
  const b = dbAs('devB').collection('clients').doc('c');
  const readByA = (await a.get()).data();
  assert.equal(readByA._rev, 1);
  await assertSucceeds(b.set({ name: 'B', _rev: 2 }, { merge: true }));
  await assertFails(a.set({ name: 'A invechit', _rev: readByA._rev + 1 }, { merge: true }));
  assert.deepEqual(await serverDoc('clients', 'c'), { name: 'B', _rev: 2 });
});

test('R6 concurenta reala: 40 de runde, A si B scriu simultan aceeasi revizie -> exact un castigator', async () => {
  for (const col of COLLECTIONS) {
    await seed((db) => db.collection(col).doc('race').set({ name: 'start', _rev: 1 }));
    for (let round = 0; round < 40; round++) {
      const cur = (await serverDoc(col, 'race'))._rev;
      const writes = ['devA', 'devB'].map((uid) =>
        dbAs(uid).collection(col).doc('race').set({ name: `${uid}-${round}`, _rev: cur + 1 }, { merge: true }));
      const res = await Promise.allSettled(writes);
      const ok = res.filter((r) => r.status === 'fulfilled').length;
      assert.equal(ok, 1, `${col} runda ${round}: ${ok} scrieri acceptate`);
      const winner = res[0].status === 'fulfilled' ? 'devA' : 'devB';
      for (const r of res) {
        if (r.status === 'rejected') assert.match(String(r.reason.code || r.reason), /permission-denied/i);
      }
      const doc = await serverDoc(col, 'race');
      assert.deepEqual(doc, { name: `${winner}-${round}`, _rev: cur + 1 });
    }
  }
});

test('R7 creare simultana a aceluiasi id pe doua dispozitive -> exact una reuseste', async () => {
  for (let round = 0; round < 20; round++) {
    const id = `nou-${round}`;
    const res = await Promise.allSettled(['devA', 'devB'].map((uid) =>
      dbAs(uid).collection('offers').doc(id).set({ name: uid, _rev: 1 }, { merge: true })));
    assert.equal(res.filter((r) => r.status === 'fulfilled').length, 1, `runda ${round}`);
  }
});

test('R8 retry dupa confirmare pierduta: retrimiterea aceleiasi revizii este respinsa (nu dubleaza)', async () => {
  await seed((db) => db.collection('jobs').doc('j').set({ name: 'v1', _rev: 1 }));
  const ref = dbAs('devA').collection('jobs').doc('j');
  await assertSucceeds(ref.set({ name: 'v2', _rev: 2 }, { merge: true }));
  // clientul nu a primit confirmarea si retrimite: regula respinge; clientul 120
  // reciteste si vede continut identic -> "aplicat" (test unitar revision_sync).
  await assertFails(ref.set({ name: 'v2', _rev: 2 }, { merge: true }));
  assert.deepEqual(await serverDoc('jobs', 'j'), { name: 'v2', _rev: 2 });
});

test('R9 RISC CUNOSCUT: stergerea nu este conditionata de revizie (o stergere invechita trece)', async () => {
  await seed((db) => db.collection('clients').doc('s').set({ name: 'v1', _rev: 1 }));
  const a = dbAs('devA').collection('clients').doc('s');
  await a.get(); // A vede rev 1 si decide stergerea
  await assertSucceeds(dbAs('devB').collection('clients').doc('s').set({ name: 'B', _rev: 2 }, { merge: true }));
  await assertSucceeds(a.delete()); // editarea lui B se pierde -> vezi propunerea tombstone (doc §9)
  assert.equal(await serverDoc('clients', 's'), null);
});

test('R10 utilizator inactiv: respins indiferent de revizie; alte colectii neschimbate', async () => {
  await assertFails(dbAs('inactive').collection('clients').doc('i').set({ name: 'x', _rev: 1 }));
  await assertSucceeds(dbAs('devA').collection('partners').doc('p').set({ name: 'fara rev' }, { merge: true }));
});
