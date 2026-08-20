'use strict';

/**
 * FAZA 1 — Endpoint HTTP READ-ONLY de disponibilitate pentru
 * WhatsApp / Programari PRO TERM.
 *
 * Leagă motorul pur din `whatsapp_availability_engine.js` de Firestore.
 * Citește DOAR colecțiile `appointments` și `teams` — nu scrie niciodată
 * (fără .set/.update/.delete/.create/runTransaction cu write/batch write).
 */

const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const crypto = require('crypto');
const admin = require('firebase-admin');

const engine = require('./whatsapp_availability_engine');

const AVAILABILITY_API_TOKEN = defineSecret('WHATSAPP_AVAILABILITY_API_TOKEN');

const MAX_WINDOW_DAYS = 31; // secțiunea 15 din task
const DEFAULT_WINDOW_DAYS = 14;
const MAX_RESULTS = 3; // secțiunea 16 din task

// ---------------------------------------------------------------------------
// Validare request — funcții pure, testabile fără Firestore/HTTP.
// ---------------------------------------------------------------------------

function parseDateOnlyStrict(raw) {
  if (typeof raw !== 'string') return null;
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(raw.trim());
  if (!m) return null;
  const year = Number(m[1]);
  const month = Number(m[2]);
  const day = Number(m[3]);
  const d = new Date(Date.UTC(year, month - 1, day));
  if (d.getUTCFullYear() !== year || d.getUTCMonth() !== month - 1 || d.getUTCDate() !== day) {
    return null; // ex: 2026-02-30 nu e o dată calendaristică validă
  }
  return raw.trim();
}

function daysBetweenKeys(fromKey, toKey) {
  const [fy, fm, fd] = fromKey.split('-').map(Number);
  const [ty, tm, td] = toKey.split('-').map(Number);
  const fromMs = Date.UTC(fy, fm - 1, fd);
  const toMs = Date.UTC(ty, tm - 1, td);
  return Math.round((toMs - fromMs) / 86400000);
}

/** "Azi" în Europe/Bucharest + fereastra implicită de 14 zile calendaristice. */
function defaultDateRange(timezone = engine.TIMEZONE) {
  const dtf = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const todayKey = dtf.format(new Date());
  const [y, m, d] = todayKey.split('-').map(Number);
  const toDate = new Date(Date.UTC(y, m - 1, d));
  toDate.setUTCDate(toDate.getUTCDate() + DEFAULT_WINDOW_DAYS);
  const pad = (n) => String(n).padStart(2, '0');
  const toKey = `${toDate.getUTCFullYear()}-${pad(toDate.getUTCMonth() + 1)}-${pad(toDate.getUTCDate())}`;
  return { dateFrom: todayKey, dateTo: toKey };
}

/**
 * Validează body-ul request-ului. Returnează { serviceType, dateFrom, dateTo }
 * sau { error: 'invalid_request' | 'unsupported_service_type' }.
 */
function validateRequestBody(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'invalid_request' };
  }

  const serviceTypeRaw = body.serviceType;
  if (typeof serviceTypeRaw !== 'string' || !serviceTypeRaw.trim()) {
    return { error: 'invalid_request' };
  }
  const category = engine.normalizeServiceType(serviceTypeRaw);
  if (!category) {
    return { error: 'unsupported_service_type' };
  }

  let dateFrom;
  let dateTo;
  const hasFrom = body.dateFrom !== undefined && body.dateFrom !== null;
  const hasTo = body.dateTo !== undefined && body.dateTo !== null;

  if (!hasFrom && !hasTo) {
    const def = defaultDateRange();
    dateFrom = def.dateFrom;
    dateTo = def.dateTo;
  } else {
    dateFrom = parseDateOnlyStrict(body.dateFrom);
    dateTo = parseDateOnlyStrict(body.dateTo);
    if (!dateFrom || !dateTo) {
      return { error: 'invalid_request' };
    }
  }

  const spanDays = daysBetweenKeys(dateFrom, dateTo);
  if (spanDays < 0) {
    return { error: 'invalid_request' }; // dateTo < dateFrom
  }
  if (spanDays + 1 > MAX_WINDOW_DAYS) {
    return { error: 'invalid_request' }; // interval > 31 zile
  }

  return { serviceType: category, dateFrom, dateTo };
}

// ---------------------------------------------------------------------------
// Autentificare server-to-server — Authorization: Bearer <secret>
// ---------------------------------------------------------------------------

function readAuthorizationHeader(req) {
  if (typeof req.get === 'function') {
    return req.get('authorization') || req.get('Authorization') || '';
  }
  const headers = req.headers || {};
  return headers.authorization || headers.Authorization || '';
}

function isAuthorized(req, expectedToken) {
  const expected = String(expectedToken || '');
  if (!expected) return false; // secret neconfigurat → refuză, nu permite implicit

  const header = String(readAuthorizationHeader(req) || '').trim();
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) return false;

  const provided = match[1].trim();
  const providedBuf = Buffer.from(provided);
  const expectedBuf = Buffer.from(expected);
  if (providedBuf.length !== expectedBuf.length) return false;
  return crypto.timingSafeEqual(providedBuf, expectedBuf);
}

// ---------------------------------------------------------------------------
// Handler HTTP — testabil direct cu req/res/deps simulate (fără emulator)
// ---------------------------------------------------------------------------

function sendJsonError(res, status, error) {
  res.status(status).json({ error });
}

async function availabilityHandler(req, res, deps) {
  const { db, expectedToken } = deps;

  if (req.method !== 'POST') {
    if (typeof res.set === 'function') res.set('Allow', 'POST');
    return sendJsonError(res, 405, 'method_not_allowed');
  }

  if (!isAuthorized(req, expectedToken)) {
    return sendJsonError(res, 401, 'unauthorized');
  }

  const contentType = String(
    (typeof req.get === 'function' ? req.get('content-type') : (req.headers || {})['content-type']) || '',
  ).toLowerCase();
  if (!contentType.includes('application/json')) {
    return sendJsonError(res, 400, 'invalid_request');
  }

  const validation = validateRequestBody(req.body);
  if (validation.error) {
    return sendJsonError(res, 400, validation.error);
  }
  const { serviceType, dateFrom, dateTo } = validation;

  try {
    const rangeStart = `${dateFrom}T00:00:00.000`;
    const rangeEnd = `${dateTo}T23:59:59.999`;

    // Query simplu pe un singur câmp (>= și <=) — NU necesită index compus
    // Firestore (regula din CLAUDE.md: evită .where().orderBy()).
    const [appointmentsSnap, teamsSnap] = await Promise.all([
      db.collection('appointments').where('scheduled_date', '>=', rangeStart).where('scheduled_date', '<=', rangeEnd).get(),
      db.collection('teams').get(),
    ]);

    const appointments = [];
    appointmentsSnap.forEach((doc) => appointments.push(doc.data()));

    const teamIds = [];
    teamsSnap.forEach((doc) => teamIds.push(doc.id));

    const result = engine.findAvailableSlots({
      serviceType,
      dateFrom,
      dateTo,
      appointments,
      teamIds,
      maxResults: MAX_RESULTS,
    });

    if (result.meta.noTeamAnomalyCount > 0) {
      // SAFE: fără PII, doar contor + motiv tehnic (secțiunea 11 din task).
      logger.warn('[whatsapp_availability] programari fara echipa asignata in fereastra query', {
        count: result.meta.noTeamAnomalyCount,
      });
    }
    if (result.meta.unparseableCount > 0) {
      logger.warn('[whatsapp_availability] programari cu scheduled_date neparsabil', {
        count: result.meta.unparseableCount,
      });
    }

    return res.status(200).json({
      serviceType: result.serviceType,
      timezone: result.timezone,
      slots: result.slots,
    });
  } catch (err) {
    logger.error('[whatsapp_availability] eroare interna', {
      message: err && err.message ? err.message : String(err),
    });
    return sendJsonError(res, 500, 'internal_error');
  }
}

// ---------------------------------------------------------------------------
// Export Cloud Function (onRequest, NU onCall — vezi secțiunea 18 din task)
// ---------------------------------------------------------------------------

const availability = onRequest({ region: 'europe-west1', secrets: [AVAILABILITY_API_TOKEN] }, async (req, res) => {
  const db = admin.firestore();
  await availabilityHandler(req, res, { db, expectedToken: AVAILABILITY_API_TOKEN.value() });
});

module.exports = {
  availability,
  availabilityHandler,
  validateRequestBody,
  isAuthorized,
  defaultDateRange,
  MAX_WINDOW_DAYS,
  MAX_RESULTS,
};
