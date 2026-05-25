import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'app_models.dart';

class LocalStore {
  LocalStore._(this._prefs);

  static const _storageKey = 'devizpro.localdb.v2';

  final SharedPreferences _prefs;
  final Uuid _uuid = const Uuid();
  late Map<String, List<Map<String, dynamic>>> _tables;

  static Future<LocalStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore._(prefs);
    await store._load();
    return store;
  }

  Future<void> _load() async {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      _tables = {
        'clients': <Map<String, dynamic>>[],
        'materials': <Map<String, dynamic>>[],
        'offers': <Map<String, dynamic>>[],
        'offer_lines': <Map<String, dynamic>>[],
        'company_settings': <Map<String, dynamic>>[],
        'overhead_settings': <Map<String, dynamic>>[],
        'employees': <Map<String, dynamic>>[],
        'vehicles': <Map<String, dynamic>>[],
        'offer_employees': <Map<String, dynamic>>[],
        'offer_vehicles': <Map<String, dynamic>>[],
      };
      await _persist();
      return;
    }

    final decoded = jsonDecode(raw);
    final next = <String, List<Map<String, dynamic>>>{};
    if (decoded is Map<String, dynamic>) {
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is List) {
          next[entry.key] = value
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
        }
      }
    }
    _tables = {
      'clients': next['clients'] ?? <Map<String, dynamic>>[],
      'materials': next['materials'] ?? <Map<String, dynamic>>[],
      'offers': next['offers'] ?? <Map<String, dynamic>>[],
      'offer_lines': next['offer_lines'] ?? <Map<String, dynamic>>[],
      'company_settings': next['company_settings'] ?? <Map<String, dynamic>>[],
      'overhead_settings':
          next['overhead_settings'] ?? <Map<String, dynamic>>[],
      'employees': next['employees'] ?? <Map<String, dynamic>>[],
      'vehicles': next['vehicles'] ?? <Map<String, dynamic>>[],
      'offer_employees': next['offer_employees'] ?? <Map<String, dynamic>>[],
      'offer_vehicles': next['offer_vehicles'] ?? <Map<String, dynamic>>[],
    };
  }

  Future<void> _persist() async {
    await _prefs.setString(_storageKey, jsonEncode(_tables));
  }

  Future<List<Map<String, dynamic>>> selectRows(
    String table, {
    String? columns,
    String? eqField,
    dynamic eqValue,
    String? orderField,
    bool ascending = true,
  }) async {
    final rows = _table(table).map(_clone).toList();
    final filtered = eqField == null
        ? rows
        : rows.where((row) => row[eqField] == eqValue).toList();

    if (orderField != null) {
      filtered.sort((a, b) {
        final comparison = _compare(a[orderField], b[orderField]);
        return ascending ? comparison : -comparison;
      });
    }

    return filtered.map((row) => _project(row, columns)).toList();
  }

  Future<List<Map<String, dynamic>>> insertRows(
    String table,
    List<Map<String, dynamic>> rows, {
    String? columns,
  }) async {
    final inserted = <Map<String, dynamic>>[];
    for (final row in rows) {
      final next = _clone(row);
      next.putIfAbsent('id', () => _uuid.v4());
      next.putIfAbsent('created_at', () => DateTime.now().toIso8601String());
      _table(table).add(next);
      inserted.add(_project(next, columns));
    }
    await _persist();
    return inserted;
  }

  Future<void> updateRows(
    String table, {
    required String matchField,
    required dynamic matchValue,
    required Map<String, dynamic> values,
  }) async {
    final rows = _table(table);
    for (var i = 0; i < rows.length; i++) {
      if (rows[i][matchField] == matchValue) {
        final updated = _clone(rows[i]);
        updated.addAll(values);
        rows[i] = updated;
      }
    }
    await _persist();
  }

  Future<void> deleteRows(
    String table, {
    required String matchField,
    required dynamic matchValue,
  }) async {
    _table(table).removeWhere((row) => row[matchField] == matchValue);
    await _persist();
  }

  Future<void> replaceSingleRow(
      String table, Map<String, dynamic> values) async {
    _tables[table] = <Map<String, dynamic>>[
      {
        'id': values['id'] ?? _uuid.v4(),
        'created_at': values['created_at'] ?? DateTime.now().toIso8601String(),
        ...values,
      }
    ];
    await _persist();
  }

  Future<void> replaceTable(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    _tables[table] = rows.map(_clone).toList();
    await _persist();
  }

  Future<Map<String, dynamic>?> singleRow(String table) async {
    final rows = _table(table);
    if (rows.isEmpty) {
      return null;
    }
    return _clone(rows.first);
  }

  List<Map<String, dynamic>> _table(String table) =>
      _tables.putIfAbsent(table, () => <Map<String, dynamic>>[]);

  Map<String, dynamic> _clone(Map<String, dynamic> row) =>
      Map<String, dynamic>.from(row);

  Map<String, dynamic> _project(Map<String, dynamic> row, String? columns) {
    if (columns == null || columns.trim().isEmpty) {
      return _clone(row);
    }
    final keys = columns
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return {
      for (final key in keys)
        if (row.containsKey(key)) key: row[key],
    };
  }

  int _compare(dynamic left, dynamic right) {
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return -1;
    }
    if (right == null) {
      return 1;
    }
    if (left is Comparable && right is Comparable) {
      return Comparable.compare(left, right);
    }
    return left.toString().compareTo(right.toString());
  }
}

class AppRepository {
  AppRepository._(this._store);

  final LocalStore _store;
  final Uuid _uuid = const Uuid();

  static Future<AppRepository> create() async {
    final repository = AppRepository._(await LocalStore.create());
    await repository._ensureDefaults();
    return repository;
  }

  Future<void> _ensureDefaults() async {
    final company = await _store.singleRow('company_settings');
    if (company == null) {
      await saveCompanySettings(
        const CompanySettings(companyName: AppDefaults.companyName),
      );
    }
    final overhead = await _store.singleRow('overhead_settings');
    if (overhead == null) {
      await saveOverheadSettings(const OverheadSettings());
    }
  }

  Future<List<Map<String, dynamic>>> listClients() async {
    debugPrint(
      '[ClientsRepo] query: table=clients eq user_id=$localUserId order=name',
    );
    final allRows = await _store.selectRows('clients');
    var mutated = false;
    final normalizedRows = allRows.map((row) {
      final next = Map<String, dynamic>.from(row);
      final rawId = next['id']?.toString().trim() ?? '';
      if (rawId.isEmpty) {
        next['id'] = _uuid.v4();
        mutated = true;
      }
      final rawUserId = next['user_id']?.toString().trim() ?? '';
      if (rawUserId.isEmpty) {
        next['user_id'] = localUserId;
        mutated = true;
      }
      final normalizedName = valueText(next['name']).trim();
      if (normalizedName.isEmpty) {
        next['name'] = 'Client fara nume';
        mutated = true;
      } else {
        next['name'] = normalizedName;
      }
      next['contact_person'] = valueText(next['contact_person']).trim();
      next['phone'] = valueText(next['phone']).trim();
      next['email'] = valueText(next['email']).trim();
      return next;
    }).toList();
    if (mutated) {
      debugPrint(
        '[ClientsRepo] normalized legacy client rows with missing id/user_id/name',
      );
      await _store.replaceTable('clients', normalizedRows);
    }
    final filtered = normalizedRows
        .where((row) => valueText(row['user_id']) == localUserId)
        .toList()
      ..sort((a, b) => valueText(a['name']).compareTo(valueText(b['name'])));
    for (final item in filtered) {
      debugPrint(
        '[ClientsRepo] item: id=${item['id']}, name=${item['name']}, phone=${item['phone']}, contact=${item['contact_person']}',
      );
    }
    return filtered;
  }

  Future<List<Map<String, dynamic>>> listMaterials() async {
    debugPrint(
      '[MaterialsRepo] query: table=materials eq user_id=$localUserId order=name',
    );
    final allRows = await _store.selectRows('materials');
    var mutated = false;
    final normalizedRows = allRows.map((row) {
      final next = Map<String, dynamic>.from(row);
      final rawId = next['id']?.toString().trim() ?? '';
      if (rawId.isEmpty) {
        next['id'] = _uuid.v4();
        mutated = true;
      }
      final rawUserId = next['user_id']?.toString().trim() ?? '';
      if (rawUserId.isEmpty) {
        next['user_id'] = localUserId;
        mutated = true;
      }
      next['name'] = valueText(next['name']).trim();
      next['unit'] = valueText(next['unit']).trim();
      next['sell_price'] = parseDouble(next['sell_price']);
      return next;
    }).toList();
    if (mutated) {
      debugPrint(
        '[MaterialsRepo] normalized legacy material rows with missing id/user_id',
      );
      await _store.replaceTable('materials', normalizedRows);
    }
    final filtered = normalizedRows
        .where((row) => valueText(row['user_id']) == localUserId)
        .toList()
      ..sort((a, b) => valueText(a['name']).compareTo(valueText(b['name'])));
    for (final item in filtered) {
      debugPrint(
        '[MaterialsRepo] item: id=${item['id']}, name=${item['name']}, unit=${item['unit']}, price=${item['sell_price']}',
      );
    }
    return filtered;
  }

  Future<List<Map<String, dynamic>>> listOffers() {
    return _store.selectRows(
      'offers',
      eqField: 'user_id',
      eqValue: localUserId,
      orderField: 'created_at',
      ascending: false,
    );
  }

  Future<List<EmployeeRecord>> listEmployees({bool activeOnly = false}) async {
    final rows = await _store.selectRows(
      'employees',
      eqField: 'user_id',
      eqValue: localUserId,
      orderField: 'name',
    );
    final items = rows.map(EmployeeRecord.fromMap).toList();
    if (!activeOnly) {
      return items;
    }
    return items.where((item) => item.active).toList();
  }

  Future<List<VehicleRecord>> listVehicles({bool activeOnly = false}) async {
    final rows = await _store.selectRows(
      'vehicles',
      eqField: 'user_id',
      eqValue: localUserId,
      orderField: 'name',
    );
    final items = rows.map(VehicleRecord.fromMap).toList();
    if (!activeOnly) {
      return items;
    }
    return items.where((item) => item.active).toList();
  }

  Future<void> saveClient(Map<String, dynamic> values) async {
    final payload = {'user_id': localUserId, ...values};
    if (valueText(values['id']).isEmpty) {
      await _store.insertRows('clients', [payload]);
      return;
    }
    await _store.updateRows(
      'clients',
      matchField: 'id',
      matchValue: values['id'],
      values: payload,
    );
  }

  Future<void> deleteClient(String id) {
    return _store.deleteRows(
      'clients',
      matchField: 'id',
      matchValue: id,
    );
  }

  Future<void> saveMaterial(Map<String, dynamic> values) async {
    final payload = {'user_id': localUserId, ...values};
    if (valueText(values['id']).isEmpty) {
      await _store.insertRows('materials', [payload]);
      return;
    }
    await _store.updateRows(
      'materials',
      matchField: 'id',
      matchValue: values['id'],
      values: payload,
    );
  }

  Future<void> deleteMaterial(String id) {
    return _store.deleteRows(
      'materials',
      matchField: 'id',
      matchValue: id,
    );
  }

  Future<void> saveEmployee(EmployeeRecord employee) async {
    final payload = {'user_id': localUserId, ...employee.toMap()};
    final existing = await _store.selectRows(
      'employees',
      eqField: 'id',
      eqValue: employee.id,
    );
    if (existing.isEmpty) {
      await _store.insertRows('employees', [payload]);
      return;
    }
    await _store.updateRows(
      'employees',
      matchField: 'id',
      matchValue: employee.id,
      values: payload,
    );
  }

  Future<void> deleteEmployee(String id) {
    return _store.deleteRows(
      'employees',
      matchField: 'id',
      matchValue: id,
    );
  }

  Future<void> saveVehicle(VehicleRecord vehicle) async {
    final payload = {'user_id': localUserId, ...vehicle.toMap()};
    final existing = await _store.selectRows(
      'vehicles',
      eqField: 'id',
      eqValue: vehicle.id,
    );
    if (existing.isEmpty) {
      await _store.insertRows('vehicles', [payload]);
      return;
    }
    await _store.updateRows(
      'vehicles',
      matchField: 'id',
      matchValue: vehicle.id,
      values: payload,
    );
  }

  Future<void> deleteVehicle(String id) {
    return _store.deleteRows(
      'vehicles',
      matchField: 'id',
      matchValue: id,
    );
  }

  Future<CompanySettings> getCompanySettings() async {
    final row = await _store.singleRow('company_settings');
    if (row == null) {
      return const CompanySettings(companyName: AppDefaults.companyName);
    }
    return CompanySettings.fromMap(row);
  }

  Future<void> saveCompanySettings(CompanySettings settings) async {
    await _store.replaceSingleRow('company_settings', settings.toMap());
  }

  Future<OverheadSettings> getOverheadSettings() async {
    final row = await _store.singleRow('overhead_settings');
    if (row == null) {
      return const OverheadSettings();
    }
    return OverheadSettings.fromMap(row);
  }

  Future<void> saveOverheadSettings(OverheadSettings settings) async {
    await _store.replaceSingleRow('overhead_settings', settings.toMap());
  }

  Future<Map<String, dynamic>> loadDashboardData() async {
    final offers = await listOffers();
    final clients = await listClients();
    final materials = await listMaterials();
    debugPrint(
      '[Dashboard] loaded/count: ${materials.length} using query table=materials eq user_id=$localUserId order=name',
    );
    final employees = await listEmployees(activeOnly: true);
    final vehicles = await listVehicles(activeOnly: true);
    final company = await getCompanySettings();
    return {
      'offers': offers.length,
      'clients': clients.length,
      'materials': materials.length,
      'employees': employees.length,
      'vehicles': vehicles.length,
      'company_name': company.companyNameOrFallback,
      'vat': company.defaultVatPercent,
    };
  }

  Future<OfferBundle?> loadOfferBundle(String offerId) async {
    final offers =
        await _store.selectRows('offers', eqField: 'id', eqValue: offerId);
    if (offers.isEmpty) {
      return null;
    }
    final lines = await _store.selectRows(
      'offer_lines',
      eqField: 'offer_id',
      eqValue: offerId,
      orderField: 'created_at',
    );
    final employeeRows = await _store.selectRows(
      'offer_employees',
      eqField: 'offer_id',
      eqValue: offerId,
      orderField: 'created_at',
    );
    final vehicleRows = await _store.selectRows(
      'offer_vehicles',
      eqField: 'offer_id',
      eqValue: offerId,
      orderField: 'created_at',
    );
    final offer = Map<String, dynamic>.from(offers.first);
    final clientId = offer['client_id'];
    if (clientId != null && valueText(clientId).trim().isNotEmpty) {
      final clients = await listClients();
      final clientMatch = clients.where((item) => item['id'] == clientId);
      if (clientMatch.isNotEmpty) {
        final client = clientMatch.first;
        offer['client_name'] = valueText(client['name']);
        offer['client_contact_person'] = valueText(client['contact_person']);
        offer['client_phone'] = valueText(client['phone']);
        offer['client_email'] = valueText(client['email']);
      }
    }
    return OfferBundle(
      offer: offer,
      lines: lines.map(DraftMaterialLine.fromMap).toList(),
      employeeAssignments:
          employeeRows.map(OfferEmployeeAssignment.fromMap).toList(),
      vehicleAssignments:
          vehicleRows.map(OfferVehicleAssignment.fromMap).toList(),
    );
  }

  Future<String> saveOffer({
    required String? offerId,
    required String? offerNumber,
    required String offerDate,
    required String documentType,
    required String offerTitle,
    required String workLocation,
    required String? clientId,
    required String currency,
    required double eurRate,
    required double vatPercent,
    required double profitPercent,
    required String overheadMode,
    required double overheadPercent,
    required CompanySettings companySnapshot,
    required String notes,
    required List<DraftMaterialLine> lines,
    required List<OfferEmployeeAssignment> employees,
    required List<OfferVehicleAssignment> vehicles,
    required OfferCalculations calculations,
  }) async {
    final number = offerNumber ??
        'OF-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final payload = {
      'user_id': localUserId,
      'client_id': clientId,
      'number': number,
      'offer_date': offerDate,
      'document_type': documentType,
      'titlu_oferta': offerTitle,
      'locatie_lucrare': workLocation,
      'currency': currency,
      'eur_rate': eurRate,
      'vat_percent': vatPercent,
      'profit_percent': profitPercent,
      'overhead_mode': overheadMode,
      'overhead_percent': overheadPercent,
      'notes': notes,
      ...companySnapshot.toMap(),
      'material_total': calculations.materialsTotal,
      'labor_total': calculations.laborTotal,
      'labor_internal_cost': calculations.laborInternalCost,
      'vehicle_total': calculations.vehicleTotal,
      'direct_total': calculations.directTotal,
      'overhead_total': calculations.overheadTotal,
      'profit_total': calculations.profitTotal,
      'total_no_vat': calculations.totalWithoutVat,
      'vat_total': calculations.vatTotal,
      'grand_total': calculations.grandTotal,
      'project_days': calculations.projectDays,
    };

    late final String savedOfferId;
    if (offerId == null) {
      final inserted =
          await _store.insertRows('offers', [payload], columns: 'id,number');
      savedOfferId = valueText(inserted.first['id']);
    } else {
      savedOfferId = offerId;
      await _store.updateRows(
        'offers',
        matchField: 'id',
        matchValue: savedOfferId,
        values: payload,
      );
      await _store.deleteRows(
        'offer_lines',
        matchField: 'offer_id',
        matchValue: savedOfferId,
      );
      await _store.deleteRows(
        'offer_employees',
        matchField: 'offer_id',
        matchValue: savedOfferId,
      );
      await _store.deleteRows(
        'offer_vehicles',
        matchField: 'offer_id',
        matchValue: savedOfferId,
      );
    }

    if (lines.isNotEmpty) {
      await _store.insertRows(
        'offer_lines',
        lines
            .map((line) => {'offer_id': savedOfferId, ...line.toMap()})
            .toList(),
      );
    }
    if (employees.isNotEmpty) {
      await _store.insertRows(
        'offer_employees',
        employees
            .map((item) => {'offer_id': savedOfferId, ...item.toMap()})
            .toList(),
      );
    }
    if (vehicles.isNotEmpty) {
      await _store.insertRows(
        'offer_vehicles',
        vehicles
            .map((item) => {'offer_id': savedOfferId, ...item.toMap()})
            .toList(),
      );
    }

    return savedOfferId;
  }
}
