// FAZA 1 — diagnostic OBLIGATORIU (nu implementare): ce impact ar avea
// Faza 2 (append in JobRecord.materials cu sourceInvoiceId/
// sourceInvoiceLineId/allocatedQty) asupra dimensiunii documentului
// `jobs/{id}` din Firestore, la 70/100/150 linii de material.
//
// NU modifica JobRecord.materials — doar masoara. Firestore are o limita
// HARD de 1 MiB (1.048.576 bytes) per document; acest test compara
// dimensiunea reala fata de acea limita, ca sa stim din timp daca Faza 2
// (alocare materiale din factura in lucrare) e sigura la volume realiste.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

/// Limita hard Firestore pentru un singur document.
const int kFirestoreDocumentByteLimit = 1024 * 1024;

/// O linie de material cu structura REALA folosita azi in
/// JobRecord.materials (vezi lucrare_detalii_page.dart _onAddMaterial /
/// services/lucrare_cost_calc.dart): id, materialId, name, um, qty,
/// price, realPrice, total.
Map<String, dynamic> _realisticMaterialLine(int index) {
  return <String, dynamic>{
    'id': 'job-mat-${1732000000000 + index}',
    'materialId': 'mat-${100000 + index}',
    // Denumire realista, lungime tipica pentru materiale HVAC/instalatii
    // (nu un placeholder de 3 caractere — ar subestima dimensiunea reala).
    'name':
        'Teava cupru frigorific izolata 1/2" x 0.8mm colac 25m - varianta $index',
    'um': 'buc',
    'qty': 12.5 + index,
    'price': 45.67,
    'realPrice': 42.10,
    'total': (12.5 + index) * 45.67,
  };
}

/// Aceeasi linie, cu campurile OPTIONALE propuse pentru Faza 2 (traseu
/// spre factura sursa) — vezi raportul de audit, sectiunea "Model de date
/// propus": sourceInvoiceId, sourceInvoiceLineId, allocatedQty. Toate
/// opționale, backward-compatible — un client vechi le ignora.
Map<String, dynamic> _realisticMaterialLineWithInvoiceRef(int index) {
  return <String, dynamic>{
    ..._realisticMaterialLine(index),
    'sourceInvoiceId': 'inv-${900000 + (index ~/ 10)}',
    'sourceInvoiceLineId': 'line-$index',
    'allocatedQty': 12.5 + index,
  };
}

int _utf8ByteSize(Object value) => utf8.encode(jsonEncode(value)).length;

void main() {
  group('Dimensiune JobRecord.materials la volume realiste (diagnostic Faza 2)',
      () {
    for (final lineCount in <int>[70, 100, 150]) {
      test('$lineCount linii material — fara referinta factura', () {
        final materials = List<Map<String, dynamic>>.generate(
          lineCount,
          _realisticMaterialLine,
        );
        final bytes = _utf8ByteSize(materials);
        final percentOfLimit = bytes / kFirestoreDocumentByteLimit * 100;

        // ignore: avoid_print
        print(
          '[size-diagnostic] $lineCount linii (schema actuala): '
          '$bytes bytes (~${(bytes / 1024).toStringAsFixed(1)} KB), '
          '${percentOfLimit.toStringAsFixed(3)}% din limita Firestore de 1 MiB.',
        );

        // Sanity check, nu o limita de produs: la 150 linii cu schema
        // actuala, documentul TREBUIE sa ramana cu mult sub limita
        // Firestore — altfel diagnosticul semnaleaza o problema reala.
        expect(bytes, lessThan(kFirestoreDocumentByteLimit ~/ 4));
      });

      test(
          '$lineCount linii material — CU referinta factura (campuri propuse Faza 2)',
          () {
        final materials = List<Map<String, dynamic>>.generate(
          lineCount,
          _realisticMaterialLineWithInvoiceRef,
        );
        final bytes = _utf8ByteSize(materials);
        final percentOfLimit = bytes / kFirestoreDocumentByteLimit * 100;

        // ignore: avoid_print
        print(
          '[size-diagnostic] $lineCount linii (+ sourceInvoiceId/'
          'sourceInvoiceLineId/allocatedQty): '
          '$bytes bytes (~${(bytes / 1024).toStringAsFixed(1)} KB), '
          '${percentOfLimit.toStringAsFixed(3)}% din limita Firestore de 1 MiB.',
        );

        expect(bytes, lessThan(kFirestoreDocumentByteLimit ~/ 4));
      });
    }

    test('cost marginal per linie al campurilor propuse pentru Faza 2', () {
      const lineCount = 100;
      final withoutRef = List<Map<String, dynamic>>.generate(
        lineCount,
        _realisticMaterialLine,
      );
      final withRef = List<Map<String, dynamic>>.generate(
        lineCount,
        _realisticMaterialLineWithInvoiceRef,
      );
      final deltaBytes = _utf8ByteSize(withRef) - _utf8ByteSize(withoutRef);
      final perLine = deltaBytes / lineCount;

      // ignore: avoid_print
      print(
        '[size-diagnostic] cost marginal per linie pentru '
        'sourceInvoiceId+sourceInvoiceLineId+allocatedQty: '
        '~${perLine.toStringAsFixed(1)} bytes/linie '
        '(total +$deltaBytes bytes la $lineCount linii).',
      );

      expect(perLine, lessThan(200));
    });
  });
}
