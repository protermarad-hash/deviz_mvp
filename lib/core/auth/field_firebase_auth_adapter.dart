import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../cloud/firebase_collections.dart';
import 'field_auth_models.dart';

class FieldFirebaseAuthAdapter {
  FieldFirebaseAuthAdapter({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection(FirebaseCollections.users);

  static const String _forcedAdminEmail = 'proterm.arad@gmail.com';

  Future<FieldAuthSession?> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) return null;
    final userProfile = await ensureCloudProfileForFirebaseUser(user);
    return FieldAuthSession(
      userId: user.uid,
      email: user.email ?? email,
      role: userProfile?.role ?? FieldUserRole.employee,
      loggedInAt: DateTime.now(),
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<List<FieldAuthUser>> listUsers() async {
    final query = await _usersCollection.get();
    return query.docs
        .map(_fromUserDoc)
        .where((user) => user.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<FieldAuthUser?> loadUserByEmail(String email) {
    return loadUserProfile(email: email, firebaseUid: '');
  }

  Future<FieldAuthUser?> loadUserProfile({
    required String email,
    required String firebaseUid,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedUid = firebaseUid.trim();

    if (normalizedUid.isNotEmpty) {
      final byUid = await _usersCollection
          .where('firebase_uid', isEqualTo: normalizedUid)
          .limit(1)
          .get();
      if (byUid.docs.isNotEmpty) {
        return _fromUserDoc(byUid.docs.first);
      }
    }

    if (normalizedEmail.isEmpty) return null;

    final byEmail = await _usersCollection
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    if (byEmail.docs.isEmpty) return null;

    final doc = byEmail.docs.first;
    final data = doc.data();
    final existingUid = (data['firebase_uid'] ?? '').toString().trim();
    if (normalizedUid.isNotEmpty && existingUid.isEmpty) {
      await doc.reference.set(
        <String, dynamic>{
          'firebase_uid': normalizedUid,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );
      final patched = <String, dynamic>{...data, 'firebase_uid': normalizedUid};
      return _fromUserMap(patched, fallbackId: doc.id);
    }
    return _fromUserMap(data, fallbackId: doc.id);
  }

  Future<FieldAuthUser?> ensureCloudProfileForFirebaseUser(User user) async {
    final email = (user.email ?? '').trim().toLowerCase();
    final uid = user.uid.trim();
    final displayName = (user.displayName ?? '').trim();
    if (uid.isEmpty || email.isEmpty) {
      return null;
    }

    final forcedAdmin = email == _forcedAdminEmail;

    final byUid = await _usersCollection
        .where('firebase_uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (byUid.docs.isNotEmpty) {
      final doc = byUid.docs.first;
      final current = doc.data();
      final needsAdminUpdate = forcedAdmin &&
          ((current['role'] ?? '').toString().trim().toLowerCase() != 'admin' ||
              current['active'] == false);
      if (needsAdminUpdate) {
        await doc.reference.set(
          <String, dynamic>{
            'role': 'admin',
            'active': true,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          SetOptions(merge: true),
        );
      }
      final refreshed = <String, dynamic>{
        ...current,
        if (needsAdminUpdate) 'role': 'admin',
        if (needsAdminUpdate) 'active': true,
      };
      return _fromUserMap(refreshed, fallbackId: doc.id);
    }

    final byEmail = await _usersCollection
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (byEmail.docs.isNotEmpty) {
      final doc = byEmail.docs.first;
      final current = doc.data();
      final patch = <String, dynamic>{
        if ((current['firebase_uid'] ?? '').toString().trim().isEmpty)
          'firebase_uid': uid,
        if (forcedAdmin) 'role': 'admin',
        if (forcedAdmin) 'active': true,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (patch.isNotEmpty) {
        await doc.reference.set(patch, SetOptions(merge: true));
      }
      final refreshed = <String, dynamic>{
        ...current,
        ...patch,
      };
      return _fromUserMap(refreshed, fallbackId: doc.id);
    }

    final baseName =
        displayName.isNotEmpty ? displayName : email.split('@').first;
    final newPayload = <String, dynamic>{
      'id': uid,
      'name': baseName,
      'email': email,
      'role': forcedAdmin ? 'admin' : 'employee',
      'active': true,
      'firebase_uid': uid,
      'employee_id': '',
      'teamId': '',
      'phone': '',
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await _usersCollection.doc(uid).set(newPayload, SetOptions(merge: true));
    return _fromUserMap(newPayload, fallbackId: uid);
  }

  Future<void> upsertUser(FieldAuthUser user) async {
    await _firestore
        .collection(FirebaseCollections.users)
        .doc(user.id)
        .set(_userToCloudMap(user), SetOptions(merge: true));
  }

  Map<String, dynamic> _userToCloudMap(FieldAuthUser user) {
    return <String, dynamic>{
      'id': user.id,
      'name': user.name,
      'email': user.email.trim().toLowerCase(),
      'role': user.role.name,
      'active': user.active,
      'firebase_uid': user.id,
      'employee_id': user.employeeId,
      'teamId': user.teamId,
      'phone': user.phone,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  FieldAuthUser _fromUserDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return _fromUserMap(doc.data(), fallbackId: doc.id);
  }

  FieldAuthUser _fromUserMap(
    Map<String, dynamic> raw, {
    required String fallbackId,
  }) {
    final id = (raw['id'] ?? raw['firebase_uid'] ?? fallbackId).toString();
    return FieldAuthUser.fromMap(<String, dynamic>{
      ...raw,
      'id': id,
      'employee_id': (raw['employee_id'] ?? raw['employeeId'] ?? '').toString(),
      'team_id': (raw['team_id'] ?? raw['teamId'] ?? '').toString(),
      'password_hash': (raw['password_hash'] ?? '').toString(),
    });
  }
}
