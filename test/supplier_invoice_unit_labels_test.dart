// Test sintetic, izolat — mapare cod UBL -> eticheta UM prietenoasa
// (descoperit ca necesar la validarea pe factura reala Romstal: unitCode
// "H87" trebuie afisat ca "buc" in UI, dar pastrat neschimbat intern).
// Nu foloseste date din factura reala — doar codul UBL "H87", care e un
// cod standard public (UN/ECE Rec 20), nu o data sensibila.

import 'package:flutter_test/flutter_test.dart';
import 'package:devizpro_ultra/features/jobs/invoice_import/supplier_invoice_unit_labels.dart';

void main() {
  group('friendlyUnitLabel', () {
    test('H87 -> buc', () {
      expect(friendlyUnitLabel('H87'), 'buc');
    });

    test('h87 (lowercase) -> buc (case-insensitive)', () {
      expect(friendlyUnitLabel('h87'), 'buc');
    });

    test('EA -> buc', () {
      expect(friendlyUnitLabel('EA'), 'buc');
    });

    test('MTR -> m', () {
      expect(friendlyUnitLabel('MTR'), 'm');
    });

    test('cod necunoscut -> ramane neschimbat (nu se inventeaza etichete)', () {
      expect(friendlyUnitLabel('XYZ'), 'XYZ');
    });

    test('null -> string gol', () {
      expect(friendlyUnitLabel(null), '');
    });

    test('string gol -> string gol', () {
      expect(friendlyUnitLabel('   '), '');
    });
  });
}
