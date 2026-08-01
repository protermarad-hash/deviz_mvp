import 'package:devizpro_ultra/features/jobs/services/lucrare_cost_calc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LucrareCostCalc.materialLineTotal', () {
    test('uses qty * price when no explicit total and no real price', () {
      final total = LucrareCostCalc.materialLineTotal(
        const {'qty': 3, 'price': 10},
      );
      expect(total, 30);
    });

    test('prefers explicit total when set and no real price', () {
      final total = LucrareCostCalc.materialLineTotal(
        const {'qty': 3, 'price': 10, 'total': 25},
      );
      expect(total, 25);
    });

    test('prefers real price over explicit total when real price is set',
        () {
      final total = LucrareCostCalc.materialLineTotal(
        const {'qty': 3, 'price': 10, 'total': 30, 'realPrice': 15},
      );
      expect(total, 45);
    });

    test('ignores real price of 0 (unset)', () {
      final total = LucrareCostCalc.materialLineTotal(
        const {'qty': 3, 'price': 10, 'realPrice': 0},
      );
      expect(total, 30);
    });
  });

  group('LucrareCostCalc.materialLineOfferedTotal', () {
    test('always ignores real price', () {
      final total = LucrareCostCalc.materialLineOfferedTotal(
        const {'qty': 3, 'price': 10, 'realPrice': 999},
      );
      expect(total, 30);
    });
  });

  group('LucrareCostCalc.materialLineRealVsOfferedDiff', () {
    test('returns 0 when real price is not set', () {
      final diff = LucrareCostCalc.materialLineRealVsOfferedDiff(
        const {'qty': 3, 'price': 10},
      );
      expect(diff, 0);
    });

    test('returns positive diff (depasire) when real price is higher', () {
      final diff = LucrareCostCalc.materialLineRealVsOfferedDiff(
        const {'qty': 2, 'price': 10, 'realPrice': 15},
      );
      expect(diff, 10);
    });

    test('returns negative diff (economie) when real price is lower', () {
      final diff = LucrareCostCalc.materialLineRealVsOfferedDiff(
        const {'qty': 2, 'price': 10, 'realPrice': 7},
      );
      expect(diff, -6);
    });
  });

  group('LucrareCostCalc.costTotalUnificat', () {
    test('sums materials, labor and partners', () {
      final total = LucrareCostCalc.costTotalUnificat(
        materialsTotal: 100,
        laborTotal: 200,
        partnersTotal: 50,
      );
      expect(total, 350);
    });
  });

  group('LucrareCostCalc.grossProfit', () {
    test('subtracts cost total from estimated value', () {
      final profit = LucrareCostCalc.grossProfit(
        estimatedValue: 1000,
        costTotal: 650,
      );
      expect(profit, 350);
    });

    test('can be negative when cost exceeds estimated value', () {
      final profit = LucrareCostCalc.grossProfit(
        estimatedValue: 500,
        costTotal: 650,
      );
      expect(profit, -150);
    });
  });
}
