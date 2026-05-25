import '../tools/scule_models.dart';

class ResolvedToolRealCost {
  const ResolvedToolRealCost({
    required this.internalHourlyCost,
    required this.sourceLabel,
    required this.isRealCostBased,
  });

  final double internalHourlyCost;
  final String sourceLabel;
  final bool isRealCostBased;
}

class OfferRealToolCostResolver {
  const OfferRealToolCostResolver();

  static const int _defaultUsefulLifeMonths = 36;
  static const double _defaultProductiveHoursPerMonth = 168;

  ResolvedToolRealCost resolve(
    ToolInventoryItem tool, {
    double productiveHoursPerMonth = _defaultProductiveHoursPerMonth,
  }) {
    final purchaseValue = tool.purchaseValue > 0 ? tool.purchaseValue : 0.0;
    final usefulLifeMonths = tool.usefulLifeMonths > 0
        ? tool.usefulLifeMonths
        : _defaultUsefulLifeMonths;
    final productiveHours = productiveHoursPerMonth > 0
        ? productiveHoursPerMonth
        : _defaultProductiveHoursPerMonth;
    final amortizationHours = usefulLifeMonths * productiveHours;
    if (purchaseValue > 0 && amortizationHours > 0) {
      return ResolvedToolRealCost(
        internalHourlyCost: purchaseValue / amortizationHours,
        sourceLabel: 'cost real intern scula',
        isRealCostBased: true,
      );
    }
    return const ResolvedToolRealCost(
      internalHourlyCost: 0,
      sourceLabel: 'fallback scula',
      isRealCostBased: false,
    );
  }
}
