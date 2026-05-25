import 'package:flutter/foundation.dart';

import '../auth_models.dart';
import 'app_role_policy.dart';
import 'field_auth_models.dart';
import 'field_auth_repository.dart';

class FieldAuthService extends ChangeNotifier {
  FieldAuthService(this._repository);

  final FieldAuthRepository _repository;

  FieldAuthSession? _session;
  FieldAuthUser? _currentUser;
  bool _loading = false;
  String? _lastError;

  FieldAuthSession? get session => _session;
  FieldAuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _session != null;
  bool get isLoading => _loading;
  String? get lastError => _lastError;

  FieldUserRole? get role => _session?.role;
  String? get userEmail => _session?.email;
  String? get userId => _session?.userId;
  String? get teamId => _currentUser?.teamId;

  /// Numele real al utilizatorului din Firestore (câmpul `name`).
  /// Dacă nu e disponibil, returnează null (nu email-ul derivat).
  String? get userName {
    final name = _currentUser?.name.trim() ?? '';
    return name.isNotEmpty ? name : null;
  }
  String get authSourceLabel => _repository.authSourceLabel;

  Future<void> restoreSession() async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      final dynamic restored = await _repository.loadSession();
      _session = _asSession(restored);
      _currentUser = await _resolveCurrentUser(_session);
    } catch (e) {
      _lastError = 'Nu am putut restaura sesiunea.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      final dynamic loginResult = await _repository.login(
        email: email,
        password: password,
      );
      final nextSession = _asSession(loginResult);
      if (nextSession == null) {
        _lastError = 'Email sau parolă invalidă.';
        _loading = false;
        notifyListeners();
        return false;
      }
      _session = nextSession;
      _currentUser = await _resolveCurrentUser(nextSession);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Autentificare eșuată.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      await _repository.logout();
      _session = null;
      _currentUser = null;
    } catch (e) {
      _lastError = 'Logout eșuat.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  bool canAccessAdmin() =>
      AppRolePolicy.resolve(fieldRole: role) == UserRole.admin;
  bool canAccessOffice() =>
      AppRolePolicy.canAccessOffice(AppRolePolicy.resolve(fieldRole: role));
  bool canAccessTeamLead() =>
      AppRolePolicy.canAccessTeamLead(AppRolePolicy.resolve(fieldRole: role));

  FieldAuthSession? _asSession(dynamic value) {
    if (value == null) return null;
    if (value is FieldAuthSession) return value;
    if (value is FieldAuthUser) {
      return FieldAuthSession(
        userId: value.id,
        email: value.email,
        role: value.role,
        loggedInAt: DateTime.now(),
      );
    }
    if (value is Map<String, dynamic>) {
      try {
        return FieldAuthSession.fromMap(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<FieldAuthUser?> _resolveCurrentUser(FieldAuthSession? session) async {
    if (session == null) return null;
    final users = await _repository.listUsers();
    for (final user in users) {
      if (user.id == session.userId) return user;
    }
    final normalizedEmail = session.email.trim().toLowerCase();
    for (final user in users) {
      if (user.email.trim().toLowerCase() == normalizedEmail) return user;
    }
    return FieldAuthUser(
      id: session.userId,
      name: normalizedEmail.isEmpty
          ? 'Utilizator'
          : normalizedEmail.split('@').first,
      email: session.email,
      role: session.role,
      active: true,
      passwordHash: '',
    );
  }
}
