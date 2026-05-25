class OfferPartner {
  const OfferPartner({
    required this.id,
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

  OfferPartner copyWith({
    String? id,
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
    return OfferPartner(
      id: id ?? this.id,
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

  factory OfferPartner.fromMap(Map<String, dynamic> map) {
    return OfferPartner(
      id: '${map['id'] ?? ''}'.trim(),
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

class OfferPartnerWorker {
  const OfferPartnerWorker({
    required this.id,
    required this.partnerId,
    required this.fullName,
    this.masterWorkerId = '',
    this.role = '',
    this.hours = 0,
    this.hourlyRate = 0,
    this.currency = 'RON',
    this.notes = '',
  });

  final String id;
  final String partnerId;
  final String fullName;
  final String masterWorkerId;
  final String role;
  final double hours;
  final double hourlyRate;
  final String currency;
  final String notes;

  double get total => hours * hourlyRate;

  OfferPartnerWorker copyWith({
    String? id,
    String? partnerId,
    String? fullName,
    String? masterWorkerId,
    String? role,
    double? hours,
    double? hourlyRate,
    String? currency,
    String? notes,
  }) {
    return OfferPartnerWorker(
      id: id ?? this.id,
      partnerId: partnerId ?? this.partnerId,
      fullName: fullName ?? this.fullName,
      masterWorkerId: masterWorkerId ?? this.masterWorkerId,
      role: role ?? this.role,
      hours: hours ?? this.hours,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'partnerId': partnerId,
      'fullName': fullName,
      'masterWorkerId': masterWorkerId,
      'role': role,
      'hours': hours,
      'hourlyRate': hourlyRate,
      'currency': currency,
      'notes': notes,
    };
  }

  factory OfferPartnerWorker.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    final currency = '${map['currency'] ?? 'RON'}'.trim().toUpperCase();
    return OfferPartnerWorker(
      id: '${map['id'] ?? ''}'.trim(),
      partnerId: '${map['partnerId'] ?? ''}'.trim(),
      fullName: '${map['fullName'] ?? ''}'.trim(),
      masterWorkerId:
          '${map['masterWorkerId'] ?? map['master_worker_id'] ?? ''}'.trim(),
      role: '${map['role'] ?? ''}'.trim(),
      hours: parseDouble(map['hours']),
      hourlyRate: parseDouble(map['hourlyRate']),
      currency: currency.isEmpty ? 'RON' : currency,
      notes: '${map['notes'] ?? ''}'.trim(),
    );
  }
}

class OfferPartnerVehicle {
  const OfferPartnerVehicle({
    required this.id,
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

  OfferPartnerVehicle copyWith({
    String? id,
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
    return OfferPartnerVehicle(
      id: id ?? this.id,
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

  factory OfferPartnerVehicle.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    final currency = '${map['currency'] ?? 'RON'}'.trim().toUpperCase();
    return OfferPartnerVehicle(
      id: '${map['id'] ?? ''}'.trim(),
      partnerId: '${map['partnerId'] ?? ''}'.trim(),
      vehicleName: '${map['vehicleName'] ?? map['label'] ?? ''}'.trim(),
      masterVehicleId:
          '${map['masterVehicleId'] ?? map['master_vehicle_id'] ?? ''}'.trim(),
      registrationNumber: '${map['registrationNumber'] ?? ''}'.trim(),
      km: parseDouble(map['km']),
      fuelConsumptionPer100Km: parseDouble(map['fuelConsumptionPer100Km']),
      fuelPricePerLiter: parseDouble(map['fuelPricePerLiter']),
      currency: currency.isEmpty ? 'RON' : currency,
      notes: '${map['notes'] ?? ''}'.trim(),
    );
  }
}
