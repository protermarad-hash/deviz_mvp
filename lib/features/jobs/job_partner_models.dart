class JobPartner {
  const JobPartner({
    required this.id,
    required this.jobId,
    required this.name,
    this.masterPartnerId = '',
    this.cui = '',
    this.tradeRegisterNumber = '',
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.city = '',
    this.county = '',
    this.iban = '',
    this.notes = '',
  });

  final String id;
  final String jobId;
  final String name;
  final String masterPartnerId;
  final String cui;
  final String tradeRegisterNumber;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;
  final String city;
  final String county;
  final String iban;
  final String notes;

  JobPartner copyWith({
    String? id,
    String? jobId,
    String? name,
    String? masterPartnerId,
    String? cui,
    String? tradeRegisterNumber,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? county,
    String? iban,
    String? notes,
  }) {
    return JobPartner(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      name: name ?? this.name,
      masterPartnerId: masterPartnerId ?? this.masterPartnerId,
      cui: cui ?? this.cui,
      tradeRegisterNumber: tradeRegisterNumber ?? this.tradeRegisterNumber,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      county: county ?? this.county,
      iban: iban ?? this.iban,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'jobId': jobId,
      'name': name,
      'masterPartnerId': masterPartnerId,
      'cui': cui,
      'tradeRegisterNumber': tradeRegisterNumber,
      'contactPerson': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'county': county,
      'iban': iban,
      'notes': notes,
    };
  }

  factory JobPartner.fromMap(Map<String, dynamic> map) {
    return JobPartner(
      id: '${map['id'] ?? ''}'.trim(),
      jobId: '${map['jobId'] ?? ''}'.trim(),
      name: '${map['name'] ?? ''}'.trim(),
      masterPartnerId:
          '${map['masterPartnerId'] ?? map['master_partner_id'] ?? ''}'.trim(),
      cui: '${map['cui'] ?? ''}'.trim(),
      tradeRegisterNumber:
          '${map['tradeRegisterNumber'] ?? map['trade_register_number'] ?? ''}'
              .trim(),
      contactPerson: '${map['contactPerson'] ?? ''}'.trim(),
      phone: '${map['phone'] ?? ''}'.trim(),
      email: '${map['email'] ?? ''}'.trim(),
      address: '${map['address'] ?? ''}'.trim(),
      city: '${map['city'] ?? ''}'.trim(),
      county: '${map['county'] ?? ''}'.trim(),
      iban: '${map['iban'] ?? ''}'.trim(),
      notes: '${map['notes'] ?? ''}'.trim(),
    );
  }
}

class JobPartnerWorker {
  const JobPartnerWorker({
    required this.id,
    required this.jobId,
    required this.partnerId,
    required this.fullName,
    this.masterWorkerId = '',
    this.role = '',
    this.workedHours = 0,
    this.hoursPerDay = 8,
    this.workPeriodStart,
    this.workPeriodEnd,
    this.workDays = 0,
    this.hourlyRate = 0,
    this.perDiemDays = 0,
    this.perDiemPerDay = 0,
    this.lodgingNights = 0,
    this.lodgingPerNight = 0,
    this.currency = 'RON',
    this.notes = '',
  });

  final String id;
  final String jobId;
  final String partnerId;
  final String fullName;
  final String masterWorkerId;
  final String role;
  final double workedHours;
  final double hoursPerDay;
  final DateTime? workPeriodStart;
  final DateTime? workPeriodEnd;
  final int workDays;
  final double hourlyRate;
  final int perDiemDays;
  final double perDiemPerDay;
  final int lodgingNights;
  final double lodgingPerNight;
  final String currency;
  final String notes;

  double get laborCost => workedHours * hourlyRate;
  double get perDiemCost => perDiemDays * perDiemPerDay;
  double get lodgingCost => lodgingNights * lodgingPerNight;
  double get total => laborCost + perDiemCost + lodgingCost;

  JobPartnerWorker copyWith({
    String? id,
    String? jobId,
    String? partnerId,
    String? fullName,
    String? masterWorkerId,
    String? role,
    double? workedHours,
    double? hoursPerDay,
    Object? workPeriodStart = _jobPartnerWorkerUnset,
    Object? workPeriodEnd = _jobPartnerWorkerUnset,
    int? workDays,
    double? hourlyRate,
    int? perDiemDays,
    double? perDiemPerDay,
    int? lodgingNights,
    double? lodgingPerNight,
    String? currency,
    String? notes,
  }) {
    return JobPartnerWorker(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      partnerId: partnerId ?? this.partnerId,
      fullName: fullName ?? this.fullName,
      masterWorkerId: masterWorkerId ?? this.masterWorkerId,
      role: role ?? this.role,
      workedHours: workedHours ?? this.workedHours,
      hoursPerDay: hoursPerDay ?? this.hoursPerDay,
      workPeriodStart: identical(workPeriodStart, _jobPartnerWorkerUnset)
          ? this.workPeriodStart
          : workPeriodStart as DateTime?,
      workPeriodEnd: identical(workPeriodEnd, _jobPartnerWorkerUnset)
          ? this.workPeriodEnd
          : workPeriodEnd as DateTime?,
      workDays: workDays ?? this.workDays,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      perDiemDays: perDiemDays ?? this.perDiemDays,
      perDiemPerDay: perDiemPerDay ?? this.perDiemPerDay,
      lodgingNights: lodgingNights ?? this.lodgingNights,
      lodgingPerNight: lodgingPerNight ?? this.lodgingPerNight,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'jobId': jobId,
      'partnerId': partnerId,
      'fullName': fullName,
      'masterWorkerId': masterWorkerId,
      'role': role,
      'workedHours': workedHours,
      'hoursPerDay': hoursPerDay,
      'workPeriodStart': workPeriodStart?.toIso8601String() ?? '',
      'workPeriodEnd': workPeriodEnd?.toIso8601String() ?? '',
      'workDays': workDays,
      'hourlyRate': hourlyRate,
      'perDiemDays': perDiemDays,
      'perDiemPerDay': perDiemPerDay,
      'lodgingNights': lodgingNights,
      'lodgingPerNight': lodgingPerNight,
      'currency': currency,
      'notes': notes,
    };
  }

  factory JobPartnerWorker.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    return JobPartnerWorker(
      id: '${map['id'] ?? ''}'.trim(),
      jobId: '${map['jobId'] ?? ''}'.trim(),
      partnerId: '${map['partnerId'] ?? ''}'.trim(),
      fullName: '${map['fullName'] ?? ''}'.trim(),
      masterWorkerId:
          '${map['masterWorkerId'] ?? map['master_worker_id'] ?? ''}'.trim(),
      role: '${map['role'] ?? ''}'.trim(),
      workedHours: parseDouble(map['workedHours']),
      hoursPerDay: parseDouble(map['hoursPerDay'] ?? map['hours_per_day']) <= 0
          ? 8
          : parseDouble(map['hoursPerDay'] ?? map['hours_per_day']),
      workPeriodStart: DateTime.tryParse(
        '${map['workPeriodStart'] ?? map['work_period_start'] ?? ''}',
      ),
      workPeriodEnd: DateTime.tryParse(
        '${map['workPeriodEnd'] ?? map['work_period_end'] ?? ''}',
      ),
      workDays: (map['workDays'] ?? map['work_days']) is num
          ? (map['workDays'] ?? map['work_days'] as num).toInt()
          : int.tryParse('${map['workDays'] ?? map['work_days'] ?? '0'}') ?? 0,
      hourlyRate: parseDouble(map['hourlyRate']),
      perDiemDays: (map['perDiemDays'] ?? map['per_diem_days']) is num
          ? (map['perDiemDays'] ?? map['per_diem_days'] as num).toInt()
          : int.tryParse(
                  '${map['perDiemDays'] ?? map['per_diem_days'] ?? '0'}') ??
              0,
      perDiemPerDay:
          parseDouble(map['perDiemPerDay'] ?? map['per_diem_per_day']),
      lodgingNights: (map['lodgingNights'] ?? map['lodging_nights']) is num
          ? (map['lodgingNights'] ?? map['lodging_nights'] as num).toInt()
          : int.tryParse(
                  '${map['lodgingNights'] ?? map['lodging_nights'] ?? '0'}') ??
              0,
      lodgingPerNight:
          parseDouble(map['lodgingPerNight'] ?? map['lodging_per_night']),
      currency: '${map['currency'] ?? 'RON'}'.trim().isEmpty
          ? 'RON'
          : '${map['currency'] ?? 'RON'}'.trim(),
      notes: '${map['notes'] ?? ''}'.trim(),
    );
  }
}

const Object _jobPartnerWorkerUnset = Object();

class JobPartnerVehicle {
  const JobPartnerVehicle({
    required this.id,
    required this.jobId,
    required this.partnerId,
    required this.vehicleName,
    this.masterVehicleId = '',
    this.registrationNumber = '',
    this.km = 0,
    this.fuelConsumptionPer100Km = 0,
    this.fuelPricePerLiter = 0,
    this.currency = 'RON',
    this.notes = '',
  });

  final String id;
  final String jobId;
  final String partnerId;
  final String vehicleName;
  final String masterVehicleId;
  final String registrationNumber;
  final double km;
  final double fuelConsumptionPer100Km;
  final double fuelPricePerLiter;
  final String currency;
  final String notes;

  double get fuelLiters => km * fuelConsumptionPer100Km / 100;
  double get total => fuelLiters * fuelPricePerLiter;

  JobPartnerVehicle copyWith({
    String? id,
    String? jobId,
    String? partnerId,
    String? vehicleName,
    String? masterVehicleId,
    String? registrationNumber,
    double? km,
    double? fuelConsumptionPer100Km,
    double? fuelPricePerLiter,
    String? currency,
    String? notes,
  }) {
    return JobPartnerVehicle(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      partnerId: partnerId ?? this.partnerId,
      vehicleName: vehicleName ?? this.vehicleName,
      masterVehicleId: masterVehicleId ?? this.masterVehicleId,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      km: km ?? this.km,
      fuelConsumptionPer100Km:
          fuelConsumptionPer100Km ?? this.fuelConsumptionPer100Km,
      fuelPricePerLiter: fuelPricePerLiter ?? this.fuelPricePerLiter,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'jobId': jobId,
      'partnerId': partnerId,
      'vehicleName': vehicleName,
      'masterVehicleId': masterVehicleId,
      'registrationNumber': registrationNumber,
      'km': km,
      'fuelConsumptionPer100Km': fuelConsumptionPer100Km,
      'fuelPricePerLiter': fuelPricePerLiter,
      'currency': currency,
      'notes': notes,
    };
  }

  factory JobPartnerVehicle.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    return JobPartnerVehicle(
      id: '${map['id'] ?? ''}'.trim(),
      jobId: '${map['jobId'] ?? ''}'.trim(),
      partnerId: '${map['partnerId'] ?? ''}'.trim(),
      vehicleName: '${map['vehicleName'] ?? map['label'] ?? ''}'.trim(),
      masterVehicleId:
          '${map['masterVehicleId'] ?? map['master_vehicle_id'] ?? ''}'.trim(),
      registrationNumber: '${map['registrationNumber'] ?? ''}'.trim(),
      km: parseDouble(map['km']),
      fuelConsumptionPer100Km: parseDouble(map['fuelConsumptionPer100Km']),
      fuelPricePerLiter: parseDouble(map['fuelPricePerLiter']),
      currency: '${map['currency'] ?? 'RON'}'.trim().isEmpty
          ? 'RON'
          : '${map['currency'] ?? 'RON'}'.trim(),
      notes: '${map['notes'] ?? ''}'.trim(),
    );
  }
}

class JobOwnVehicle {
  const JobOwnVehicle({
    required this.id,
    required this.jobId,
    this.masterVehicleId = '',
    this.vehicleName = '',
    this.plateNumber = '',
    this.km = 0,
    this.fuelConsumptionPer100Km = 0,
    this.fuelPricePerLiter = 0,
    this.currency = 'RON',
    this.notes = '',
  });

  final String id;
  final String jobId;
  final String masterVehicleId;
  final String vehicleName;
  final String plateNumber;
  final double km;
  final double fuelConsumptionPer100Km;
  final double fuelPricePerLiter;
  final String currency;
  final String notes;

  double get fuelLiters => km * fuelConsumptionPer100Km / 100;
  double get total => fuelLiters * fuelPricePerLiter;

  JobOwnVehicle copyWith({
    String? id,
    String? jobId,
    String? masterVehicleId,
    String? vehicleName,
    String? plateNumber,
    double? km,
    double? fuelConsumptionPer100Km,
    double? fuelPricePerLiter,
    String? currency,
    String? notes,
  }) {
    return JobOwnVehicle(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      masterVehicleId: masterVehicleId ?? this.masterVehicleId,
      vehicleName: vehicleName ?? this.vehicleName,
      plateNumber: plateNumber ?? this.plateNumber,
      km: km ?? this.km,
      fuelConsumptionPer100Km:
          fuelConsumptionPer100Km ?? this.fuelConsumptionPer100Km,
      fuelPricePerLiter: fuelPricePerLiter ?? this.fuelPricePerLiter,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'jobId': jobId,
      'masterVehicleId': masterVehicleId,
      'vehicleName': vehicleName,
      'plateNumber': plateNumber,
      'km': km,
      'fuelConsumptionPer100Km': fuelConsumptionPer100Km,
      'fuelPricePerLiter': fuelPricePerLiter,
      'currency': currency,
      'notes': notes,
    };
  }

  factory JobOwnVehicle.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    return JobOwnVehicle(
      id: '${map['id'] ?? ''}'.trim(),
      jobId: '${map['jobId'] ?? ''}'.trim(),
      masterVehicleId: '${map['masterVehicleId'] ?? ''}'.trim(),
      vehicleName: '${map['vehicleName'] ?? ''}'.trim(),
      plateNumber: '${map['plateNumber'] ?? ''}'.trim(),
      km: parseDouble(map['km']),
      fuelConsumptionPer100Km: parseDouble(map['fuelConsumptionPer100Km']),
      fuelPricePerLiter: parseDouble(map['fuelPricePerLiter']),
      currency: '${map['currency'] ?? 'RON'}'.trim().isEmpty
          ? 'RON'
          : '${map['currency'] ?? 'RON'}'.trim(),
      notes: '${map['notes'] ?? ''}'.trim(),
    );
  }
}
