'use strict';

/**
 * Motor READ-ONLY de disponibilitate (FAZA 1) — WhatsApp / Programari PRO TERM.
 *
 * Modul PUR — nu atinge Firestore. Testabil integral cu fixtures în memorie.
 * Vezi `whatsapp_availability.js` pentru handler-ul HTTP care leagă acest
 * modul de Firestore (citire read-only din `appointments` + `teams`).
 */

const TIMEZONE = 'Europe/Bucharest';

// TODO arhitectural: mutare ulterioară în configurație administrabilă
// (Firestore `availability_config/proterm`), fără schimbarea algoritmului.
// Reguli confirmate de utilizator (FAZA 1, aug. 2026):
//   - montaj: 4 blocuri fixe de 3h (09-12 / 12-15 / 15-18 / 18-21)
//   - revizie/reparatie/igienizare: sloturi de 1h, aliniate la oră, 09-21
//   - luni-vineri, fără pauză de masă, fără buffer
//   - sâmbătă: OFF automat (necesită aprobare manuală administrator, nu în FAZA 1)
//   - duminică: OFF integral
const WORKDAY_START_HOUR = 9;
const WORKDAY_END_HOUR = 21;

const SERVICE_RULES = {
  montaj: { mode: 'fixed_3h_blocks' },
  revizie: { mode: 'hourly' },
  reparatie: { mode: 'hourly' },
  igienizare: { mode: 'hourly' },
};

const FIXED_3H_BLOCKS = [
  [9, 12],
  [12, 15],
  [15, 18],
  [18, 21],
];

function hourlyBlocks() {
  const blocks = [];
  for (let h = WORKDAY_START_HOUR; h < WORKDAY_END_HOUR; h++) {
    blocks.push([h, h + 1]);
  }
  return blocks;
}

const SERVICE_TYPE_ALIASES = {
  montaj: 'montaj',
  instalare: 'montaj',
  revizie: 'revizie',
  verificare: 'revizie',
  reparatie: 'reparatie',
  service: 'reparatie',
  igienizare: 'igienizare',
  'igienizare ac': 'igienizare',
  curatare: 'igienizare',
};

// Statusuri care NU blochează intervalul (vezi programari_page.dart:2599 —
// doar 'anulata' e exclus din verificarea de conflict; 'amanata' e adăugat
// aici pe baza fluxului real de amânare, vezi RAPORT FINAL secțiunea 3).
const NON_BLOCKING_STATUSES = new Set(['anulata', 'amanata']);

// ---------------------------------------------------------------------------
// Normalizare text (mirror appointment_status_utils.dart / mapping serviciu)
// ---------------------------------------------------------------------------

function stripDiacritics(value) {
  return String(value || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '');
}

function normalizeToken(value) {
  return stripDiacritics(String(value || '').trim().toLowerCase())
    .replace(/-/g, '_')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Normalizează serviceType primit de la agentul WhatsApp la o categorie
 * din SERVICE_RULES. Returnează null dacă tipul nu este recunoscut.
 */
function normalizeServiceType(raw) {
  const token = normalizeToken(raw).replace(/_/g, ' ');
  return SERVICE_TYPE_ALIASES[token] || null;
}

/**
 * Mirror exact al `normalizeAppointmentStatus` din
 * lib/features/programari/appointment_status_utils.dart — inclusiv
 * comportamentul de default: status necunoscut/corupt → 'planificata'
 * (adică BLOCHEAZĂ, fail-safe, la fel ca aplicația reală).
 */
function normalizeAppointmentStatus(raw) {
  const value = normalizeToken(raw).replace(/ /g, '_');
  switch (value) {
    case 'planificata':
    case 'planned':
    case 'noua':
      return 'planificata';
    case 'in_curs':
    case 'incurs':
    case 'in_progress':
      return 'in_curs';
    case 'finalizata':
    case 'done':
    case 'completed':
      return 'finalizata';
    case 'amanata':
    case 'postponed':
      return 'amanata';
    case 'anulata':
    case 'canceled':
    case 'cancelled':
      return 'anulata';
    default:
      return 'planificata';
  }
}

function appointmentBlocksSchedule(rawStatus) {
  return !NON_BLOCKING_STATUSES.has(normalizeAppointmentStatus(rawStatus));
}

// ---------------------------------------------------------------------------
// Conversie fus orar — Europe/Bucharest, DST-aware, fără dependență externă
// (Node 22 are ICU complet built-in; verificat: Intl.DateTimeFormat cu
// timeZone: 'Europe/Bucharest' dă offset corect +2 iarna / +3 vara).
// ---------------------------------------------------------------------------

function getZoneOffsetMinutes(utcMs, timeZone) {
  const dtf = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
  const parts = dtf.formatToParts(new Date(utcMs)).reduce((acc, p) => {
    acc[p.type] = p.value;
    return acc;
  }, {});
  const asUtc = Date.UTC(
    Number(parts.year),
    Number(parts.month) - 1,
    Number(parts.day),
    Number(parts.hour) === 24 ? 0 : Number(parts.hour),
    Number(parts.minute),
    Number(parts.second),
  );
  return (asUtc - utcMs) / 60000;
}

/**
 * Convertește o oră locală "de perete" (year/month/day/hour/minute în
 * timeZone) în epoch ms UTC. Algoritm iterativ standard (2 pași sunt
 * suficienți pentru orice offset real-world, inclusiv tranziții DST).
 */
function zonedTimeToUtcMs(year, month, day, hour, minute, second, timeZone) {
  second = second || 0;
  let guess = Date.UTC(year, month - 1, day, hour, minute, second);
  for (let i = 0; i < 2; i++) {
    const offsetMin = getZoneOffsetMinutes(guess, timeZone);
    const next = Date.UTC(year, month - 1, day, hour, minute, second) - offsetMin * 60000;
    if (next === guess) break;
    guess = next;
  }
  return guess;
}

function formatIsoWithOffset(utcMs, timeZone) {
  const offsetMin = getZoneOffsetMinutes(utcMs, timeZone);
  const local = new Date(utcMs + offsetMin * 60000);
  const pad = (n) => String(n).padStart(2, '0');
  const y = local.getUTCFullYear();
  const mo = pad(local.getUTCMonth() + 1);
  const d = pad(local.getUTCDate());
  const h = pad(local.getUTCHours());
  const mi = pad(local.getUTCMinutes());
  const s = pad(local.getUTCSeconds());
  const sign = offsetMin >= 0 ? '+' : '-';
  const absMin = Math.abs(offsetMin);
  const offH = pad(Math.floor(absMin / 60));
  const offM = pad(absMin % 60);
  return `${y}-${mo}-${d}T${h}:${mi}:${s}${sign}${offH}:${offM}`;
}

// ---------------------------------------------------------------------------
// Zile calendaristice — iterare, weekend, format YYYY-MM-DD
// ---------------------------------------------------------------------------

function parseDateOnly(raw) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(raw || '').trim());
  if (!m) return null;
  return { year: Number(m[1]), month: Number(m[2]), day: Number(m[3]) };
}

/** Zi a săptămânii (0=duminică..6=sâmbătă) calculată în timeZone dat. */
function weekdayInZone(dateComponents, timeZone) {
  const noonUtcMs = zonedTimeToUtcMs(
    dateComponents.year,
    dateComponents.month,
    dateComponents.day,
    12,
    0,
    0,
    timeZone,
  );
  const dtf = new Intl.DateTimeFormat('en-US', { timeZone, weekday: 'short' });
  const label = dtf.format(new Date(noonUtcMs));
  const map = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };
  return map[label];
}

function addDays(dateComponents, days) {
  // Folosim UTC "date-only" aritmetică — sigur pt. zile calendaristice,
  // fără interferență cu DST (nu implică ore locale aici).
  const d = new Date(Date.UTC(dateComponents.year, dateComponents.month - 1, dateComponents.day));
  d.setUTCDate(d.getUTCDate() + days);
  return { year: d.getUTCFullYear(), month: d.getUTCMonth() + 1, day: d.getUTCDate() };
}

function dateComponentsToKey(c) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${c.year}-${pad(c.month)}-${pad(c.day)}`;
}

function compareDateComponents(a, b) {
  return dateComponentsToKey(a).localeCompare(dateComponentsToKey(b));
}

// ---------------------------------------------------------------------------
// Generare candidați (sloturi fixe pe grilă, per categorie serviciu)
// ---------------------------------------------------------------------------

function blocksForCategory(category) {
  const rule = SERVICE_RULES[category];
  if (!rule) return null;
  return rule.mode === 'fixed_3h_blocks' ? FIXED_3H_BLOCKS : hourlyBlocks();
}

/**
 * Generează sloturile candidat (grilă fixă) pentru [dateFrom, dateTo]
 * inclusiv, excluzând sâmbăta și duminica. Returnează listă ordonată
 * cronologic, fiecare element cu startMs/endMs (UTC) + reprezentare locală.
 */
function generateCandidateSlots({ category, dateFrom, dateTo, timezone = TIMEZONE }) {
  const blocks = blocksForCategory(category);
  if (!blocks) throw new Error('unsupported_service_type');

  const from = parseDateOnly(dateFrom);
  const to = parseDateOnly(dateTo);
  if (!from || !to) throw new Error('invalid_date_range');

  const candidates = [];
  let cursor = from;
  let guard = 0;
  while (compareDateComponents(cursor, to) <= 0) {
    guard += 1;
    if (guard > 400) break; // siguranță anti-buclă infinită
    const weekday = weekdayInZone(cursor, timezone);
    const isWeekend = weekday === 0 || weekday === 6; // Duminică sau Sâmbătă
    if (!isWeekend) {
      for (const [startHour, endHour] of blocks) {
        const startMs = zonedTimeToUtcMs(cursor.year, cursor.month, cursor.day, startHour, 0, 0, timezone);
        const endMs = zonedTimeToUtcMs(cursor.year, cursor.month, cursor.day, endHour, 0, 0, timezone);
        candidates.push({ dateKey: dateComponentsToKey(cursor), startMs, endMs });
      }
    }
    cursor = addDays(cursor, 1);
  }
  return candidates;
}

// ---------------------------------------------------------------------------
// Normalizare programări existente — mirror appointment_models.dart
// effectiveStartDateTime / effectiveEndDateTime (Appointment.fromMap +
// getters, vezi lib/features/programari/appointment_models.dart:710-725)
// ---------------------------------------------------------------------------

function hasExplicitOffset(raw) {
  return /Z$|[+-]\d{2}:?\d{2}$/.test(String(raw || '').trim());
}

/**
 * Interpretează un câmp datetime din documentul Appointment. Dacă string-ul
 * conține deja un offset/„Z” explicit, îl respectăm ca instant real. Altfel
 * (cazul normal — DateTime local Dart serializat fără offset), interpretăm
 * componentele ca oră de perete Europe/Bucharest.
 */
function parseAppointmentInstant(raw, timezone) {
  const s = String(raw || '').trim();
  if (!s) return null;
  if (hasExplicitOffset(s)) {
    const ms = Date.parse(s);
    return Number.isNaN(ms) ? null : ms;
  }
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?/.exec(s);
  if (!m) return null;
  return zonedTimeToUtcMs(
    Number(m[1]),
    Number(m[2]),
    Number(m[3]),
    Number(m[4]),
    Number(m[5]),
    m[6] ? Number(m[6]) : 0,
    timezone,
  );
}

function combineDateAndTime(dateComponents, rawTime, timezone) {
  const trimmed = String(rawTime || '').trim();
  const parts = trimmed.split(':');
  const hour = parts.length > 0 ? Number.parseInt(parts[0], 10) || 0 : 0;
  const minute = parts.length > 1 ? Number.parseInt(parts[1], 10) || 0 : 0;
  return zonedTimeToUtcMs(dateComponents.year, dateComponents.month, dateComponents.day, hour, minute, 0, timezone);
}

function field(doc, snakeKey, camelKey) {
  return doc[snakeKey] !== undefined && doc[snakeKey] !== null ? doc[snakeKey] : doc[camelKey];
}

/**
 * Reproduce Appointment.effectiveStartDateTime / effectiveEndDateTime.
 * Returnează null dacă scheduled_date lipsește/e invalid — programarea nu
 * poate fi plasată pe nicio zi și e exclusă din calcul (logat ca anomalie
 * de către apelator, vezi whatsapp_availability.js).
 */
function normalizeAppointmentInterval(doc, timezone = TIMEZONE) {
  const dateComponents = parseDateOnly(field(doc, 'scheduled_date', 'scheduledDate') || doc.date);
  if (!dateComponents) return null;

  const explicitStartRaw = field(doc, 'start_date_time', 'startDateTime');
  const explicitStart = parseAppointmentInstant(explicitStartRaw, timezone);
  const startMs =
    explicitStart != null ? explicitStart : combineDateAndTime(dateComponents, field(doc, 'start_time', 'startTime'), timezone);

  const explicitEndRaw = field(doc, 'end_date_time', 'endDateTime');
  let endMs;
  if (explicitEndRaw) {
    const explicitEnd = parseAppointmentInstant(explicitEndRaw, timezone);
    endMs = explicitEnd != null && explicitEnd >= startMs ? explicitEnd : startMs;
  } else {
    const fallbackEnd = combineDateAndTime(dateComponents, field(doc, 'end_time', 'endTime'), timezone);
    endMs = fallbackEnd >= startMs ? fallbackEnd : startMs;
  }

  return { startMs, endMs };
}

/** Mirror Appointment.resolvedAssignedTeamIds (dedup, team_id ca fallback). */
function resolveAppointmentTeamIds(doc) {
  const values = [];
  const add = (raw) => {
    const id = String(raw || '').trim();
    if (!id || values.includes(id)) return;
    values.push(id);
  };
  const assigned = field(doc, 'assigned_team_ids', 'assignedTeamIds');
  if (Array.isArray(assigned)) {
    for (const v of assigned) add(v);
  }
  add(field(doc, 'team_id', 'teamId'));
  return values;
}

// ---------------------------------------------------------------------------
// Overlap — interval semi-deschis [start, end), fără buffer
// ---------------------------------------------------------------------------

function hasOverlap(aStart, aEnd, bStart, bEnd) {
  return aStart < bEnd && aEnd > bStart;
}

// ---------------------------------------------------------------------------
// Orchestrare pură — findAvailableSlots
// ---------------------------------------------------------------------------

/**
 * Funcție pură, fără Firestore. Primește documentele appointment brute
 * (așa cum vin din Firestore, snake_case) + lista de ID-uri de echipă
 * cunoscute (din colecția `teams`), și întoarce sloturile disponibile.
 *
 * @param {object} params
 * @param {string} params.serviceType
 * @param {string} params.dateFrom  'YYYY-MM-DD'
 * @param {string} params.dateTo    'YYYY-MM-DD'
 * @param {Array<object>} params.appointments  documente brute din Firestore
 * @param {Array<string>} params.teamIds       toate echipele cunoscute (colecția `teams`)
 * @param {number} [params.maxResults]
 * @param {string} [params.timezone]
 */
function findAvailableSlots({
  serviceType,
  dateFrom,
  dateTo,
  appointments,
  teamIds,
  maxResults = 3,
  timezone = TIMEZONE,
}) {
  const category = normalizeServiceType(serviceType);
  if (!category) {
    const err = new Error('unsupported_service_type');
    err.code = 'unsupported_service_type';
    throw err;
  }

  const knownTeamIds = new Set((teamIds || []).map((id) => String(id || '').trim()).filter(Boolean));

  const normalized = [];
  let noTeamAnomalyCount = 0;
  let unparseableCount = 0;

  for (const doc of appointments || []) {
    const interval = normalizeAppointmentInterval(doc, timezone);
    if (!interval) {
      unparseableCount += 1;
      continue;
    }
    const teams = resolveAppointmentTeamIds(doc);
    if (teams.length === 0) {
      noTeamAnomalyCount += 1;
      continue; // nu blochează nicio echipă (secțiunea 11 din task)
    }
    normalized.push({
      startMs: interval.startMs,
      endMs: interval.endMs,
      teamIds: teams,
      blocks: appointmentBlocksSchedule(doc.status),
    });
  }

  const candidates = generateCandidateSlots({ category, dateFrom, dateTo, timezone });

  const slots = [];
  const seenKeys = new Set();
  for (const candidate of candidates) {
    if (slots.length >= maxResults) break;
    const blockedTeams = new Set();
    for (const appt of normalized) {
      if (!appt.blocks) continue;
      if (hasOverlap(candidate.startMs, candidate.endMs, appt.startMs, appt.endMs)) {
        for (const t of appt.teamIds) blockedTeams.add(t);
      }
    }
    let hasFreeTeam = false;
    for (const t of knownTeamIds) {
      if (!blockedTeams.has(t)) {
        hasFreeTeam = true;
        break;
      }
    }
    if (hasFreeTeam) {
      const key = `${candidate.startMs}-${candidate.endMs}`;
      if (!seenKeys.has(key)) {
        seenKeys.add(key);
        slots.push({
          start: formatIsoWithOffset(candidate.startMs, timezone),
          end: formatIsoWithOffset(candidate.endMs, timezone),
        });
      }
    }
  }

  return {
    serviceType: category,
    timezone,
    slots,
    meta: {
      knownTeamCount: knownTeamIds.size,
      noTeamAnomalyCount,
      unparseableCount,
    },
  };
}

module.exports = {
  TIMEZONE,
  SERVICE_RULES,
  WORKDAY_START_HOUR,
  WORKDAY_END_HOUR,
  normalizeServiceType,
  normalizeAppointmentStatus,
  appointmentBlocksSchedule,
  zonedTimeToUtcMs,
  formatIsoWithOffset,
  generateCandidateSlots,
  normalizeAppointmentInterval,
  resolveAppointmentTeamIds,
  hasOverlap,
  findAvailableSlots,
  // exportate pentru teste interne suplimentare:
  parseDateOnly,
  weekdayInZone,
  getZoneOffsetMinutes,
};
