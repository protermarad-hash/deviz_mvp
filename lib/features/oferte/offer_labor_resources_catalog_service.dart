import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_models.dart';
import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/local_store.dart';
import '../../core/lookup_models.dart';
import '../employees/firebase_angajati_repository.dart';
import '../hr_core/hr_contract_resolver.dart';
import '../hr_core/hr_employee_catalog_service.dart';
import '../hr_core/hr_employee_models.dart';
import '../master/master_local_store.dart';
import '../teams/firebase_echipe_repository.dart';
import '../tool_packages/pachete_scule_catalog_service.dart';
import '../tool_packages/pachete_scule_models.dart';
import '../tools/scule_catalog_service.dart';
import '../tools/scule_models.dart';
import 'company_cost_profile_models.dart';
import 'company_cost_profile_service.dart';
import 'offer_real_labor_cost_resolver.dart';
import 'offer_real_tool_cost_resolver.dart';
import 'offer_real_vehicle_cost_resolver.dart';

class OfferLaborResourceOption {
  const OfferLaborResourceOption({
    required this.id,
    required this.name,
    required this.defaultHourlyRate,
    required this.defaultDailyRate,
    this.metaLabel = '',
  });

  final String id;
  final String name;
  final double defaultHourlyRate;
  final double defaultDailyRate;
  final String metaLabel;
}

class OfferLaborTeamOption {
  const OfferLaborTeamOption({
    required this.id,
    required this.name,
    required this.memberIds,
  });

  final String id;
  final String name;
  final List<String> memberIds;
}

class OfferLaborResourcesCatalog {
  const OfferLaborResourcesCatalog({
    required this.personnel,
    required this.teams,
    required this.vehicles,
    required this.toolPackages,
    required this.dataSourceLabel,
    this.fallbackReason,
  });

  final List<OfferLaborResourceOption> personnel;
  final List<OfferLaborTeamOption> teams;
  final List<OfferLaborResourceOption> vehicles;
  final List<OfferLaborResourceOption> toolPackages;
  final String dataSourceLabel;
  final String? fallbackReason;
}

class OfferLaborResourcesCatalogService {
  OfferLaborResourcesCatalogService({
    CompanyCostProfileService? companyCostProfileService,
    HrEmployeeCatalogService? hrEmployeeCatalogService,
    OfferRealLaborCostResolver? realLaborCostResolver,
    OfferRealToolCostResolver? realToolCostResolver,
    OfferRealVehicleCostResolver? realVehicleCostResolver,
    HrContractResolver? contractResolver,
  })  : _companyCostProfileService =
            companyCostProfileService ?? CompanyCostProfileService(),
        _hrEmployeeCatalogService =
            hrEmployeeCatalogService ?? HrEmployeeCatalogService(),
        _realLaborCostResolver =
            realLaborCostResolver ?? const OfferRealLaborCostResolver(),
        _realToolCostResolver =
            realToolCostResolver ?? const OfferRealToolCostResolver(),
        _realVehicleCostResolver =
            realVehicleCostResolver ?? const OfferRealVehicleCostResolver(),
        _contractResolver = contractResolver ?? const HrContractResolver();

  static const double _standardMonthlyHours = 168;
  static const double _toolPackageAmortizationMonths = 36;
  static const double _vehiclePurchaseAmortizationMonths = 60;
  static const double _vehicleWorkHoursPerDay = 8;

  final CompanyCostProfileService _companyCostProfileService;
  final HrEmployeeCatalogService _hrEmployeeCatalogService;
  final OfferRealLaborCostResolver _realLaborCostResolver;
  final OfferRealToolCostResolver _realToolCostResolver;
  final OfferRealVehicleCostResolver _realVehicleCostResolver;
  final HrContractResolver _contractResolver;

  Future<OfferLaborResourcesCatalog> load() async {
    var dataSourceLabel = 'local';
    String? fallbackReason;
    final companyCostProfile = await _companyCostProfileService.load();
    List<HrContract> contracts = const <HrContract>[];
    try {
      contracts = await _hrEmployeeCatalogService.listContracts();
    } catch (_) {
      contracts = const <HrContract>[];
    }

    final personnel = <OfferLaborResourceOption>[];
    final activeDate = DateTime.now();
    if (FirebaseBootstrap.isInitialized) {
      try {
        final cloudRows = await FirebaseAngajatiRepository().listEmployees();
        final cloudLookups = cloudRows
            .map((item) => _lookupFromMasterEmployee(item))
            .toList(growable: false);
        final productiveEmployeeCount = _resolveProductiveEmployeeCount(
          companyCostProfile: companyCostProfile,
          employees: cloudLookups,
        );
        personnel.addAll(
          cloudRows
              .where((row) => row.active && row.id.trim().isNotEmpty)
              .map(
                (row) => _personnelOption(
                  employee: _lookupFromMasterEmployee(row),
                  contracts: contracts,
                  companyCostProfile: companyCostProfile,
                  productiveEmployeeCount: productiveEmployeeCount,
                  activeDate: activeDate,
                ),
              ),
        );
        dataSourceLabel = 'cloud';
      } catch (error) {
        fallbackReason = _shortError(error);
      }
    }

    if (personnel.isEmpty) {
      final localRows = await MasterLocalStore.readEmployees();
      final productiveEmployeeCount = _resolveProductiveEmployeeCount(
        companyCostProfile: companyCostProfile,
        employees: localRows
            .map((item) => _lookupFromMasterEmployee(item))
            .toList(growable: false),
      );
      personnel.addAll(
        localRows
            .where((row) => row.active && row.id.trim().isNotEmpty)
            .map(
              (row) => _personnelOption(
                employee: _lookupFromMasterEmployee(row),
                contracts: contracts,
                companyCostProfile: companyCostProfile,
                productiveEmployeeCount: productiveEmployeeCount,
                activeDate: activeDate,
              ),
            ),
      );
      if (dataSourceLabel != 'cloud') {
        dataSourceLabel = 'local';
      }
    }

    final teams = <OfferLaborTeamOption>[];
    if (FirebaseBootstrap.isInitialized) {
      try {
        final cloudRows = await FirebaseEchipeRepository().listTeams();
        teams.addAll(
          cloudRows.where((row) => row.id.trim().isNotEmpty).map(
                (row) => OfferLaborTeamOption(
                  id: row.id,
                  name: row.name.trim().isEmpty ? 'Echipa' : row.name.trim(),
                  memberIds: row.memberIds
                      .map((item) => item.trim())
                      .where((item) => item.isNotEmpty)
                      .toList(growable: false),
                ),
              ),
        );
      } catch (error) {
        fallbackReason ??= _shortError(error);
      }
    }

    if (teams.isEmpty) {
      final localTeams = await MasterLocalStore.readTeams();
      teams.addAll(
        localTeams.where((row) => row.id.trim().isNotEmpty).map(
              (row) => OfferLaborTeamOption(
                id: row.id,
                name: row.name.trim().isEmpty ? 'Echipa' : row.name.trim(),
                memberIds: row.memberIds
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .toList(growable: false),
              ),
            ),
      );
    }

    final vehicles = await _loadVehicleOptions();
    final tools = await _loadToolPackageOptions();

    return OfferLaborResourcesCatalog(
      personnel: _dedupeAndSort(personnel),
      teams: _dedupeTeamsAndSort(teams),
      vehicles: _dedupeAndSort(vehicles),
      toolPackages: _dedupeAndSort(tools),
      dataSourceLabel: dataSourceLabel,
      fallbackReason: fallbackReason,
    );
  }

  OfferLaborResourceOption _personnelOption({
    required EmployeeLookup employee,
    required List<HrContract> contracts,
    required CompanyCostProfile companyCostProfile,
    required int productiveEmployeeCount,
    required DateTime activeDate,
  }) {
    final contract = _contractResolver.resolveActiveContract(
      contracts: contracts,
      employeeId: employee.id,
      date: activeDate,
    );
    final resolved = _realLaborCostResolver.resolve(
      employee: employee,
      activeContract: contract,
      companyCostProfile: companyCostProfile,
      resolvedProductiveEmployeeCount: productiveEmployeeCount,
    );
    final hourlyRate = resolved.hourlyInternalCost > 0
        ? resolved.hourlyInternalCost
        : employee.effectiveTarifOrar;
    return OfferLaborResourceOption(
      id: employee.id,
      name: employee.name.trim().isEmpty ? 'Angajat' : employee.name.trim(),
      defaultHourlyRate: hourlyRate,
      defaultDailyRate: hourlyRate * 8,
      metaLabel: resolved.sourceLabel,
    );
  }

  int _resolveProductiveEmployeeCount({
    required CompanyCostProfile companyCostProfile,
    required List<EmployeeLookup> employees,
  }) {
    if (companyCostProfile.productiveEmployeeCount > 0) {
      return companyCostProfile.productiveEmployeeCount;
    }
    final activeCount = employees.where((item) => item.active).length;
    return activeCount > 0 ? activeCount : 1;
  }

  EmployeeLookup _lookupFromMasterEmployee(MasterEmployee employee) {
    return EmployeeLookup(
      id: employee.id,
      name: employee.name,
      role: employee.role,
      perDiemPerDay: employee.dailyAllowance,
      lodgingPerDay: employee.defaultLodgingCost,
      laborCostType: employee.laborCostType,
      costLunar: employee.costLunar,
      tarifOrar: employee.tarifOrar,
      oreLunareStandard: employee.oreLunareStandard,
      requiresLodgingByDefault: employee.requiresLodgingByDefault,
      active: employee.active,
    );
  }

  Future<List<OfferLaborResourceOption>> _loadVehicleOptions() async {
    try {
      final repository = await AppRepository.create();
      final vehicles = await repository.listVehicles(activeOnly: true);
      if (vehicles.isNotEmpty) {
        return vehicles
            .where((item) => item.id.trim().isNotEmpty)
            .map(
              (item) => OfferLaborResourceOption(
                id: item.id,
                name: _vehicleLabel(item),
                defaultHourlyRate:
                    _realVehicleCostResolver.resolve(item).internalHourlyCost,
                defaultDailyRate:
                    _realVehicleCostResolver.resolve(item).internalKmCost,
                metaLabel: _realVehicleCostResolver.resolve(item).sourceLabel,
              ),
            )
            .toList(growable: false);
      }
    } catch (_) {
      // Fall through to legacy lookup storage.
    }

    final rows = await _loadLegacyListRows(
      priorityKeys: const <String>[
        'vehicles_v1',
        'deviz_vehicles_v1',
        'vehicles',
      ],
      keyHints: const <String>['vehicle', 'vehicles', 'auto', 'car'],
    );
    return rows
        .map(
          (row) => OfferLaborResourceOption(
            id: _pick(row, const <String>['id', 'vehicle_id', 'uid', 'key']),
            name: _pick(
              row,
              const <String>[
                'name',
                'vehicle_name',
                'plate_number',
                'numar',
                'nume',
              ],
            ),
            defaultHourlyRate: _asDouble(
              row['hourly_rate'] ??
                  row['cost_hourly'] ??
                  row['cost_orar'] ??
                  row['tarif_orar'],
            ),
            defaultDailyRate: _asDouble(
              row['cost_per_km_optional'] ??
                  row['cost_per_km'] ??
                  row['cost_km'] ??
                  row['effective_cost_per_km'],
            ),
            metaLabel: _vehicleAcquisitionTypeFromLegacy(row),
          ),
        )
        .map(
          (item) => OfferLaborResourceOption(
            id: item.id,
            name: item.name,
            defaultHourlyRate: item.defaultHourlyRate > 0
                ? item.defaultHourlyRate
                : _vehicleHourlyCostFromLegacy(rows.firstWhere(
                    (row) =>
                        _pick(
                          row,
                          const <String>['id', 'vehicle_id', 'uid', 'key'],
                        ) ==
                        item.id,
                    orElse: () => const <String, dynamic>{},
                  )),
            defaultDailyRate: item.defaultDailyRate > 0
                ? item.defaultDailyRate
                : _vehicleCostPerKmFromLegacy(rows.firstWhere(
                    (row) =>
                        _pick(
                          row,
                          const <String>['id', 'vehicle_id', 'uid', 'key'],
                        ) ==
                        item.id,
                    orElse: () => const <String, dynamic>{},
                  )),
            metaLabel: item.metaLabel.trim().isEmpty
                ? 'fallback autoturism'
                : item.metaLabel,
          ),
        )
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<List<OfferLaborResourceOption>> _loadToolPackageOptions() async {
    final packageService = PacheteSculeCatalogService();
    final toolService = SculeCatalogService();
    final packages = await packageService.listPackages();
    final tools = await toolService.listTools();
    if (packages.isNotEmpty) {
      final toolById = <String, ToolInventoryItem>{
        for (final item in tools)
          if (item.id.trim().isNotEmpty) item.id.trim(): item,
      };
      final toolByInventoryCode = <String, ToolInventoryItem>{
        for (final item in tools)
          if (item.inventoryCode.trim().isNotEmpty)
            item.inventoryCode.trim().toLowerCase(): item,
      };
      return packages
          .map(
            (row) => OfferLaborResourceOption(
              id: row.id,
              name: row.name,
              defaultHourlyRate: _toolPackageHourlyCost(
                row,
                toolById: toolById,
                toolByInventoryCode: toolByInventoryCode,
              ),
              defaultDailyRate: 0,
              metaLabel: 'cost real intern pachet scule',
            ),
          )
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false);
    }

    final rows = await _loadLegacyListRows(
      priorityKeys: const <String>[
        'pachete_scule_v1',
        'tool_packages_v1',
        'toolkits_v1',
      ],
      keyHints: const <String>['pachet', 'scule', 'tool', 'kit'],
    );
    return rows
        .map(
          (row) => OfferLaborResourceOption(
            id: _pick(row, const <String>['id', 'package_id', 'uid', 'key']),
            name: _pick(
              row,
              const <String>[
                'name',
                'package_name',
                'title',
                'nume',
              ],
            ),
            defaultHourlyRate: _asDouble(
              row['hourly_rate'] ??
                  row['cost_hourly'] ??
                  row['cost_orar'] ??
                  row['tarif_orar'],
            ),
            defaultDailyRate: 0,
            metaLabel: 'fallback pachet scule',
          ),
        )
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  double _toolPackageHourlyCost(
    ToolPackageRecord row, {
    required Map<String, ToolInventoryItem> toolById,
    required Map<String, ToolInventoryItem> toolByInventoryCode,
  }) {
    final refs = row.toolInventoryCodes
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final fallbackRefs = row.toolIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final targets = refs.isNotEmpty ? refs : fallbackRefs;

    var total = 0.0;
    for (final ref in targets) {
      final tool = toolByInventoryCode[ref.toLowerCase()] ?? toolById[ref];
      if (tool == null) continue;
      total += _toolHourlyCost(tool) * _standardMonthlyHours;
    }
    final amortizationHours =
        _standardMonthlyHours;
    if (total <= 0 || amortizationHours <= 0) return 0;
    return total / amortizationHours;
  }

  double _toolHourlyCost(ToolInventoryItem item) {
    final resolved = _realToolCostResolver.resolve(
      item,
      productiveHoursPerMonth: _standardMonthlyHours,
    );
    if (resolved.internalHourlyCost > 0) {
      return resolved.internalHourlyCost;
    }
    if (item.purchaseValue > 0) {
      return item.purchaseValue /
          (_toolPackageAmortizationMonths * _standardMonthlyHours);
    }
    return 0;
  }

  String _vehicleLabel(VehicleRecord item) {
    final plate = item.plateNumber.trim();
    final name = item.name.trim().isEmpty ? 'Autoturism' : item.name.trim();
    if (plate.isEmpty) return name;
    return '$name ($plate)';
  }

  double _vehicleHourlyCostFromLegacy(Map<String, dynamic> row) {
    final acquisitionType = _vehicleAcquisitionTypeFromLegacy(row);
    final purchasePrice = _asDouble(row['purchase_price']);
    if (acquisitionType == 'purchase' && purchasePrice > 0) {
      return purchasePrice /
          (_vehiclePurchaseAmortizationMonths * _standardMonthlyHours);
    }
    final leasing = _asDouble(
      row['monthly_leasing_cost'] ??
          row['leasing_cost_optional'] ??
          row['leasing_cost'] ??
          row['leasing_monthly_cost'],
    );
    if (acquisitionType == 'leasing' && leasing > 0) {
      return leasing / _standardMonthlyHours;
    }
    if (leasing > 0) {
      return leasing / _standardMonthlyHours;
    }
    final fixedDaily = _asDouble(
      row['fixed_daily_cost'] ??
          row['daily_rate'] ??
          row['cost_daily'] ??
          row['cost_zi'],
    );
    if (fixedDaily > 0) {
      return fixedDaily / _vehicleWorkHoursPerDay;
    }
    return 0;
  }

  String _vehicleAcquisitionTypeFromLegacy(Map<String, dynamic> row) {
    final raw = (row['acquisition_type'] ?? '').toString().trim().toLowerCase();
    if (raw == 'leasing') return 'leasing';
    if (raw == 'purchase') return 'purchase';
    final monthlyLeasingCost = _asDouble(
      row['monthly_leasing_cost'] ??
          row['leasing_cost_optional'] ??
          row['leasing_cost'] ??
          row['leasing_monthly_cost'],
    );
    return monthlyLeasingCost > 0 ? 'leasing' : 'purchase';
  }

  double _vehicleCostPerKmFromLegacy(Map<String, dynamic> row) {
    final explicit = _asDouble(
      row['cost_per_km_optional'] ??
          row['cost_per_km'] ??
          row['cost_km'] ??
          row['effective_cost_per_km'],
    );
    if (explicit > 0) return explicit;
    final consumption =
        _asDouble(row['fuel_consumption_l_per_100km'] ?? row['consumption']);
    final fuelPrice =
        _asDouble(row['fuel_price_per_liter'] ?? row['fuel_price']);
    if (consumption <= 0 || fuelPrice <= 0) return 0;
    return (consumption / 100.0) * fuelPrice;
  }

  Future<List<Map<String, dynamic>>> _loadLegacyListRows({
    required List<String> priorityKeys,
    required List<String> keyHints,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in priorityKeys) {
      final rows = _decodeListRows(prefs.getString(key));
      if (rows.isNotEmpty) return rows;
    }
    final keys = prefs.getKeys().toList()..sort((a, b) => a.compareTo(b));
    for (final key in keys) {
      final lower = key.toLowerCase();
      if (!keyHints.any((hint) => lower.contains(hint))) continue;
      final rows = _decodeListRows(prefs.getString(key));
      if (rows.isNotEmpty) return rows;
    }
    return const <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _decodeListRows(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        return decoded
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
      }
    } catch (e) {
      debugPrint('[OfferLaborCatalog] parsare cache eșuată: $e');
    }
    return const <Map<String, dynamic>>[];
  }

  double _asDouble(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString().replaceAll(',', '.').trim()) ?? 0;
  }

  String _pick(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = (row[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  List<OfferLaborResourceOption> _dedupeAndSort(
    List<OfferLaborResourceOption> rows,
  ) {
    final map = <String, OfferLaborResourceOption>{};
    for (final row in rows) {
      map[row.id] = row;
    }
    final values = map.values.toList(growable: false);
    values.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return values;
  }

  List<OfferLaborTeamOption> _dedupeTeamsAndSort(
    List<OfferLaborTeamOption> rows,
  ) {
    final map = <String, OfferLaborTeamOption>{};
    for (final row in rows) {
      map[row.id] = row;
    }
    final values = map.values.toList(growable: false);
    values.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return values;
  }

  String _shortError(Object error) {
    final text = error.toString().replaceAll('\n', ' ').trim();
    if (text.isEmpty) return 'necunoscuta';
    return text.length > 140 ? '${text.substring(0, 140)}...' : text;
  }
}
