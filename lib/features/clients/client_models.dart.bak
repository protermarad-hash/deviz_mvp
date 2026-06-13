enum ClientType {
  persoanaFizica,
  persoanaJuridica;

  String get value {
    switch (this) {
      case ClientType.persoanaFizica:
        return 'persoana_fizica';
      case ClientType.persoanaJuridica:
        return 'persoana_juridica';
    }
  }

  String get label {
    switch (this) {
      case ClientType.persoanaFizica:
        return 'Persoana fizica';
      case ClientType.persoanaJuridica:
        return 'Persoana juridica';
    }
  }

  static ClientType fromValue(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return ClientType.values.firstWhere(
      (item) => item.value == normalized,
      orElse: () => ClientType.persoanaJuridica,
    );
  }
}

class ClientDepartment {
  const ClientDepartment({
    required this.id,
    required this.name,
    this.notes = '',
  });

  final String id;
  final String name;
  final String notes;

  ClientDepartment copyWith({
    String? id,
    String? name,
    String? notes,
  }) {
    return ClientDepartment(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'notes': notes,
    };
  }

  factory ClientDepartment.fromMap(Map<String, dynamic> map) {
    return ClientDepartment(
      id: (map['id'] ?? '').toString().trim(),
      name: (map['name'] ?? '').toString().trim(),
      notes: (map['notes'] ?? '').toString(),
    );
  }
}

class ClientContactPerson {
  const ClientContactPerson({
    required this.id,
    required this.fullName,
    this.role = '',
    this.email = '',
    this.phone = '',
    this.departmentId = '',
    this.notes = '',
  });

  final String id;
  final String fullName;
  final String role;
  final String email;
  final String phone;
  final String departmentId;
  final String notes;

  ClientContactPerson copyWith({
    String? id,
    String? fullName,
    String? role,
    String? email,
    String? phone,
    String? departmentId,
    String? notes,
  }) {
    return ClientContactPerson(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      departmentId: departmentId ?? this.departmentId,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'full_name': fullName,
      'role': role,
      'email': email,
      'phone': phone,
      'department_id': departmentId,
      'notes': notes,
    };
  }

  factory ClientContactPerson.fromMap(Map<String, dynamic> map) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return ClientContactPerson(
      id: pick(const <String>['id']),
      fullName: pick(const <String>[
        'full_name',
        'fullName',
        'name',
      ]),
      role: pick(const <String>['role', 'functie']),
      email: pick(const <String>['email']),
      phone: pick(const <String>['phone', 'telefon']),
      departmentId: pick(const <String>['department_id', 'departmentId']),
      notes: pick(const <String>['notes']),
    );
  }
}

class ClientRecord {
  const ClientRecord({
    required this.id,
    required this.clientCode,
    this.externalClientCode = '',
    this.externalClientSource = '',
    required this.type,
    required this.name,
    required this.contactPerson,
    required this.phone,
    this.phone2 = '',
    this.phone3 = '',
    required this.email,
    required this.address,
    required this.city,
    required this.county,
    required this.notes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.cui = '',
    this.regCom = '',
    this.iban = '',
    this.bank = '',
    this.departments = const <ClientDepartment>[],
    this.contactPeople = const <ClientContactPerson>[],
  });

  final String id;
  final String clientCode;
  final String externalClientCode;
  final String externalClientSource;
  final ClientType type;
  final String name;
  final String contactPerson;
  final String phone;
  final String phone2;
  final String phone3;
  final String email;
  final String cui;
  final String regCom;
  final String iban;
  final String bank;
  final List<ClientDepartment> departments;
  final List<ClientContactPerson> contactPeople;
  final String address;
  final String city;
  final String county;
  final String notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClientRecord copyWith({
    String? id,
    String? clientCode,
    String? externalClientCode,
    String? externalClientSource,
    ClientType? type,
    String? name,
    String? contactPerson,
    String? phone,
    String? phone2,
    String? phone3,
    String? email,
    String? cui,
    String? regCom,
    String? iban,
    String? bank,
    List<ClientDepartment>? departments,
    List<ClientContactPerson>? contactPeople,
    String? address,
    String? city,
    String? county,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClientRecord(
      id: id ?? this.id,
      clientCode: clientCode ?? this.clientCode,
      externalClientCode: externalClientCode ?? this.externalClientCode,
      externalClientSource: externalClientSource ?? this.externalClientSource,
      type: type ?? this.type,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      phone2: phone2 ?? this.phone2,
      phone3: phone3 ?? this.phone3,
      email: email ?? this.email,
      cui: cui ?? this.cui,
      regCom: regCom ?? this.regCom,
      iban: iban ?? this.iban,
      bank: bank ?? this.bank,
      departments: departments ?? this.departments,
      contactPeople: contactPeople ?? this.contactPeople,
      address: address ?? this.address,
      city: city ?? this.city,
      county: county ?? this.county,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_code': clientCode,
      'external_client_code': externalClientCode,
      'external_client_source': externalClientSource,
      'type': type.value,
      'name': name,
      'contact_person': contactPerson,
      'phone': phone,
      'phone2': phone2,
      'phone3': phone3,
      'email': email,
      'cui': cui,
      'reg_com': regCom,
      'iban': iban,
      'bank': bank,
      'departments': departments.map((item) => item.toMap()).toList(),
      'contact_people': contactPeople.map((item) => item.toMap()).toList(),
      'address': address,
      'city': city,
      'county': county,
      'notes': notes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ClientRecord.fromMap(Map<String, dynamic> map) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    final now = DateTime.now();
    List<ClientDepartment> parseDepartments(dynamic raw) {
      if (raw is! List) return const <ClientDepartment>[];
      return raw
          .whereType<Map>()
          .map((item) => ClientDepartment.fromMap(Map<String, dynamic>.from(item)))
          .where((item) => item.id.isNotEmpty || item.name.isNotEmpty)
          .toList(growable: false);
    }

    List<ClientContactPerson> parseContacts(dynamic raw) {
      if (raw is! List) return const <ClientContactPerson>[];
      return raw
          .whereType<Map>()
          .map(
            (item) => ClientContactPerson.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) => item.id.isNotEmpty || item.fullName.isNotEmpty)
          .toList(growable: false);
    }

    return ClientRecord(
      id: pick(const ['id', 'client_id', 'uid', 'key']),
      clientCode: pick(const ['client_code', 'code']),
      externalClientCode: pick(
        const ['external_client_code', 'externalCode', 'partner_client_code'],
      ),
      externalClientSource: pick(
        const [
          'external_client_source',
          'externalSource',
          'partner_source',
          'external_partner',
        ],
      ),
      type: ClientType.fromValue(pick(const ['type', 'client_type'])),
      name: pick(const ['name', 'company_name', 'client_name', 'nume']),
      contactPerson: pick(
        const ['contact_person', 'contact_name', 'person', 'persoana_contact'],
      ),
      phone: pick(const ['phone', 'telefon']),
      phone2: pick(const ['phone2', 'telefon2']),
      phone3: pick(const ['phone3', 'telefon3']),
      email: pick(const ['email']),
      cui: pick(const ['cui']),
      regCom: pick(const ['reg_com', 'trade_register']),
      iban: pick(const ['iban']),
      bank: pick(const ['bank', 'banca']),
      departments: parseDepartments(
        map['departments'] ?? map['client_departments'],
      ),
      contactPeople: parseContacts(
        map['contact_people'] ?? map['contactPeople'] ?? map['contacts'],
      ),
      address: pick(const ['address', 'adresa']),
      city: pick(const ['city', 'oras']),
      county: pick(const ['county', 'judet']),
      notes: pick(const ['notes', 'observatii']),
      isActive: map['is_active'] != false,
      createdAt:
          DateTime.tryParse((map['created_at'] ?? '').toString()) ?? now,
      updatedAt:
          DateTime.tryParse((map['updated_at'] ?? '').toString()) ?? now,
    );
  }
}
