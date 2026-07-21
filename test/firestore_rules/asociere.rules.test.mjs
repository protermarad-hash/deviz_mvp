import fs from 'node:fs';
import path from 'node:path';
import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

const projectId = 'devizpro-ultra-pilot';
const root = path.resolve(import.meta.dirname, '..', '..');
const rules = fs.readFileSync(path.join(root, 'firestore.rules'), 'utf8');
let env;

const now = '2026-07-21T08:00:00.000Z';
const later = '2026-07-21T09:00:00.000Z';
const users = {
  admin: ['u-admin', 'admin', 'emp-admin'],
  office: ['u-office', 'office', 'emp-office'],
  lead: ['u-lead', 'team_lead', 'emp-lead'],
  tech: ['u-tech', 'employee', 'emp-tech'],
  outsider: ['u-out', 'employee', 'emp-out'],
  unknown: ['u-unknown', 'mystery', 'emp-unknown'],
};

function project(overrides = {}) {
  return {
    id: 'p1', numar: 'AS-001', denumire: 'Proiect test', descriere: '',
    client_id: 'client-1', client_name_snapshot: 'CLIENT-A', beneficiar: '',
    adresa: '', localitate: 'Arad', judet: 'Arad', tara: 'România',
    partner_id: 'partner-1', partner_name_snapshot: 'PARTNER-A',
    responsabil_id: 'emp-lead', responsabil_name_snapshot: 'PERSON-LEAD',
    manager_id: 'emp-lead', manager_name_snapshot: 'PERSON-LEAD',
    assigned_employee_ids: ['emp-lead', 'emp-tech'],
    data_inceput: now, termen_estimat: null, data_finalizare: null,
    status: 'draft', moneda: 'RON', observatii: '', created_at: now,
    updated_at: now, created_by: 'u-admin', updated_by: 'u-admin',
    revision: 1, active: true, arhivat: false, ...overrides,
  };
}

function contract(overrides = {}) {
  return {
    id: 'c1', lucrare_asociere_id: 'p1',
    cine_factureaza_beneficiarul: 'pro_term', partener_extern_id: 'partner-1',
    partener_extern_nume: 'PARTNER-A', partener_extern_cui: '',
    partener_extern_iban: '', partener_extern_telefon: '',
    cota_pro_term: 50, cota_partener: 50, prag_aprobare_ron: 1000,
    procent_distribuire_intermediara: 70, procent_rezerva_garantie: 30,
    durata_garantie_luni: 24, data_inceput: now, data_receptie_finala: null,
    status: 'activa', created_at: now, updated_at: now,
    created_by: 'u-admin', updated_by: 'u-admin', revision: 1, ...overrides,
  };
}

function audited(id, projectIdValue = 'p1', overrides = {}) {
  return {
    id, project_id: projectIdValue, created_at: now, updated_at: now,
    created_by: 'u-admin', updated_by: 'u-admin', revision: 1, ...overrides,
  };
}

function pontaj(overrides = {}) {
  return audited('pontaj-1', 'p1', {
    contract_id: 'c1', persoana_id: 'emp-tech',
    persoana_name_snapshot: 'PERSON-TECH', angajator: 'pro_term',
    calificare: 'tehnician', data: now, ore: 8, activitate: 'Activitate',
    faza: '', zona: '', tarif_snapshot: 50, cost_calculat: 400,
    status: 'draft', confirmare_interna: false,
    confirmare_interna_actor: '', confirmare_interna_la: null,
    confirmare_externa_inregistrata: false, confirmare_externa_actor: '',
    confirmare_externa_la: null, confirmare_document_ref: '', ...overrides,
  });
}

function cost(overrides = {}) {
  return audited('cost-1', 'p1', {
    contract_id: 'c1', source_type: 'manual', source_id: 'src-1',
    categorie: 'materiale', descriere: 'Material', data: now, furnizor: '',
    document_ref: null, valoare_fara_tva: 100, tva_informativ: 0,
    moneda: 'RON', curs: 1, valoare_proiect: 100, platitor: 'pro_term',
    refacturabil: false, eligibil: true, status: 'draft', aprobat_de: null,
    aprobat_la: null, observatii: '', ...overrides,
  });
}

function settlement(overrides = {}) {
  return {
    id: 'd1', project_id: 'p1', contract_id: 'c1', luna: 7, an: 2026,
    project_snapshot: { id: 'p1' }, contract_snapshot: { id: 'c1' },
    input_ids: [], venituri_incasat_total: 0, cost_recunoscut_pro_term: 0,
    cost_recunoscut_partener: 0, rezultat: 0,
    rambursare_datorata_catre: 'niciunul', rambursare_costuri: 0,
    distribuire_profit_imediata: 0, suma_rambursare: 0,
    suma_rezerva_retinuta: 0, suma_de_achitat_acum: 0,
    formula_revision: 1, status: 'draft', data_generare: now,
    generat_de: 'u-admin', confirmat_de: null, confirmat_la: null,
    revision: 1, ...overrides,
  };
}

async function seed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [uid, role, employeeId] of Object.values(users)) {
      await setDoc(doc(db, 'users', uid), {
        id: uid, firebase_uid: uid, role, employee_id: employeeId,
        team_id: role === 'team_lead' ? 'team-1' : '', active: true,
      });
    }
    await setDoc(doc(db, 'lucrari_asociere', 'p1'), project());
    await setDoc(doc(db, 'lucrari_asociere', 'p2'), project({
      id: 'p2', numar: 'AS-002', assigned_employee_ids: ['emp-out'],
      manager_id: 'emp-out', responsabil_id: 'emp-out',
    }));
    await setDoc(doc(db, 'asocieri', 'c1'), contract());
    await setDoc(doc(db, 'tarife_asociere', 'tarif-1'), {
      id: 'tarif-1', project_id: 'p1', contract_id: 'c1', calificare: 'standard',
      tarif_ora: 50, tarif_km: 2, moneda: 'RON', unitate: 'ora', asociat: 'pro_term',
      valabil_de_la: now, valabil_pana_la: null, activ: true, observatii: '',
      created_at: now, updated_at: now, revision: 1,
    });
    await setDoc(doc(db, 'pontaje_asociere', 'pontaj-1'), pontaj());
    await setDoc(doc(db, 'deplasari_asociere', 'trip-1'), audited('trip-1', 'p1', { status: 'draft' }));
    await setDoc(doc(db, 'cazari_asociere', 'stay-1'), audited('stay-1', 'p1', { deplasare_id: 'trip-1', status: 'draft' }));
    await setDoc(doc(db, 'diurne_asociere', 'allowance-1'), audited('allowance-1', 'p1', { deplasare_id: 'trip-1', persoana_id: 'emp-tech', status: 'draft' }));
    await setDoc(doc(db, 'costuri_asociere', 'cost-1'), cost());
    await setDoc(doc(db, 'venituri_asociere', 'income-1'), audited('income-1', 'p1', { contract_id: 'c1', status: 'draft' }));
    await setDoc(doc(db, 'deconturi_lunare_asociere', 'd1'), settlement());
  });
}

function dbFor(kind) {
  const [uid] = users[kind];
  return env.authenticatedContext(uid).firestore();
}

before(async () => {
  env = await initializeTestEnvironment({ projectId, firestore: { rules } });
});
beforeEach(async () => { await env.clearFirestore(); await seed(); });
after(async () => { await env.cleanup(); });

const collections = [
  ['lucrari_asociere', 'p1'], ['asocieri', 'c1'], ['tarife_asociere', 'tarif-1'],
  ['pontaje_asociere', 'pontaj-1'], ['deplasari_asociere', 'trip-1'],
  ['cazari_asociere', 'stay-1'], ['diurne_asociere', 'allowance-1'],
  ['costuri_asociere', 'cost-1'], ['venituri_asociere', 'income-1'],
  ['deconturi_lunare_asociere', 'd1'],
];

for (const [collection, id] of collections) {
  test(`admin citește ${collection}`, async () => {
    await assertSucceeds(getDoc(doc(dbFor('admin'), collection, id)));
  });
}

for (const [collection, id] of collections) {
  const allowed = collection !== 'tarife_asociere';
  test(`birou ${allowed ? 'citește' : 'nu citește'} ${collection}`, async () => {
    const op = getDoc(doc(dbFor('office'), collection, id));
    await (allowed ? assertSucceeds(op) : assertFails(op));
  });
}

for (const [collection, id] of collections) {
  const allowed = ['lucrari_asociere', 'pontaje_asociere', 'deplasari_asociere',
    'cazari_asociere', 'diurne_asociere'].includes(collection);
  test(`șef echipă ${allowed ? 'citește' : 'nu citește'} ${collection}`, async () => {
    const op = getDoc(doc(dbFor('lead'), collection, id));
    await (allowed ? assertSucceeds(op) : assertFails(op));
  });
}

for (const [collection, id] of collections) {
  const allowed = ['lucrari_asociere', 'pontaje_asociere', 'deplasari_asociere',
    'cazari_asociere', 'diurne_asociere'].includes(collection);
  test(`tehnician ${allowed ? 'citește' : 'nu citește'} ${collection}`, async () => {
    const op = getDoc(doc(dbFor('tech'), collection, id));
    await (allowed ? assertSucceeds(op) : assertFails(op));
  });
}

test('admin poate crea proiect', async () => {
  await assertSucceeds(setDoc(doc(dbFor('admin'), 'lucrari_asociere', 'p3'), project({
    id: 'p3', numar: 'AS-003', created_by: 'u-admin', updated_by: 'u-admin',
  })));
});
test('admin poate configura contractul', async () => {
  await assertSucceeds(setDoc(doc(dbFor('admin'), 'asocieri', 'c2'), contract({
    id: 'c2', created_by: 'u-admin', updated_by: 'u-admin',
  })));
});
test('admin poate modifica tariful', async () => {
  await assertSucceeds(updateDoc(doc(dbFor('admin'), 'tarife_asociere', 'tarif-1'), {
    tarif_ora: 60, updated_at: later, revision: 2,
  }));
});
test('admin poate aproba cost cu document și audit', async () => {
  await assertSucceeds(updateDoc(doc(dbFor('admin'), 'costuri_asociere', 'cost-1'), {
    status: 'aprobat', document_ref: 'doc-ref', aprobat_de: 'u-admin',
    aprobat_la: later, updated_by: 'u-admin', updated_at: later, revision: 2,
  }));
});
test('admin poate confirma decont', async () => {
  await assertSucceeds(updateDoc(doc(dbFor('admin'), 'deconturi_lunare_asociere', 'd1'), {
    status: 'confirmat', confirmat_de: 'u-admin', confirmat_la: later, revision: 2,
  }));
});
test('admin poate arhiva numai proiect finalizat', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => updateDoc(doc(ctx.firestore(), 'lucrari_asociere', 'p1'), { status: 'finalizata' }));
  await assertSucceeds(updateDoc(doc(dbFor('admin'), 'lucrari_asociere', 'p1'), {
    arhivat: true, active: false, updated_by: 'u-admin', updated_at: later, revision: 2,
  }));
});

test('birou poate crea proiect draft', async () => {
  await assertSucceeds(setDoc(doc(dbFor('office'), 'lucrari_asociere', 'p3'), project({
    id: 'p3', numar: 'AS-003', created_by: 'u-office', updated_by: 'u-office',
  })));
});
test('birou poate introduce cost draft', async () => {
  await assertSucceeds(setDoc(doc(dbFor('office'), 'costuri_asociere', 'cost-2'), cost({
    id: 'cost-2', source_id: 'src-2', created_by: 'u-office', updated_by: 'u-office',
  })));
});
test('birou poate introduce venit', async () => {
  await assertSucceeds(setDoc(doc(dbFor('office'), 'venituri_asociere', 'income-2'), audited('income-2', 'p1', {
    contract_id: 'c1', status: 'draft', created_by: 'u-office', updated_by: 'u-office',
  })));
});
test('birou poate crea deplasare', async () => {
  await assertSucceeds(setDoc(doc(dbFor('office'), 'deplasari_asociere', 'trip-2'), audited('trip-2', 'p1', {
    status: 'draft', created_by: 'u-office', updated_by: 'u-office',
  })));
});
test('birou nu poate închide decont', async () => {
  await assertFails(updateDoc(doc(dbFor('office'), 'deconturi_lunare_asociere', 'd1'), {
    status: 'confirmat', confirmat_de: 'u-office', confirmat_la: later,
    revision: 2,
  }));
});
test('birou nu poate modifica cotele', async () => {
  await assertFails(updateDoc(doc(dbFor('office'), 'asocieri', 'c1'), {
    cota_pro_term: 60, cota_partener: 40, updated_by: 'u-office',
    updated_at: later, revision: 2,
  }));
});

test('șef echipă nu citește proiect neatribuit', async () => {
  await assertFails(getDoc(doc(dbFor('lead'), 'lucrari_asociere', 'p2')));
});
test('șef echipă poate crea pontaj pentru persoană alocată', async () => {
  await assertSucceeds(setDoc(doc(dbFor('lead'), 'pontaje_asociere', 'pontaj-2'), pontaj({
    id: 'pontaj-2', created_by: 'u-lead', updated_by: 'u-lead',
  })));
});

test('tehnician citește doar pontajul propriu', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), 'pontaje_asociere', 'pontaj-lead'), pontaj({ id: 'pontaj-lead', persoana_id: 'emp-lead' })));
  await assertFails(getDoc(doc(dbFor('tech'), 'pontaje_asociere', 'pontaj-lead')));
});

test('respinge projectId invalid', async () => {
  await assertFails(setDoc(doc(dbFor('office'), 'costuri_asociere', 'bad'), cost({
    id: 'bad', project_id: 'absent', created_by: 'u-office', updated_by: 'u-office',
  })));
});
test('respinge document copil orfan', async () => {
  await assertFails(setDoc(doc(dbFor('office'), 'cazari_asociere', 'orphan'), audited('orphan', 'p1', {
    deplasare_id: 'missing', created_by: 'u-office', updated_by: 'u-office',
  })));
});
test('respinge revizie expirată', async () => {
  await assertFails(updateDoc(doc(dbFor('admin'), 'costuri_asociere', 'cost-1'), {
    updated_by: 'u-admin', updated_at: later, revision: 3,
  }));
});
test('respinge schimbarea createdBy', async () => {
  await assertFails(updateDoc(doc(dbFor('admin'), 'costuri_asociere', 'cost-1'), {
    created_by: 'u-office', updated_by: 'u-admin', updated_at: later, revision: 2,
  }));
});
test('respinge modificarea snapshotului pontajului confirmat', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => updateDoc(doc(ctx.firestore(), 'pontaje_asociere', 'pontaj-1'), {
    confirmare_interna: true, confirmare_interna_actor: 'u-admin', confirmare_interna_la: now,
    confirmare_externa_inregistrata: true, confirmare_externa_actor: 'u-admin',
    confirmare_externa_la: now, confirmare_document_ref: 'doc-ref',
  }));
  await assertFails(updateDoc(doc(dbFor('admin'), 'pontaje_asociere', 'pontaj-1'), {
    ore: 10, updated_by: 'u-admin', updated_at: later, revision: 2,
  }));
});
test('respinge rescrierea decontului închis', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => updateDoc(doc(ctx.firestore(), 'deconturi_lunare_asociere', 'd1'), {
    status: 'confirmat', confirmat_de: 'u-admin', confirmat_la: now,
  }));
  await assertFails(updateDoc(doc(dbFor('admin'), 'deconturi_lunare_asociere', 'd1'), {
    rezultat: 999, revision: 2,
  }));
});
test('respinge cost aprobat fără document', async () => {
  await assertFails(updateDoc(doc(dbFor('admin'), 'costuri_asociere', 'cost-1'), {
    status: 'aprobat', aprobat_de: 'u-admin', aprobat_la: later,
    updated_by: 'u-admin', updated_at: later, revision: 2,
  }));
});
test('respinge confirmare externă fără audit', async () => {
  await assertFails(updateDoc(doc(dbFor('admin'), 'pontaje_asociere', 'pontaj-1'), {
    confirmare_externa_inregistrata: true, updated_by: 'u-admin',
    updated_at: later, revision: 2,
  }));
});
test('respinge confirmarea Partenerului de către birou', async () => {
  await assertFails(updateDoc(doc(dbFor('office'), 'pontaje_asociere', 'pontaj-1'), {
    confirmare_externa_inregistrata: true, confirmare_externa_actor: 'u-office',
    confirmare_externa_la: later, confirmare_document_ref: 'doc-ref',
    updated_by: 'u-office', updated_at: later, revision: 2,
  }));
});
test('respinge scriere anonimă', async () => {
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'lucrari_asociere', 'p3'), project({ id: 'p3' })));
});
test('respinge rol necunoscut', async () => {
  await assertFails(getDoc(doc(dbFor('unknown'), 'lucrari_asociere', 'p1')));
});
test('proiectul operațional nu poate conține date financiare', async () => {
  await assertFails(setDoc(doc(dbFor('admin'), 'lucrari_asociere', 'p3'), project({
    id: 'p3', numar: 'AS-003', valoare_contractuala: 1000,
  })));
});

test('sanity: matricea are toate cele zece colecții', () => {
  assert.equal(collections.length, 10);
});
