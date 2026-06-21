import '../lucrare_detalii_models.dart';
import '../lucrare_format_utils.dart';

/// Calculator de manoperă pentru o lucrare — rezolvare tarife (angajat/echipă),
/// costuri linie (ore/diurnă/cazare), normalizare și deduplicare rânduri.
///
/// Extras din `lucrare_detalii_page.dart` (Faza 2). Nu deține UI și nu mută
/// starea: primește `jobId` plus provideri read-only pentru lista de angajați
/// și pentru rândurile sursă ale echipelor (closure-uri care întorc starea
/// curentă, evitând valori stale). Metodele sunt publice fiindcă pagina le
/// apelează din altă bibliotecă.
class LucrareLaborCalculator {
  LucrareLaborCalculator({
    required this.jobId,
    required this.employeesProvider,
    required this.teamsProvider,
  });

  final String jobId;
  final List<LucrareOption> Function() employeesProvider;
  final List<Map<String, dynamic>> Function() teamsProvider;

  List<LucrareOption> get _employees => employeesProvider();
  List<Map<String, dynamic>> get _teamsSourceRows => teamsProvider();

  // Helperi puri delegați (mirror al celor din pagină).
  double _asDouble(dynamic raw) => lucrareAsDouble(raw);
  bool _asBool(dynamic raw) => lucrareAsBool(raw);
  String _formatDecimal(double value) => lucrareFormatDecimal(value);
  DateTime _dateOnly(DateTime value) => lucrareDateOnly(value);
  DateTime? _tryParseLaborDate(dynamic raw) => lucrareTryParseLaborDate(raw);
  String _encodeLaborPeriodDate(DateTime value) =>
      lucrareEncodeLaborPeriodDate(value);
  String _formatDate(DateTime value) => lucrareFormatDate(value);

  List<String> extractTeamMembers(Map<String, dynamic> team) {
    final dynamic rawMembers = team['members'] ??
        team['memberIds'] ??
        team['employees'] ??
        team['employeeIds'];
    if (rawMembers is List) {
      return rawMembers
          .map((member) {
            if (member is Map) {
              final name = '${member['name'] ?? ''}'.trim();
              if (name.isNotEmpty) {
                return name;
              }
              return '${member['id'] ?? ''}'.trim();
            }
            return '$member'.trim();
          })
          .where((member) => member.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  double laborPeriodDays({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final start = _dateOnly(periodStart);
    final end = periodEnd.isBefore(periodStart) ? start : _dateOnly(periodEnd);
    return end.difference(start).inDays.toDouble() + 1;
  }

  double sanitizeLaborHoursPerDay(dynamic raw) {
    final value = _asDouble(raw);
    return value > 0 ? value : 8.0;
  }

  DateTime? laborPeriodStart(Map<String, dynamic> row) {
    return _tryParseLaborDate(
      row['periodStartDate'] ?? row['startDate'] ?? row['date'],
    );
  }

  DateTime? laborPeriodEnd(Map<String, dynamic> row) {
    return _tryParseLaborDate(
      row['periodEndDate'] ?? row['endDate'] ?? row['periodStartDate'],
    );
  }

  double laborHoursPerDay(Map<String, dynamic> row) {
    final explicit = _asDouble(row['hoursPerDay']);
    if (explicit > 0) return explicit;
    final hours = _asDouble(row['hours']);
    final tripDays = laborTripDays(row);
    if (hours > 0 && tripDays > 0) {
      return hours / tripDays;
    }
    return 8.0;
  }

  String laborPeriodLabel(Map<String, dynamic> row) {
    final start = laborPeriodStart(row);
    if (start == null) {
      final date = '${row['date'] ?? ''}'.trim();
      return date.isEmpty ? '-' : date;
    }
    final end = laborPeriodEnd(row) ?? start;
    final startLabel = _formatDate(start);
    final endLabel = _formatDate(end);
    if (startLabel == endLabel) {
      return startLabel;
    }
    return '$startLabel - $endLabel';
  }

  String normalizeEmployeeRef(String raw) {
    var value = raw.trim();
    if (value.startsWith('emp:')) {
      value = value.substring(4).trim();
    }
    return value.toLowerCase();
  }

  double employeeRateById(String employeeId) {
    final normalizedRef = normalizeEmployeeRef(employeeId);
    if (normalizedRef.isEmpty) return 0;

    for (final employee in _employees) {
      if (!employee.active) continue;
      final employeeIdNormalized = normalizeEmployeeRef(employee.id);
      final employeeLabelNormalized = employee.label.trim().toLowerCase();
      if (employeeIdNormalized == normalizedRef ||
          employeeLabelNormalized == normalizedRef) {
        return employee.hourlyRate;
      }
    }
    return 0;
  }

  double teamRateById(String teamId, List<Map<String, dynamic>> teamRows) {
    String normalizeTeamRef(String raw) {
      var value = raw.trim().toLowerCase();
      if (value.startsWith('team:')) {
        value = value.substring(5).trim();
      } else if (value.startsWith('emp:team:')) {
        value = value.substring('emp:team:'.length).trim();
      } else if (value.startsWith('emp:echipa:')) {
        value = value.substring('emp:echipa:'.length).trim();
      } else if (value.startsWith('emp:echipă:')) {
        value = value.substring('emp:echipă:'.length).trim();
      } else if (value.startsWith('emp:echipă:')) {
        value = value.substring('emp:echipă:'.length).trim();
      } else if (value.startsWith('echipa:')) {
        value = value.substring('echipa:'.length).trim();
      } else if (value.startsWith('echipă:')) {
        value = value.substring('echipă:'.length).trim();
      } else if (value.startsWith('echipă:')) {
        value = value.substring('echipă:'.length).trim();
      }
      return value;
    }

    final probe = normalizeTeamRef(teamId);
    if (probe.isEmpty) return 0;

    Map<String, dynamic>? teamRow;
    for (final row in teamRows) {
      final rowId = normalizeTeamRef('${row['id'] ?? ''}');
      final rowName = '${row['name'] ?? ''}'.trim().toLowerCase();
      if (rowId == probe || rowName == probe) {
        teamRow = row;
        break;
      }
    }
    if (teamRow == null) return 0;

    final explicitTeamRate = _asDouble(
      teamRow['hourlyRate'] ??
          teamRow['hourly_rate'] ??
          teamRow['tarifOrar'] ??
          teamRow['tarif_orar'] ??
          teamRow['rate'],
    );
    if (explicitTeamRate > 0) return explicitTeamRate;

    final members = extractTeamMembers(teamRow);
    if (members.isEmpty) return 0;

    var teamRate = 0.0;
    for (final member in members) {
      teamRate += employeeRateById(member);
    }
    return teamRate;
  }

  LucrareOption? findActiveEmployeeByRef(String reference) {
    final normalizedRef = normalizeEmployeeRef(reference);
    if (normalizedRef.isEmpty) return null;
    for (final employee in _employees) {
      if (!employee.active) continue;
      final employeeIdNormalized = normalizeEmployeeRef(employee.id);
      final employeeLabelNormalized = employee.label.trim().toLowerCase();
      if (employeeIdNormalized == normalizedRef ||
          employeeLabelNormalized == normalizedRef) {
        return employee;
      }
    }
    return null;
  }

  double employeeDailyAllowanceByRef(String reference) {
    final employee = findActiveEmployeeByRef(reference);
    return employee?.dailyAllowance ?? 0;
  }

  double employeeLodgingByRef(String reference) {
    final employee = findActiveEmployeeByRef(reference);
    if (employee == null) return 0;
    if (!employee.requiresLodgingByDefault) return 0;
    return employee.defaultLodgingCost;
  }

  bool employeeRequiresLodgingByRef(String reference) {
    final employee = findActiveEmployeeByRef(reference);
    return employee?.requiresLodgingByDefault ?? false;
  }

  double teamDailyAllowanceById(
      String teamId, List<Map<String, dynamic>> teamRows) {
    final probe = teamId.trim().toLowerCase();
    if (probe.isEmpty) return 0;
    Map<String, dynamic>? teamRow;
    for (final row in teamRows) {
      final rowId = '${row['id'] ?? ''}'.trim().toLowerCase();
      final rowName = '${row['name'] ?? ''}'.trim().toLowerCase();
      if (rowId == probe || rowName == probe) {
        teamRow = row;
        break;
      }
    }
    if (teamRow == null) return 0;
    final members = extractTeamMembers(teamRow);
    if (members.isEmpty) return 0;
    var total = 0.0;
    for (final member in members) {
      total += employeeDailyAllowanceByRef(member);
    }
    return total;
  }

  double teamLodgingById(String teamId, List<Map<String, dynamic>> teamRows) {
    final probe = teamId.trim().toLowerCase();
    if (probe.isEmpty) return 0;
    Map<String, dynamic>? teamRow;
    for (final row in teamRows) {
      final rowId = '${row['id'] ?? ''}'.trim().toLowerCase();
      final rowName = '${row['name'] ?? ''}'.trim().toLowerCase();
      if (rowId == probe || rowName == probe) {
        teamRow = row;
        break;
      }
    }
    if (teamRow == null) return 0;
    final members = extractTeamMembers(teamRow);
    if (members.isEmpty) return 0;
    var total = 0.0;
    for (final member in members) {
      total += employeeLodgingByRef(member);
    }
    return total;
  }

  bool teamRequiresLodgingById(
      String teamId, List<Map<String, dynamic>> teamRows) {
    final probe = teamId.trim().toLowerCase();
    if (probe.isEmpty) return false;
    Map<String, dynamic>? teamRow;
    for (final row in teamRows) {
      final rowId = '${row['id'] ?? ''}'.trim().toLowerCase();
      final rowName = '${row['name'] ?? ''}'.trim().toLowerCase();
      if (rowId == probe || rowName == probe) {
        teamRow = row;
        break;
      }
    }
    if (teamRow == null) return false;
    final members = extractTeamMembers(teamRow);
    if (members.isEmpty) return false;
    for (final member in members) {
      if (employeeRequiresLodgingByRef(member)) return true;
    }
    return false;
  }

  String normalizedKeyPart(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(':', '_');
  }

  String canonicalLaborType({
    required String rawType,
    required String rawWhoId,
    required String rawWhoLabel,
  }) {
    final type = rawType.trim().toLowerCase();
    if (type == 'team' || type == 'echipa' || type == 'echipă') {
      return 'team';
    }
    if (type == 'person' ||
        type == 'employee' ||
        type == 'persoana' ||
        type == 'persoană') {
      return 'person';
    }

    final whoId = rawWhoId.trim().toLowerCase();
    if (whoId.startsWith('team:') ||
        whoId.startsWith('emp:team:') ||
        whoId.startsWith('emp:echipa:') ||
        whoId.startsWith('emp:echipă:') ||
        whoId.startsWith('echipa:') ||
        whoId.startsWith('echipă:')) {
      return 'team';
    }
    if (whoId.startsWith('emp:')) {
      return 'person';
    }

    final whoLabel = rawWhoLabel.trim().toLowerCase();
    if (whoLabel.startsWith('echipa') || whoLabel.startsWith('echipă')) {
      return 'team';
    }
    return 'person';
  }

  String canonicalLaborWhoId({
    required String rawWhoId,
    required String normalizedType,
    required String rawWhoLabel,
  }) {
    var value = rawWhoId.trim();
    if (value.startsWith('emp:team:')) {
      value = 'team:${value.substring('emp:team:'.length).trim()}';
    } else if (value.startsWith('emp:echipa:') ||
        value.startsWith('emp:echipă:')) {
      value =
          'team:${value.substring(value.indexOf(':') + 1).replaceFirst('echipa:', '').replaceFirst('echipă:', '').trim()}';
    } else if (value.startsWith('echipa:') || value.startsWith('echipă:')) {
      value = 'team:${value.substring(value.indexOf(':') + 1).trim()}';
    }

    if (value.startsWith('team:')) {
      final id = value.substring(5).trim();
      if (id.isNotEmpty) return 'team:$id';
    }
    if (value.startsWith('emp:')) {
      final id = value.substring(4).trim();
      if (id.isNotEmpty) return 'emp:$id';
    }
    if (value.isNotEmpty) {
      final prefix = normalizedType == 'team' ? 'team' : 'emp';
      return '$prefix:$value';
    }

    final label = rawWhoLabel.trim();
    if (label.isNotEmpty) {
      final cleanedLabel = label
          .replaceFirst(RegExp(r'^echip[ăa]\s*:\s*', caseSensitive: false), '')
          .trim();
      final key =
          normalizedKeyPart(cleanedLabel.isEmpty ? label : cleanedLabel);
      final prefix = normalizedType == 'team' ? 'team' : 'emp';
      return '$prefix:$key';
    }
    return normalizedType == 'team' ? 'team:unknown' : 'emp:unknown';
  }

  double teamRateByWhoLabel(String rawWhoLabel) {
    var label = rawWhoLabel.trim();
    if (label.isEmpty) return 0;
    label = label
        .replaceFirst(RegExp(r'^echip[ăa]\s*:\s*', caseSensitive: false), '')
        .trim();
    if (label.isEmpty) return 0;

    for (final row in _teamsSourceRows) {
      final rowId = '${row['id'] ?? ''}'.trim();
      final rowName = '${row['name'] ?? ''}'.trim();
      if (rowId.isEmpty && rowName.isEmpty) continue;
      final sameById =
          rowId.isNotEmpty && rowId.toLowerCase() == label.toLowerCase();
      final sameByName =
          rowName.isNotEmpty && rowName.toLowerCase() == label.toLowerCase();
      if (!sameById && !sameByName) continue;
      if (rowId.isNotEmpty) {
        return teamRateById(rowId, _teamsSourceRows);
      }
      final members = extractTeamMembers(row);
      if (members.isEmpty) return 0;
      return members.fold<double>(
          0, (sum, memberId) => sum + employeeRateById(memberId));
    }
    return 0;
  }

  double laborRateForWhoId(String whoId, {String? type, String? whoLabel}) {
    final normalizedType = canonicalLaborType(
      rawType: type ?? '',
      rawWhoId: whoId,
      rawWhoLabel: whoLabel ?? '',
    );
    final value = canonicalLaborWhoId(
      rawWhoId: whoId,
      normalizedType: normalizedType,
      rawWhoLabel: whoLabel ?? '',
    );
    if (value.isEmpty) return 0;

    if (value.startsWith('team:')) {
      final teamRate = teamRateById(value.substring(5), _teamsSourceRows);
      if (teamRate > 0) return teamRate;
      final fallbackByLabel = teamRateByWhoLabel(whoLabel ?? '');
      if (fallbackByLabel > 0) return fallbackByLabel;
      return 0;
    }
    if (value.startsWith('emp:')) {
      return employeeRateById(value.substring(4));
    }
    return 0;
  }

  double laborRateForRow(Map<String, dynamic> row) {
    final explicit = _asDouble(row['hourlyRate']);
    if (explicit > 0) return explicit;
    final whoId = '${row['whoId'] ?? ''}'.trim();
    final type = '${row['type'] ?? ''}'.trim();
    final whoLabel = '${row['whoLabel'] ?? row['who'] ?? ''}'.trim();
    return laborRateForWhoId(whoId, type: type, whoLabel: whoLabel);
  }

  double laborOreCost(Map<String, dynamic> row) {
    final hours = _asDouble(row['hours']);
    final rate = laborRateForRow(row);
    return hours * rate;
  }

  double laborTripDays(Map<String, dynamic> row) => (() {
        final periodStart = laborPeriodStart(row);
        final periodEnd = laborPeriodEnd(row);
        if (periodStart != null) {
          return laborPeriodDays(
            periodStart: periodStart,
            periodEnd: periodEnd ?? periodStart,
          );
        }
        return _asDouble(row['tripDays'] ??
            row['zileDeplasare'] ??
            row['zileDiurna'] ??
            row['noptiCazare']);
      })();

  bool laborIncludePerDiem(Map<String, dynamic> row) {
    if (row.containsKey('includeDiurna')) {
      return _asBool(row['includeDiurna']);
    }
    return _asDouble(row['zileDiurna'] ?? row['daysPerDiem']) > 0;
  }

  bool laborIncludeLodging(Map<String, dynamic> row) {
    if (row.containsKey('includeCazare')) {
      return _asBool(row['includeCazare']);
    }
    return _asDouble(row['noptiCazare'] ?? row['nightsLodging']) > 0;
  }

  double laborDaysPerDiem(Map<String, dynamic> row) {
    final fromFlags = laborIncludePerDiem(row) ? laborTripDays(row) : 0.0;
    if (fromFlags > 0) return fromFlags;
    return _asDouble(row['zileDiurna'] ?? row['daysPerDiem']);
  }

  double laborPerDiemPerDay(Map<String, dynamic> row) =>
      _asDouble(row['valoareDiurnaPeZi'] ?? row['perDiemPerDay']);

  double laborNightsLodging(Map<String, dynamic> row) {
    final fromFlags = laborIncludeLodging(row) ? laborTripDays(row) : 0.0;
    if (fromFlags > 0) return fromFlags;
    return _asDouble(row['noptiCazare'] ?? row['nightsLodging']);
  }

  double laborLodgingPerNight(Map<String, dynamic> row) =>
      _asDouble(row['valoareCazarePeNoapte'] ?? row['lodgingPerNight']);

  double laborPerDiemCost(Map<String, dynamic> row) {
    final explicit = _asDouble(row['costDiurna']);
    if (explicit > 0) return explicit;
    return laborDaysPerDiem(row) * laborPerDiemPerDay(row);
  }

  double laborLodgingCost(Map<String, dynamic> row) {
    final explicit = _asDouble(row['costCazare']);
    if (explicit > 0) return explicit;
    return laborNightsLodging(row) * laborLodgingPerNight(row);
  }

  double laborTotalLineCost(Map<String, dynamic> row) {
    final costOre = laborOreCost(row);
    final costDiurna = laborPerDiemCost(row);
    final costCazare = laborLodgingCost(row);
    final calculated = costOre + costDiurna + costCazare;
    if (calculated > 0) return calculated;
    final legacy =
        _asDouble(row['costTotalLinie'] ?? row['costTotalLine'] ?? row['cost']);
    if (legacy > 0) return legacy;
    return costOre;
  }

  double laborLineCost(Map<String, dynamic> row) {
    return laborTotalLineCost(row);
  }

  String laborTypeOf(Map<String, dynamic> row) {
    return canonicalLaborType(
      rawType: '${row['type'] ?? ''}',
      rawWhoId: '${row['whoId'] ?? ''}',
      rawWhoLabel: '${row['whoLabel'] ?? row['who'] ?? ''}',
    );
  }

  Map<String, dynamic> normalizeLaborRow(Map<String, dynamic> row) {
    final nRawWhoId = '${row['whoId'] ?? ''}';
    final nRawWhoLabel = '${row['whoLabel'] ?? row['who'] ?? ''}'.trim();
    final nType = canonicalLaborType(
      rawType: '${row['type'] ?? ''}',
      rawWhoId: nRawWhoId,
      rawWhoLabel: nRawWhoLabel,
    );
    final nWhoId = canonicalLaborWhoId(
      rawWhoId: nRawWhoId,
      normalizedType: nType,
      rawWhoLabel: nRawWhoLabel,
    );
    final nWhoLabel = nRawWhoLabel.isEmpty
        ? (nType == 'team' ? 'Echipa' : 'Persoana')
        : nRawWhoLabel;
    final nDate = '${row['date'] ?? ''}'.trim().isEmpty
        ? _formatDate(DateTime.now())
        : '${row['date'] ?? ''}'.trim();
    final nPeriodStart =
        laborPeriodStart(row) ?? _tryParseLaborDate(nDate) ?? DateTime.now();
    final nPeriodEnd = laborPeriodEnd(row) ?? nPeriodStart;
    final nFallbackRate = laborRateForWhoId(
      nWhoId,
      type: nType,
      whoLabel: nWhoLabel,
    );
    final nExplicitRate = _asDouble(row['hourlyRate']);
    final nRate = nExplicitRate > 0 ? nExplicitRate : nFallbackRate;
    final nRawJobId = '${row['jobId'] ?? ''}'.trim();
    final nRawZileDiurna = _asDouble(row['zileDiurna'] ?? row['daysPerDiem']);
    final nValDiurna =
        _asDouble(row['valoareDiurnaPeZi'] ?? row['perDiemPerDay']);
    final nRawNoptiCazare =
        _asDouble(row['noptiCazare'] ?? row['nightsLodging']);
    final nValCazare =
        _asDouble(row['valoareCazarePeNoapte'] ?? row['lodgingPerNight']);
    final nTripDays = laborPeriodDays(
      periodStart: nPeriodStart,
      periodEnd: nPeriodEnd,
    );
    final nIncludeDiurna = row.containsKey('includeDiurna')
        ? _asBool(row['includeDiurna'])
        : nRawZileDiurna > 0;
    final nIncludeCazare = row.containsKey('includeCazare')
        ? _asBool(row['includeCazare'])
        : nRawNoptiCazare > 0;
    final nZileDiurna = nIncludeDiurna ? nTripDays : 0.0;
    final nNoptiCazare = nIncludeCazare ? nTripDays : 0.0;
    final nHoursPerDay = sanitizeLaborHoursPerDay(
      row['hoursPerDay'] ??
          ((nTripDays > 0 && _asDouble(row['hours']) > 0)
              ? (_asDouble(row['hours']) / nTripDays)
              : 8.0),
    );
    final nHours = nTripDays * nHoursPerDay;
    final nCostOre = nHours * nRate;
    final nCostDiurna = _asDouble(row['costDiurna']) > 0
        ? _asDouble(row['costDiurna'])
        : (nZileDiurna * nValDiurna);
    final nCostCazare = _asDouble(row['costCazare']) > 0
        ? _asDouble(row['costCazare'])
        : (nNoptiCazare * nValCazare);
    final nLegacyTotal =
        _asDouble(row['costTotalLinie'] ?? row['costTotalLine'] ?? row['cost']);
    final nCostTotal = (() {
      final value = nCostOre + nCostDiurna + nCostCazare;
      if (value > 0) return value;
      if (nLegacyTotal > 0) return nLegacyTotal;
      return nCostOre;
    })();
    return {
      'id':
          '${row['id'] ?? 'job-labor-${DateTime.now().millisecondsSinceEpoch}'}',
      'jobId': nRawJobId.isEmpty ? jobId : nRawJobId,
      'whoId': nWhoId,
      'type': nType,
      'whoLabel': nWhoLabel,
      'who': nWhoLabel,
      'date': _formatDate(nPeriodStart),
      'periodStartDate': _encodeLaborPeriodDate(nPeriodStart),
      'periodEndDate': _encodeLaborPeriodDate(nPeriodEnd),
      'hoursPerDay': nHoursPerDay,
      'hours': nHours,
      'hourlyRate': nRate,
      'tripDays': nTripDays,
      'includeDiurna': nIncludeDiurna,
      'includeCazare': nIncludeCazare,
      'zileDiurna': nZileDiurna,
      'valoareDiurnaPeZi': nValDiurna,
      'noptiCazare': nNoptiCazare,
      'valoareCazarePeNoapte': nValCazare,
      'costOre': nCostOre,
      'costDiurna': nCostDiurna,
      'costCazare': nCostCazare,
      'costTotalLinie': nCostTotal,
      'notes': '${row['notes'] ?? ''}'.trim(),
    };
  }

  String laborDedupKey(Map<String, dynamic> row) {
    final type = '${row['type'] ?? ''}'.trim().toLowerCase();
    final whoId = '${row['whoId'] ?? ''}'.trim().toLowerCase();
    final date = '${row['date'] ?? ''}'.trim();
    final periodEnd = '${row['periodEndDate'] ?? ''}'.trim();
    final hoursPerDay = _formatDecimal(_asDouble(row['hoursPerDay']));
    return '$type|$whoId|$date|$periodEnd|$hoursPerDay';
  }

  List<Map<String, dynamic>> dedupeLaborRows(List<Map<String, dynamic>> rows) {
    final merged = <String, Map<String, dynamic>>{};
    for (final raw in rows) {
      final row = normalizeLaborRow(raw);
      final key = laborDedupKey(row);
      if (!merged.containsKey(key)) {
        merged[key] = row;
        continue;
      }
      final existing = merged[key]!;
      final existingHours = _asDouble(existing['hours']);
      final newHours = _asDouble(row['hours']);
      final existingRate = _asDouble(existing['hourlyRate']);
      final newRate = _asDouble(row['hourlyRate']);
      final existingDays = _asDouble(existing['zileDiurna']);
      final newDays = _asDouble(row['zileDiurna']);
      final existingPerDiemValue = _asDouble(existing['valoareDiurnaPeZi']);
      final newPerDiemValue = _asDouble(row['valoareDiurnaPeZi']);
      final existingNights = _asDouble(existing['noptiCazare']);
      final newNights = _asDouble(row['noptiCazare']);
      final existingTripDays = _asDouble(existing['tripDays']);
      final newTripDays = _asDouble(row['tripDays']);
      final existingIncludeDiurna = _asBool(existing['includeDiurna']);
      final newIncludeDiurna = _asBool(row['includeDiurna']);
      final existingIncludeCazare = _asBool(existing['includeCazare']);
      final newIncludeCazare = _asBool(row['includeCazare']);
      final existingLodgingValue = _asDouble(existing['valoareCazarePeNoapte']);
      final newLodgingValue = _asDouble(row['valoareCazarePeNoapte']);
      final notesA = '${existing['notes'] ?? ''}'.trim();
      final notesB = '${row['notes'] ?? ''}'.trim();
      final mergedNotes = <String>[
        if (notesA.isNotEmpty) notesA,
        if (notesB.isNotEmpty && notesB != notesA) notesB,
      ].join(' | ');
      final mergedHours = existingHours + newHours;
      final mergedRate = existingRate > 0 ? existingRate : newRate;
      final mergedDays = existingDays + newDays;
      final mergedPerDiem =
          existingPerDiemValue > 0 ? existingPerDiemValue : newPerDiemValue;
      final mergedNights = existingNights + newNights;
      final mergedTripDays = existingTripDays + newTripDays;
      final mergedIncludeDiurna = existingIncludeDiurna || newIncludeDiurna;
      final mergedIncludeCazare = existingIncludeCazare || newIncludeCazare;
      final mergedLodging =
          existingLodgingValue > 0 ? existingLodgingValue : newLodgingValue;
      final mergedCostOre = mergedHours * mergedRate;
      final mergedCostDiurna = mergedDays * mergedPerDiem;
      final mergedCostCazare = mergedNights * mergedLodging;
      merged[key] = {
        ...existing,
        'hours': mergedHours,
        'hourlyRate': mergedRate,
        'tripDays': mergedTripDays,
        'includeDiurna': mergedIncludeDiurna,
        'includeCazare': mergedIncludeCazare,
        'zileDiurna': mergedDays,
        'valoareDiurnaPeZi': mergedPerDiem,
        'noptiCazare': mergedNights,
        'valoareCazarePeNoapte': mergedLodging,
        'costOre': mergedCostOre,
        'costDiurna': mergedCostDiurna,
        'costCazare': mergedCostCazare,
        'costTotalLinie': mergedCostOre + mergedCostDiurna + mergedCostCazare,
        'notes': mergedNotes,
      };
    }
    return merged.values.toList(growable: false);
  }
}
