// Control de concurență pentru documentele sincronizate (clienți, oferte,
// lucrări): revizii confirmate de server + scrieri condiționate în tranzacție.
//
// Problema (demonstrată 15.10.2026): scrierile cloud erau oarbe
// (`set(merge: true)`), iar `updated_at` era restampilat la momentul trimiterii.
// O editare veche, trimisă târziu de pe dispozitivul A, suprascria silențios
// versiunea mai nouă salvată între timp de dispozitivul B.
//
// Modelul:
// - fiecare document primește `_rev` (întreg), incrementat DOAR de o scriere
//   condiționată, în tranzacție, deci confirmat de server;
// - fiecare dispozitiv ține, per entitate, „baza” editării locale: revizia și
//   amprenta conținutului versiunii de server pe care s-a pornit editarea;
// - o scriere reușește doar dacă serverul este încă exact la bază (revizie ȘI
//   amprentă). Amprenta detectează și scrierile aplicațiilor vechi
//   (113/118/119), care nu modifică `_rev`;
// - dacă serverul are deja exact conținutul local, scrierea e considerată
//   aplicată (reîncercare după confirmare pierdută) — idempotent;
// - altfel este CONFLICT: nu se scrie nimic, ambele variante se păstrează
//   (versiunea locală rămâne local, iar perechea local/server se salvează în
//   [SyncConflictStore]); nu se șterge automat nicio modificare locală.
// Ordinea NU se stabilește după `updated_at` (ceasuri diferite, restampilare).
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_sync_models.dart';
import 'keyed_mutex.dart';

/// Blocare comună per tip de entitate: îmbinarea cloud → local și perechea
/// „salvare locală + coadă” nu se intercalează. Altfel o îmbinare putea citi
/// entitatea ca neprotejată (încă fără element în coadă) și suprascrie local
/// editarea abia salvată. Reentrantă.
Future<T> runEntitySyncLocked<T>(CloudEntityType type, Future<T> Function() body) =>
    KeyedMutex.run('entity-sync:${type.name}', body);

const String kRevField = '_rev';
const String kRevWriterField = '_rev_writer';

/// Ora serverului la scrierea condiționată. Un document al cărui `updateTime`
/// (metadata Firestore) este mai nou decât `_rev_at` a fost modificat fără
/// revizie (aplicație veche sau consolă): semnalul de monitorizare pentru M2.
const String kRevAtField = '_rev_at';

/// Câmpuri care nu fac parte din conținut (metadate, ștampile de timp care pot
/// fi rescrise de versiuni vechi la fiecare trimitere).
bool _isVolatileKey(String key) {
  if (key == kRevField || key == kRevWriterField || key == kRevAtField) return true;
  final k = key.toLowerCase();
  return k == 'updated_at' ||
      k == 'updatedat' ||
      k == 'synced_at' ||
      k == 'last_synced_at' ||
      k == 'details_updated_at' ||
      k == 'detailsupdatedat';
}

Object? _canonical(Object? value) {
  if (value == null) return null;
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    final out = <String, Object?>{};
    for (final k in keys) {
      final v = _canonical(value[k]);
      if (v != null) out[k] = v;
    }
    return out;
  }
  if (value is Iterable) return value.map(_canonical).toList();
  if (value is num) {
    // Firestore poate întoarce 2 ca 2.0 sau invers: normalizăm.
    final d = value.toDouble();
    return d == d.truncateToDouble() && d.abs() < 1e15 ? d.toInt() : d;
  }
  if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is bool || value is String) return value;
  return value.toString();
}

/// Amprenta conținutului: SHA-256 peste JSON canonic, doar pentru [keys]
/// (câmpurile pe care le scrie versiunea curentă), fără câmpurile volatile.
/// Restrângerea la [keys] evită conflicte false din câmpuri pe care doar alte
/// versiuni le scriu.
String contentFingerprint(Map<String, dynamic> data, Iterable<String> keys) {
  final selected = <String, Object?>{};
  for (final k in keys) {
    if (_isVolatileKey(k)) continue;
    final v = _canonical(data[k]);
    if (v != null) selected[k] = v;
  }
  final json = jsonEncode(_canonical(selected));
  return sha256.convert(utf8.encode(json)).toString();
}

int revisionOf(Map<String, dynamic>? data) {
  final raw = data?[kRevField];
  return raw is num ? raw.toInt() : 0;
}

class RevisionBase {
  const RevisionBase({required this.rev, required this.fingerprint, this.ownWrite = false});
  final int rev;
  final String fingerprint;

  /// Versiunea a fost scrisă de ACEST dispozitiv (scriere condiționată proprie
  /// sau citită de pe server cu `_rev_writer` propriu).
  final bool ownWrite;

  Map<String, dynamic> toMap() => {'rev': rev, 'fp': fingerprint, if (ownWrite) 'own': true};
  static RevisionBase? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final rev = raw['rev'];
    final fp = raw['fp'];
    if (rev is! num || fp is! String || fp.isEmpty) return null;
    return RevisionBase(rev: rev.toInt(), fingerprint: fp, ownWrite: raw['own'] == true);
  }
}

String _entityKey(CloudEntityType type, String id) => '${type.name}:$id';

/// Baza (revizie + amprentă) a ultimei versiuni de server cunoscute per entitate.
class RevisionBaseStore {
  /// [namespace] doar pentru teste (mai multe „dispozitive” în același proces).
  RevisionBaseStore({String namespace = ''})
      : _key = namespace.isEmpty ? 'sync_revision_base_v1' : 'sync_revision_base_v1_$namespace';
  final String _key;

  Future<Map<String, dynamic>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String get _initKey => '${_key}_init';

  /// Prima îmbinare cu serverul a avut loc pe această instalare (RC 120). Înainte
  /// de ea nu există baze, deci „fără bază” NU înseamnă „niciodată trimis”.
  Future<bool> isInitialized(CloudEntityType type) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_initKey) ?? const <String>[]).contains(type.name);
  }

  Future<void> markInitialized(CloudEntityType type) => KeyedMutex.run(_initKey, () async {
        final prefs = await SharedPreferences.getInstance();
        final done = {...?prefs.getStringList(_initKey), type.name};
        await prefs.setStringList(_initKey, done.toList()..sort());
      });

  /// Entitățile pentru care există o bază (au fost văzute pe server).
  Future<Set<String>> idsWithBase(CloudEntityType type) async {
    final prefix = '${type.name}:';
    return (await _read())
        .keys
        .where((k) => k.startsWith(prefix))
        .map((k) => k.substring(prefix.length))
        .toSet();
  }

  Future<RevisionBase?> get(CloudEntityType type, String id) async =>
      RevisionBase.fromMap((await _read())[_entityKey(type, id)]);

  Future<T> _locked<T>(Future<T> Function() body) => KeyedMutex.run(_key, body);

  Future<void> set(CloudEntityType type, String id, RevisionBase base) => _locked(() async {
    final all = await _read();
    all[_entityKey(type, id)] = base.toMap();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
  });

  /// Bazele din citiri de server (apelantul exclude entitățile protejate și
  /// rulează sub `runEntitySyncLocked`, ca o salvare + coadă să nu se intercaleze).
  Future<void> setMany(CloudEntityType type, Map<String, RevisionBase> byId) => _locked(() async {
    if (byId.isEmpty) return;
    final all = await _read();
    byId.forEach((id, base) => all[_entityKey(type, id)] = base.toMap());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
  });

  Future<void> remove(CloudEntityType type, String id) => _locked(() async {
    final all = await _read();
    if (all.remove(_entityKey(type, id)) == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
  });
}

/// Variantele din conflict se salvează local ca JSON. Documentele de server pot
/// conține `Timestamp`, `GeoPoint`, referințe sau `FieldValue`, pe care
/// `jsonEncode` le refuză: fără conversie, salvarea conflictului ar eșua.
Object? _jsonSafe(Object? value) {
  if (value == null || value is bool || value is String) return value;
  if (value is num) return value.isFinite ? value : value.toString();
  if (value is Map) return {for (final e in value.entries) e.key.toString(): _jsonSafe(e.value)};
  if (value is Iterable) return value.map(_jsonSafe).toList();
  if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
  if (value is DateTime) return value.toUtc().toIso8601String();
  return value.toString();
}

/// Prima îmbinare după actualizare: o înregistrare doar-locală, neprotejată, poate
/// fi „niciodată trimisă” SAU ștearsă pe alt dispozitiv înainte de actualizare.
/// Nu se poate distinge, deci NU se încarcă automat (ar readuce la viață o
/// ștergere) și NU se șterge: rămâne local, cu un conflict `unknown_on_upgrade`.
Future<void> parkUnknownOnUpgrade(
  CloudEntityType type,
  String id,
  Map<String, dynamic> localPayload, {
  SyncConflictStore? store,
}) =>
    (store ?? SyncConflictStore()).add(SyncConflict(
      entityType: type,
      entityId: id,
      kind: 'unknown_on_upgrade',
      localPayload: localPayload,
      serverPayload: null,
      baseRev: null,
      serverRev: null,
      detectedAt: DateTime.now(),
    ));

/// Un conflict păstrat: varianta locală și cea de server, fără ștergere automată.
class SyncConflict {
  SyncConflict({
    required this.entityType,
    required this.entityId,
    required this.kind,
    required this.localPayload,
    required this.serverPayload,
    required this.baseRev,
    required this.serverRev,
    required this.detectedAt,
  });

  final CloudEntityType entityType;
  final String entityId;

  /// `concurrent_edit`, `deleted_remotely`, `delete_vs_remote_edit`,
  /// `retry_exhausted`.
  final String kind;
  final Map<String, dynamic>? localPayload;
  final Map<String, dynamic>? serverPayload;
  final int? baseRev;
  final int? serverRev;
  final DateTime detectedAt;

  Map<String, dynamic> toMap() => {
        'entity_type': entityType.name,
        'entity_id': entityId,
        'kind': kind,
        'local_payload': _jsonSafe(localPayload),
        'server_payload': _jsonSafe(serverPayload),
        'base_rev': baseRev,
        'server_rev': serverRev,
        'detected_at': detectedAt.toIso8601String(),
      };

  static SyncConflict? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final type = CloudEntityType.values
        .where((t) => t.name == raw['entity_type'])
        .firstOrNull;
    final id = (raw['entity_id'] ?? '').toString();
    if (type == null || id.isEmpty) return null;
    Map<String, dynamic>? asMap(Object? v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;
    return SyncConflict(
      entityType: type,
      entityId: id,
      kind: (raw['kind'] ?? 'concurrent_edit').toString(),
      localPayload: asMap(raw['local_payload']),
      serverPayload: asMap(raw['server_payload']),
      baseRev: (raw['base_rev'] as num?)?.toInt(),
      serverRev: (raw['server_rev'] as num?)?.toInt(),
      detectedAt: DateTime.tryParse((raw['detected_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

/// Conflicte deschise. Un singur conflict per entitate (cel mai recent payload
/// local îl înlocuiește pe cel anterior; versiunea de server rămâne cea văzută).
class SyncConflictStore {
  /// [namespace] doar pentru teste (mai multe „dispozitive” în același proces).
  SyncConflictStore({String namespace = ''})
      : _isDefault = namespace.isEmpty,
        _key = namespace.isEmpty ? 'sync_conflicts_v1' : 'sync_conflicts_v1_$namespace',
        _archiveKey =
            namespace.isEmpty ? 'sync_conflicts_archive_v1' : 'sync_conflicts_archive_v1_$namespace';
  final String _key;
  final bool _isDefault;

  /// Numărul conflictelor deschise pe acest dispozitiv (indicatorul din aplicație).
  /// Un conflict = o modificare locală care NU a ajuns pe server și nu se mai
  /// reîncearcă automat (spre deosebire de o eroare temporară din coadă).
  static final ValueNotifier<int> openCount = ValueNotifier<int>(0);

  /// La pornire: încarcă numărul conflictelor persistate.
  static Future<void> refreshOpenCount() async {
    openCount.value = (await SyncConflictStore().listOpen()).length;
  }

  Future<void> _publish(int count) async {
    if (_isDefault) openCount.value = count;
  }

  /// Arhivă doar-adăugare: un conflict înlocuit (alt conflict pe aceeași entitate)
  /// sau rezolvat nu se șterge, se mută aici cu ambele variante.
  final String _archiveKey;

  Future<List<Map<String, dynamic>>> listArchived() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_archiveKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _archive(Iterable<SyncConflict> items, String reason) =>
      KeyedMutex.run(_archiveKey, () => _archiveUnlocked(items.toList(), reason));

  Future<void> _archiveUnlocked(List<SyncConflict> items, String reason) async {
    if (items.isEmpty) return;
    final all = [...await listArchived()];
    final at = DateTime.now().toIso8601String();
    for (final c in items) {
      all.add({...c.toMap(), 'archived_reason': reason, 'archived_at': at});
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_archiveKey, jsonEncode(all));
  }

  Future<List<SyncConflict>> listOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.map(SyncConflict.fromMap).whereType<SyncConflict>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Set<String>> openEntityIds(CloudEntityType type) async =>
      (await listOpen()).where((c) => c.entityType == type).map((c) => c.entityId).toSet();

  Future<void> add(SyncConflict conflict) => KeyedMutex.run(_key, () async {
    final all = [...await listOpen()];
    bool same(SyncConflict c) => c.entityType == conflict.entityType && c.entityId == conflict.entityId;
    await _archive(all.where(same), 'replaced');
    all
      ..removeWhere(same)
      ..add(conflict);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all.map((c) => c.toMap()).toList()));
    await _publish(all.length);
    debugPrint('[Sync] CONFLICT ${conflict.kind} ${conflict.entityType.name}:${conflict.entityId} '
        'baza=${conflict.baseRev} server=${conflict.serverRev} (ambele variante pastrate)');
  });

  Future<void> resolve(CloudEntityType type, String id, {String resolution = 'resolved'}) =>
      KeyedMutex.run(_key, () async {
    final all = [...await listOpen()];
    bool same(SyncConflict c) => c.entityType == type && c.entityId == id;
    await _archive(all.where(same), resolution);
    all.removeWhere(same);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all.map((c) => c.toMap()).toList()));
    await _publish(all.length);
  });
}

/// Aruncată de scrierile condiționate la conflict, DUPĂ ce conflictul a fost
/// salvat. Coada offline nu o reîncearcă orb.
class RevisionConflictException implements Exception {
  RevisionConflictException(this.conflict);
  final SyncConflict conflict;
  @override
  String toString() =>
      'RevisionConflictException(${conflict.kind} ${conflict.entityType.name}:${conflict.entityId})';
}

enum ConditionalWriteOutcome { written, alreadyApplied }

/// Operațiile unei tranzacții (Firestore sau un server fals în teste).
abstract class RevisionTx {
  Future<Map<String, dynamic>?> get(String collection, String id);
  void set(String collection, String id, Map<String, dynamic> data);
  void delete(String collection, String id);
}

abstract class RevisionTransport {
  Future<T> run<T>(Future<T> Function(RevisionTx tx) body);
}

class FirestoreRevisionTransport implements RevisionTransport {
  FirestoreRevisionTransport({FirebaseFirestore? firestore, this.timeout = const Duration(seconds: 10)})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Duration timeout;

  /// Doar QA: rulează între citirea de pe server și scriere (Windows), pentru a
  /// reproduce o scriere concurentă exact în fereastra neatomică. Null în producție.
  @visibleForTesting
  static Future<void> Function(String collection, String id)? debugAfterServerRead;

  @override
  Future<T> run<T>(Future<T> Function(RevisionTx tx) body) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return _runReadCheckWrite(body);
    }
    return _firestore
        .runTransaction<T>((t) => body(_FirestoreTx(_firestore, t)), timeout: timeout)
        .timeout(timeout + const Duration(seconds: 5));
  }

  /// Windows: tranzacțiile pluginului cloud_firestore 5.6.12 (SDK C++) opresc
  /// procesul cu o excepție C++ necapturată (0xE06D7363, QA izolat 15.10.2026).
  /// Aceeași verificare, fără tranzacție: citire DE PE SERVER, decizie, scriere.
  /// Nu este atomică (fereastră de concurență de ordinul sutelor de ms, nu ore);
  /// atomicitatea completă necesită regulile Firestore cu revizie obligatorie.
  Future<T> _runReadCheckWrite<T>(Future<T> Function(RevisionTx tx) body) async {
    final tx = _ReadCheckWriteTx(_firestore, timeout);
    final result = await body(tx);
    await tx.commit();
    return result;
  }
}

class _ReadCheckWriteTx implements RevisionTx {
  _ReadCheckWriteTx(this._db, this._timeout);
  final FirebaseFirestore _db;
  final Duration _timeout;
  final List<Future<void> Function()> _ops = [];

  @override
  Future<Map<String, dynamic>?> get(String collection, String id) async {
    final snap = await _db
        .collection(collection)
        .doc(id)
        .get(const GetOptions(source: Source.server))
        .timeout(_timeout);
    await FirestoreRevisionTransport.debugAfterServerRead?.call(collection, id);
    return snap.exists ? snap.data() : null;
  }

  @override
  void set(String collection, String id, Map<String, dynamic> data) => _ops.add(
      () => _db.collection(collection).doc(id).set(data, SetOptions(merge: true)));

  @override
  void delete(String collection, String id) =>
      _ops.add(() => _db.collection(collection).doc(id).delete());

  Future<void> commit() async {
    for (final op in _ops) {
      await op().timeout(_timeout);
    }
  }
}

class _FirestoreTx implements RevisionTx {
  _FirestoreTx(this._db, this._t);
  final FirebaseFirestore _db;
  final Transaction _t;
  @override
  Future<Map<String, dynamic>?> get(String collection, String id) async {
    final snap = await _t.get(_db.collection(collection).doc(id));
    return snap.exists ? snap.data() : null;
  }

  @override
  void set(String collection, String id, Map<String, dynamic> data) =>
      _t.set(_db.collection(collection).doc(id), data, SetOptions(merge: true));

  @override
  void delete(String collection, String id) => _t.delete(_db.collection(collection).doc(id));
}

/// Identificator stabil al instalării (doar pentru diagnostic: `_rev_writer`).
class SyncDeviceId {
  static const String _key = 'sync_device_id_v1';
  static String? _cached;
  static Future<String> get() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await prefs.setString(_key, id);
    }
    return _cached = id;
  }
}

/// Scriitorul condiționat. Efectele locale (bază, conflicte) se aplică DOAR
/// după ce tranzacția s-a încheiat (corpul tranzacției poate rula de mai multe ori).
class RevisionWriter {
  RevisionWriter({
    RevisionTransport? transport,
    RevisionBaseStore? bases,
    SyncConflictStore? conflicts,
    String? deviceId,
  })  : _deviceId = deviceId,
        _transport = transport ?? FirestoreRevisionTransport(),
        bases = bases ?? RevisionBaseStore(),
        conflicts = conflicts ?? SyncConflictStore();

  final RevisionTransport _transport;

  /// Doar teste (mai multe „dispozitive” în același proces); altfel [SyncDeviceId].
  final String? _deviceId;
  Future<String> _me() async => _deviceId ?? await SyncDeviceId.get();
  final RevisionBaseStore bases;
  final SyncConflictStore conflicts;

  /// Server fals pentru teste (înlocuiește transportul Firestore implicit).
  @visibleForTesting
  static RevisionTransport? debugTransport;

  static RevisionWriter standard({FirebaseFirestore? firestore}) => RevisionWriter(
      transport: debugTransport ?? FirestoreRevisionTransport(firestore: firestore));

  Future<ConditionalWriteOutcome> upsert({
    required CloudEntityType type,
    required String collection,
    required String id,
    required Map<String, dynamic> data,
    int? startRev,
  }) async {
    final base = await bases.get(type, id);
    final writer = await _me();
    final keys = data.keys.where((k) => !_isVolatileKey(k)).toList();
    final localFp = contentFingerprint(data, keys);
    late _Decision decision;
    await _runReevaluatingOnRejection((tx) async {
      final server = await tx.get(collection, id);
      decision = _decide(base: base, server: server, keys: keys, localFp: localFp, startRev: startRev);
      if (decision.write) {
        tx.set(collection, id, {
          ...data,
          kRevField: decision.newRev,
          kRevWriterField: writer,
          kRevAtField: FieldValue.serverTimestamp(),
        });
      }
    });
    return _apply(decision, type: type, id: id, local: data, localFp: localFp, base: base);
  }

  /// [keysFor] = cheile pe care le scrie versiunea curentă (aceleași ca la bază);
  /// fără ele, câmpuri scrise doar de alte versiuni ar face orice ștergere conflict.
  Future<ConditionalWriteOutcome> delete({
    required CloudEntityType type,
    required String collection,
    required String id,
    Iterable<String> Function(Map<String, dynamic> serverData)? keysFor,
  }) async {
    final base = await bases.get(type, id);
    late _Decision decision;
    await _runReevaluatingOnRejection((tx) async {
      final server = await tx.get(collection, id);
      if (server == null) {
        decision = _Decision.applied(serverRev: 0, serverFp: '', server: null);
        return;
      }
      final keys = (keysFor?.call(server) ?? server.keys).where((k) => !_isVolatileKey(k)).toList();
      final sRev = revisionOf(server);
      final sFp = contentFingerprint(server, keys);
      // Ștergerea e permisă doar dacă serverul este încă versiunea pe care
      // utilizatorul a văzut-o (altfel s-ar pierde o editare de la distanță).
      if (base != null && base.rev == sRev && base.fingerprint == sFp) {
        tx.delete(collection, id);
        decision = _Decision.write(newRev: 0, server: server);
      } else {
        decision = _Decision.conflict('delete_vs_remote_edit', server: server, serverRev: sRev);
      }
    });
    if (decision.conflictKind != null) {
      final c = SyncConflict(
        entityType: type, entityId: id, kind: decision.conflictKind!,
        localPayload: null, serverPayload: decision.server,
        baseRev: base?.rev, serverRev: decision.serverRev, detectedAt: DateTime.now(),
      );
      await conflicts.add(c);
      throw RevisionConflictException(c);
    }
    // Baza rămâne: entitatea a fost văzută pe server (și ștearsă). Astfel o copie
    // locală rămasă nu e luată drept „niciodată trimisă” și readusă la viață.
    return decision.write ? ConditionalWriteOutcome.written : ConditionalWriteOutcome.alreadyApplied;
  }

  /// Pe Windows verificarea nu e atomică: între citire și scriere, alt dispozitiv
  /// poate scrie. Cu regulile cu revizie obligatorie (etapa M3), serverul respinge
  /// atunci scrierea (`permission-denied`). Se reevaluează O SINGURĂ dată: recitire
  /// și decizie (aplicat / conflict / scriere). Un refuz repetat (de exemplu
  /// utilizator inactiv) se propagă; elementul rămâne în coadă.
  Future<void> _runReevaluatingOnRejection(Future<void> Function(RevisionTx tx) body) async {
    try {
      await _transport.run<void>(body);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      await _transport.run<void>(body);
    }
  }

  _Decision _decide({
    required RevisionBase? base,
    required Map<String, dynamic>? server,
    required List<String> keys,
    required String localFp,
    int? startRev,
  }) {
    if (server == null) {
      // Document inexistent: creare doar dacă nu l-am mai văzut pe server (nici
      // baza, nici înregistrarea editată nu au revizie de server); altfel a fost
      // șters de alt dispozitiv → nu-l readucem la viață orb.
      return base == null && (startRev ?? 0) == 0
          ? _Decision.write(newRev: 1, server: null)
          : _Decision.conflict('deleted_remotely', server: null, serverRev: null);
    }
    final sRev = revisionOf(server);
    final sFp = contentFingerprint(server, keys);
    if (sFp == localFp) {
      return _Decision.applied(serverRev: sRev, serverFp: sFp, server: server);
    }
    if (base != null && base.fingerprint == localFp) {
      // Conținutul local este exact o versiune pe care serverul a avut-o deja
      // (de exemplu scrierea imediată a reușit, iar elementul din coadă e reluat
      // după ce alt dispozitiv a editat): nimic de trimis, fără conflict fals.
      // Baza NU avansează: o editare locală ulterioară trebuie să rămână
      // comparată cu versiunea din care a pornit.
      return _Decision.superseded(serverRev: sRev, server: server);
    }
    if (startRev != null && base != null && startRev < base.rev && !base.ownWrite) {
      // Editarea a pornit dintr-o versiune mai veche decât cea pe care alt
      // dispozitiv a scris-o între timp (editor deschis, bază actualizată din
      // fundal): scrierea ar șterge silențios editarea celuilalt → conflict.
      return _Decision.conflict('concurrent_edit', server: server, serverRev: sRev);
    }
    if (base != null && base.rev == sRev && base.fingerprint == sFp) {
      return _Decision.write(newRev: sRev + 1, server: server);
    }
    return _Decision.conflict('concurrent_edit', server: server, serverRev: sRev);
  }

  Future<ConditionalWriteOutcome> _apply(
    _Decision d, {
    required CloudEntityType type,
    required String id,
    required Map<String, dynamic> local,
    required String localFp,
    required RevisionBase? base,
  }) async {
    if (d.conflictKind != null) {
      final c = SyncConflict(
        entityType: type, entityId: id, kind: d.conflictKind!,
        localPayload: local, serverPayload: d.server,
        baseRev: base?.rev, serverRev: d.serverRev, detectedAt: DateTime.now(),
      );
      await conflicts.add(c);
      throw RevisionConflictException(c);
    }
    if (d.write) {
      await bases.set(type, id, RevisionBase(rev: d.newRev, fingerprint: localFp, ownWrite: true));
      return ConditionalWriteOutcome.written;
    }
    if (d.isSuperseded) return ConditionalWriteOutcome.alreadyApplied;
    // Conținut identic pe server: dacă versiunea e scrierea acestui dispozitiv
    // (de exemplu scrierea imediată, apoi reluarea din coadă), baza rămâne „proprie”;
    // altfel următoarea editare dintr-o înregistrare locală cu revizia veche ar
    // deveni conflict fals.
    final own = d.server?[kRevWriterField] == await _me();
    await bases.set(type, id, RevisionBase(rev: d.serverRev!, fingerprint: d.serverFp!, ownWrite: own));
    return ConditionalWriteOutcome.alreadyApplied;
  }

  /// Ca [recordServerBase], pentru o listă întreagă (o singură scriere locală).
  Future<void> recordServerBases({
    required CloudEntityType type,
    required Map<String, Map<String, dynamic>> serverDocs,
    required Iterable<String> Function(Map<String, dynamic> data) keysFor,
    required Set<String> protectedIds,
  }) async {
    final me = await _me();
    final byId = <String, RevisionBase>{};
    serverDocs.forEach((id, data) {
      if (id.isEmpty || protectedIds.contains(id)) return;
      byId[id] = RevisionBase(
        rev: revisionOf(data),
        fingerprint: contentFingerprint(data, keysFor(data)),
        ownWrite: data[kRevWriterField] == me,
      );
    });
    await bases.setMany(type, byId);
  }

  /// Înregistrează baza dintr-o citire de server, DOAR dacă entitatea nu are
  /// modificări locale nesincronizate sau conflict deschis (altfel baza trebuie
  /// să rămână versiunea pe care s-a pornit editarea locală).
  Future<void> recordServerBase({
    required CloudEntityType type,
    required String id,
    required Map<String, dynamic> serverData,
    required Iterable<String> keys,
    required Set<String> protectedIds,
  }) async {
    if (id.isEmpty || protectedIds.contains(id)) return;
    await bases.set(
      type,
      id,
      RevisionBase(rev: revisionOf(serverData), fingerprint: contentFingerprint(serverData, keys)),
    );
  }
}

class _Decision {
  _Decision.write({required this.newRev, required this.server})
      : write = true, conflictKind = null, serverRev = null, serverFp = null, isSuperseded = false;
  _Decision.applied({required this.serverRev, required this.serverFp, required this.server})
      : write = false, conflictKind = null, newRev = 0, isSuperseded = false;
  _Decision.conflict(this.conflictKind, {required this.server, required this.serverRev})
      : write = false, newRev = 0, serverFp = null, isSuperseded = false;
  _Decision.superseded({required this.serverRev, required this.server})
      : write = false, conflictKind = null, newRev = 0, serverFp = null, isSuperseded = true;

  final bool write;
  final int newRev;
  final String? conflictKind;
  final Map<String, dynamic>? server;
  final int? serverRev;
  final String? serverFp;
  final bool isSuperseded;
}
