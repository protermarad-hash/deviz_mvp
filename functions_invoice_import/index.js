'use strict';

// Codebase Firebase Functions IZOLAT — vezi package.json pentru motiv.
// Contine EXCLUSIV parseSupplierInvoiceXml. Nicio dependenta, niciun
// require catre codebase-ul legacy (../functions/) — cele doua codebase-uri
// sunt complet independente, deployabile separat, fara ca CLI-ul sa
// analizeze vreodata codul/secretele celuilalt.

const { setGlobalOptions } = require('firebase-functions/v2/options');
const admin = require('firebase-admin');

admin.initializeApp();
setGlobalOptions({ region: 'europe-west1', maxInstances: 10 });

const { parseSupplierInvoiceXml } = require('./supplier_invoice_parse');
exports.parseSupplierInvoiceXml = parseSupplierInvoiceXml;
