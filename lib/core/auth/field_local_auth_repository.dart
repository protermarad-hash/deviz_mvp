import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'field_auth_models.dart';
import 'field_auth_repository.dart';
import 'local_password_hasher.dart';

class FieldLocalAuthRepository implements FieldAuthRepository {
  /// [seedDefaultAdmin]: creează contul local de dezvoltare `admin@local.test`
  /// când lista locală e goală. Implicit DOAR în build-urile non-release —
  /// o instalare release nu primește niciodată un administrator cu parolă
  /// cunoscută (parola de dezvoltare e definită în cod).
  FieldLocalAuthRepository({
    bool? seedDefaultAdmin,
    LocalPasswordHasher? hasher,
  })  : _seedDefaultAdmin = seedDefaultAdmin ?? !kReleaseMode,
        _hasher = hasher ?? LocalPasswordHasher();

  static const String _usersKey = 'field_auth_users_v1';
  static const String _sessionKey = 'field_auth_session_v1';
  static const String _mustChangeKey = 'field_auth_must_change_password_v1';
  static const int minPasswordLength = 8;
  static const String defaultAdminEmail = 'admin@local.test';

  /// Parola contului de dezvoltare (creat doar în build-uri non-release).
  /// Dispozitivele care au rulat versiuni mai vechi o pot avea încă pe
  /// `admin@local.test`; în release, folosirea ei impune schimbarea parolei.
  @visibleForTesting
  static const String devSeedPassword = '1234';

  final bool _seedDefaultAdmin;
  final LocalPasswordHasher _hasher;

  @override
  String get authSourceLabel => 'local';

  Future<void> ensureSeedUsers() async {
    if (!_seedDefaultAdmin) return;
    final users = await listUsers();
    if (users.isNotEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final seeded = <FieldAuthUser>[
      FieldAuthUser(
        id: 'user-admin-$now',
        name: 'Admin local',
        email: defaultAdminEmail,
        role: FieldUserRole.admin,
        active: true,
        passwordHash: hashPasswordForStorage(devSeedPassword),
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
    if (password.isEmpty) return null;
    final users = await listUsers();
    final normalizedEmail = email.trim().toLowerCase();
    for (final user in users) {
      if (!user.active) continue;
      if (user.email.trim().toLowerCase() != normalizedEmail) continue;
      final stored = user.passwordHash;
      final legacy = LocalPasswordHasher.isLegacy(stored);
      if (!await _verifyAsync(password, stored)) continue;

      // Migrare transparentă: formatul vechi (base64 reversibil) sau
      // parametri mai slabi sunt înlocuiți cu PBKDF2 la primul login reușit.
      var authenticated = user;
      if (legacy || _hasher.needsRehash(stored)) {
        authenticated =
            user.copyWith(passwordHash: await _hasher.hashAsync(password));
        await saveUser(authenticated);
      }

      // Contul de dezvoltare rămas din versiuni vechi, folosit în release cu
      // parola publică din cod: accesul NU este blocat (parola rămâne
      // valabilă), dar aplicația cere schimbarea ei înainte de a continua.
      if (!_seedDefaultAdmin &&
          authenticated.email.trim().toLowerCase() == defaultAdminEmail &&
          password == devSeedPassword) {
        await _setMustChange(authenticated.id, true);
      }

      await saveSession(
        FieldAuthSession(
          userId: authenticated.id,
          email: authenticated.email,
          role: authenticated.role,
          loggedInAt: DateTime.now(),
        ),
      );
      return authenticated;
    }
    return null;
  }

  /// Verificare cu PBKDF2 în afara firului UI (formatul vechi e instantaneu).
  Future<bool> _verifyAsync(String password, String stored) async =>
      LocalPasswordHasher.isLegacy(stored)
          ? LocalPasswordHasher.verifyLegacy(password, stored)
          : await _hasher.verifyAsync(password, stored);

  Future<Set<String>> _mustChangeIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_mustChangeKey) ?? const <String>[]).toSet();
  }

  Future<void> _setMustChange(String userId, bool value) async {
    final ids = await _mustChangeIds();
    if (value ? !ids.add(userId) : !ids.remove(userId)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_mustChangeKey, ids.toList(growable: false));
  }

  @override
  Future<bool> mustChangePassword(String userId) async =>
      (await _mustChangeIds()).contains(userId);

  @override
  Future<String?> changeLocalPassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final users = await listUsers();
    final index = users.indexWhere((u) => u.id == userId && u.active);
    if (index < 0) return 'Utilizatorul nu există sau este inactiv.';
    final user = users[index];
    if (!await _verifyAsync(currentPassword, user.passwordHash)) {
      return 'Parola curentă este greșită.';
    }
    if (newPassword.length < minPasswordLength) {
      return 'Parola nouă trebuie să aibă cel puțin $minPasswordLength caractere.';
    }
    if (newPassword == currentPassword || newPassword == devSeedPassword) {
      return 'Alege o parolă nouă, diferită de cea curentă.';
    }
    await saveUser(
        user.copyWith(passwordHash: await _hasher.hashAsync(newPassword)));
    await _setMustChange(userId, false);
    return null;
  }

  @override
  Future<void> logout() async {
    await saveSession(null);
  }

  /// Hash PBKDF2 pentru o parolă locală nouă (vezi [LocalPasswordHasher]).
  String hashPasswordForStorage(String value) => _hasher.hash(value);
}
