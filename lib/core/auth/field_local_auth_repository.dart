import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'field_auth_models.dart';
import 'field_auth_repository.dart';

class FieldLocalAuthRepository implements FieldAuthRepository {
  static const String _usersKey = 'field_auth_users_v1';
  static const String _sessionKey = 'field_auth_session_v1';

  @override
  String get authSourceLabel => 'local';

  Future<void> ensureSeedUsers() async {
    final users = await listUsers();
    if (users.isNotEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final seeded = <FieldAuthUser>[
      FieldAuthUser(
        id: 'user-admin-$now',
        name: 'Admin local',
        email: 'admin@local.test',
        role: FieldUserRole.admin,
        active: true,
        passwordHash: hashPasswordForStorage('1234'),
      ),
    ];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _usersKey,
      jsonEncode(seeded.map((e) => e.toMap()).toList(growable: false)),
    );
  }

  @override
  Future<List<FieldAuthUser>> listUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usersKey);
    if (raw == null || raw.trim().isEmpty) return const <FieldAuthUser>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <FieldAuthUser>[];
    return decoded
        .map((e) => FieldAuthUser.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  @override
  Future<void> saveUser(FieldAuthUser user) async {
    final users = <FieldAuthUser>[...await listUsers()];
    final index = users.indexWhere((u) => u.id == user.id);
    if (index >= 0) {
      users[index] = user;
    } else {
      users.add(user);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _usersKey,
      jsonEncode(users.map((e) => e.toMap()).toList(growable: false)),
    );
  }

  @override
  Future<FieldAuthSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return FieldAuthSession.fromMap(Map<String, dynamic>.from(decoded));
  }

  @override
  Future<void> saveSession(FieldAuthSession? session) async {
    final prefs = await SharedPreferences.getInstance();
    if (session == null) {
      await prefs.remove(_sessionKey);
      return;
    }
    await prefs.setString(_sessionKey, jsonEncode(session.toMap()));
  }

  @override
  Future<FieldAuthUser?> login({
    required String email,
    required String password,
  }) async {
    await ensureSeedUsers();
    final users = await listUsers();
    final normalizedEmail = email.trim().toLowerCase();
    final hash = hashPasswordForStorage(password);
    for (final user in users) {
      if (!user.active) continue;
      if (user.email.trim().toLowerCase() != normalizedEmail) continue;
      if (user.passwordHash != hash) continue;

      await saveSession(
        FieldAuthSession(
          userId: user.id,
          email: user.email,
          role: user.role,
          loggedInAt: DateTime.now(),
        ),
      );
      return user;
    }
    return null;
  }

  @override
  Future<void> logout() async {
    await saveSession(null);
  }

  String hashPasswordForStorage(String value) {
    // Lightweight local hash placeholder for pilot usage.
    return base64Encode(utf8.encode(value));
  }
}
