enum TripSourceType {
  job,
  appointment,
  ticket,
  manual;

  static TripSourceType fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return TripSourceType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => TripSourceType.manual,
    );
  }
}

extension TripSourceTypeX on TripSourceType {
  String get value {
    switch (this) {
      case TripSourceType.job:
        return 'job';
      case TripSourceType.appointment:
        return 'appointment';
      case TripSourceType.ticket:
        return 'ticket';
      case TripSourceType.manual:
        return 'manual';
    }
  }

  String get label {
    switch (this) {
      case TripSourceType.job:
        return 'Lucrare';
      case TripSourceType.appointment:
        return 'Programare';
      case TripSourceType.ticket:
        return 'Reclamatie';
      case TripSourceType.manual:
        return 'Manual';
    }
  }
}

enum TripStatus {
  draft,
  aprobata,
  activa,
  finalizata,
  anulata;

  static TripStatus fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return TripStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => TripStatus.draft,
    );
  }
}

extension TripStatusX on TripStatus {
  String get value {
    switch (this) {
      case TripStatus.draft:
        return 'draft';
      case TripStatus.aprobata:
        return 'aprobata';
      case TripStatus.activa:
        return 'activa';
      case TripStatus.finalizata:
        return 'finalizata';
      case TripStatus.anulata:
        return 'anulata';
    }
  }

  String get label {
    switch (this) {
      case TripStatus.draft:
        return 'Ciorna';
      case TripStatus.aprobata:
        return 'Aprobata';
      case TripStatus.activa:
        return 'Activa';
      case TripStatus.finalizata:
        return 'Finalizata';
      case TripStatus.anulata:
        return 'Anulata';
    }
  }
}

class Trip {
  const Trip({
    required this.id,
    required this.tripNumber,
    required this.sourceType,
    required this.originLocation,
    required this.destinationLocation,
    required this.departureDate,
    required this.returnDateEstimated,
    required this.purpose,
    required this.assignedEmployeeIds,
    required this.estimatedKm,
    required this.status,
    required this.notes,
    this.sourceId = '',
    this.clientId = '',
    this.jobId = '',
    this.appointmentId = '',
    this.ticketId = '',
    this.returnDateActual,
    this.teamId = '',
    this.vehicleId = '',
    this.vehicleIds = const <String>[],
    this.actualKm,
  });

  final String id;
  final String tripNumber;
  final TripSourceType sourceType;
  final String sourceId;
  final String clientId;
  final String jobId;
  final String appointmentId;
  final String ticketId;
  final String originLocation;
  final String destinationLocation;
  final DateTime departureDate;
  final DateTime returnDateEstimated;
  final DateTime? returnDateActual;
  final String purpose;
  final String teamId;
  final List<String> assignedEmployeeIds;
  final String vehicleId;
  final List<String> vehicleIds;
  final double estimatedKm;
  final double? actualKm;
  final TripStatus status;
  final String notes;

  Trip copyWith({
    String? id,
    String? tripNumber,
    TripSourceType? sourceType,
    String? sourceId,
    String? clientId,
    String? jobId,
    String? appointmentId,
    String? ticketId,
    String? originLocation,
    String? destinationLocation,
    DateTime? departureDate,
    DateTime? returnDateEstimated,
    DateTime? returnDateActual,
    String? purpose,
    String? teamId,
    List<String>? assignedEmployeeIds,
    String? vehicleId,
    List<String>? vehicleIds,
    double? estimatedKm,
    double? actualKm,
    TripStatus? status,
    String? notes,
  }) {
    return Trip(
      id: id ?? this.id,
      tripNumber: tripNumber ?? this.tripNumber,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      clientId: clientId ?? this.clientId,
      jobId: jobId ?? this.jobId,
      appointmentId: appointmentId ?? this.appointmentId,
      ticketId: ticketId ?? this.ticketId,
      originLocation: originLocation ?? this.originLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      departureDate: departureDate ?? this.departureDate,
      returnDateEstimated: returnDateEstimated ?? this.returnDateEstimated,
      returnDateActual: returnDateActual ?? this.returnDateActual,
      purpose: purpose ?? this.purpose,
      teamId: teamId ?? this.teamId,
      assignedEmployeeIds: assignedEmployeeIds ?? this.assignedEmployeeIds,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleIds: vehicleIds ?? this.vehicleIds,
      estimatedKm: estimatedKm ?? this.estimatedKm,
      actualKm: actualKm ?? this.actualKm,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_number': tripNumber,
      'source_type': sourceType.value,
      'source_id': sourceId,
      'client_id': clientId,
      'job_id': jobId,
      'appointment_id': appointmentId,
      'ticket_id': ticketId,
      'origin_location': originLocation,
      'destination_location': destinationLocation,
      'departure_date': departureDate.toIso8601String(),
      'return_date_estimated': returnDateEstimated.toIso8601String(),
      'return_date_actual': returnDateActual?.toIso8601String(),
      'purpose': purpose,
      'team_id': teamId,
      'assigned_employee_ids': assignedEmployeeIds,
      'vehicle_id': vehicleIds.isNotEmpty ? vehicleIds.first : vehicleId,
      'vehicle_ids': vehicleIds.isNotEmpty
          ? vehicleIds
          : (vehicleId.trim().isEmpty ? const <String>[] : <String>[vehicleId]),
      'estimated_km': estimatedKm,
      'actual_km': actualKm,
      'status': status.value,
      'notes': notes,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(String key, DateTime fallback) {
      return DateTime.tryParse((map[key] ?? '').toString()) ?? fallback;
    }

    List<String> parseIds(dynamic raw) {
      if (raw is! List) {
        return const <String>[];
      }
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    final legacyVehicleId = (map['vehicle_id'] ?? '').toString().trim();
    final parsedVehicleIds = parseIds(map['vehicle_ids']);
    final normalizedVehicleIds = parsedVehicleIds.isNotEmpty
        ? parsedVehicleIds
        : (legacyVehicleId.isEmpty
            ? const <String>[]
            : <String>[legacyVehicleId]);

    return Trip(
      id: (map['id'] ?? '').toString(),
      tripNumber: (map['trip_number'] ?? '').toString(),
      sourceType:
          TripSourceType.fromValue((map['source_type'] ?? '').toString()),
      sourceId: (map['source_id'] ?? '').toString(),
      clientId: (map['client_id'] ?? '').toString(),
      jobId: (map['job_id'] ?? '').toString(),
      appointmentId: (map['appointment_id'] ?? '').toString(),
      ticketId: (map['ticket_id'] ?? '').toString(),
      originLocation: (map['origin_location'] ?? '').toString(),
      destinationLocation: (map['destination_location'] ?? '').toString(),
      departureDate: parseDate('departure_date', DateTime.now()),
      returnDateEstimated: parseDate('return_date_estimated', DateTime.now()),
      returnDateActual:
          DateTime.tryParse((map['return_date_actual'] ?? '').toString()),
      purpose: (map['purpose'] ?? '').toString(),
      teamId: (map['team_id'] ?? '').toString(),
      assignedEmployeeIds:
          (map['assigned_employee_ids'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList(),
      vehicleId:
          normalizedVehicleIds.isNotEmpty ? normalizedVehicleIds.first : '',
      vehicleIds: normalizedVehicleIds,
      estimatedKm: _parseDouble(map['estimated_km']),
      actualKm:
          map['actual_km'] == null ? null : _parseDouble(map['actual_km']),
      status: TripStatus.fromValue((map['status'] ?? '').toString()),
      notes: (map['notes'] ?? '').toString(),
    );
  }
}

enum TravelOrderStatus {
  draft,
  emis,
  trimis,
  inchis;

  static TravelOrderStatus fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return TravelOrderStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => TravelOrderStatus.draft,
    );
  }
}

const String kDefaultTravelOrderSigner = 'HERMAN SEBASTIAN';

extension TravelOrderStatusX on TravelOrderStatus {
  String get value {
    switch (this) {
      case TravelOrderStatus.draft:
        return 'draft';
      case TravelOrderStatus.emis:
        return 'emis';
      case TravelOrderStatus.trimis:
        return 'trimis';
      case TravelOrderStatus.inchis:
        return 'inchis';
    }
  }

  String get label {
    switch (this) {
      case TravelOrderStatus.draft:
        return 'Ciorna';
      case TravelOrderStatus.emis:
        return 'Emis';
      case TravelOrderStatus.trimis:
        return 'Trimis';
      case TravelOrderStatus.inchis:
        return 'Inchis';
    }
  }
}

class TravelOrderLodging {
  const TravelOrderLodging({
    required this.location,
    this.startDate,
    this.endDate,
    this.nights = 0,
    this.pricePerNight = 0,
    this.totalCost = 0,
    this.notes = '',
  });

  final String location;
  final DateTime? startDate;
  final DateTime? endDate;
  final int nights;
  final double pricePerNight;
  final double totalCost;
  final String notes;

  int get resolvedNights {
    if (nights > 0) {
      return nights;
    }
    if (startDate == null || endDate == null) {
      return 0;
    }
    return calculateTravelOrderLodgingNights(startDate!, endDate!);
  }

  double get resolvedTotalCost {
    if (totalCost > 0) {
      return totalCost;
    }
    if (resolvedNights > 0 && pricePerNight > 0) {
      return resolvedNights * pricePerNight;
    }
    return 0;
  }

  TravelOrderLodging copyWith({
    String? location,
    Object? startDate = _travelOrderUnsetValue,
    Object? endDate = _travelOrderUnsetValue,
    int? nights,
    double? pricePerNight,
    double? totalCost,
    String? notes,
  }) {
    return TravelOrderLodging(
      location: location ?? this.location,
      startDate: identical(startDate, _travelOrderUnsetValue)
          ? this.startDate
          : startDate as DateTime?,
      endDate: identical(endDate, _travelOrderUnsetValue)
          ? this.endDate
          : endDate as DateTime?,
      nights: nights ?? this.nights,
      pricePerNight: pricePerNight ?? this.pricePerNight,
      totalCost: totalCost ?? this.totalCost,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'location': location,
      'start_date': startDate?.toIso8601String() ?? '',
      'end_date': endDate?.toIso8601String() ?? '',
      'nights': nights,
      'price_per_night': pricePerNight,
      'total_cost': totalCost,
      'notes': notes,
    };
  }

  factory TravelOrderLodging.fromMap(Map<String, dynamic> map) {
    return TravelOrderLodging(
      location: (map['location'] ?? '').toString(),
      startDate: DateTime.tryParse((map['start_date'] ?? '').toString()),
      endDate: DateTime.tryParse((map['end_date'] ?? '').toString()),
      nights: _parseInt(map['nights']),
      pricePerNight: _parseDouble(map['price_per_night']),
      totalCost: _parseDouble(map['total_cost']),
      notes: (map['notes'] ?? '').toString(),
    );
  }
}

class TravelOrder {
  const TravelOrder({
    required this.id,
    required this.orderNumber,
    required this.issueDate,
    required this.tripId,
    required this.originLocation,
    required this.destinationLocation,
    required this.returnLocation,
    required this.periodStart,
    required this.periodEnd,
    required this.purpose,
    required this.transportType,
    required this.estimatedKm,
    required this.perDiemPerDay,
    required this.lodgingPerDay,
    required this.lodgingNightsCount,
    this.lodgings = const <TravelOrderLodging>[],
    required this.daysCount,
    required this.advanceAmount,
    required this.issuedBy,
    required this.approvedBy,
    required this.status,
    this.employeeId = '',
    this.teamId = '',
    this.clientId = '',
    this.jobId = '',
    this.appointmentId = '',
    this.ticketId = '',
    this.vehicleId = '',
    this.pdfPath = '',
    this.registryEntryId = '',
    this.registryNumber = '',
    this.registeredAt,
  });

  final String id;
  final String orderNumber;
  final DateTime issueDate;
  final String tripId;
  final String employeeId;
  final String teamId;
  final String clientId;
  final String jobId;
  final String appointmentId;
  final String ticketId;
  final String originLocation;
  final String destinationLocation;
  final String returnLocation;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String purpose;
  final String transportType;
  final String vehicleId;
  final double estimatedKm;
  final double perDiemPerDay;
  final double lodgingPerDay;
  final int lodgingNightsCount;
  final List<TravelOrderLodging> lodgings;
  final int daysCount;
  final double advanceAmount;
  final String issuedBy;
  final String approvedBy;
  final TravelOrderStatus status;
  final String pdfPath;
  final String registryEntryId;
  final String registryNumber;
  final DateTime? registeredAt;

  String get resolvedIssuedBy =>
      issuedBy.trim().isEmpty ? kDefaultTravelOrderSigner : issuedBy.trim();

  String get resolvedApprovedBy =>
      approvedBy.trim().isEmpty ? kDefaultTravelOrderSigner : approvedBy.trim();

  bool get hasDetailedLodgings => lodgings.isNotEmpty;

  int get autoPerDiemDays =>
      calculateTravelOrderPerDiemDays(periodStart, periodEnd);

  int get autoLodgingNights =>
      calculateTravelOrderLodgingNights(periodStart, periodEnd);

  int get resolvedPerDiemDays {
    if (daysCount > 0) {
      return daysCount;
    }
    return autoPerDiemDays;
  }

  int get resolvedLodgingNights {
    if (lodgings.isNotEmpty) {
      return lodgings.fold<int>(0, (sum, item) => sum + item.resolvedNights);
    }
    if (lodgingNightsCount > 0) {
      return lodgingNightsCount;
    }
    return autoLodgingNights;
  }

  double get totalPerDiemCost => resolvedPerDiemDays * perDiemPerDay;

  double get totalLodgingCost {
    if (lodgings.isNotEmpty) {
      return lodgings.fold<double>(
        0,
        (sum, item) => sum + item.resolvedTotalCost,
      );
    }
    return lodgingPerDay * resolvedLodgingNights;
  }

  double get totalEstimatedCost =>
      advanceAmount + totalPerDiemCost + totalLodgingCost;

  TravelOrder copyWith({
    String? id,
    String? orderNumber,
    DateTime? issueDate,
    String? tripId,
    String? employeeId,
    String? teamId,
    String? clientId,
    String? jobId,
    String? appointmentId,
    String? ticketId,
    String? originLocation,
    String? destinationLocation,
    String? returnLocation,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? purpose,
    String? transportType,
    String? vehicleId,
    double? estimatedKm,
    double? perDiemPerDay,
    double? lodgingPerDay,
    int? lodgingNightsCount,
    List<TravelOrderLodging>? lodgings,
    int? daysCount,
    double? advanceAmount,
    String? issuedBy,
    String? approvedBy,
    TravelOrderStatus? status,
    String? pdfPath,
    String? registryEntryId,
    String? registryNumber,
    DateTime? registeredAt,
  }) {
    return TravelOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      issueDate: issueDate ?? this.issueDate,
      tripId: tripId ?? this.tripId,
      employeeId: employeeId ?? this.employeeId,
      teamId: teamId ?? this.teamId,
      clientId: clientId ?? this.clientId,
      jobId: jobId ?? this.jobId,
      appointmentId: appointmentId ?? this.appointmentId,
      ticketId: ticketId ?? this.ticketId,
      originLocation: originLocation ?? this.originLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      returnLocation: returnLocation ?? this.returnLocation,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      purpose: purpose ?? this.purpose,
      transportType: transportType ?? this.transportType,
      vehicleId: vehicleId ?? this.vehicleId,
      estimatedKm: estimatedKm ?? this.estimatedKm,
      perDiemPerDay: perDiemPerDay ?? this.perDiemPerDay,
      lodgingPerDay: lodgingPerDay ?? this.lodgingPerDay,
      lodgingNightsCount: lodgingNightsCount ?? this.lodgingNightsCount,
      lodgings: lodgings ?? this.lodgings,
      daysCount: daysCount ?? this.daysCount,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      issuedBy: issuedBy ?? this.issuedBy,
      approvedBy: approvedBy ?? this.approvedBy,
      status: status ?? this.status,
      pdfPath: pdfPath ?? this.pdfPath,
      registryEntryId: registryEntryId ?? this.registryEntryId,
      registryNumber: registryNumber ?? this.registryNumber,
      registeredAt: registeredAt ?? this.registeredAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_number': orderNumber,
      'issue_date': issueDate.toIso8601String(),
      'trip_id': tripId,
      'employee_id': employeeId,
      'team_id': teamId,
      'client_id': clientId,
      'job_id': jobId,
      'appointment_id': appointmentId,
      'ticket_id': ticketId,
      'origin_location': originLocation,
      'destination_location': destinationLocation,
      'return_location': returnLocation,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
      'purpose': purpose,
      'transport_type': transportType,
      'vehicle_id': vehicleId,
      'estimated_km': estimatedKm,
      'per_diem_per_day': perDiemPerDay,
      'lodging_per_day': lodgingPerDay,
      'lodging_nights_count': lodgingNightsCount,
      'lodgings': lodgings.map((item) => item.toMap()).toList(growable: false),
      'days_count': daysCount,
      'advance_amount': advanceAmount,
      'issued_by': issuedBy,
      'approved_by': approvedBy,
      'status': status.value,
      'pdf_path': pdfPath,
      'registry_entry_id': registryEntryId,
      'registry_number': registryNumber,
      'registered_at': registeredAt?.toIso8601String() ?? '',
    };
  }

  factory TravelOrder.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(String key, DateTime fallback) {
      return DateTime.tryParse((map[key] ?? '').toString()) ?? fallback;
    }

    List<TravelOrderLodging> parseLodgings(dynamic raw) {
      if (raw is! List) {
        return const <TravelOrderLodging>[];
      }
      return raw
          .whereType<Map>()
          .map((item) =>
              TravelOrderLodging.fromMap(Map<String, dynamic>.from(item)))
          .where((item) => item.location.trim().isNotEmpty)
          .toList(growable: false);
    }

    return TravelOrder(
      id: (map['id'] ?? '').toString(),
      orderNumber: (map['order_number'] ?? '').toString(),
      issueDate: parseDate('issue_date', DateTime.now()),
      tripId: (map['trip_id'] ?? '').toString(),
      employeeId: (map['employee_id'] ?? '').toString(),
      teamId: (map['team_id'] ?? '').toString(),
      clientId: (map['client_id'] ?? '').toString(),
      jobId: (map['job_id'] ?? '').toString(),
      appointmentId: (map['appointment_id'] ?? '').toString(),
      ticketId: (map['ticket_id'] ?? '').toString(),
      originLocation: (map['origin_location'] ?? '').toString(),
      destinationLocation: (map['destination_location'] ?? '').toString(),
      returnLocation:
          (map['return_location'] ?? map['origin_location'] ?? '').toString(),
      periodStart: parseDate('period_start', DateTime.now()),
      periodEnd: parseDate('period_end', DateTime.now()),
      purpose: (map['purpose'] ?? '').toString(),
      transportType: (map['transport_type'] ?? '').toString(),
      vehicleId: (map['vehicle_id'] ?? '').toString(),
      estimatedKm: _parseDouble(map['estimated_km']),
      perDiemPerDay: _parseDouble(map['per_diem_per_day']),
      lodgingPerDay: _parseDouble(map['lodging_per_day']),
      lodgingNightsCount: _parseInt(
        map['lodging_nights_count'],
        fallback: calculateTravelOrderLodgingNights(
          parseDate('period_start', DateTime.now()),
          parseDate('period_end', DateTime.now()),
        ),
      ),
      lodgings: parseLodgings(map['lodgings']),
      daysCount: _parseInt(
        map['days_count'],
        fallback: calculateTravelOrderPerDiemDays(
          parseDate('period_start', DateTime.now()),
          parseDate('period_end', DateTime.now()),
        ),
      ),
      advanceAmount: _parseDouble(map['advance_amount']),
      issuedBy: (map['issued_by'] ?? '').toString(),
      approvedBy: (map['approved_by'] ?? '').toString(),
      status: TravelOrderStatus.fromValue((map['status'] ?? '').toString()),
      pdfPath: (map['pdf_path'] ?? '').toString(),
      registryEntryId:
          (map['registry_entry_id'] ?? map['registryEntryId'] ?? '').toString(),
      registryNumber:
          (map['registry_number'] ?? map['registryNumber'] ?? '').toString(),
      registeredAt: DateTime.tryParse(
          (map['registered_at'] ?? map['registeredAt'] ?? '').toString()),
    );
  }
}

DateTime normalizeTravelOrderEnd(DateTime start, DateTime end) {
  return end.isBefore(start) ? start : end;
}

int calculateTravelOrderPerDiemDays(DateTime start, DateTime end) {
  final safeEnd = normalizeTravelOrderEnd(start, end);
  final duration = safeEnd.difference(start);
  final fullDays = duration.inHours ~/ 24;
  final remainderMinutes =
      duration.inMinutes - (fullDays * const Duration(hours: 24).inMinutes);
  final extraDay =
      remainderMinutes >= const Duration(hours: 12).inMinutes ? 1 : 0;
  final result = fullDays + extraDay;
  return result < 0 ? 0 : result;
}

int calculateTravelOrderLodgingNights(DateTime start, DateTime end) {
  final safeEnd = normalizeTravelOrderEnd(start, end);
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(safeEnd.year, safeEnd.month, safeEnd.day);
  final result = endDay.difference(startDay).inDays;
  return result < 0 ? 0 : result;
}

const Object _travelOrderUnsetValue = Object();

double _parseDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  final raw = value?.toString() ?? '';
  return double.tryParse(raw) ?? double.tryParse(raw.replaceAll(',', '.')) ?? 0;
}

int _parseInt(dynamic value, {int fallback = 0}) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
