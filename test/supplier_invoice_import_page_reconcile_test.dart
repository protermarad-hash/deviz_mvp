// FAZA "reconcile prin server" — teste STRUCTURALE pentru
// _pickAndParseFile din supplier_invoice_import_page.dart.
//
// De ce structural, nu comportamental: metoda e privata pe un State ce
// necesita FilePicker + Firebase (cloud_functions, cloud_firestore) reale
// pentru a rula end-to-end — niciun emulator/mock nu e cablat pentru
// acest ecran in suita curenta de teste (acelasi motiv documentat in
// supplier_invoice_import_repair_test.dart pentru markInvoiceAllocated).
// In loc sa simulam un mock fragil, verificam DIRECT ordinea reala a
// codului sursa — proprietatea critica ceruta de audit: parserul
// (server) trebuie apelat INTOTDEAUNA, iar verificarea de reutilizare
// Firestore trebuie sa foloseasca EXCLUSIV invoiceId-ul canonic (server),
// niciodata hash-ul local — nu un shortcut care sare peste server.
//
// Comportamentul de fond (idempotenta persistarii Storage indiferent de
// starea Firestore, reutilizare fara duplicat) e verificat separat:
// - functions_invoice_import/test/supplier_invoice_source_persistence.test.js
//   (self-heal Storage — server, cu fake bucket)
// - test/supplier_invoice_hash_dedup_test.dart (divergenta BOM)
// - inspectia codului persistNewInvoice (tranzactie Firestore, verificare
//   existentei dupa invoiceId canonic, neschimbata din FAZA 2/1.1).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('_pickAndParseFile — reconciliere exclusiv prin server', () {
    late String source;

    setUpAll(() {
      source = File(
        'lib/features/jobs/invoice_import/supplier_invoice_import_page.dart',
      ).readAsStringSync();
    });

    String bodyOf(String methodSignature) {
      final start = source.indexOf(methodSignature);
      expect(start, greaterThanOrEqualTo(0),
          reason: 'metoda $methodSignature trebuie sa existe in fisier');
      // Corpul metodei se termina la "\n  }\n\n" (inchidere metoda,
      // indentare 2 spatii) — suficient de precis pentru acest fisier.
      final end = source.indexOf('\n  }\n', start);
      expect(end, greaterThan(start));
      return source.substring(start, end);
    }

    test(
        'parseXml (server) este apelat NECONDITIONAT — nu exista niciun '
        'return/shortcut bazat pe hash local INAINTE de apelul catre '
        'parser', () {
      final body = bodyOf('Future<void> _pickAndParseFile()');

      final parseCallIndex = body.indexOf('_parserClient.parseXml(');
      expect(parseCallIndex, greaterThanOrEqualTo(0),
          reason: 'metoda trebuie sa apeleze parserul server-side');

      // Orice 'return' din corpul metodei INAINTE de apelul parseXml ar
      // insemna ca exista o cale care sare peste server — cauta explicit
      // un shortcut de forma "loadExistingInvoiceByHash(...)" urmat de
      // 'return' INAINTE de indexul apelului parseXml.
      final beforeParse = body.substring(0, parseCallIndex);
      final hasExistenceCheckBeforeParse =
          beforeParse.contains('loadExistingInvoiceByHash');
      expect(hasExistenceCheckBeforeParse, false,
          reason: 'nu trebuie sa existe nicio verificare de existenta '
              'Firestore INAINTE de apelul catre parseSupplierInvoiceXml '
              '(asta ar recrea shortcut-ul eliminat)');
    });

    test(
        'verificarea de reutilizare Firestore (loadExistingInvoiceByHash) '
        'foloseste EXCLUSIV parseResult.invoiceId (canonic, server) — NU '
        'localHash — ca prim criteriu de reuse', () {
      final body = bodyOf('Future<void> _pickAndParseFile()');

      final parseCallIndex = body.indexOf('_parserClient.parseXml(');
      final afterParse = body.substring(parseCallIndex);

      final firstExistenceCheckIndex =
          afterParse.indexOf('loadExistingInvoiceByHash(');
      expect(firstExistenceCheckIndex, greaterThanOrEqualTo(0),
          reason: 'trebuie sa existe o verificare de reutilizare DUPA '
              'apelul parserului');

      // Argumentul primului apel loadExistingInvoiceByHash(...) de dupa
      // parseXml trebuie sa fie invoiceId-ul canonic din raspunsul
      // serverului, nu variabila locala.
      final argStart = firstExistenceCheckIndex +
          'loadExistingInvoiceByHash('.length;
      final argEnd = afterParse.indexOf(')', argStart);
      final firstArg = afterParse.substring(argStart, argEnd).trim();
      expect(firstArg, 'parseResult.invoiceId');
    });

    test(
        'localHash este folosit DOAR diagnostic si ca fallback LEGACY '
        '(auxiliar) — niciodata pentru a seta _invoiceId direct', () {
      final body = bodyOf('Future<void> _pickAndParseFile()');

      // Nicaieri in metoda nu trebuie sa apara atribuirea directa
      // "_invoiceId = localHash" — invoiceId-ul canonic vine mereu din
      // parseResult.invoiceId sau dintr-un document Firestore incarcat.
      expect(body.contains('_invoiceId = localHash'), false);
    });
  });
}
