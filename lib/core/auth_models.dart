enum UserRole {
  admin,
  birou,
  sefEchipa,
  tehnician,
}

extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.birou:
        return 'Birou';
      case UserRole.sefEchipa:
        return 'Sef echipa';
      case UserRole.tehnician:
        return 'Tehnician';
    }
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.role,
    this.email = '',
    this.isDemo = false,
  });

  final String id;
  final String displayName;
  final UserRole role;
  final String email;
  final bool isDemo;

  factory AppUser.localDemo({UserRole role = UserRole.admin}) {
    return AppUser(
      id: 'local-demo-user',
      displayName: 'Utilizator local',
      email: '',
      role: role,
      isDemo: true,
    );
  }

  AppUser copyWith({
    String? id,
    String? displayName,
    UserRole? role,
    String? email,
    bool? isDemo,
  }) {
    return AppUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      email: email ?? this.email,
      isDemo: isDemo ?? this.isDemo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'role': role.name,
      'email': email,
      'is_demo': isDemo,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: (map['id'] ?? '').toString(),
      displayName: (map['display_name'] ?? '').toString(),
      role: UserRole.values.firstWhere(
        (value) => value.name == (map['role'] ?? '').toString(),
        orElse: () => UserRole.birou,
      ),
      email: (map['email'] ?? '').toString(),
      isDemo: map['is_demo'] == true,
    );
  }
}
