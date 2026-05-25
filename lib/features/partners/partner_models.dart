class PartnerRecord {
  const PartnerRecord({
    required this.id,
    required this.name,
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
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
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
  final DateTime createdAt;
  final DateTime updatedAt;

  PartnerRecord copyWith({
    String? id,
    String? name,
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PartnerRecord(
      id: id ?? this.id,
      name: name ?? this.name,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'cui': cui,
      'trade_register_number': tradeRegisterNumber,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'county': county,
      'iban': iban,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PartnerRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    return PartnerRecord(
      id: pick(const <String>['id']),
      name: pick(const <String>['name', 'partner_name']),
      cui: pick(const <String>['cui', 'vat_code']),
      tradeRegisterNumber: pick(const <String>[
        'trade_register_number',
        'tradeRegisterNumber',
        'nr_reg_com',
      ]),
      contactPerson: pick(const <String>[
        'contact_person',
        'contactPerson',
        'persoana_contact',
      ]),
      phone: pick(const <String>['phone', 'telefon']),
      email: pick(const <String>['email']),
      address: pick(const <String>['address', 'adresa']),
      city: pick(const <String>['city', 'localitate']),
      county: pick(const <String>['county', 'judet']),
      iban: pick(const <String>['iban']),
      notes: pick(const <String>['notes', 'observatii']),
      createdAt:
          DateTime.tryParse((map['created_at'] ?? '').toString()) ?? now,
      updatedAt:
          DateTime.tryParse((map['updated_at'] ?? '').toString()) ?? now,
    );
  }
}

class PartnerWorkerRecord {
  const PartnerWorkerRecord({
    required this.id,
    required this.partnerId,
    required this.fullName,
    this.role = '',
    this.hourlyRate = 0,
    this.currency = 'RON',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String partnerId;
  final String fullName;
  final String role;
  final double hourlyRate;
  final String currency;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  PartnerWorkerRecord copyWith({
    String? id,
    String? partnerId,
    String? fullName,
    String? role,
    double? hourlyRate,
    String? currency,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PartnerWorkerRecord(
      id: id ?? this.id,
      partnerId: partnerId ?? this.partnerId,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'partner_id': partnerId,
      'full_name': fullName,
      'role': role,
      'hourly_rate': hourlyRate,
      'currency': currency,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PartnerWorkerRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    final currency = pick(const <String>['currency']);
    return PartnerWorkerRecord(
      id: pick(const <String>['id']),
      partnerId: pick(const <String>['partner_id', 'partnerId']),
      fullName: pick(const <String>['full_name', 'fullName', 'name']),
      role: pick(const <String>['role']),
      hourlyRate: parseDouble(map['hourly_rate'] ?? map['hourlyRate']),
      currency: currency.isEmpty ? 'RON' : currency.toUpperCase(),
      notes: pick(const <String>['notes', 'observatii']),
      createdAt:
          DateTime.tryParse((map['created_at'] ?? '').toString()) ?? now,
      updatedAt:
          DateTime.tryParse((map['updated_at'] ?? '').toString()) ?? now,
    );
  }
}

class PartnerVehicleRecord {
  const PartnerVehicleRecord({
    required this.id,
    required this.partnerId,
    required this.vehicleName,
    this.registrationNumber = '',
    this.fuelConsumptionPer100Km = 0,
    this.fuelPricePerLiter = 0,
    this.currency = 'RON',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String partnerId;
  final String vehicleName;
  final String registrationNumber;
  final double fuelConsumptionPer100Km;
  final double fuelPricePerLiter;
  final String currency;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  PartnerVehicleRecord copyWith({
    String? id,
    String? partnerId,
    String? vehicleName,
    String? registrationNumber,
    double? fuelConsumptionPer100Km,
    double? fuelPricePerLiter,
    String? currency,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PartnerVehicleRecord(
      id: id ?? this.id,
      partnerId: partnerId ?? this.partnerId,
      vehicleName: vehicleName ?? this.vehicleName,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      fuelConsumptionPer100Km:
          fuelConsumptionPer100Km ?? this.fuelConsumptionPer100Km,
      fuelPricePerLiter: fuelPricePerLiter ?? this.fuelPricePerLiter,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'partner_id': partnerId,
      'vehicle_name': vehicleName,
      'registration_number': registrationNumber,
      'fuel_consumption_per_100_km': fuelConsumptionPer100Km,
      'fuel_price_per_liter': fuelPricePerLiter,
      'currency': currency,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PartnerVehicleRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    final currency = pick(const <String>['currency']);
    return PartnerVehicleRecord(
      id: pick(const <String>['id']),
      partnerId: pick(const <String>['partner_id', 'partnerId']),
      vehicleName: pick(const <String>[
        'vehicle_name',
        'vehicleName',
        'name',
        'label',
      ]),
      registrationNumber: pick(const <String>[
        'registration_number',
        'registrationNumber',
      ]),
      fuelConsumptionPer100Km: parseDouble(
        map['fuel_consumption_per_100_km'] ?? map['fuelConsumptionPer100Km'],
      ),
      fuelPricePerLiter: parseDouble(
        map['fuel_price_per_liter'] ?? map['fuelPricePerLiter'],
      ),
      currency: currency.isEmpty ? 'RON' : currency.toUpperCase(),
      notes: pick(const <String>['notes', 'observatii']),
      createdAt:
          DateTime.tryParse((map['created_at'] ?? '').toString()) ?? now,
      updatedAt:
          DateTime.tryParse((map['updated_at'] ?? '').toString()) ?? now,
    );
  }
}
