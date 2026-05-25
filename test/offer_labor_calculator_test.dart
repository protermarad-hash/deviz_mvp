import 'package:devizpro_ultra/features/oferte/offer_labor_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfferLaborCalculator.roundPriceUpToTen', () {
    test('keeps exact multiples of ten unchanged', () {
      expect(OfferLaborCalculator.roundPriceUpToTen(1000), 1000);
    });

    test('rounds positive values upward to nearest ten', () {
      expect(OfferLaborCalculator.roundPriceUpToTen(1919.45), 1920);
      expect(OfferLaborCalculator.roundPriceUpToTen(2510.08), 2520);
    });
  });

  group('OfferLaborCalculator.computeFromResources', () {
    test('computes totals from personal, vehicles, tools and allowances', () {
      final breakdown = OfferLaborCalculator.computeFromResources(
        personal: const <OfferLaborResourceUsage>[
          OfferLaborResourceUsage(
            resourceId: 'p-1',
            name: 'Tech',
            hours: 10,
            days: 0,
            hourlyRate: 100,
            dailyRate: 0,
          ),
        ],
        autoturisme: const <OfferLaborResourceUsage>[
          OfferLaborResourceUsage(
            resourceId: 'v-1',
            name: 'Van',
            hours: 5,
            days: 2,
            hourlyRate: 20,
            dailyRate: 50,
          ),
        ],
        pacheteScule: const <OfferLaborResourceUsage>[
          OfferLaborResourceUsage(
            resourceId: 't-1',
            name: 'Kit',
            hours: 4,
            days: 3,
            hourlyRate: 10,
            dailyRate: 100,
          ),
        ],
        perDiemDays: 2,
        perDiemPerDay: 30,
        lodgingNights: 1,
        lodgingPerNight: 40,
      );

      expect(breakdown.costOre, 1000);
      expect(breakdown.costAutoturisme, 200);
      expect(breakdown.costScule, 40);
      expect(breakdown.costDiurna, 60);
      expect(breakdown.costCazare, 40);
      expect(breakdown.total, 1340);
    });
  });
}
