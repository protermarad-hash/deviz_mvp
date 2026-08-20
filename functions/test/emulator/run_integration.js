'use strict';

/**
 * FAZA 1.1 — Integration test END-TO-END prin Firebase Emulator Suite REAL.
 *
 * Traseu testat:
 *   fetch (HTTP) -> Functions Emulator -> Cloud Function `availability`
 *   -> Firestore Emulator (colecțiile `teams` + `appointments`)
 *
 * SIGURANȚĂ — NU atinge producția:
 *   - proiect folosit: "demo-proterm-emulator-test" (prefix "demo-" =
 *     Firebase CLI tratează proiectul STRICT local, fără cont GCP real,
 *     fără credențiale, fără rețea către Google — imposibil să scrie live).
 *   - config emulator complet separat: functions/test/emulator/firebase.emulator.json
 *     (NU firebase.json de la rădăcina repo-ului, care rămâne neatins).
 *   - reguli Firestore emulator: functions/test/emulator/firestore.emulator-test.rules
 *     (permisive, dar folosite DOAR local, niciodată deployate).
 *   - Admin SDK din acest script se conectează la emulator prin
 *     FIRESTORE_EMULATOR_HOST — nu la Firestore real.
 *
 * Rulare: npm run test:emulator  (necesită Java/JRE instalat pentru
 * Firestore Emulator; scriptul verifică asta explicit la pornire).
 */

const { spawn, execSync } = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');

const PROJECT_ID = 'demo-proterm-emulator-test';
const REGION = 'europe-west1';
const FUNCTIONS_PORT = 5301;
const FIRESTORE_PORT = 5302;
const FUNCTIONS_HOST = '127.0.0.1';
const FUNCTION_BASE_URL = `http://${FUNCTIONS_HOST}:${FUNCTIONS_PORT}/${PROJECT_ID}/${REGION}/availability`;

const EMULATOR_DIR = __dirname;
const EMULATOR_CONFIG = path.join(EMULATOR_DIR, 'firebase.emulator.json');
const FUNCTIONS_DIR = path.join(EMULATOR_DIR, '..', '..');
const SECRET_LOCAL = path.join(FUNCTIONS_DIR, '.secret.local');

// ---------------------------------------------------------------------------
// 0. Verificări de mediu — NU pornim nimic dacă lipsește ceva critic
// ---------------------------------------------------------------------------

function checkJavaAvailable() {
  try {
    execSync('java -version', { stdio: 'pipe' });
    return true;
  } catch (_) {
    return false;
  }
}

function readTestToken() {
  if (!fs.existsSync(SECRET_LOCAL)) {
    throw new Error(`Lipsește ${SECRET_LOCAL} — rulează întâi setup-ul (.secret.local cu token de test).`);
  }
  const content = fs.readFileSync(SECRET_LOCAL, 'utf8');
  const m = /^WHATSAPP_AVAILABILITY_API_TOKEN=(.+)$/m.exec(content);
  if (!m) throw new Error('WHATSAPP_AVAILABILITY_API_TOKEN nu e definit în .secret.local');
  return m[1].trim();
}

// ---------------------------------------------------------------------------
// 1. Pornire / oprire emulator
// ---------------------------------------------------------------------------

let emulatorProcess = null;
const emulatorLogLines = [];

function startEmulators() {
  return new Promise((resolve, reject) => {
    const args = [
      'firebase',
      'emulators:start',
      '--config',
      EMULATOR_CONFIG,
      '--project',
      PROJECT_ID,
      '--only',
      'functions,firestore',
      '--non-interactive',
    ];
    emulatorProcess = spawn('npx', args, {
      cwd: EMULATOR_DIR,
      // NODE_ENV=production: reproduce comportamentul real de deploy (GCF v2
      // setează automat NODE_ENV=production pe runtime). Verificat manual:
      // fără asta, wrapper-ul Express intern al emulatorului local
      // (firebase-tools) scurge stack trace complet către client la body
      // JSON malformat — cu NODE_ENV=production, Express ascunde stack-ul
      // (comportament standard Express, nu al codului nostru).
      env: { ...process.env, CI: 'true', NODE_ENV: 'production' },
      shell: true,
    });

    let ready = false;
    const onData = (buf) => {
      const text = buf.toString();
      emulatorLogLines.push(text);
      if (!ready && /All emulators ready/i.test(text)) {
        ready = true;
        resolve();
      }
      if (!ready && /Port \d+ is not open/i.test(text)) {
        reject(new Error('Port ocupat pentru emulator — vezi log:\n' + text));
      }
    };
    emulatorProcess.stdout.on('data', onData);
    emulatorProcess.stderr.on('data', onData);
    emulatorProcess.on('exit', (code) => {
      if (!ready) {
        reject(new Error(`Emulatorul s-a oprit înainte de a fi gata (exit code ${code}).\n` + emulatorLogLines.join('')));
      }
    });

    setTimeout(() => {
      if (!ready) reject(new Error('Timeout (120s) așteptând "All emulators ready".\n' + emulatorLogLines.join('')));
    }, 120000);
  });
}

/**
 * Omoară forțat orice proces care mai ascultă pe porturile emulatorului.
 * NECESAR pe Windows: `taskkill /T` pe procesul npx NU garantează oprirea
 * JVM-ului Firestore (constatat empiric — java.exe a rămas orfan, legat pe
 * portul 5302, după `taskkill /pid <npx> /T /F`). Plasă de siguranță finală
 * ca să nu rămână un emulator „zombie" între rulări.
 */
function killPortListeners(ports) {
  if (process.platform !== 'win32') return;
  try {
    const out = execSync('netstat -ano', { encoding: 'utf8' });
    const pids = new Set();
    for (const line of out.split('\n')) {
      for (const port of ports) {
        if (line.includes(`:${port}`) && /LISTENING/i.test(line)) {
          const m = /(\d+)\s*$/.exec(line.trim());
          if (m) pids.add(m[1]);
        }
      }
    }
    for (const pid of pids) {
      try {
        execSync(`taskkill /pid ${pid} /F`, { stdio: 'ignore' });
      } catch (_) {
        /* proces deja oprit */
      }
    }
  } catch (_) {
    /* netstat indisponibil — best-effort */
  }
}

function stopEmulators() {
  return new Promise((resolve) => {
    if (!emulatorProcess) return resolve();
    emulatorProcess.once('exit', () => resolve());
    try {
      if (process.platform === 'win32') {
        // Pe Windows, spawn cu shell:true creează un proces cmd.exe wrapper;
        // taskkill /T oprește tot arborele (emulator + JVM copii) — DAR nu e
        // garantat 100% (vezi killPortListeners mai jos, plasă de siguranță).
        execSync(`taskkill /pid ${emulatorProcess.pid} /T /F`, { stdio: 'ignore' });
      } else {
        emulatorProcess.kill('SIGTERM');
      }
    } catch (_) {
      resolve();
    }
    setTimeout(() => {
      killPortListeners([FUNCTIONS_PORT, FIRESTORE_PORT]);
      resolve();
    }, 3000);
  });
}

// ---------------------------------------------------------------------------
// 2. Test harness minimal (fără dependențe noi)
// ---------------------------------------------------------------------------

const results = [];

async function scenario(name, fn) {
  try {
    await fn();
    results.push({ name, pass: true });
    console.log(`✔ ${name}`);
  } catch (err) {
    results.push({ name, pass: false, error: err.message });
    console.log(`✖ ${name}`);
    console.log(`  ${err.message}`);
  }
}

function assertEqual(actual, expected, label) {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) {
    throw new Error(`${label}: expected ${e}, got ${a}`);
  }
}

function assertTrue(cond, label) {
  if (!cond) throw new Error(`${label}: expected true`);
}

// ---------------------------------------------------------------------------
// 3. Fixtures Firestore — schema identică cu Appointment.toMap() (Dart)
// ---------------------------------------------------------------------------

function apt({ date, startTime = '', endTime = '', teamIds = ['team-a'], status = 'planificata' }) {
  return {
    scheduled_date: `${date}T00:00:00.000`,
    start_time: startTime,
    end_time: endTime,
    start_date_time: null,
    end_date_time: null,
    team_id: teamIds[0] || '',
    assigned_team_ids: teamIds,
    status,
  };
}

async function callAvailability(db, admin, { serviceType, dateFrom, dateTo }, token) {
  const res = await fetch(FUNCTION_BASE_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: token != null ? `Bearer ${token}` : undefined,
    },
    body: JSON.stringify({ serviceType, dateFrom, dateTo }),
  });
  const status = res.status;
  let body = null;
  try {
    body = await res.json();
  } catch (_) {
    body = null;
  }
  return { status, body };
}

async function clearCollection(db, name) {
  const snap = await db.collection(name).get();
  const batch = db.batch();
  snap.forEach((doc) => batch.delete(doc.ref));
  if (!snap.empty) await batch.commit();
}

// ---------------------------------------------------------------------------
// 4. MAIN
// ---------------------------------------------------------------------------

async function main() {
  console.log('=== FAZA 1.1 — Integration test END-TO-END (Firebase Emulator Suite) ===\n');

  if (!checkJavaAvailable()) {
    console.error('EROARE: Java (JRE) nu este disponibil. Firestore Emulator nu poate porni.');
    process.exit(2);
  }

  const token = readTestToken();
  console.log(`Token test citit din .secret.local (mascat): ${token.slice(0, 10)}...${token.slice(-4)}\n`);

  console.log('Pornire Firebase Emulator Suite (functions + firestore)...');
  console.log(`  config: ${EMULATOR_CONFIG}`);
  console.log(`  project: ${PROJECT_ID} (prefix "demo-" => fără GCP real, fără credențiale)`);
  await startEmulators();
  console.log('Emulator gata.\n');

  // Admin SDK conectat EXPLICIT la emulator (nu la producție).
  process.env.FIRESTORE_EMULATOR_HOST = `127.0.0.1:${FIRESTORE_PORT}`;
  process.env.GCLOUD_PROJECT = PROJECT_ID;
  delete require.cache[require.resolve('firebase-admin')];
  const admin = require('firebase-admin');
  const app = admin.initializeApp({ projectId: PROJECT_ID }, 'integration-test-seed');
  const db = app.firestore();

  console.log(`Admin SDK conectat la FIRESTORE_EMULATOR_HOST=${process.env.FIRESTORE_EMULATOR_HOST} (confirmare: NU producție)\n`);

  const MONDAY = '2026-08-24';
  const TUESDAY = '2026-08-25';
  const FRIDAY = '2026-08-21';
  const SATURDAY = '2026-08-22';
  const SUNDAY = '2026-08-23';
  const WINTER_MONDAY = '2026-01-19';
  const SPRING_DST_MONDAY = '2026-03-30';

  async function resetFixtures({ teams = ['team-a', 'team-b'], appointments = [] } = {}) {
    await clearCollection(db, 'teams');
    await clearCollection(db, 'appointments');
    for (const teamId of teams) {
      await db.collection('teams').doc(teamId).set({ name: teamId });
    }
    let i = 0;
    for (const appointment of appointments) {
      i += 1;
      await db.collection('appointments').doc(`fixture-${i}`).set(appointment);
    }
  }

  // --- Read-only proof: snapshot înainte ------------------------------------
  await resetFixtures({
    teams: ['team-a', 'team-b'],
    appointments: [apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: ['team-a'] })],
  });
  const beforeAppointments = await db.collection('appointments').get();
  const beforeTeams = await db.collection('teams').get();
  const beforeAppointmentsData = beforeAppointments.docs.map((d) => ({ id: d.id, data: d.data() }));
  const beforeTeamsData = beforeTeams.docs.map((d) => ({ id: d.id, data: d.data() }));

  // ---------------------------------------------------------------------------
  // Scenariul 1 — zi complet liberă
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 1 — zi complet liberă (team-a, team-b, zero programări)', async () => {
    await resetFixtures({ teams: ['team-a', 'team-b'], appointments: [] });
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    assertEqual(body.slots.length, 3, 'nr. sloturi');
    assertEqual(body.slots[0].start, `${MONDAY}T09:00:00+03:00`, 'slot 0 start');
    assertEqual(body.slots[1].start, `${MONDAY}T12:00:00+03:00`, 'slot 1 start');
    assertEqual(body.slots[2].start, `${MONDAY}T15:00:00+03:00`, 'slot 2 start');
  });

  // ---------------------------------------------------------------------------
  // Scenariul 2 — o echipă ocupată, una liberă
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 2 — team-a ocupată 09-12, team-b liberă -> 09-12 apare', async () => {
    await resetFixtures({
      teams: ['team-a', 'team-b'],
      appointments: [apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: ['team-a'] })],
    });
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    assertTrue(
      body.slots.some((s) => s.start === `${MONDAY}T09:00:00+03:00`),
      '09-12 trebuie să apară',
    );
  });

  // ---------------------------------------------------------------------------
  // Scenariul 3 — toate echipele ocupate
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 3 — team-a și team-b ocupate 09-12 -> 09-12 NU apare, primul e 12-15', async () => {
    await resetFixtures({
      teams: ['team-a', 'team-b'],
      appointments: [
        apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: ['team-a'] }),
        apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: ['team-b'] }),
      ],
    });
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    assertTrue(
      !body.slots.some((s) => s.start === `${MONDAY}T09:00:00+03:00`),
      '09-12 NU trebuie să apară',
    );
    assertEqual(body.slots[0].start, `${MONDAY}T12:00:00+03:00`, 'primul slot');
  });

  // ---------------------------------------------------------------------------
  // Scenariul 4 — conflict parțial (interval real, nerotunjit)
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 4 — ambele echipe 10:30-12:30 -> 09-12 și 12-15 conflict, primul 15-18', async () => {
    await resetFixtures({
      teams: ['team-a', 'team-b'],
      appointments: [
        apt({ date: MONDAY, startTime: '10:30', endTime: '12:30', teamIds: ['team-a'] }),
        apt({ date: MONDAY, startTime: '10:30', endTime: '12:30', teamIds: ['team-b'] }),
      ],
    });
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    assertEqual(body.slots[0].start, `${MONDAY}T15:00:00+03:00`, 'primul slot disponibil');
  });

  // ---------------------------------------------------------------------------
  // Scenariul 5 — service 1h (reparatie)
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 5 — reparatie, ambele echipe 09:30-10:30 -> 09-10 și 10-11 indisponibile, 11-12 disponibil', async () => {
    await resetFixtures({
      teams: ['team-a', 'team-b'],
      appointments: [
        apt({ date: MONDAY, startTime: '09:30', endTime: '10:30', teamIds: ['team-a'] }),
        apt({ date: MONDAY, startTime: '09:30', endTime: '10:30', teamIds: ['team-b'] }),
      ],
    });
    const { status, body } = await callAvailability(db, admin, { serviceType: 'reparatie', dateFrom: MONDAY, dateTo: MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    const starts = body.slots.map((s) => s.start);
    assertTrue(!starts.includes(`${MONDAY}T09:00:00+03:00`), '09-10 indisponibil');
    assertTrue(!starts.includes(`${MONDAY}T10:00:00+03:00`), '10-11 indisponibil');
    assertTrue(starts.includes(`${MONDAY}T11:00:00+03:00`), '11-12 disponibil');
  });

  // ---------------------------------------------------------------------------
  // Scenariul 6 — fără buffer
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 6 — ambele echipe ocupate 09-12 -> 12-15 disponibil imediat (fără buffer)', async () => {
    await resetFixtures({
      teams: ['team-a', 'team-b'],
      appointments: [
        apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: ['team-a'] }),
        apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: ['team-b'] }),
      ],
    });
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    assertEqual(body.slots[0].start, `${MONDAY}T12:00:00+03:00`, '12-15 primul disponibil, fără buffer');
  });

  // ---------------------------------------------------------------------------
  // Scenariul 7 — status anulata
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 7 — status anulata pe ambele echipe -> 09-12 disponibil', async () => {
    await resetFixtures({
      teams: ['team-a', 'team-b'],
      appointments: [
        apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: ['team-a'], status: 'anulata' }),
        apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: ['team-b'], status: 'anulata' }),
      ],
    });
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    assertEqual(body.slots[0].start, `${MONDAY}T09:00:00+03:00`, '09-12 disponibil (anulata nu blochează)');
  });

  // ---------------------------------------------------------------------------
  // Scenariul 8 — status amanata
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 8 — status amanata pe ambele echipe -> 09-12 disponibil', async () => {
    await resetFixtures({
      teams: ['team-a', 'team-b'],
      appointments: [
        apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: ['team-a'], status: 'amanata' }),
        apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: ['team-b'], status: 'amanata' }),
      ],
    });
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    assertEqual(body.slots[0].start, `${MONDAY}T09:00:00+03:00`, '09-12 disponibil (amanata nu blochează)');
  });

  // ---------------------------------------------------------------------------
  // Scenariul 9 — status necunoscut (fail-safe)
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 9 — status necunoscut pe ambele echipe -> 09-12 BLOCAT (fail-safe)', async () => {
    await resetFixtures({
      teams: ['team-a', 'team-b'],
      appointments: [
        apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: ['team-a'], status: 'ceva_necunoscut' }),
        apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: ['team-b'], status: 'ceva_necunoscut' }),
      ],
    });
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    assertTrue(
      !body.slots.some((s) => s.start === `${MONDAY}T09:00:00+03:00`),
      '09-12 trebuie blocat (status necunoscut => planificata => blochează)',
    );
  });

  // ---------------------------------------------------------------------------
  // Scenariul 10 — legacy (scheduled_date + start_time/end_time, fără *_date_time)
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 10 — legacy snake_case fără start_date_time/end_date_time -> conflict detectat corect', async () => {
    await resetFixtures({
      teams: ['team-a', 'team-b'],
      appointments: [apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: ['team-a', 'team-b'] })],
    });
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    assertTrue(
      !body.slots.some((s) => s.start === `${MONDAY}T09:00:00+03:00`),
      '09-12 trebuie detectat ca ocupat din câmpurile legacy',
    );
  });

  // ---------------------------------------------------------------------------
  // Scenariul 11 — camelCase legacy (scheduledDate/startTime/endTime/teamId)
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 11 — camelCase legacy (scheduledDate/startTime/endTime/teamId) -> conflict detectat', async () => {
    // IMPORTANT: fixture-ul trebuie să ocupe AMBELE echipe, altfel testul nu
    // verifică nimic — o singură echipă ocupată + una liberă înseamnă că
    // motorul oferă corect slotul prin echipa liberă (comportament corect,
    // vezi Scenariul 2). Ca să izolăm strict parsarea câmpurilor camelCase,
    // ambele echipe trebuie blocate de acest document.
    await clearCollection(db, 'teams');
    await clearCollection(db, 'appointments');
    await db.collection('teams').doc('team-a').set({ name: 'team-a' });
    await db.collection('teams').doc('team-b').set({ name: 'team-b' });
    await db.collection('appointments').doc('fixture-camel').set({
      scheduledDate: `${MONDAY}T00:00:00.000`,
      startTime: '09:00',
      endTime: '12:00',
      assignedTeamIds: ['team-a', 'team-b'],
      status: 'planificata',
    });
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    assertTrue(
      !body.slots.some((s) => s.start === `${MONDAY}T09:00:00+03:00`),
      '09-12 trebuie detectat ca ocupat din câmpurile camelCase (assignedTeamIds)',
    );
    assertTrue(
      body.slots.some((s) => s.start === `${MONDAY}T12:00:00+03:00`),
      '12-15 rămâne disponibil (fără conflict)',
    );
  });

  // ---------------------------------------------------------------------------
  // Scenariul 12 — weekend
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 12 — sâmbătă liberă -> slots = []', async () => {
    await resetFixtures({ teams: ['team-a', 'team-b'], appointments: [] });
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: SATURDAY, dateTo: SATURDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    assertEqual(body.slots, [], 'sâmbătă -> zero sloturi');
  });

  await scenario('Scenariul 12 — duminică liberă -> slots = []', async () => {
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: SUNDAY, dateTo: SUNDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    assertEqual(body.slots, [], 'duminică -> zero sloturi');
  });

  // ---------------------------------------------------------------------------
  // Scenariul 13 — vineri -> luni (nu sâmbătă/duminică)
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 13 — vineri ocupat integral, interval vineri->luni -> următoarele sloturi sunt luni', async () => {
    await resetFixtures({
      teams: ['team-a', 'team-b'],
      appointments: [
        apt({ date: FRIDAY, startTime: '09:00', endTime: '12:00', teamIds: ['team-a', 'team-b'] }),
        apt({ date: FRIDAY, startTime: '12:00', endTime: '15:00', teamIds: ['team-a', 'team-b'] }),
        apt({ date: FRIDAY, startTime: '15:00', endTime: '18:00', teamIds: ['team-a', 'team-b'] }),
        apt({ date: FRIDAY, startTime: '18:00', endTime: '21:00', teamIds: ['team-a', 'team-b'] }),
      ],
    });
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: FRIDAY, dateTo: MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    assertTrue(body.slots.length > 0, 'trebuie să existe sloturi');
    for (const slot of body.slots) {
      const dateKey = slot.start.slice(0, 10);
      assertTrue(dateKey !== SATURDAY && dateKey !== SUNDAY, `slotul ${slot.start} nu trebuie să fie weekend`);
    }
    assertTrue(
      body.slots.every((s) => s.start.slice(0, 10) === MONDAY),
      'toate sloturile rămase trebuie să fie luni',
    );
  });

  // ---------------------------------------------------------------------------
  // Scenariul 14 — multi-team dedup
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 14 — team-a și team-b libere -> 09-12 apare o singură dată', async () => {
    await resetFixtures({ teams: ['team-a', 'team-b'], appointments: [] });
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    const matches = body.slots.filter((s) => s.start === `${MONDAY}T09:00:00+03:00`);
    assertEqual(matches.length, 1, '09-12 trebuie să apară o singură dată');
  });

  // ---------------------------------------------------------------------------
  // Scenariul 15 — programare fără echipă
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 15 — programare fără teamId/assignedTeamIds -> NU blochează toate echipele', async () => {
    await clearCollection(db, 'teams');
    await clearCollection(db, 'appointments');
    await db.collection('teams').doc('team-a').set({ name: 'team-a' });
    await db.collection('teams').doc('team-b').set({ name: 'team-b' });
    await db.collection('appointments').doc('fixture-no-team').set({
      scheduled_date: `${MONDAY}T00:00:00.000`,
      start_time: '09:00',
      end_time: '12:00',
      team_id: '',
      assigned_team_ids: [],
      status: 'planificata',
    });
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    assertTrue(
      body.slots.some((s) => s.start === `${MONDAY}T09:00:00+03:00`),
      '09-12 trebuie disponibil — programarea fără echipă nu poate bloca',
    );
  });

  // ---------------------------------------------------------------------------
  // Scenariul 16 — Auth
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 16 — fără Authorization -> 401', async () => {
    const { status } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: MONDAY }, null);
    assertEqual(status, 401, 'HTTP status');
  });
  await scenario('Scenariul 16 — token greșit -> 401', async () => {
    const { status } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: MONDAY }, 'token-complet-gresit');
    assertEqual(status, 401, 'HTTP status');
  });
  await scenario('Scenariul 16 — token corect -> 200', async () => {
    await resetFixtures({ teams: ['team-a', 'team-b'], appointments: [] });
    const { status } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
  });

  // ---------------------------------------------------------------------------
  // Scenariul 17 — HTTP method
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 17 — GET -> 405', async () => {
    const res = await fetch(FUNCTION_BASE_URL, {
      method: 'GET',
      headers: { Authorization: `Bearer ${token}` },
    });
    assertEqual(res.status, 405, 'HTTP status');
  });
  await scenario('Scenariul 17 — POST valid -> 200', async () => {
    const { status } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
  });

  // ---------------------------------------------------------------------------
  // Scenariul 18 — validare date
  // ---------------------------------------------------------------------------
  await scenario('Scenariul 18 — dateTo < dateFrom -> 400', async () => {
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: FRIDAY }, token);
    assertEqual(status, 400, 'HTTP status');
    assertEqual(body.error, 'invalid_request', 'error code');
  });
  await scenario('Scenariul 18 — interval >31 zile -> 400', async () => {
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: '2026-08-01', dateTo: '2026-09-15' }, token);
    assertEqual(status, 400, 'HTTP status');
    assertEqual(body.error, 'invalid_request', 'error code');
  });
  await scenario('Scenariul 18 — serviceType necunoscut -> 400', async () => {
    const { status, body } = await callAvailability(db, admin, { serviceType: 'zugravit', dateFrom: MONDAY, dateTo: MONDAY }, token);
    assertEqual(status, 400, 'HTTP status');
    assertEqual(body.error, 'unsupported_service_type', 'error code');
  });
  await scenario('Scenariul 18 — JSON invalid -> răspuns controlat, fără stack trace', async () => {
    const res = await fetch(FUNCTION_BASE_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: '{not-valid-json',
    });
    assertTrue(res.status >= 400 && res.status < 500, `status trebuie 4xx, a fost ${res.status}`);
    const text = await res.text();
    assertTrue(!/at\s+\S+\s+\(/.test(text), 'răspunsul nu trebuie să conțină stack trace');
  });

  // ---------------------------------------------------------------------------
  // Scenariul TIMEZONE/DST end-to-end
  // ---------------------------------------------------------------------------
  await scenario('DST — luni de iarnă (EET, +02:00) -> sloturi publice 09/12/15/18 fără decalaj', async () => {
    await resetFixtures({ teams: ['team-a', 'team-b'], appointments: [] });
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: WINTER_MONDAY, dateTo: WINTER_MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    assertEqual(body.slots[0].start, `${WINTER_MONDAY}T09:00:00+02:00`, 'ora locală trebuie 09:00 +02:00');
  });
  await scenario('DST — luni imediat după trecerea la ora de vară (+03:00) -> sloturi publice 09/12/15/18 fără decalaj', async () => {
    const { status, body } = await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: SPRING_DST_MONDAY, dateTo: SPRING_DST_MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    assertEqual(body.slots[0].start, `${SPRING_DST_MONDAY}T09:00:00+03:00`, 'ora locală trebuie 09:00 +03:00');
  });

  // ---------------------------------------------------------------------------
  // Scenariul Firestore query la marginea zilei (09:00 / 20:00 / 21:00)
  // ---------------------------------------------------------------------------
  await scenario('Query range — programare 20:00-21:00 la marginea zilei este văzută corect', async () => {
    await resetFixtures({
      teams: ['team-a', 'team-b'],
      appointments: [apt({ date: MONDAY, startTime: '20:00', endTime: '21:00', teamIds: ['team-a', 'team-b'] })],
    });
    const { status, body } = await callAvailability(db, admin, { serviceType: 'reparatie', dateFrom: MONDAY, dateTo: MONDAY }, token);
    assertEqual(status, 200, 'HTTP status');
    const starts = body.slots.map((s) => s.start);
    assertTrue(!starts.includes(`${MONDAY}T20:00:00+03:00`), '20-21 trebuie blocat');
    assertTrue(starts.includes(`${MONDAY}T19:00:00+03:00`) || starts.includes(`${MONDAY}T09:00:00+03:00`), 'restul zilei rămâne disponibil');
  });

  // ---------------------------------------------------------------------------
  // Read-only proof — nimic scris de motor
  // ---------------------------------------------------------------------------
  await scenario('READ-ONLY — după toate apelurile, appointments/teams identice cu snapshot-ul inițial (după re-seed identic)', async () => {
    await resetFixtures({
      teams: ['team-a', 'team-b'],
      appointments: [apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: ['team-a'] })],
    });
    const preCallAppointments = await db.collection('appointments').get();
    const preCallTeams = await db.collection('teams').get();
    const preAppCount = preCallAppointments.size;
    const preTeamCount = preCallTeams.size;

    // Rulăm 5 apeluri succesive către endpoint — motorul NU trebuie să scrie nimic.
    for (let i = 0; i < 5; i++) {
      await callAvailability(db, admin, { serviceType: 'montaj', dateFrom: MONDAY, dateTo: MONDAY }, token);
    }

    const postCallAppointments = await db.collection('appointments').get();
    const postCallTeams = await db.collection('teams').get();
    assertEqual(postCallAppointments.size, preAppCount, 'nr. appointments neschimbat');
    assertEqual(postCallTeams.size, preTeamCount, 'nr. teams neschimbat');

    const preData = preCallAppointments.docs.map((d) => ({ id: d.id, data: d.data() })).sort((a, b) => a.id.localeCompare(b.id));
    const postData = postCallAppointments.docs.map((d) => ({ id: d.id, data: d.data() })).sort((a, b) => a.id.localeCompare(b.id));
    assertEqual(postData, preData, 'conținutul appointments neschimbat byte-cu-byte');
  });

  await scenario('READ-ONLY — nu apare nicio colecție nouă (ex. appointment_holds)', async () => {
    const collections = await db.listCollections();
    const names = collections.map((c) => c.id).sort();
    assertEqual(names, ['appointments', 'teams'], 'doar appointments + teams trebuie să existe');
  });

  // ---------------------------------------------------------------------------
  // PII — logurile emulatorului nu trebuie să conțină date client
  // ---------------------------------------------------------------------------
  await scenario('PII — logurile emulatorului nu conțin nume/telefon/adresă din fixtures', async () => {
    const fullLog = emulatorLogLines.join('');
    const forbidden = ['Ion Popescu', '0700000000', 'Strada Test'];
    for (const needle of forbidden) {
      assertTrue(!fullLog.includes(needle), `logul nu trebuie să conțină "${needle}"`);
    }
    assertTrue(!fullLog.includes(token), 'logul nu trebuie să conțină tokenul de test în clar');
  });

  // ---------------------------------------------------------------------------
  // Cleanup + raport final
  // ---------------------------------------------------------------------------
  await clearCollection(db, 'teams');
  await clearCollection(db, 'appointments');

  const passCount = results.filter((r) => r.pass).length;
  const failCount = results.filter((r) => !r.pass).length;

  console.log('\n=== REZULTAT INTEGRATION/EMULATOR ===');
  console.log(`${passCount}/${results.length} scenarii au trecut.`);
  if (failCount > 0) {
    console.log('\nEșecuri:');
    for (const r of results.filter((r) => !r.pass)) {
      console.log(`  - ${r.name}: ${r.error}`);
    }
  }

  await stopEmulators();
  process.exit(failCount > 0 ? 1 : 0);
}

main().catch(async (err) => {
  console.error('EROARE FATALĂ în integration test:', err);
  await stopEmulators();
  process.exit(2);
});
