import 'package:flutter/material.dart';

import '../oferte/offer_models.dart';
import '../deviz_tehnic/deviz_tehnic_models.dart';

/// Opțiune internă pentru selectoare (echipă / angajat) din fișa lucrării.
/// Conține și datele de cost (tarif orar, diurnă, cazare) folosite la manoperă.
class LucrareOption {
  const LucrareOption({
    required this.id,
    required this.label,
    this.hourlyRate = 0,
    this.dailyAllowance = 0,
    this.defaultLodgingCost = 0,
    this.requiresLodgingByDefault = false,
    this.active = true,
  });
  final String id;
  final String label;
  final double hourlyRate;
  final double dailyAllowance;
  final double defaultLodgingCost;
  final bool requiresLodgingByDefault;
  final bool active;
  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'hourlyRate': hourlyRate,
        'dailyAllowance': dailyAllowance,
        'defaultLodgingCost': defaultLodgingCost,
        'requiresLodgingByDefault': requiresLodgingByDefault,
        'active': active,
      };
  factory LucrareOption.fromMap(Map<String, dynamic> map) => LucrareOption(
        id: (map['id'] ?? '').toString().trim(),
        label: (map['label'] ?? '').toString().trim(),
        hourlyRate: double.tryParse(
                (map['hourlyRate'] ?? '0').toString().replaceAll(',', '.')) ??
            0,
        dailyAllowance: double.tryParse((map['dailyAllowance'] ?? '0')
                .toString()
                .replaceAll(',', '.')) ??
            0,
        defaultLodgingCost: double.tryParse(
              (map['defaultLodgingCost'] ?? '0')
                  .toString()
                  .replaceAll(',', '.'),
            ) ??
            0,
        requiresLodgingByDefault: map['requiresLodgingByDefault'] == true,
        active: map['active'] != false,
      );
  factory LucrareOption.fromAny(dynamic raw) {
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      final id = (m['id'] ?? '').toString().trim();
      final label = ((m['label'] ??
                  m['displayName'] ??
                  m['title'] ??
                  m['name'] ??
                  m['companyName'] ??
                  m['contactPerson']) ??
              '')
          .toString()
          .trim();
      final hourlyRate = double.tryParse(
            (m['hourlyRate'] ??
                    m['hourly_rate'] ??
                    m['rate'] ??
                    m['ratePerHour'] ??
                    '0')
                .toString()
                .replaceAll(',', '.'),
          ) ??
          0.0;
      final monthlyCost = double.tryParse(
            (m['costLunar'] ??
                    m['cost_lunar'] ??
                    m['monthlyCost'] ??
                    m['monthly_cost'] ??
                    m['monthly_salary_optional'] ??
                    '0')
                .toString()
                .replaceAll(',', '.'),
          ) ??
          0.0;
      final monthlyHours = double.tryParse(
            (m['oreLunareStandard'] ??
                    m['ore_lunare_standard'] ??
                    m['standardMonthlyHours'] ??
                    m['monthly_hours_standard'] ??
                    '168')
                .toString()
                .replaceAll(',', '.'),
          ) ??
          168.0;
      final laborCostType = (m['laborCostType'] ??
              m['labor_cost_type'] ??
              m['tipCostManopera'] ??
              m['tip_cost_manopera'] ??
              '')
          .toString()
          .trim()
          .toLowerCase();
      final bool isLunarCostType = laborCostType == 'lunar';
      final double effectiveHourlyRate = isLunarCostType
          ? (monthlyCost > 0 && monthlyHours > 0
              ? monthlyCost / monthlyHours
              : 0.0)
          : (hourlyRate > 0 ? hourlyRate : 0.0);
      final dailyAllowance = double.tryParse(
            (m['dailyAllowance'] ??
                    m['daily_allowance'] ??
                    m['perDiemPerDay'] ??
                    m['per_diem_per_day'] ??
                    m['per_diem'] ??
                    m['diurna'] ??
                    '0')
                .toString()
                .replaceAll(',', '.'),
          ) ??
          0;
      final defaultLodgingCost = double.tryParse(
            (m['defaultLodgingCost'] ??
                    m['default_lodging_cost'] ??
                    m['lodgingPerDay'] ??
                    m['lodging_per_day'] ??
                    m['lodging'] ??
                    m['cazare'] ??
                    '0')
                .toString()
                .replaceAll(',', '.'),
          ) ??
          0;
      final requiresLodgingByDefaultRaw =
          m['requiresLodgingByDefault'] ?? m['requires_lodging_by_default'];
      final requiresLodgingByDefault = requiresLodgingByDefaultRaw is bool
          ? requiresLodgingByDefaultRaw
          : '${requiresLodgingByDefaultRaw ?? ''}'.toLowerCase().trim() ==
              'true';
      final activeRaw = m['active'];
      final active = activeRaw is bool
          ? activeRaw
          : !('${activeRaw ?? 'true'}'.toLowerCase().trim() == 'false');
      return LucrareOption(
        id: id,
        label: label.isEmpty ? id : label,
        hourlyRate: effectiveHourlyRate,
        dailyAllowance: dailyAllowance,
        defaultLodgingCost: defaultLodgingCost,
        requiresLodgingByDefault: requiresLodgingByDefault,
        active: active,
      );
    }
    String read(dynamic Function() getter) {
      try {
        return getter()?.toString().trim() ?? '';
      } catch (_) {
        return '';
      }
    }

    final id = read(() => (raw as dynamic).id);
    final label = read(() => (raw as dynamic).label).isNotEmpty
        ? read(() => (raw as dynamic).label)
        : (read(() => (raw as dynamic).displayName).isNotEmpty
            ? read(() => (raw as dynamic).displayName)
            : read(() => (raw as dynamic).name));
    final hourlyRateRaw = read(() => (raw as dynamic).hourlyRate).isNotEmpty
        ? read(() => (raw as dynamic).hourlyRate)
        : (read(() => (raw as dynamic).hourly_rate).isNotEmpty
            ? read(() => (raw as dynamic).hourly_rate)
            : read(() => (raw as dynamic).rate));
    final hourlyRate =
        double.tryParse(hourlyRateRaw.replaceAll(',', '.')) ?? 0.0;
    final monthlyCostRaw = read(() => (raw as dynamic).costLunar).isNotEmpty
        ? read(() => (raw as dynamic).costLunar)
        : (read(() => (raw as dynamic).monthlyCost).isNotEmpty
            ? read(() => (raw as dynamic).monthlyCost)
            : read(() => (raw as dynamic).monthly_cost));
    final monthlyCost =
        double.tryParse(monthlyCostRaw.replaceAll(',', '.')) ?? 0.0;
    final monthlyHoursRaw =
        read(() => (raw as dynamic).oreLunareStandard).isNotEmpty
            ? read(() => (raw as dynamic).oreLunareStandard)
            : (read(() => (raw as dynamic).standardMonthlyHours).isNotEmpty
                ? read(() => (raw as dynamic).standardMonthlyHours)
                : read(() => (raw as dynamic).monthly_hours_standard));
    final monthlyHours =
        double.tryParse(monthlyHoursRaw.replaceAll(',', '.')) ?? 168.0;
    final laborCostTypeRaw =
        read(() => (raw as dynamic).laborCostType).isNotEmpty
            ? read(() => (raw as dynamic).laborCostType)
            : read(() => (raw as dynamic).tipCostManopera);
    final isLunarCostType = laborCostTypeRaw.trim().toLowerCase() == 'lunar';
    final double effectiveHourlyRate = isLunarCostType
        ? (monthlyCost > 0 && monthlyHours > 0
            ? monthlyCost / monthlyHours
            : 0.0)
        : (hourlyRate > 0 ? hourlyRate : 0.0);
    final dailyAllowanceRaw =
        read(() => (raw as dynamic).dailyAllowance).isNotEmpty
            ? read(() => (raw as dynamic).dailyAllowance)
            : (read(() => (raw as dynamic).perDiemPerDay).isNotEmpty
                ? read(() => (raw as dynamic).perDiemPerDay)
                : read(() => (raw as dynamic).per_diem_per_day));
    final dailyAllowance =
        double.tryParse(dailyAllowanceRaw.replaceAll(',', '.')) ?? 0;
    final defaultLodgingCostRaw =
        read(() => (raw as dynamic).defaultLodgingCost).isNotEmpty
            ? read(() => (raw as dynamic).defaultLodgingCost)
            : (read(() => (raw as dynamic).lodgingPerDay).isNotEmpty
                ? read(() => (raw as dynamic).lodgingPerDay)
                : read(() => (raw as dynamic).lodging_per_day));
    final defaultLodgingCost =
        double.tryParse(defaultLodgingCostRaw.replaceAll(',', '.')) ?? 0;
    bool requiresLodgingByDefault = false;
    try {
      final dynamic value = (raw as dynamic).requiresLodgingByDefault;
      if (value is bool) {
        requiresLodgingByDefault = value;
      } else {
        requiresLodgingByDefault =
            value?.toString().toLowerCase().trim() == 'true';
      }
    } catch (_) {/* intenționat ignorat: probare duck-typing pe dynamic, folosesc default */}
    bool active = true;
    try {
      final dynamic value = (raw as dynamic).active;
      if (value is bool) {
        active = value;
      } else {
        active = value?.toString().toLowerCase().trim() != 'false';
      }
    } catch (_) {/* intenționat ignorat: probare duck-typing pe dynamic, folosesc default */}
    return LucrareOption(
      id: id,
      label: label.isEmpty ? id : label,
      hourlyRate: effectiveHourlyRate,
      dailyAllowance: dailyAllowance,
      defaultLodgingCost: defaultLodgingCost,
      requiresLodgingByDefault: requiresLodgingByDefault,
      active: active,
    );
  }
}

/// Opțiune internă pentru selectorul de material din fișa lucrării.
class LucrareMaterialOption {
  const LucrareMaterialOption(
      {required this.id,
      required this.name,
      required this.um,
      required this.price});
  final String id;
  final String name;
  final String um;
  final double price;
  factory LucrareMaterialOption.fromAny(dynamic raw) {
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      return LucrareMaterialOption(
          id: (m['id'] ?? '').toString().trim(),
          name: (m['name'] ?? m['label'] ?? m['title'] ?? '').toString().trim(),
          um: (m['um'] ?? m['unit'] ?? '').toString().trim(),
          price: double.tryParse((m['price'] ?? m['unitPrice'] ?? '0')
                  .toString()
                  .replaceAll(',', '.')) ??
              0);
    }
    String read(dynamic Function() getter) {
      try {
        return getter()?.toString().trim() ?? '';
      } catch (_) {
        return '';
      }
    }

    return LucrareMaterialOption(
        id: read(() => (raw as dynamic).id),
        name: read(() => (raw as dynamic).name),
        um: read(() => (raw as dynamic).um),
        price: double.tryParse(
                read(() => (raw as dynamic).price).replaceAll(',', '.')) ??
            0);
  }
}

/// Wrapper tip uniune pentru picker combinat oferte + devize tehnice.
class LucrareSourceDocument {
  LucrareSourceDocument.fromOffer(OfferRecord o)
      : offer = o,
        deviz = null;
  LucrareSourceDocument.fromDeviz(DevizTehnicRecord d)
      : deviz = d,
        offer = null;
  final OfferRecord? offer;
  final DevizTehnicRecord? deviz;

  String get numar => offer?.offerNumber ?? deviz?.numar ?? '';
  String get titlu => offer?.title ?? deviz?.titlu ?? '';
  String get client => offer?.clientName ?? deviz?.clientName ?? '';
  String get tipLabel => offer != null ? 'Ofertă' : 'Deviz tehnic';
  Color get tipColor => offer != null ? Colors.blue : Colors.purple;
  int get nrArticole => offer != null
      ? offer!.lines.where((l) => l.lineType.name != 'text').length
      : (deviz?.articole.length ?? 0);
}
