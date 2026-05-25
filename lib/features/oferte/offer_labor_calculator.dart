class OfferLaborResourceUsage {
  const OfferLaborResourceUsage({
    required this.resourceId,
    required this.name,
    required this.hours,
    required this.days,
    required this.hourlyRate,
    required this.dailyRate,
  });

  final String resourceId;
  final String name;
  final double hours;
  final double days;
  final double hourlyRate;
  final double dailyRate;

  double get total => (hours * hourlyRate) + (days * dailyRate);

  OfferLaborResourceUsage copyWith({
    String? resourceId,
    String? name,
    double? hours,
    double? days,
    double? hourlyRate,
    double? dailyRate,
  }) {
    return OfferLaborResourceUsage(
      resourceId: resourceId ?? this.resourceId,
      name: name ?? this.name,
      hours: hours ?? this.hours,
      days: days ?? this.days,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      dailyRate: dailyRate ?? this.dailyRate,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'resource_id': resourceId,
      'name': name,
      'hours': hours,
      'days': days,
      'hourly_rate': hourlyRate,
      'daily_rate': dailyRate,
    };
  }

  factory OfferLaborResourceUsage.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic raw) {
      if (raw == null) return 0;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString().replaceAll(',', '.').trim()) ?? 0;
    }

    return OfferLaborResourceUsage(
      resourceId: (map['resource_id'] ?? map['resourceId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      hours: asDouble(map['hours']),
      days: asDouble(map['days']),
      hourlyRate: asDouble(map['hourly_rate'] ?? map['hourlyRate']),
      dailyRate: asDouble(map['daily_rate'] ?? map['dailyRate']),
    );
  }
}

class OfferLaborBreakdown {
  const OfferLaborBreakdown({
    required this.costOre,
    this.costAutoturisme = 0,
    this.costScule = 0,
    required this.costDiurna,
    required this.costCazare,
    required this.total,
  });

  final double costOre;
  final double costAutoturisme;
  final double costScule;
  final double costDiurna;
  final double costCazare;
  final double total;

  double get costPersonal => costOre;
}

class OfferLaborCalculator {
  const OfferLaborCalculator._();

  /// Rounds a price UP to the nearest 10
  /// Examples: 1919.45 -> 1920, 2510.08 -> 2520, 1000 -> 1000
  static double roundPriceUpToTen(double price) {
    if (price <= 0) return price;
    return ((price / 10).ceil() * 10).toDouble();
  }

  static double _sumResourceTotals(List<OfferLaborResourceUsage> rows) {
    return rows.fold<double>(0, (sum, item) => sum + item.total);
  }

  static double _sumResourceTotalsHoursOnly(
      List<OfferLaborResourceUsage> rows) {
    return rows.fold<double>(
        0, (sum, item) => sum + (item.hours * item.hourlyRate));
  }

  static double _sumToolPackageTotalsHoursOnly(
    List<OfferLaborResourceUsage> rows,
  ) {
    return rows.fold<double>(
      0,
      (sum, item) => sum + (item.hours * item.hourlyRate),
    );
  }

  static OfferLaborBreakdown computeFromResources({
    required List<OfferLaborResourceUsage> personal,
    required List<OfferLaborResourceUsage> autoturisme,
    required List<OfferLaborResourceUsage> pacheteScule,
    required double perDiemDays,
    required double perDiemPerDay,
    required double lodgingNights,
    required double lodgingPerNight,
  }) {
    final costPersonal = _sumResourceTotalsHoursOnly(personal);
    final costAutoturisme = _sumResourceTotals(autoturisme);
    final costScule = _sumToolPackageTotalsHoursOnly(pacheteScule);
    final costDiurna = perDiemDays * perDiemPerDay;
    final costCazare = lodgingNights * lodgingPerNight;
    var total =
        costPersonal + costAutoturisme + costScule + costDiurna + costCazare;

    // Round final total UP to nearest 10
    total = roundPriceUpToTen(total);

    return OfferLaborBreakdown(
      costOre: costPersonal,
      costAutoturisme: costAutoturisme,
      costScule: costScule,
      costDiurna: costDiurna,
      costCazare: costCazare,
      total: total,
    );
  }

  static OfferLaborBreakdown compute({
    required double hours,
    required double hourlyRate,
    required double perDiemDays,
    required double perDiemPerDay,
    required double lodgingNights,
    required double lodgingPerNight,
  }) {
    return computeFromResources(
      personal: <OfferLaborResourceUsage>[
        OfferLaborResourceUsage(
          resourceId: '',
          name: '',
          hours: hours,
          days: 0,
          hourlyRate: hourlyRate,
          dailyRate: 0,
        ),
      ],
      autoturisme: const <OfferLaborResourceUsage>[],
      pacheteScule: const <OfferLaborResourceUsage>[],
      perDiemDays: perDiemDays,
      perDiemPerDay: perDiemPerDay,
      lodgingNights: lodgingNights,
      lodgingPerNight: lodgingPerNight,
    );
  }
}
