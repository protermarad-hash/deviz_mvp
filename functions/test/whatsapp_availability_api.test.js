'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const api = require('../whatsapp_availability');

const VALID_TOKEN = 'test-secret-token-123';

function fakeReq({ method = 'POST', headers = {}, body = {} } = {}) {
  const normalizedHeaders = {};
  for (const [k, v] of Object.entries(headers)) {
    normalizedHeaders[k.toLowerCase()] = v;
  }
  return {
    method,
    headers: normalizedHeaders,
    body,
    get(name) {
      return normalizedHeaders[String(name).toLowerCase()];
    },
  };
}

function fakeRes() {
  const res = {
    statusCode: null,
    body: null,
    headers: {},
    status(code) {
      res.statusCode = code;
      return res;
    },
    json(payload) {
      res.body = payload;
      return res;
    },
    set(name, value) {
      res.headers[name] = value;
      return res;
    },
  };
  return res;
}

function fakeEmptyDb() {
  const emptySnap = { forEach: () => {} };
  const chain = {
    where() {
      return chain;
    },
    get: async () => emptySnap,
  };
  return { collection: () => chain };
}

const AUTH_HEADERS = { authorization: `Bearer ${VALID_TOKEN}`, 'content-type': 'application/json' };

// ---------------------------------------------------------------------------
// Validare API (teste 25-30 din specificație)
// ---------------------------------------------------------------------------

test('25. serviceType necunoscut -> 400 unsupported_service_type', async () => {
  const req = fakeReq({ headers: AUTH_HEADERS, body: { serviceType: 'zugravit' } });
  const res = fakeRes();
  await api.availabilityHandler(req, res, { db: fakeEmptyDb(), expectedToken: VALID_TOKEN });
  assert.equal(res.statusCode, 400);
  assert.equal(res.body.error, 'unsupported_service_type');
});

test('26. dateTo < dateFrom -> 400 invalid_request', async () => {
  const req = fakeReq({
    headers: AUTH_HEADERS,
    body: { serviceType: 'montaj', dateFrom: '2026-08-24', dateTo: '2026-08-20' },
  });
  const res = fakeRes();
  await api.availabilityHandler(req, res, { db: fakeEmptyDb(), expectedToken: VALID_TOKEN });
  assert.equal(res.statusCode, 400);
  assert.equal(res.body.error, 'invalid_request');
});

test('27. interval > 31 zile -> 400 invalid_request', async () => {
  const req = fakeReq({
    headers: AUTH_HEADERS,
    body: { serviceType: 'montaj', dateFrom: '2026-08-01', dateTo: '2026-09-15' },
  });
  const res = fakeRes();
  await api.availabilityHandler(req, res, { db: fakeEmptyDb(), expectedToken: VALID_TOKEN });
  assert.equal(res.statusCode, 400);
  assert.equal(res.body.error, 'invalid_request');
});

test('27b. interval de exact 31 zile -> acceptat (nu 400)', async () => {
  const req = fakeReq({
    headers: AUTH_HEADERS,
    body: { serviceType: 'montaj', dateFrom: '2026-08-01', dateTo: '2026-08-31' },
  });
  const res = fakeRes();
  await api.availabilityHandler(req, res, { db: fakeEmptyDb(), expectedToken: VALID_TOKEN });
  assert.equal(res.statusCode, 200);
});

test('28. fără Authorization -> 401 unauthorized', async () => {
  const req = fakeReq({ headers: { 'content-type': 'application/json' }, body: { serviceType: 'montaj' } });
  const res = fakeRes();
  await api.availabilityHandler(req, res, { db: fakeEmptyDb(), expectedToken: VALID_TOKEN });
  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, 'unauthorized');
});

test('29. token greșit -> 401 unauthorized', async () => {
  const req = fakeReq({
    headers: { authorization: 'Bearer token-gresit', 'content-type': 'application/json' },
    body: { serviceType: 'montaj' },
  });
  const res = fakeRes();
  await api.availabilityHandler(req, res, { db: fakeEmptyDb(), expectedToken: VALID_TOKEN });
  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, 'unauthorized');
});

test('30. GET -> 405 method_not_allowed', async () => {
  const req = fakeReq({ method: 'GET', headers: AUTH_HEADERS, body: {} });
  const res = fakeRes();
  await api.availabilityHandler(req, res, { db: fakeEmptyDb(), expectedToken: VALID_TOKEN });
  assert.equal(res.statusCode, 405);
  assert.equal(res.body.error, 'method_not_allowed');
});

// ---------------------------------------------------------------------------
// Cazuri suplimentare de siguranță HTTP
// ---------------------------------------------------------------------------

test('content-type non-JSON -> 400 invalid_request', async () => {
  const req = fakeReq({
    headers: { authorization: `Bearer ${VALID_TOKEN}`, 'content-type': 'text/plain' },
    body: { serviceType: 'montaj' },
  });
  const res = fakeRes();
  await api.availabilityHandler(req, res, { db: fakeEmptyDb(), expectedToken: VALID_TOKEN });
  assert.equal(res.statusCode, 400);
  assert.equal(res.body.error, 'invalid_request');
});

test('fără dateFrom/dateTo -> se aplică fereastra implicită de 14 zile, request valid', async () => {
  const req = fakeReq({ headers: AUTH_HEADERS, body: { serviceType: 'igienizare' } });
  const res = fakeRes();
  await api.availabilityHandler(req, res, { db: fakeEmptyDb(), expectedToken: VALID_TOKEN });
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.timezone, 'Europe/Bucharest');
  assert.equal(res.body.serviceType, 'igienizare');
});

test('secret neconfigurat (gol) -> refuză, nu permite implicit', async () => {
  const req = fakeReq({ headers: AUTH_HEADERS, body: { serviceType: 'montaj' } });
  const res = fakeRes();
  await api.availabilityHandler(req, res, { db: fakeEmptyDb(), expectedToken: '' });
  assert.equal(res.statusCode, 401);
});

test('răspuns de succes conține doar start/end/timezone/serviceType/slots — fără PII', async () => {
  const req = fakeReq({
    headers: AUTH_HEADERS,
    body: { serviceType: 'montaj', dateFrom: '2026-08-24', dateTo: '2026-08-24' },
  });
  const res = fakeRes();
  const teamsSnap = { forEach: (fn) => fn({ id: 'teamA' }) };
  const apptsSnap = { forEach: () => {} };
  const db = {
    collection(name) {
      if (name === 'teams') {
        return { get: async () => teamsSnap };
      }
      return {
        where() {
          return this;
        },
        get: async () => apptsSnap,
      };
    },
  };
  await api.availabilityHandler(req, res, { db, expectedToken: VALID_TOKEN });
  assert.equal(res.statusCode, 200);
  const keys = Object.keys(res.body).sort();
  assert.deepEqual(keys, ['serviceType', 'slots', 'timezone']);
  for (const slot of res.body.slots) {
    assert.deepEqual(Object.keys(slot).sort(), ['end', 'start']);
  }
});

test('eroare internă (Firestore aruncă) -> 500 internal_error, fără stack trace expus', async () => {
  const req = fakeReq({ headers: AUTH_HEADERS, body: { serviceType: 'montaj' } });
  const res = fakeRes();
  const db = {
    collection() {
      return {
        where() {
          return this;
        },
        get: async () => {
          throw new Error('boom - detaliu intern care nu trebuie expus');
        },
      };
    },
  };
  await api.availabilityHandler(req, res, { db, expectedToken: VALID_TOKEN });
  assert.equal(res.statusCode, 500);
  assert.deepEqual(res.body, { error: 'internal_error' });
});
