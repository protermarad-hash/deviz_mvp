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
      // Normalizează forced-admin chiar și pe calea locală: o sesiune locală
      // coruptă cu 'employee' (dintr-un bug vechi de restore) NU trebuie să
      // rămână pentru contul admin garantat prin politică.
      return _normalizeForcedAdmin(await _localRepository.loadSession());
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      _authSourceLabel = 'local';
      return _normalizeForcedAdmin(await _localRepository.loadSession());
    }

    final email = (firebaseUser.email ?? '').trim();

    // (a) Încearcă să confirmi profilul din cloud (timeout scurt — pe
    // desktop/offline Firestore poate bloca indefinit).
    final profile = await _tryLoadCloudProfile(
      firebaseUser,
      const Duration(seconds: 8),
    );
    if (profile != null) {
      final session = FieldAuthSession(
        userId: firebaseUser.uid,
        email: email,
        role: profile.role,
        loggedInAt: DateTime.now(),
      );
      await _localRepository.saveSession(session);
      await _ensureLocalProjection(session: session, profile: profile);
      _authSourceLabel = 'cloud';
      return session;
    }

    // Fetch eșuat/timeout. NU retrograda silențios utilizatorul la rolul cel
    // mai restrictiv (employee) — o problemă temporară de rețea NU înseamnă
    // că rolul s-a schimbat.

    // (b) Există o sesiune locală anterioară pentru ACELAȘI utilizator →
    // păstrează rolul confirmat anterior. EXCEPȚIE: pentru contul admin
    // garantat prin politică, ignoră complet previous.role (poate fi corupt cu
    // 'employee' dintr-un bug vechi de restore) și forțează admin.
    final previous = await _localRepository.loadSession();
    if (previous != null && _isSameUser(previous, firebaseUser, email)) {
      final effectiveEmail = email.isEmpty ? previous.email : email;
      final isForcedAdmin = effectiveEmail.trim().toLowerCase() ==
          FieldFirebaseAuthAdapter.forcedAdminEmail;
      final resolvedRole =
          isForcedAdmin ? FieldUserRole.admin : previous.role;
      final preserved = FieldAuthSession(
        userId: firebaseUser.uid,
        email: effectiveEmail,
        role: resolvedRole,
        loggedInAt: DateTime.now(),
      );
      await _localRepository.saveSession(preserved);
      _authSourceLabel = 'local';
      return preserved;
    }

    // (c) Nicio sesiune locală anterioară pentru acest utilizator.
    // Mai încearcă O SINGURĂ dată, cu timeout mai mare, înainte de a ceda.
    final retryProfile = await _tryLoadCloudProfile(
      firebaseUser,
      const Duration(seconds: 15),
    );
    if (retryProfile != null) {
      final session = FieldAuthSession(
        userId: firebaseUser.uid,
        email: email,
        role: retryProfile.role,
        loggedInAt: DateTime.now(),
      );
      await _localRepository.saveSession(session);
      await _ensureLocalProjection(session: session, profile: retryProfile);
      _authSourceLabel = 'cloud';
      return session;
    }

    // Plasă de siguranță suplimentară pentru contul admin garantat prin
    // politică: rolul lui e admin indiferent de starea temporară a cloud-ului.
    // (Fix-ul general de mai sus protejează deja pe oricine — asta e doar un
    // strat în plus pentru acest cont specific.)
    if (email.trim().toLowerCase() ==
        FieldFirebaseAuthAdapter.forcedAdminEmail) {
      final session = FieldAuthSession(
        userId: firebaseUser.uid,
        email: email,
        role: FieldUserRole.admin,
        loggedInAt: DateTime.now(),
      );
      await _localRepository.saveSession(session);
      _authSourceLabel = 'cloud';
      return session;
    }

    // Profil neconfirmat ȘI fără sesiune anterioară pentru acest utilizator.
    // NU inventa un rol employee și NU salva o sesiune degradată local.
    // Returnează null → aplicația tratează asta ca sesiune nerestaurată
    // (ecran de login / reîncercare), în loc de o sesiune falsă.
    _authSourceLabel = 'local';
    return null;
  }

  /// Ridică rolul la admin pentru contul admin garantat prin politică,
  /// indiferent de rolul salvat (posibil corupt din bug-uri vechi de restore)
  /// și indiferent de calea prin care s-a obținut sesiunea (cache local etc.).
  FieldAuthSession? _normalizeForcedAdmin(FieldAuthSession? session) {
    if (session == null) return null;
    final isForcedAdmin = session.email.trim().toLowerCase() ==
        FieldFirebaseAuthAdapter.forcedAdminEmail;
    if (isForcedAdmin && session.role != FieldUserRole.admin) {
      return FieldAuthSession(
        userId: session.userId,
        email: session.email,
        role: FieldUserRole.admin,
        loggedInAt: session.loggedInAt,
      );
    }
    return session;
  }

  /// Încearcă să încarce profilul din cloud cu timeout; înghite orice eroare
  /// tehnică și returnează null (nu aruncă), pentru a permite fallback-ul
  /// controlat din `loadSession`.
  Future<FieldAuthUser?> _tryLoadCloudProfile(
    User firebaseUser,
    Duration timeout,
  ) async {
    try {
      return await _firebaseAdapter
          .ensureCloudProfileForFirebaseUser(firebaseUser)
          .timeout(timeout, onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  /// True dacă sesiunea locală salvată aparține aceluiași utilizator Firebase
  /// (potrivire pe uid sau, în lipsă, pe email normalizat).
  bool _isSameUser(
    FieldAuthSession session,
    User firebaseUser,
    String email,
  ) {
    final uid = firebaseUser.uid.trim();
    if (uid.isNotEmpty && session.userId.trim() == uid) {
      return true;
    }
    final normalized = email.trim().toLowerCase();
    if (normalized.isNotEmpty &&
        session.email.trim().toLowerCase() == normalized) {
      return true;
    }
    return false;
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

