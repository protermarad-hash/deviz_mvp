// Audit hash/dedup — FAZA "reconcile prin server". Teste PURE (fara
// Firebase) pentru divergenta dintre hash-ul local (pe bytes brute,
// echivalent SupplierInvoiceRepository.computeSha256) si hash-ul canonic
// server (pe xmlContent DUPA decodeXmlBytesToUtf8Text — acelasi text
// trimis catre parseSupplierInvoiceXml, care calculeaza
// computeSourceFileHash(xmlContent) server-side).
//
// Confirma exact ce a demonstrat auditul manual (rulat pe XML-ul Romstal
// real, in afara acestui repo): identice pentru fisiere fara BOM
// (inclusiv diacritice/CRLF/LF/trailing newline), diferite DOAR cand
// fisierul are BOM UTF-8 la inceput.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devizpro_ultra/features/jobs/invoice_import/supplier_invoice_repository.dart';

const _bom = <int>[0xEF, 0xBB, 0xBF];

String _localHash(Uint8List bytes) => sha256.convert(bytes).toString();

String _serverHash(Uint8List bytes) {
  final xmlText = decodeXmlBytesToUtf8Text(bytes);
  return sha256.convert(utf8.encode(xmlText)).toString();
}

Uint8List _bytesOf(String text) => Uint8List.fromList(utf8.encode(text));

Uint8List _withBom(String text) =>
    Uint8List.fromList([..._bom, ...utf8.encode(text)]);

void main() {
  group('Audit hash/dedup — localHash vs invoiceId canonic server', () {
    const simple = '<Invoice><ID>F1</ID></Invoice>';
    const diacritice = '<Invoice><ID>F1</ID><Name>Țeavă cupru â î ș</Name></Invoice>';

    test('UTF-8 simplu, fara BOM -> hash-uri IDENTICE', () {
      final bytes = _bytesOf(simple);
      expect(_localHash(bytes), _serverHash(bytes));
    });

    test('UTF-8 cu diacritice romanesti, fara BOM -> hash-uri IDENTICE', () {
      final bytes = _bytesOf(diacritice);
      expect(_localHash(bytes), _serverHash(bytes));
    });

    test('LF line endings -> hash-uri IDENTICE', () {
      final bytes = _bytesOf(simple.replaceAll('><', '>\n<'));
      expect(_localHash(bytes), _serverHash(bytes));
    });

    test('CRLF line endings -> hash-uri IDENTICE', () {
      final bytes = _bytesOf(simple.replaceAll('><', '>\r\n<'));
      expect(_localHash(bytes), _serverHash(bytes));
    });

    test('cu trailing newline -> hash-uri IDENTICE', () {
      final bytes = _bytesOf('$simple\n');
      expect(_localHash(bytes), _serverHash(bytes));
    });

    test('fara trailing newline -> hash-uri IDENTICE', () {
      final bytes = _bytesOf(simple);
      expect(_localHash(bytes), _serverHash(bytes));
    });

    // ── Cazul BOM — SINGURA divergenta ────────────────────────────────
    test(
        'BOM: localHash (bytes brute, INCLUDE BOM) DIFERA de invoiceId '
        'canonic server (xmlContent dupa strip BOM) — invoiceId-ul '
        'serverului e cel autoritar, folosit pentru dedup, niciodata '
        'localHash', () {
      final bytes = _withBom(simple);
      final local = _localHash(bytes);
      final server = _serverHash(bytes);
      expect(local, isNot(equals(server)));

      // Confirmare directa a cauzei: server hash-ul e calculat pe
      // text-ul FARA BOM.
      expect(_serverHash(bytes), _serverHash(_bytesOf(simple)));
    });

    test('BOM + diacritice -> tot divergent, acelasi motiv', () {
      final bytes = _withBom(diacritice);
      expect(_localHash(bytes), isNot(equals(_serverHash(bytes))));
    });

    test(
        'decodeXmlBytesToUtf8Text elimina EXACT un singur BOM de la '
        'inceput, restul textului ramane neschimbat', () {
      final withBom = _withBom(simple);
      final withoutBom = _bytesOf(simple);
      expect(decodeXmlBytesToUtf8Text(withBom), simple);
      expect(decodeXmlBytesToUtf8Text(withoutBom), simple);
    });
  });
}
