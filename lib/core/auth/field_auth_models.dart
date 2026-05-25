enum FieldUserRole {
  admin,
  office,
  teamLead,
  employee;

  String get value {
    switch (this) {
      case FieldUserRole.admin:
        return 'admin';
      case FieldUserRole.office:
        return 'office';
      case FieldUserRole.teamLead:
        return 'team_lead';
      case FieldUserRole.employee:
        return 'employee';
    }
  }

  String get label {
    switch (this) {
      case FieldUserRole.admin:
        return 'admin';
      case FieldUserRole.office:
        return 'office';
      case FieldUserRole.teamLead:
        return 'sef echipa';
      case FieldUserRole.employee:
        return 'angajat';
    }
  }

  static FieldUserRole fromValue(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'admin':
        return FieldUserRole.admin;
      case 'office':
        return FieldUserRole.office;
      case 'team_lead':
      case 'sef_echipa':
      case 'sef echipa':
        return FieldUserRole.teamLead;
      case 'employee':
      case 'angajat':
      default:
        return FieldUserRole.employee;
    }
  }
}

class FieldAuthUser {
  const FieldAuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    this.employeeId = '',
    this.teamId = '',
    this.phone = '',
    this.passwordHash = '',
  });

  final String id;
  final String name;
  final String email;
  final FieldUserRole role;
  final bool active;
  final String employeeId;
  final String teamId;
  final String phone;
  final String passwordHash;

  FieldAuthUser copyWith({
    String? id,
    String? name,
    String? email,
    FieldUserRole? role,
    bool? active,
    String? employeeId,
    String? teamId,
    String? phone,
    String? passwordHash,
  }) {
    return FieldAuthUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      active: active ?? this.active,
      employeeId: employeeId ?? this.employeeId,
      teamId: teamId ?? this.teamId,
      phone: phone ?? this.phone,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'role': role.value,
      'active': active,
      'employee_id': employeeId,
      'team_id': teamId,
      'phone': phone,
      'password_hash': passwordHash,
    };
  }

  factory FieldAuthUser.fromMap(Map<String, dynamic> map) {
    return FieldAuthUser(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      role: FieldUserRole.fromValue(map['role']?.toString()),
      active: map['active'] != false,
      employeeId:
          (map['employee_id'] ?? map['employeeId'] ?? '').toString(),
      teamId: (map['team_id'] ?? map['teamId'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      passwordHash:
          (map['password_hash'] ?? map['passwordHash'] ?? '').toString(),
    );
  }
}

class FieldAuthSession {
  const FieldAuthSession({
    required this.userId,
    required this.email,
    required this.role,
    required this.loggedInAt,
  });

  final String userId;
  final String email;
  final FieldUserRole role;
  final DateTime loggedInAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'user_id': userId,
      'email': email,
      'role': role.value,
      'logged_in_at': loggedInAt.toIso8601String(),
    };
  }

  factory FieldAuthSession.fromMap(Map<String, dynamic> map) {
    return FieldAuthSession(
      userId: (map['user_id'] ?? map['userId'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      role: FieldUserRole.fromValue(map['role']?.toString()),
      loggedInAt: DateTime.tryParse(
            (map['logged_in_at'] ?? map['loggedInAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }
}
