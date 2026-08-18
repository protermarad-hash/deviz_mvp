import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/user_preferences/status_order_utils.dart';

void main() {
  group('resolveStatusOrder — ordine custom de grupuri de status', () {
    const allKeys = <String>['draft', 'sent', 'accepted', 'convertit'];
    const defaultOrder = <String>['accepted', 'sent', 'draft', 'convertit'];

    test('fără ordine salvată → cade pe ordinea implicită (fallback)', () {
      final result = resolveStatusOrder(
        allKeys: allKeys,
        defaultOrder: defaultOrder,
        savedOrder: null,
      );
      expect(result, defaultOrder);
    });

    test('ordine salvată completă → respectă exact ordinea userului', () {
      final result = resolveStatusOrder(
        allKeys: allKeys,
        defaultOrder: defaultOrder,
        savedOrder: const ['convertit', 'draft', 'sent', 'accepted'],
      );
      expect(result, ['convertit', 'draft', 'sent', 'accepted']);
    });

    test(
        'status nou apărut în enum (absent din ordinea salvată) → inclus automat la final, fără crash',
        () {
      final result = resolveStatusOrder(
        allKeys: const ['draft', 'sent', 'accepted', 'convertit', 'anulat'],
        defaultOrder: defaultOrder,
        savedOrder: const ['accepted', 'sent', 'draft', 'convertit'],
      );
      expect(result, ['accepted', 'sent', 'draft', 'convertit', 'anulat']);
    });

    test(
        'cheie din ordinea salvată care nu mai există (status șters din cod) → ignorată silențios',
        () {
      final result = resolveStatusOrder(
        allKeys: allKeys,
        defaultOrder: defaultOrder,
        savedOrder: const ['accepted', 'expirat_demult', 'sent', 'draft', 'convertit'],
      );
      expect(result, ['accepted', 'sent', 'draft', 'convertit']);
    });

    test('ordine salvată parțială → completată cu restul din ordinea implicită', () {
      final result = resolveStatusOrder(
        allKeys: allKeys,
        defaultOrder: defaultOrder,
        savedOrder: const ['convertit'],
      );
      expect(result, ['convertit', 'accepted', 'sent', 'draft']);
    });

    test('ordine salvată goală → tratată la fel ca null (fallback pe implicit)', () {
      final result = resolveStatusOrder(
        allKeys: allKeys,
        defaultOrder: defaultOrder,
        savedOrder: const [],
      );
      expect(result, defaultOrder);
    });

    test('duplicate în ordinea salvată → păstrate o singură dată', () {
      final result = resolveStatusOrder(
        allKeys: allKeys,
        defaultOrder: defaultOrder,
        savedOrder: const ['accepted', 'accepted', 'sent', 'draft', 'convertit'],
      );
      expect(result, ['accepted', 'sent', 'draft', 'convertit']);
      expect(result.toSet().length, result.length);
    });

    test('rezultatul conține exact toate cheile din allKeys, fără omitere', () {
      final result = resolveStatusOrder(
        allKeys: allKeys,
        defaultOrder: defaultOrder,
        savedOrder: const ['sent'],
      );
      expect(result.toSet(), allKeys.toSet());
      expect(result.length, allKeys.length);
    });
  });
}
