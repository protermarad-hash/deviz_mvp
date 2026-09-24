'use strict';

// Teste unitare pentru parserul XML e-Factura (FAZA 1 — Import materiale
// din factura). Toate fixture-urile sunt sintetice (date fictive, generate
// in acest fisier) — NU foloseste nicio factura reala. Vezi raportul FAZA 1
// pentru distinctia explicita fata de testarea cu o factura reala (locala,
// necommit-uita).

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  parseUblInvoiceXml,
  evaluateInvoiceAuthorization,
  MAX_XML_BYTES,
} = require('../supplier_invoice_parse')._internal;

// ── Helpere de generare fixture UBL ─────────────────────────────────────

function invoiceLineXml({
  id,
  name = 'Teava cupru frigorific 1/2',
  supplierCode = null,
  quantity = '10',
  unitCode = 'MTR',
  lineExtensionAmount = '100.00',
  priceAmount = '10.00',
  baseQuantity = null,
  vatPercent = '19',
  prefix = 'cbc',
  aggPrefix = 'cac',
} = {}) {
  const itemIdBlock = supplierCode
    ? `<${aggPrefix}:SellersItemIdentification><${prefix}:ID>${supplierCode}</${prefix}:ID></${aggPrefix}:SellersItemIdentification>`
    : '';
  const taxCategoryBlock =
    vatPercent !== null
      ? `<${aggPrefix}:ClassifiedTaxCategory><${prefix}:Percent>${vatPercent}</${prefix}:Percent></${aggPrefix}:ClassifiedTaxCategory>`
      : '';
  const baseQuantityBlock =
    baseQuantity !== null
      ? `<${prefix}:BaseQuantity unitCode="${unitCode}">${baseQuantity}</${prefix}:BaseQuantity>`
      : '';

  return `
  <${aggPrefix}:InvoiceLine>
    <${prefix}:ID>${id}</${prefix}:ID>
    <${prefix}:InvoicedQuantity unitCode="${unitCode}">${quantity}</${prefix}:InvoicedQuantity>
    <${prefix}:LineExtensionAmount currencyID="RON">${lineExtensionAmount}</${prefix}:LineExtensionAmount>
    <${aggPrefix}:Item>
      <${prefix}:Name>${name}</${prefix}:Name>
      ${itemIdBlock}
      ${taxCategoryBlock}
    </${aggPrefix}:Item>
    <${aggPrefix}:Price>
      <${prefix}:PriceAmount currencyID="RON">${priceAmount}</${prefix}:PriceAmount>
      ${baseQuantityBlock}
    </${aggPrefix}:Price>
  </${aggPrefix}:InvoiceLine>`;
}

function invoiceXml({
  invoiceId = 'F-2026-001',
  issueDate = '2026-09-01',
  currency = 'RON',
  supplierName = 'SC Furnizor Test SRL',
  supplierTaxId = 'RO12345678',
  linesXml = '',
  prefix = 'cbc',
  aggPrefix = 'cac',
  rootTag = 'Invoice',
} = {}) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<${rootTag} xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
  xmlns:${prefix}="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"
  xmlns:${aggPrefix}="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2">
  <${prefix}:ID>${invoiceId}</${prefix}:ID>
  <${prefix}:IssueDate>${issueDate}</${prefix}:IssueDate>
  <${prefix}:DocumentCurrencyCode>${currency}</${prefix}:DocumentCurrencyCode>
  <${aggPrefix}:AccountingSupplierParty>
    <${aggPrefix}:Party>
      <${aggPrefix}:PartyName><${prefix}:Name>${supplierName}</${prefix}:Name></${aggPrefix}:PartyName>
      <${aggPrefix}:PartyTaxScheme><${prefix}:CompanyID>${supplierTaxId}</${prefix}:CompanyID></${aggPrefix}:PartyTaxScheme>
    </${aggPrefix}:Party>
  </${aggPrefix}:AccountingSupplierParty>
  <${aggPrefix}:LegalMonetaryTotal>
    <${prefix}:TaxExclusiveAmount currencyID="RON">1000.00</${prefix}:TaxExclusiveAmount>
  </${aggPrefix}:LegalMonetaryTotal>
  ${linesXml}
</${rootTag}>`;
}

// ── 1. XML UBL valid cu o singura linie ─────────────────────────────────
test('1. XML UBL valid cu o singura linie', () => {
  const xml = invoiceXml({ linesXml: invoiceLineXml({ id: 1 }) });
  const result = parseUblInvoiceXml(xml);
  assert.equal(result.lines.length, 1);
  assert.equal(result.header.invoiceNumber, 'F-2026-001');
  assert.equal(result.header.invoiceDate, '2026-09-01');
  assert.equal(result.lines[0].rawName, 'Teava cupru frigorific 1/2');
});

// ── 2. XML cu 60-70 linii ────────────────────────────────────────────────
test('2. XML cu 65 de linii — toate extrase, in ordine', () => {
  const lines = Array.from({ length: 65 }, (_, i) =>
    invoiceLineXml({ id: i + 1, name: `Material test ${i + 1}` }),
  ).join('\n');
  const xml = invoiceXml({ linesXml: lines });
  const result = parseUblInvoiceXml(xml);
  assert.equal(result.lines.length, 65);
  assert.equal(result.lines[0].rawName, 'Material test 1');
  assert.equal(result.lines[64].rawName, 'Material test 65');
  result.lines.forEach((line, idx) => assert.equal(line.lineIndex, idx));
});

// ── 3. Namespace prefixes diferite ──────────────────────────────────────
test('3. Namespace prefixes diferite (nu cbc/cac) — tot extrage corect', () => {
  const xml = invoiceXml({
    prefix: 'n2',
    aggPrefix: 'n3',
    linesXml: invoiceLineXml({ id: 1, prefix: 'n2', aggPrefix: 'n3' }),
  });
  const result = parseUblInvoiceXml(xml);
  assert.equal(result.header.invoiceNumber, 'F-2026-001');
  assert.equal(result.lines.length, 1);
  assert.equal(result.lines[0].rawName, 'Teava cupru frigorific 1/2');
});

// ── 4. Supplier name + tax ID ────────────────────────────────────────────
test('4. Supplier name + CUI extrase corect', () => {
  const xml = invoiceXml({
    supplierName: 'SC ALTFEL INSTAL SRL',
    supplierTaxId: 'RO87654321',
    linesXml: invoiceLineXml({ id: 1 }),
  });
  const result = parseUblInvoiceXml(xml);
  assert.equal(result.header.supplierName, 'SC ALTFEL INSTAL SRL');
  assert.equal(result.header.supplierTaxId, 'RO87654321');
});

// ── 5. Cod produs furnizor prezent ──────────────────────────────────────
test('5. Cod produs furnizor prezent — pastrat exact (inclusiv zerouri)', () => {
  const xml = invoiceXml({ linesXml: invoiceLineXml({ id: 1, supplierCode: '00789' }) });
  const result = parseUblInvoiceXml(xml);
  assert.equal(result.lines[0].supplierProductCode, '00789');
});

// ── 6. Cod produs lipsa ──────────────────────────────────────────────────
test('6. Cod produs furnizor lipsa — null, nu fabricat', () => {
  const xml = invoiceXml({ linesXml: invoiceLineXml({ id: 1, supplierCode: null }) });
  const result = parseUblInvoiceXml(xml);
  assert.equal(result.lines[0].supplierProductCode, null);
});

// ── 7. TVA prezent ───────────────────────────────────────────────────────
test('7. Cota TVA prezenta — extrasa ca numar', () => {
  const xml = invoiceXml({ linesXml: invoiceLineXml({ id: 1, vatPercent: '19' }) });
  const result = parseUblInvoiceXml(xml);
  assert.equal(result.lines[0].vatRate, 19);
});

// ── 8. TVA lipsa/ambigua ────────────────────────────────────────────────
test('8. Cota TVA lipsa — ramane null, avertisment inclus, nu se calculeaza', () => {
  const xml = invoiceXml({ linesXml: invoiceLineXml({ id: 1, vatPercent: null }) });
  const result = parseUblInvoiceXml(xml);
  assert.equal(result.lines[0].vatRate, null);
  assert.ok(result.lines[0].warnings.some((w) => w.toLowerCase().includes('tva')));
});

// ── 9. Cantitate fractionara ────────────────────────────────────────────
test('9. Cantitate fractionara — pastrata cu precizie', () => {
  const xml = invoiceXml({ linesXml: invoiceLineXml({ id: 1, quantity: '12.375' }) });
  const result = parseUblInvoiceXml(xml);
  assert.equal(result.lines[0].quantity, 12.375);
});

// ── 10. Pret cu zecimale ─────────────────────────────────────────────────
test('10. Pret cu zecimale — extras corect', () => {
  const xml = invoiceXml({
    linesXml: invoiceLineXml({ id: 1, priceAmount: '10.4567', quantity: '1', lineExtensionAmount: '10.4567' }),
  });
  const result = parseUblInvoiceXml(xml);
  assert.equal(result.lines[0].unitPriceNoVat, 10.4567);
  assert.equal(result.lines[0].unitPriceDerived, false);
});

// ── 11. BaseQuantity diferit de 1 ────────────────────────────────────────
test('11. Price/BaseQuantity diferit de 1 — pret unitar = PriceAmount / BaseQuantity', () => {
  // Pret de 50 RON pentru un pachet de 5 metri => 10 RON/metru.
  const xml = invoiceXml({
    linesXml: invoiceLineXml({
      id: 1,
      quantity: '15',
      unitCode: 'MTR',
      lineExtensionAmount: '150.00',
      priceAmount: '50.00',
      baseQuantity: '5',
    }),
  });
  const result = parseUblInvoiceXml(xml);
  assert.equal(result.lines[0].unitPriceNoVat, 10);
  assert.ok(result.lines[0].warnings.some((w) => w.includes('BaseQuantity')));
});

test('11b. Price/BaseQuantity absent (implicit 1) — nu genereaza avertisment BaseQuantity', () => {
  const xml = invoiceXml({
    linesXml: invoiceLineXml({ id: 1, priceAmount: '10.00', baseQuantity: null }),
  });
  const result = parseUblInvoiceXml(xml);
  assert.equal(result.lines[0].unitPriceNoVat, 10);
  assert.ok(!result.lines[0].warnings.some((w) => w.includes('BaseQuantity')));
});

// ── 12. XML invalid ──────────────────────────────────────────────────────
test('12. XML invalid (tag neinchis) — arunca eroare invalid-argument', () => {
  const badXml = '<Invoice><ID>F1</ID></InvoiceWrong>';
  assert.throws(
    () => parseUblInvoiceXml(badXml),
    (err) => err.code === 'invalid-argument',
  );
});

// ── 13. XML fara InvoiceLine ─────────────────────────────────────────────
test('13. XML valid dar fara InvoiceLine — arunca eroare invalid-argument', () => {
  const xml = invoiceXml({ linesXml: '' });
  assert.throws(
    () => parseUblInvoiceXml(xml),
    (err) => err.code === 'invalid-argument' && /InvoiceLine/.test(err.message),
  );
});

test('13b. Radacina care nu este Invoice — arunca eroare invalid-argument', () => {
  const xml = invoiceXml({ rootTag: 'ApplicationResponse', linesXml: invoiceLineXml({ id: 1 }) });
  assert.throws(
    () => parseUblInvoiceXml(xml),
    (err) => err.code === 'invalid-argument',
  );
});

// ── 14. Fisier peste limita permisa ─────────────────────────────────────
test('14. Continut peste MAX_XML_BYTES — semnal de dimensiune, verificat de callable', () => {
  const oversized = 'x'.repeat(MAX_XML_BYTES + 1);
  assert.ok(Buffer.byteLength(oversized, 'utf8') > MAX_XML_BYTES);
  // Verificarea efectiva de respingere are loc in handler-ul onCall
  // (parseSupplierInvoiceXml), inainte de a apela parseUblInvoiceXml —
  // acest test confirma doar ca pragul e cel documentat (5MB).
  assert.equal(MAX_XML_BYTES, 5 * 1024 * 1024);
});

// ── 15. Utilizator neautentificat ───────────────────────────────────────
test('15. Utilizator neautentificat — authorized=false, code=unauthenticated', () => {
  const result = evaluateInvoiceAuthorization({
    hasAuth: false,
    uid: '',
    userExists: false,
    userData: {},
  });
  assert.equal(result.authorized, false);
  assert.equal(result.code, 'unauthenticated');
});

// ── 16. Utilizator fara rol administrativ ───────────────────────────────
test('16. Utilizator autentificat, activ, rol "employee" — permission-denied', () => {
  const result = evaluateInvoiceAuthorization({
    hasAuth: true,
    uid: 'uid-employee-1',
    userExists: true,
    userData: { role: 'employee', active: true },
  });
  assert.equal(result.authorized, false);
  assert.equal(result.code, 'permission-denied');
});

test('16b. Utilizator admin, dar cont inactiv — permission-denied', () => {
  const result = evaluateInvoiceAuthorization({
    hasAuth: true,
    uid: 'uid-admin-inactive',
    userExists: true,
    userData: { role: 'admin', active: false },
  });
  assert.equal(result.authorized, false);
  assert.equal(result.code, 'permission-denied');
});

test('16c. Utilizator rol "office", activ — autorizat', () => {
  const result = evaluateInvoiceAuthorization({
    hasAuth: true,
    uid: 'uid-office-1',
    userExists: true,
    userData: { role: 'office', active: true },
  });
  assert.equal(result.authorized, true);
  assert.equal(result.role, 'office');
});

test('16d. Utilizator rol "admin", camp active absent (backward-compat) — autorizat', () => {
  const result = evaluateInvoiceAuthorization({
    hasAuth: true,
    uid: 'uid-admin-legacy',
    userExists: true,
    userData: { role: 'admin' },
  });
  assert.equal(result.authorized, true);
});
