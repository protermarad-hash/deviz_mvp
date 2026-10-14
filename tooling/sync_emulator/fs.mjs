// Helper gazdă pentru testele de sincronizare pe Firebase Emulator Suite.
// Vorbește EXCLUSIV cu emulatoarele locale (127.0.0.1) ale proiectului
// demo-proventaris-sync; refuză orice alt proiect sau host.
//
// Utilizare: node tooling/sync_emulator/fs.mjs <comandă> [argumente]
//   seed <uid>          profil users/{uid} (admin, activ) + date „din cloud”
//   edit-cloud          modificări făcute „de alt dispozitiv” cât timp
//                       telefonul e offline (conflict + PULL)
//   delete-team <id>    șterge o echipă direct în cloud
//   verify-sync         verifică datele împinse de dispozitiv (JSON)
//   count <colecție>    numărul de documente
//   get <colecție> <id> documentul (JSON)
//   isolation           confirmă proiectul și host-ul emulatorului

const PROJECT = 'demo-proventaris-sync';
const FS = 'http://127.0.0.1:5310';
const AUTH = 'http://127.0.0.1:5311';
if (!PROJECT.startsWith('demo-')) throw new Error('proiectul trebuie să fie demo-*');

const DOCS = `${FS}/v1/projects/${PROJECT}/databases/(default)/documents`;
// „owner” ocolește regulile — acceptat DOAR de emulator.
const OWNER = { Authorization: 'Bearer owner', 'Content-Type': 'application/json' };

function enc(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'string') return { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(enc) } };
  return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, enc(x)])) } };
}
function dec(v) {
  if ('nullValue' in v) return null;
  if ('booleanValue' in v) return v.booleanValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('stringValue' in v) return v.stringValue;
  if ('timestampValue' in v) return v.timestampValue;
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(dec);
  if ('mapValue' in v) return Object.fromEntries(Object.entries(v.mapValue.fields || {}).map(([k, x]) => [k, dec(x)]));
  return v;
}
const fields = (o) => Object.fromEntries(Object.entries(o).map(([k, v]) => [k, enc(v)]));

async function put(col, id, data) {
  const r = await fetch(`${DOCS}/${col}/${encodeURIComponent(id)}`, {
    method: 'PATCH', headers: OWNER, body: JSON.stringify({ fields: fields(data) }),
  });
  if (!r.ok) throw new Error(`put ${col}/${id}: ${r.status} ${await r.text()}`);
}
async function get(col, id) {
  const r = await fetch(`${DOCS}/${col}/${encodeURIComponent(id)}`, { headers: OWNER });
  if (r.status === 404) return null;
  if (!r.ok) throw new Error(`get ${col}/${id}: ${r.status}`);
  const j = await r.json();
  return dec({ mapValue: { fields: j.fields || {} } });
}
async function list(col) {
  const out = [];
  let token = '';
  do {
    const r = await fetch(`${DOCS}/${col}?pageSize=300${token ? `&pageToken=${token}` : ''}`, { headers: OWNER });
    if (!r.ok) throw new Error(`list ${col}: ${r.status}`);
    const j = await r.json();
    for (const d of j.documents || []) out.push({ id: d.name.split('/').pop(), ...dec({ mapValue: { fields: d.fields || {} } }) });
    token = j.nextPageToken || '';
  } while (token);
  return out;
}
async function del(col, id) {
  const r = await fetch(`${DOCS}/${col}/${encodeURIComponent(id)}`, { method: 'DELETE', headers: OWNER });
  if (!r.ok) throw new Error(`delete ${col}/${id}: ${r.status}`);
}

// Rând de pontaj sintetic: 3 zile, diurnă 55/zi, cazare 125/noapte.
export const laborRow = (jobId, id, hours = 24) => ({
  id, jobId, whoId: 'emp:e-cloud-1', type: 'person', whoLabel: 'Angajat Cloud QA', who: 'Angajat Cloud QA',
  date: '04.08.2026', periodStartDate: '2026-08-04', periodEndDate: '2026-08-06',
  hoursPerDay: 8.0, hours, hourlyRate: 40.0, tripDays: 3.0, includeDiurna: true, includeCazare: true,
  zileDiurna: 3.0, valoareDiurnaPeZi: 55.0, noptiCazare: 3.0, valoareCazarePeNoapte: 125.0,
  costOre: hours * 40.0, costDiurna: 165.0, costCazare: 375.0, costTotalLinie: hours * 40.0 + 540.0,
});

const cmd = process.argv[2];
const arg = process.argv.slice(3);
const now = new Date().toISOString();

if (cmd === 'seed') {
  const uid = arg[0];
  if (!uid) throw new Error('uid lipsă');
  await put('users', uid, { id: uid, email: 'sync.qa@demo.test', name: 'Sync QA', role: 'admin', active: true, firebase_uid: uid, updatedAt: now });
  await put('employees', 'e-cloud-1', { id: 'e-cloud-1', name: 'Angajat Cloud QA', role: 'Tehnician', active: true, team_id: 't-cloud-1', laborCostType: 'orar', costLunar: 0, tarifOrar: 40.0, oreLunareStandard: 168.0, dailyAllowance: 55.0, defaultLodgingCost: 125.0, requiresLodgingByDefault: true, updatedAt: now });
  await put('teams', 't-cloud-1', { id: 't-cloud-1', name: 'Echipa Cloud QA', notes: '', memberIds: ['e-cloud-1'], colorValue: 0, updatedAt: now });
  await put('teams', 't-cloud-2', { id: 't-cloud-2', name: 'Echipa Cloud QA 2', notes: '', memberIds: [], colorValue: 0, updatedAt: now });
  await put('jobs', 'j-cloud-1', { id: 'j-cloud-1', job_code: 'QA-CLOUD-1', title: 'Lucrare din cloud (sintetic)', client_id: 'qa', status: 'in_progress', notes: 'initial', is_active: true, created_at: now, updated_at: now, details_updated_at: now, labor_entries: [laborRow('j-cloud-1', 'l-cloud-1')], job_partners: [], job_partner_workers: [], time_entries: [] });
  console.log('SEED OK');
} else if (cmd === 'edit-cloud') {
  const j = await get('jobs', 'j-cloud-1');
  await put('jobs', 'j-cloud-1', { ...j, notes: 'editat in cloud (alt dispozitiv)', updated_at: new Date().toISOString() });
  const e = await get('employees', 'e-cloud-1');
  await put('employees', 'e-cloud-1', { ...e, tarifOrar: 45.0, updatedAt: new Date().toISOString() });
  console.log('EDIT-CLOUD OK');
} else if (cmd === 'delete-team') {
  await del('teams', arg[0]);
  console.log(`DELETE ${arg[0]} OK`);
} else if (cmd === 'count') {
  console.log((await list(arg[0])).length);
} else if (cmd === 'get') {
  console.log(JSON.stringify(await get(arg[0], arg[1]), null, 1));
} else if (cmd === 'verify-sync') {
  const jobs = await list('jobs');
  const ids = jobs.map((j) => j.id);
  const dup = ids.filter((x, i) => ids.indexOf(x) !== i);
  const jl = jobs.find((j) => j.id === 'j-local-1');
  const jc = jobs.find((j) => j.id === 'j-cloud-1');
  const labor = jl?.labor_entries?.[0];
  const out = {
    jobs: ids.sort(), duplicate_ids: dup,
    j_local_1: jl ? { labor_count: jl.labor_entries.length, hours: labor?.hours, costDiurna: labor?.costDiurna, costCazare: labor?.costCazare, costTotalLinie: labor?.costTotalLinie, partner_workers: (jl.job_partner_workers || []).length } : null,
    j_cloud_1_notes: jc?.notes,
    employees: (await list('employees')).map((e) => `${e.id}:${e.tarifOrar}`).sort(),
    teams: (await list('teams')).map((t) => t.id).sort(),
  };
  console.log(JSON.stringify(out));
} else if (cmd === 'isolation') {
  // Proiectul există doar în emulator; host-ul e local.
  const r = await fetch(`${FS}/`, { headers: OWNER });
  const a = await fetch(`${AUTH}/emulator/v1/projects/${PROJECT}/config`);
  console.log(JSON.stringify({ firestore_host: FS, firestore_up: r.ok, auth_host: AUTH, auth_project_config: a.status, project: PROJECT }));
} else {
  throw new Error(`comandă necunoscută: ${cmd}`);
}
