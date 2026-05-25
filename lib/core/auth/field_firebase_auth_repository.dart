import 'package:firebase_auth/firebase_auth.dart';

import '../cloud/firebase_bootstrap.dart';
import 'field_auth_models.dart';
import 'field_auth_repository.dart';
import 'field_firebase_auth_adapter.dart';
import 'field_local_auth_repository.dart';

class FieldFirebaseAuthRepository implements FieldAuthRepository {
  FieldFirebaseAuthRepository({
    FieldFirebaseAuthAdapter? firebaseAdapter,
    FieldLocalAuthRepository? localRepository,
  })  : _firebaseAdapter = firebaseAdapter ?? FieldFirebaseAuthAdapter(),
        _localRepository = localRepository ?? FieldLocalAuthRepository();

  final FieldFirebaseAuthAdapter _firebaseAdapter;
  final FieldLocalAuthRepository _localRepository;

  String _authSourceLabel = 'cloud';

  @override
  String get authSourceLabel => _authSourceLabel;

  bool get _cloudReady => FirebaseBootstrap.isInitialized;

  @override
  Future<List<FieldAuthUser>> listUsers() async {
    if (!_cloudReady) {
      _authSourceLabel = 'local';
      return _localRepository.listUsers();
    }
    try {
      final users = await _firebaseAdapter.listUsers().timeout(
            const Duration(seconds: 10),
            onTimeout: () => <FieldAuthUser>[],
          );
      if (users.isEmpty) {
        _authSourceLabel = 'local';
        return _localRepository.listUsers();
      }
      _authSourceLabel = 'cloud';
      for (final user in users) {
        await _localRepository.saveUser(user);
      }
      return users;
    } catch (_) {
      _authSourceLabel = 'local';
      return _localRepository.listUsers();
    }
  }

  @override
  Future<void> saveUser(FieldAuthUser user) async {
    await _localRepository.saveUser(user);
    if (!_cloudReady) return;
    try {
      await _firebaseAdapter.upsertUser(user);
    } catch (_) {
      // Keep local as stable source for admin/user management in pilot mode.
    }
  }

  @override
  Future<FieldAuthSession?> loadSession() async {
    if (!_cloudReady) {
      _authSourceLabel = 'local';
      return _localRepository.loadSession();
    }

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final email = (firebaseUser.email ?? '').trim();
        // Timeout de 8s — pe desktop/offline Firestore poate bloca indefinit.
        final profile = await _firebaseAdapter
            .ensureCloudProfileForFirebaseUser(firebaseUser)
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () => null,
            );
        final session = FieldAuthSession(
          userId: firebaseUser.uid,
          email: email,
          role: profile?.role ?? FieldUserRole.employee,
          loggedInAt: DateTime.now(),
        );
        await _localRepository.saveSession(session);
        await _ensureLocalProjection(session: session, profile: profile);
        _authSourceLabel = 'cloud';
        return session;
      }
    } catch (_) {
      // fallback below
    }

    _authSourceLabel = 'local';
    return _localRepository.loadSession();
  }

  @override
  Future<void> saveSession(FieldAuthSession? session) async {
    await _localRepository.saveSession(session);
  }

  @override
  Future<FieldAuthUser?> login({
    required String email,
    required String password,
  }) async {
    await _localRepository.ensureSeedUsers();

    if (_cloudReady) {
      try {
        final session = await _firebaseAdapter.signIn(
          email: email,
          password: password,
        );
        if (session != null) {
          await _localRepository.saveSession(session);
          final firebaseUser = FirebaseAuth.instance.currentUser;
          final profile = firebaseUser == null
              ? await _firebaseAdapter.loadUserProfile(
                  email: session.email,
                  firebaseUid: session.userId,
                )
              : await _firebaseAdapter.ensureCloudProfileForFirebaseUser(
                  firebaseUser,
                );
          final projected = _projectUserFromCloud(
            session: session,
            profile: profile,
          );
          await _localRepository.saveUser(projected);
          _authSourceLabel = 'cloud';
          return projected;
        }
        _authSourceLabel = 'cloud';
        return null;
      } on FirebaseAuthException catch (error) {
        if (!_isTechnicalFirebaseError(error)) {
          _authSourceLabel = 'cloud';
          return null;
        }
      } catch (_) {
        // fallback local for technical failures
      }
    }

    final localUser = await _localRepository.login(
      email: email,
      password: password,
    );
    _authSourceLabel = 'local';
    return localUser;
  }

  @override
  Future<void> logout() async {
    if (_cloudReady) {
      try {
        await _firebaseAdapter.signOut();
      } catch (_) {
        // keep local logout as authoritative fallback
      }
    }
    await _localRepository.logout();
    _authSourceLabel = 'local';
  }

  bool _isTechnicalFirebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'network-request-failed':
      case 'unknown':
      case 'internal-error':
      case 'too-many-requests':
      case 'web-context-canceled':
        return true;
      default:
        return false;
    }
  }

  FieldAuthUser _projectUserFromCloud({
    required FieldAuthSession session,
    required FieldAuthUser? profile,
  }) {
    if (profile != null) {
      return profile.copyWith(
        id: profile.id.trim().isEmpty ? session.userId : profile.id,
        email: session.email.trim().isEmpty ? profile.email : session.email,
        active: true,
      );
    }
    final defaultName = session.email.trim().isEmpty
        ? 'Utilizator cloud'
        : session.email.split('@').first;
    return FieldAuthUser(
      id: session.userId,
      name: defaultName,
      email: session.email,
      role: session.role,
      active: true,
      passwordHash: '',
    );
  }

  Future<void> _ensureLocalProjection({
    required FieldAuthSession session,
    required FieldAuthUser? profile,
  }) async {
    final projected = _projectUserFromCloud(session: session, profile: profile);
    await _localRepository.saveUser(projected);
  }
}

