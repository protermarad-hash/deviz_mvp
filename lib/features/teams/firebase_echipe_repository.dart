import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import '../master/master_local_store.dart';
import 'echipe_cloud_repository.dart';

class FirebaseEchipeRepository implements EchipeCloudRepository {
  FirebaseEchipeRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.teams);

  @override
  Future<void> deleteTeam(String teamId) async {
    final id = teamId.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).delete();
  }

  @override
  Future<List<MasterTeam>> listTeams() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => MasterTeam.fromMap(_normalizeMap(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> upsertTeam(MasterTeam team) async {
    final id = team.id.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).set(
      <String, dynamic>{
        ...team.toMap(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Stream<List<MasterTeam>> watchTeams() {
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => MasterTeam.fromMap(_normalizeMap(doc.data())))
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false);
    });
  }

  Map<String, dynamic> _normalizeMap(Map<String, dynamic> raw) {
    final membersRaw =
        raw['memberIds'] ?? raw['member_ids'] ?? const <dynamic>[];
    final members = membersRaw is List
        ? membersRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'name': (raw['name'] ?? '').toString(),
      'notes': (raw['notes'] ?? '').toString(),
      'memberIds': members,
      'colorValue': _parseColorValue(
        raw['colorValue'] ?? raw['color_value'] ?? raw['teamColor'],
      ),
    };
  }

  int _parseColorValue(Object? raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    final text = raw.toString().trim();
    if (text.isEmpty) return 0;
    return int.tryParse(text) ?? 0;
  }
}
