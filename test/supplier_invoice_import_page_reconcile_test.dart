// FAZA "reconcile prin server" + "persist invoice metadata server-side" —
// teste STRUCTURALE pentru _pickAndParseFile din
// supplier_invoice_import_page.dart.
//
// De ce structural, nu comportamental: metoda e privata pe un State ce
// necesita FilePicker + Firebase (cloud_functions, cloud_firestore) reale
// pentru a rula end-to-end — niciun emulator/mock nu e cablat pentru
// acest ecran in suita curenta de teste (acelasi motiv documentat in
// supplier_invoice_import_repair_test.dart pentru markInvoiceAllocated).
// In loc sa simulam un mock fragil, verificam DIRECT ordinea reala a
// codului sursa — proprietatile critice cerute de audit:
//   1. parserul (server) trebuie apelat INTOTDEAUNA, fara niciun shortcut
//      care sare peste el;
//   2. dupa parsare, clientul NU mai face NICIUN apel Firestore pentru
//      cazul canonic (serverul e deja autoritar — invoicePersisted
//      garantat) — singurul apel Firestore ramas e fallback-ul LEGACY,
//      strict conditionat de divergenta BOM (localHash != invoiceId
//      server), niciodata folosit pentru cazul normal;
//   3. `_invoiceId` nu e niciodata setat direct din `localHash`.
//
// Comportamentul de fond (idempotenta persistarii Storage/Firestore
// indiferent de starea existenta, reutilizare fara duplicat, self-heal) e
// verificat separat:
// - functions_invoice_import/test/supplier_invoice_source_persistence.test.js
// - functions_invoice_import/test/supplier_invoice_metadata_persistence.test.js
// - test/supplier_invoice_hash_dedup_test.dart (divergenta BOM)

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
        'dupa parseXml, SINGURUL apel loadExistingInvoiceByHash ramas este '
        'fallback-ul LEGACY, argumentul lui fiind localHash — NU '
        'parseResult.invoiceId (serverul e deja autoritar pentru cazul '
        'canonic, niciun apel Firestore suplimentar necesar)', () {
      final body = bodyOf('Future<void> _pickAndParseFile()');

      final parseCallIndex = body.indexOf('_parserClient.parseXml(');
      final afterParse = body.substring(parseCallIndex);

      final matches = 'loadExistingInvoiceByHash('.allMatches(afterParse).toList();
      expect(matches.length, 1,
          reason: 'trebuie sa existe EXACT un singur apel '
              'loadExistingInvoiceByHash dupa parseXml (fallback-ul legacy) '
              '— orice apel suplimentar ar insemna reintroducerea '
              'verificarii canonice redundante');

      final argStart = matches.first.end;
      final argEnd = afterParse.indexOf(')', argStart);
      final arg = afterParse.substring(argStart, argEnd).trim();
      expect(arg, 'localHash',
          reason: 'fallback-ul legacy trebuie sa verifice dupa hash-ul '
              'local (bytes brute), nu dupa invoiceId-ul canonic');

      // Acest apel trebuie sa fie strict conditionat de divergenta BOM
      // (bomMismatch), nu necondiționat.
      final callSite = afterParse.substring(0, matches.first.start);
      expect(callSite.contains('if (bomMismatch)'), true,
          reason: 'fallback-ul legacy trebuie sa ruleze DOAR cand '
              'localHash difera de invoiceId-ul canonic');
    });

    test(
        'clientul se bazeaza direct pe parseResult.invoicePersisted (NU mai '
        'face niciun apel Firestore de scriere pentru metadata facturii)',
        () {
      final body = bodyOf('Future<void> _pickAndParseFile()');
      expect(body.contains('parseResult.invoicePersisted'), true);
      expect(body.contains('persistNewInvoice'), false,
          reason: 'persistNewInvoice a fost eliminat complet din '
              'SupplierInvoiceRepository — nu mai poate fi apelat aici');
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

  group('_doImport — nicio tranzactie/scriere Firestore client-side', () {
    late String source;

    setUpAll(() {
      source = File(
        'lib/features/jobs/invoice_import/supplier_invoice_import_page.dart',
      ).readAsStringSync();
    });

    test('_doImport nu mai contine niciun apel persistNewInvoice(...)/runTransaction(...)', () {
      final start = source.indexOf('Future<void> _doImport(');
      expect(start, greaterThanOrEqualTo(0));
      final end = source.indexOf('\n  }\n', start);
      final body = source.substring(start, end);

      // Verificam sintaxa de APEL (paranteza), nu simpla mentiune a
      // numelui — comentariile explicative pot mentiona legitim
      // "persistNewInvoice" ca sa documenteze DE CE a fost eliminat.
      expect(body.contains('persistNewInvoice('), false);
      expect(body.contains('.runTransaction('), false);
    });
  });
}
