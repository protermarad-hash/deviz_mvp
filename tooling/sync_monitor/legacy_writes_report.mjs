// RC 120 / M2: raport DOAR-CITIRE al scrierilor fara revizie pe clients/offers/jobs.
//
// Semnal: o scriere RC 120 seteaza `_rev_at` = ora serverului. Daca `updateTime`
// (metadata Firestore a documentului) este mai nou decat `_rev_at`, documentul a
// fost modificat de cineva care NU incrementeaza revizia: aplicatie veche
// (112/113/118/119), consola Firebase sau un script. Documentele fara `_rev` nu au
// fost inca scrise de 120 (normal pana la prima editare).
//
// Nu scrie nimic. Implicit ruleaza DOAR pe emulator (127.0.0.1). Pentru PROD:
// necesita aprobare separata, `--prod <projectId>` si un token OAuth de citire in
// variabila de mediu FIRESTORE_TOKEN (nu se afiseaza, nu se salveaza).
//
// Utilizare:
//   node legacy_writes_report.mjs [--since 2026-10-20T00:00:00Z] [--emulator 127.0.0.1:5310 --project demo-x]
//   node legacy_writes_report.mjs --prod <projectId> --since <ISO>   (doar cu aprobare)

const args = process.argv.slice(2);
const opt = (name, def) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
};
const prodProject = opt('--prod', null);
const since = opt('--since', null);
const toleranceMs = Number(opt('--tolerance-ms', '2000'));
const collections = opt('--collections', 'clients,offers,jobs').split(',');

let base;
let headers;
if (prodProject) {
  const token = process.env.FIRESTORE_TOKEN;
  if (!token) {
    console.error('BLOCKED: --prod necesita FIRESTORE_TOKEN (citire) si aprobare separata.');
    process.exit(2);
  }
  base = `https://firestore.googleapis.com/v1/projects/${prodProject}/databases/(default)/documents`;
  headers = { Authorization: `Bearer ${token}` };
} else {
  const host = opt('--emulator', '127.0.0.1:5310');
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
    console.error('BLOCKED: --emulator accepta doar 127.0.0.1/localhost.');
    process.exit(2);
  }
  const project = opt('--project', 'demo-proventaris-sync');
  if (!project.startsWith('demo-')) {
    console.error('BLOCKED: pe emulator se accepta doar proiecte demo-.');
    process.exit(2);
  }
  base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
  headers = { Authorization: 'Bearer owner' };
}

const val = (f) => (f == null ? undefined : Object.values(f)[0]);

async function* listAll(col) {
  let pageToken = '';
  do {
    const url = `${base}/${col}?pageSize=300${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`;
    const res = await fetch(url, { headers });
    if (!res.ok) throw new Error(`${col}: HTTP ${res.status}`);
    const body = await res.json();
    for (const d of body.documents ?? []) yield d;
    pageToken = body.nextPageToken ?? '';
  } while (pageToken);
}

const report = { generatedAt: new Date().toISOString(), target: prodProject ? `PROD:${prodProject}` : base, since, collections: {} };
let legacyTotal = 0;
for (const col of collections) {
  const r = { total: 0, withRev: 0, withoutRev: 0, withoutRevChangedSince: 0, legacyAfterRev: [] };
  for await (const d of listAll(col)) {
    r.total++;
    const f = d.fields ?? {};
    const id = d.name.split('/').pop();
    const updated = Date.parse(d.updateTime);
    if (f._rev === undefined) {
      r.withoutRev++;
      if (since && updated > Date.parse(since)) r.withoutRevChangedSince++;
      continue;
    }
    r.withRev++;
    const revAt = Date.parse(val(f._rev_at) ?? '');
    if (Number.isFinite(revAt) && updated - revAt > toleranceMs) {
      r.legacyAfterRev.push({ id, rev: Number(val(f._rev)), revAt: new Date(revAt).toISOString(), updateTime: d.updateTime });
    }
  }
  legacyTotal += r.legacyAfterRev.length + r.withoutRevChangedSince;
  report.collections[col] = r;
}
report.legacyWritesDetected = legacyTotal;
console.log(JSON.stringify(report, null, 2));
process.exit(legacyTotal > 0 ? 1 : 0);
