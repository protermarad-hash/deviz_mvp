'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const engine = require('../whatsapp_availability_engine');

const TZ = 'Europe/Bucharest';

// Zile de referință (verificate ca zile din săptămână reale în 2026):
const MONDAY = '2026-08-24';
const TUESDAY = '2026-08-25';
const FRIDAY = '2026-08-21';
const SATURDAY = '2026-08-22';
const SUNDAY = '2026-08-23';
const NEXT_MONDAY = '2026-08-31';

function apt({
  date,
  startTime = '',
  endTime = '',
  startDateTime = null,
  endDateTime = null,
  teamIds = ['teamA'],
  status = 'planificata',
}) {
  return {
    scheduled_date: `${date}T00:00:00.000`,
    start_time: startTime,
    end_time: endTime,
    start_date_time: startDateTime,
    end_date_time: endDateTime,
    assigned_team_ids: teamIds,
    status,
  };
}

function slotsFor(overrides) {
  const result = engine.findAvailableSlots({
    serviceType: 'montaj',
    dateFrom: MONDAY,
    dateTo: NEXT_MONDAY,
    appointments: [],
    teamIds: ['teamA'],
    ...overrides,
  });
  return result.slots;
}

// ---------------------------------------------------------------------------
// MONTAJ (teste 1-6 din specificație)
// ---------------------------------------------------------------------------

test('1. montaj: zi liberă luni -> primele 3 rezultate 09-12/12-15/15-18', () => {
  const slots = slotsFor({});
  assert.equal(slots.length, 3);
  assert.equal(slots[0].start, `${MONDAY}T09:00:00+03:00`);
  assert.equal(slots[0].end, `${MONDAY}T12:00:00+03:00`);
  assert.equal(slots[1].start, `${MONDAY}T12:00:00+03:00`);
  assert.equal(slots[2].start, `${MONDAY}T15:00:00+03:00`);
});

test('2. montaj: 09-12 ocupat -> primul rezultat este 12-15', () => {
  const slots = slotsFor({
    appointments: [apt({ date: MONDAY, startTime: '09:00', endTime: '12:00' })],
  });
  assert.equal(slots[0].start, `${MONDAY}T12:00:00+03:00`);
});

test('3. montaj: programare existentă 10:30-12:30 -> 09-12 și 12-15 în conflict, primul posibil 15-18', () => {
  const slots = slotsFor({
    appointments: [apt({ date: MONDAY, startTime: '10:30', endTime: '12:30' })],
  });
  assert.equal(slots[0].start, `${MONDAY}T15:00:00+03:00`);
});

test('4. montaj: 09-12 și 15-18 ocupate -> 12-15, 18-21, apoi ziua următoare 09-12', () => {
  const slots = slotsFor({
    appointments: [
      apt({ date: MONDAY, startTime: '09:00', endTime: '12:00' }),
      apt({ date: MONDAY, startTime: '15:00', endTime: '18:00' }),
    ],
  });
  assert.equal(slots.length, 3);
  assert.equal(slots[0].start, `${MONDAY}T12:00:00+03:00`);
  assert.equal(slots[1].start, `${MONDAY}T18:00:00+03:00`);
  assert.equal(slots[2].start, `${TUESDAY}T09:00:00+03:00`);
});

test('5. montaj: programare 08:30-09:30 -> 09-12 în conflict', () => {
  const slots = slotsFor({
    appointments: [apt({ date: MONDAY, startTime: '08:30', endTime: '09:30' })],
  });
  assert.notEqual(slots[0].start, `${MONDAY}T09:00:00+03:00`);
  assert.equal(slots[0].start, `${MONDAY}T12:00:00+03:00`);
});

test('6. montaj: programare 21:00-22:00 -> 18-21 NU e în conflict ([start,end))', () => {
  const slots = slotsFor({
    appointments: [apt({ date: MONDAY, startTime: '21:00', endTime: '22:00' })],
    maxResults: 4,
  });
  const starts = slots.map((s) => s.start);
  assert.ok(starts.includes(`${MONDAY}T18:00:00+03:00`));
});

// ---------------------------------------------------------------------------
// REVIZIE / REPARATIE / IGIENIZARE (teste 7-9)
// ---------------------------------------------------------------------------

function hourlySlotsFor(overrides) {
  const result = engine.findAvailableSlots({
    serviceType: 'revizie',
    dateFrom: MONDAY,
    dateTo: NEXT_MONDAY,
    appointments: [],
    teamIds: ['teamA'],
    maxResults: 5,
    ...overrides,
  });
  return result.slots;
}

test('7. revizie: zi liberă -> 09-10, 10-11, 11-12', () => {
  const slots = hourlySlotsFor({});
  assert.equal(slots[0].start, `${MONDAY}T09:00:00+03:00`);
  assert.equal(slots[1].start, `${MONDAY}T10:00:00+03:00`);
  assert.equal(slots[2].start, `${MONDAY}T11:00:00+03:00`);
});

test('8. revizie: 09:30-10:30 ocupat -> 09-10 și 10-11 conflict, primul 11-12', () => {
  const slots = hourlySlotsFor({
    appointments: [apt({ date: MONDAY, startTime: '09:30', endTime: '10:30' })],
    maxResults: 1,
  });
  assert.equal(slots[0].start, `${MONDAY}T11:00:00+03:00`);
});

test('9. revizie: 10-11 ocupat exact -> 09-10 disponibil, 10-11 indisponibil, 11-12 disponibil', () => {
  const result = engine.findAvailableSlots({
    serviceType: 'revizie',
    dateFrom: MONDAY,
    dateTo: MONDAY,
    appointments: [apt({ date: MONDAY, startTime: '10:00', endTime: '11:00' })],
    teamIds: ['teamA'],
    maxResults: 12,
  });
  const starts = result.slots.map((s) => s.start);
  assert.ok(starts.includes(`${MONDAY}T09:00:00+03:00`));
  assert.ok(!starts.includes(`${MONDAY}T10:00:00+03:00`));
  assert.ok(starts.includes(`${MONDAY}T11:00:00+03:00`));
});

// ---------------------------------------------------------------------------
// CALENDAR (teste 10-14)
// ---------------------------------------------------------------------------

test('10. sâmbătă complet liberă -> niciun slot', () => {
  const result = engine.findAvailableSlots({
    serviceType: 'montaj',
    dateFrom: SATURDAY,
    dateTo: SATURDAY,
    appointments: [],
    teamIds: ['teamA'],
  });
  assert.equal(result.slots.length, 0);
});

test('11. duminică complet liberă -> niciun slot', () => {
  const result = engine.findAvailableSlots({
    serviceType: 'montaj',
    dateFrom: SUNDAY,
    dateTo: SUNDAY,
    appointments: [],
    teamIds: ['teamA'],
  });
  assert.equal(result.slots.length, 0);
});

test('12. vineri urmat de weekend -> după sloturile de vineri, următorul e luni, nu sâmbătă', () => {
  const result = engine.findAvailableSlots({
    serviceType: 'montaj',
    dateFrom: FRIDAY,
    dateTo: MONDAY,
    appointments: [],
    teamIds: ['teamA'],
    maxResults: 100,
  });
  const dates = result.slots.map((s) => s.start.slice(0, 10));
  assert.ok(!dates.includes(SATURDAY));
  assert.ok(!dates.includes(SUNDAY));
  assert.ok(dates.includes(FRIDAY));
  assert.ok(dates.includes(MONDAY));
});

test('13. fără pauză de masă -> 12-13 și 13-14 valide pentru servicii de 1h', () => {
  const result = engine.findAvailableSlots({
    serviceType: 'reparatie',
    dateFrom: MONDAY,
    dateTo: MONDAY,
    appointments: [],
    teamIds: ['teamA'],
    maxResults: 100,
  });
  const starts = result.slots.map((s) => s.start);
  assert.ok(starts.includes(`${MONDAY}T12:00:00+03:00`));
  assert.ok(starts.includes(`${MONDAY}T13:00:00+03:00`));
});

test('14. fără buffer: 09-12 ocupat, 12-15 este disponibil imediat', () => {
  const result = engine.findAvailableSlots({
    serviceType: 'montaj',
    dateFrom: MONDAY,
    dateTo: MONDAY,
    appointments: [apt({ date: MONDAY, startTime: '09:00', endTime: '12:00' })],
    teamIds: ['teamA'],
  });
  assert.equal(result.slots[0].start, `${MONDAY}T12:00:00+03:00`);
});

// ---------------------------------------------------------------------------
// STATUS (teste 15-17)
// ---------------------------------------------------------------------------

test('15. status anulata -> nu blochează', () => {
  const result = engine.findAvailableSlots({
    serviceType: 'montaj',
    dateFrom: MONDAY,
    dateTo: MONDAY,
    appointments: [apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', status: 'anulata' })],
    teamIds: ['teamA'],
  });
  assert.equal(result.slots[0].start, `${MONDAY}T09:00:00+03:00`);
});

test('16. status necunoscut -> fail-safe: blochează (mirror normalizeAppointmentStatus -> default planificata)', () => {
  const result = engine.findAvailableSlots({
    serviceType: 'montaj',
    dateFrom: MONDAY,
    dateTo: MONDAY,
    appointments: [apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', status: 'status_ciudat_corupt' })],
    teamIds: ['teamA'],
  });
  assert.notEqual(result.slots[0].start, `${MONDAY}T09:00:00+03:00`);
});

test('17. status amanata -> nu blochează (documentul rămâne pe slotul vechi, reprogramarea e document nou)', () => {
  const result = engine.findAvailableSlots({
    serviceType: 'montaj',
    dateFrom: MONDAY,
    dateTo: MONDAY,
    appointments: [apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', status: 'amanata' })],
    teamIds: ['teamA'],
  });
  assert.equal(result.slots[0].start, `${MONDAY}T09:00:00+03:00`);
});

// ---------------------------------------------------------------------------
// LEGACY (teste 18-19)
// ---------------------------------------------------------------------------

test('18. fără startDateTime/endDateTime, doar scheduled_date + start_time/end_time -> interval corect', () => {
  const interval = engine.normalizeAppointmentInterval(apt({ date: MONDAY, startTime: '09:00', endTime: '12:00' }));
  assert.equal(engine.formatIsoWithOffset(interval.startMs, TZ), `${MONDAY}T09:00:00+03:00`);
  assert.equal(engine.formatIsoWithOffset(interval.endMs, TZ), `${MONDAY}T12:00:00+03:00`);
});

test('19. compatibilitate camelCase istoric (scheduledDate/startTime/endTime/teamId)', () => {
  const legacyDoc = {
    scheduledDate: `${MONDAY}T00:00:00.000`,
    startTime: '09:00',
    endTime: '12:00',
    teamId: 'teamLegacy',
    status: 'planificata',
  };
  const interval = engine.normalizeAppointmentInterval(legacyDoc);
  assert.equal(engine.formatIsoWithOffset(interval.startMs, TZ), `${MONDAY}T09:00:00+03:00`);
  assert.deepEqual(engine.resolveAppointmentTeamIds(legacyDoc), ['teamLegacy']);
});

// ---------------------------------------------------------------------------
// TIMEZONE (teste 20-21)
// ---------------------------------------------------------------------------

test('20. zi normală EEST -> orele publice 09-12 în Europe/Bucharest (+03:00)', () => {
  const slots = slotsFor({});
  assert.equal(slots[0].start, `${MONDAY}T09:00:00+03:00`);
});

test('21. zi din jurul schimbării DST -> sloturile locale rămân 09-12 etc., fără decalaj de 1h', () => {
  const winterMonday = '2026-01-19'; // luni, EET (+02:00)
  const result = engine.findAvailableSlots({
    serviceType: 'montaj',
    dateFrom: winterMonday,
    dateTo: winterMonday,
    appointments: [],
    teamIds: ['teamA'],
  });
  assert.equal(result.slots[0].start, `${winterMonday}T09:00:00+02:00`);
  assert.equal(result.slots[0].end, `${winterMonday}T12:00:00+02:00`);

  const dayAfterSpringDst = '2026-03-30'; // luni imediat după trecerea la ora de vară
  const resultDst = engine.findAvailableSlots({
    serviceType: 'montaj',
    dateFrom: dayAfterSpringDst,
    dateTo: dayAfterSpringDst,
    appointments: [],
    teamIds: ['teamA'],
  });
  assert.equal(resultDst.slots[0].start, `${dayAfterSpringDst}T09:00:00+03:00`);
});

// ---------------------------------------------------------------------------
// MULTI-TEAM (teste 22-24)
// ---------------------------------------------------------------------------

test('22. Echipa A ocupată 09-12, Echipa B liberă 09-12 -> 09-12 disponibil pentru client', () => {
  const result = engine.findAvailableSlots({
    serviceType: 'montaj',
    dateFrom: MONDAY,
    dateTo: MONDAY,
    appointments: [apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: ['teamA'] })],
    teamIds: ['teamA', 'teamB'],
  });
  assert.equal(result.slots[0].start, `${MONDAY}T09:00:00+03:00`);
});

test('23. Toate echipele ocupate 09-12 -> 09-12 indisponibil', () => {
  const result = engine.findAvailableSlots({
    serviceType: 'montaj',
    dateFrom: MONDAY,
    dateTo: MONDAY,
    appointments: [
      apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: ['teamA'] }),
      apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: ['teamB'] }),
    ],
    teamIds: ['teamA', 'teamB'],
  });
  assert.notEqual(result.slots[0].start, `${MONDAY}T09:00:00+03:00`);
});

test('24. Două echipe libere în același interval -> intervalul apare o singură dată', () => {
  const result = engine.findAvailableSlots({
    serviceType: 'montaj',
    dateFrom: MONDAY,
    dateTo: MONDAY,
    appointments: [],
    teamIds: ['teamA', 'teamB', 'teamC'],
  });
  const nineToTwelve = result.slots.filter((s) => s.start === `${MONDAY}T09:00:00+03:00`);
  assert.equal(nineToTwelve.length, 1);
});

// ---------------------------------------------------------------------------
// Reguli suplimentare acoperite de motor (nu numerotate explicit în task)
// ---------------------------------------------------------------------------

test('programare fără nicio echipă -> nu blochează automat toate echipele, e raportată ca anomalie', () => {
  const noTeamDoc = apt({ date: MONDAY, startTime: '09:00', endTime: '12:00', teamIds: [] });
  const result = engine.findAvailableSlots({
    serviceType: 'montaj',
    dateFrom: MONDAY,
    dateTo: MONDAY,
    appointments: [noTeamDoc],
    teamIds: ['teamA'],
  });
  assert.equal(result.slots[0].start, `${MONDAY}T09:00:00+03:00`);
  assert.equal(result.meta.noTeamAnomalyCount, 1);
});

test('serviceType necunoscut -> aruncă eroare unsupported_service_type', () => {
  assert.throws(
    () =>
      engine.findAvailableSlots({
        serviceType: 'zugravit',
        dateFrom: MONDAY,
        dateTo: MONDAY,
        appointments: [],
        teamIds: ['teamA'],
      }),
    /unsupported_service_type/,
  );
});

test('normalizare serviceType: montaj/instalare, revizie/verificare, reparatie/reparație/service, igienizare/curățare', () => {
  assert.equal(engine.normalizeServiceType('montaj'), 'montaj');
  assert.equal(engine.normalizeServiceType('Instalare'), 'montaj');
  assert.equal(engine.normalizeServiceType('revizie'), 'revizie');
  assert.equal(engine.normalizeServiceType('verificare'), 'revizie');
  assert.equal(engine.normalizeServiceType('reparatie'), 'reparatie');
  assert.equal(engine.normalizeServiceType('reparație'), 'reparatie');
  assert.equal(engine.normalizeServiceType('service'), 'reparatie');
  assert.equal(engine.normalizeServiceType('igienizare'), 'igienizare');
  assert.equal(engine.normalizeServiceType('igienizare AC'), 'igienizare');
  assert.equal(engine.normalizeServiceType('curățare'), 'igienizare');
  assert.equal(engine.normalizeServiceType('zugravit'), null);
});
