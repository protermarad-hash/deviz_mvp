import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../cloud/firebase_collections.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model rezultat migrare
// ─────────────────────────────────────────────────────────────────────────────

class FieldPhotoMigrationItem {
  const FieldPhotoMigrationItem({
    required this.storagePath,
    required this.fileName,
    required this.programareId,
    this.downloadUrl = '',
    this.alreadyInFirestore = false,
    this.skipped = false,
    this.error = '',
  });

  final String storagePath;
  final String fileName;
  final String programareId;
  final String downloadUrl;
  final bool alreadyInFirestore;
  final bool skipped;
  final String error;

  bool get hasError => error.isNotEmpty;

  @override
  String toString() {
    if (hasError) return '[EROARE] $storagePath → $error';
    if (alreadyInFirestore) return '[SĂRIT] $storagePath (deja în Firestore)';
    if (skipped) return '[SĂRIT] $storagePath';
    return '[MIGRAT] $storagePath → $downloadUrl';
  }
}

class FieldPhotoMigrationResult {
  const FieldPhotoMigrationResult({
    required this.items,
    required this.dryRun,
  });

  final List<FieldPhotoMigrationItem> items;
  final bool dryRun;

  int get migrated => items.where((i) => !i.alreadyInFirestore && !i.skipped && !i.hasError).length;
  int get skipped => items.where((i) => i.alreadyInFirestore || i.skipped).length;
  int get errors => items.where((i) => i.hasError).length;
  int get total => items.length;

  List<FieldPhotoMigrationItem> get migratedItems =>
      items.where((i) => !i.alreadyInFirestore && !i.skipped && !i.hasError).toList();
  List<FieldPhotoMigrationItem> get skippedItems =>
      items.where((i) => i.alreadyInFirestore || i.skipped).toList();
  List<FieldPhotoMigrationItem> get errorItems =>
      items.where((i) => i.hasError).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// Serviciu de migrare
// ─────────────────────────────────────────────────────────────────────────────

class FieldPhotosMigrationService {
  const FieldPhotosMigrationService._();

  static const String _storageBasePath = 'field_photos/programari';
  static const Uuid _uuid = Uuid();

  // Colecția Firestore unde sunt salvate pozele
  static CollectionReference<Map<String, dynamic>> get _firestoreCollection =>
      FirebaseFirestore.instance.collection(FirebaseCollections.fieldPhotos);

  // ──────────────────────────────────────────────────────
  // Pas 1: Listează fișierele din Storage
  // ──────────────────────────────────────────────────────

  /// Listează toate fișierele din field_photos/programari/ și subdirectoarele lor.
  /// Returnează [(storagePath, programareId, fileName)] pentru fiecare fișier găsit.
  ///
  /// Strategia de listare (robustă):
  /// 1. Diagnostic: verifică bucket și conectivitate
  /// 2. Listează subdirectoarele (ID-urile programărilor) din field_photos/programari/
  /// 3. Pentru fiecare subdirector, listează fișierele cu paginare (list + pageToken)
  ///    — mai robust decât listAll() care poate eșua silențios
  static Future<List<({String storagePath, String programareId, String fileName})>>
      listStorageFiles({
    void Function(String message)? onProgress,
  }) async {
    final storage = FirebaseStorage.instance;
    final bucket = storage.bucket;

    onProgress?.call('=== DIAGNOSTICARE STORAGE ===');
    onProgress?.call('Bucket: $bucket');
    onProgress?.call('Path scanat: $_storageBasePath');
    onProgress?.call('');

    final result = <({String storagePath, String programareId, String fileName})>[];

    // ── Pasul 1a: Test conectivitate — listează field_photos/ (un nivel mai sus) ──
    onProgress?.call('Test conectivitate: listez field_photos/...');
    try {
      final rootRef = storage.ref().child('field_photos');
      final rootList = await rootRef.list(const ListOptions(maxResults: 20));
      onProgress?.call(
        '  field_photos/ → ${rootList.prefixes.length} subdirectoare, '
        '${rootList.items.length} fișiere directe',
      );
      for (final p in rootList.prefixes) {
        onProgress?.call('    📁 ${p.fullPath}');
      }
      if (rootList.prefixes.isEmpty && rootList.items.isEmpty) {
        onProgress?.call(
          '⚠ field_photos/ este GOL sau nu există în bucket $bucket.',
        );
        onProgress?.call(
          '  Verifică că bucket-ul din Firebase Console conține folder-ul field_photos/.',
        );
      }
    } catch (e) {
      onProgress?.call('❌ Nu pot accesa field_photos/: $e');
      onProgress?.call(
        '  Cauze posibile:\n'
        '  1. Firebase Storage Rules nu permit operațiunea "list"\n'
        '  2. Autentificare expirată\n'
        '  3. Bucket greșit (verifică Firebase Console)',
      );
      // Continuăm — posibil că regulile permit accesul la sub-path
    }

    onProgress?.call('');
    onProgress?.call('Se listează: $_storageBasePath/');

    // ── Pasul 1b: Listează subdirectoarele (ID-uri programări) ──
    List<Reference> programareRefs = [];
    try {
      final baseRef = storage.ref().child(_storageBasePath);

      // Folosim list() cu paginare în loc de listAll() — mai robust
      String? pageToken;
      do {
        final page = await baseRef.list(
          ListOptions(
            maxResults: 100,
            pageToken: pageToken,
          ),
        );
        programareRefs.addAll(page.prefixes);

        // Fișiere direct în rădăcina programari/ (fără subfolderul ID)
        for (final item in page.items) {
          result.add((
            storagePath: item.fullPath,
            programareId: 'unassigned',
            fileName: item.name,
          ));
          onProgress?.call('  [direct] ${item.fullPath}');
        }

        pageToken = page.nextPageToken;
      } while (pageToken != null);

      onProgress?.call(
        'Găsite ${programareRefs.length} directoare de programări'
        '${result.isNotEmpty ? " + ${result.length} fișiere directe" : ""}.',
      );

      if (programareRefs.isEmpty && result.isEmpty) {
        onProgress?.call(
          '⚠ Directorul $_storageBasePath/ există dar este GOL.',
        );
        onProgress?.call(
          '  Verifică în Firebase Console > Storage că pozele sunt la calea:',
        );
        onProgress?.call('  $_storageBasePath/[ID_PROGRAMARE]/[filename].jpg');
        return result;
      }
    } catch (e) {
      onProgress?.call('❌ Eroare la listarea $_storageBasePath/: $e');
      onProgress?.call(
        '  Dacă eroarea conține "unauthorized" sau "403":\n'
        '  → Adaugă în Firebase Storage Rules:\n'
        '     allow list: if request.auth != null;',
      );
      return result;
    }

    // ── Pasul 1c: Parcurge fiecare subdirector (ID programare) ──
    for (final prefixRef in programareRefs) {
      final programareId = prefixRef.name;
      onProgress?.call('  → Scanez: $programareId');

      try {
        String? pageToken;
        int count = 0;
        do {
          final page = await prefixRef.list(
            ListOptions(
              maxResults: 100,
              pageToken: pageToken,
            ),
          );
          for (final item in page.items) {
            result.add((
              storagePath: item.fullPath,
              programareId: programareId,
              fileName: item.name,
            ));
            count++;
          }
          // Sub-subdirectoare (rare, dar posibile)
          for (final subPrefix in page.prefixes) {
            onProgress?.call('    📁 sub-director: ${subPrefix.fullPath}');
            try {
              final subPage = await subPrefix.listAll();
              for (final item in subPage.items) {
                result.add((
                  storagePath: item.fullPath,
                  programareId: programareId,
                  fileName: item.name,
                ));
                count++;
              }
            } catch (subE) {
              onProgress?.call('    ⚠ Eroare sub-director: $subE');
            }
          }
          pageToken = page.nextPageToken;
        } while (pageToken != null);

        onProgress?.call('     $count fișiere');
      } catch (e) {
        onProgress?.call('  ⚠ Eroare la scanarea $programareId: $e');
      }
    }

    onProgress?.call('');
    onProgress?.call('Total fișiere găsite în Storage: ${result.length}');
    return result;
  }

  // ──────────────────────────────────────────────────────
  // Pas 2: Verifică ce există deja în Firestore
  // ──────────────────────────────────────────────────────

  /// Returnează setul de cloud_path-uri deja existente în Firestore.
  static Future<Set<String>> _loadExistingCloudPaths({
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('Se verifică înregistrările existente în Firestore...');
    try {
      final snapshot = await _firestoreCollection.get();
      final paths = snapshot.docs
          .map((doc) => (doc.data()['cloud_path'] ?? '').toString().trim())
          .where((p) => p.isNotEmpty)
          .toSet();
      onProgress?.call('Firestore: ${paths.length} înregistrări existente.');
      return paths;
    } catch (e) {
      onProgress?.call('⚠ Nu s-au putut încărca înregistrările din Firestore: $e');
      return {};
    }
  }

  // ──────────────────────────────────────────────────────
  // Pas 3: Dry run — preview fără scriere
  // ──────────────────────────────────────────────────────

  /// Dry run: listează ce s-ar migra fără a scrie nimic în Firestore.
  /// NU obține downloadURL (ar fi prea lent) — arată doar path-urile.
  static Future<FieldPhotoMigrationResult> dryRun({
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('=== DRY RUN — nu se scrie nimic ===');

    final files = await listStorageFiles(onProgress: onProgress);
    final existingPaths = await _loadExistingCloudPaths(onProgress: onProgress);

    final items = <FieldPhotoMigrationItem>[];

    for (final file in files) {
      final alreadyExists = existingPaths.contains(file.storagePath);
      items.add(FieldPhotoMigrationItem(
        storagePath: file.storagePath,
        fileName: file.fileName,
        programareId: file.programareId,
        alreadyInFirestore: alreadyExists,
      ));

      if (alreadyExists) {
        onProgress?.call('  [SĂRIT] ${file.storagePath} — deja în Firestore');
      } else {
        onProgress?.call('  [AR MIGRA] ${file.storagePath}');
      }
    }

    onProgress?.call('');
    onProgress?.call('=== SUMAR DRY RUN ===');
    final toMigrate = items.where((i) => !i.alreadyInFirestore).length;
    final toSkip = items.where((i) => i.alreadyInFirestore).length;
    onProgress?.call('Total fișiere: ${items.length}');
    onProgress?.call('De migrat: $toMigrate');
    onProgress?.call('De sărit (deja în Firestore): $toSkip');

    return FieldPhotoMigrationResult(items: items, dryRun: true);
  }

  // ──────────────────────────────────────────────────────
  // Pas 4: Migrare efectivă
  // ──────────────────────────────────────────────────────

  /// Migrare efectivă: pentru fiecare fișier din Storage care NU există în
  /// Firestore, obține downloadURL și creează un document nou.
  /// NU modifică documentele existente.
  static Future<FieldPhotoMigrationResult> migrate({
    void Function(String message)? onProgress,
    void Function(int current, int total)? onItemProgress,
  }) async {
    onProgress?.call('=== MIGRARE EFECTIVĂ ===');

    final files = await listStorageFiles(onProgress: onProgress);
    final existingPaths = await _loadExistingCloudPaths(onProgress: onProgress);

    final toMigrate = files.where((f) => !existingPaths.contains(f.storagePath)).toList();
    final alreadyExists = files.where((f) => existingPaths.contains(f.storagePath)).toList();

    onProgress?.call('');
    onProgress?.call('Fișiere de migrat: ${toMigrate.length}');
    onProgress?.call('Fișiere sărite (deja în Firestore): ${alreadyExists.length}');
    onProgress?.call('');

    final items = <FieldPhotoMigrationItem>[];

    // Adaugă elementele deja existente ca "sărite"
    for (final file in alreadyExists) {
      items.add(FieldPhotoMigrationItem(
        storagePath: file.storagePath,
        fileName: file.fileName,
        programareId: file.programareId,
        alreadyInFirestore: true,
      ));
    }

    // Migrare efectivă
    for (var i = 0; i < toMigrate.length; i++) {
      final file = toMigrate[i];
      onItemProgress?.call(i + 1, toMigrate.length);
      onProgress?.call('[${i + 1}/${toMigrate.length}] Migrare: ${file.storagePath}');

      try {
        // Obține downloadURL din Storage
        final ref = FirebaseStorage.instance.ref(file.storagePath);
        final downloadUrl = await ref.getDownloadURL();

        // Generează timestamp din metadata Storage dacă disponibil,
        // altfel folosim now
        DateTime fileDate = DateTime.now();
        try {
          final metadata = await ref.getMetadata();
          if (metadata.timeCreated != null) {
            fileDate = metadata.timeCreated!;
          }
        } catch (_) {
          // metadata indisponibilă — folosim now
        }

        // Creează document nou în Firestore
        final docId = _uuid.v4();
        final now = DateTime.now();
        final doc = <String, dynamic>{
          'id': docId,
          'source_module': 'programari',
          'source_entity_id': file.programareId,
          'document_id': '',
          'photo_type': 'altul',
          'description': '',
          'file_path': '',          // nu avem fișier local pe dispozitivul de migrare
          'file_name': file.fileName,
          'cloud_path': file.storagePath,
          'download_url': downloadUrl,
          'taken_at': fileDate.toIso8601String(),
          'taken_by_name': '',
          'taken_by_user_id': '',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          // Câmp special pentru audit — indică că documentul a fost creat prin migrare
          'migrated': true,
          'migrated_at': now.toIso8601String(),
        };

        // NU folosim merge: true — doar set() simplu (document NOU)
        await _firestoreCollection.doc(docId).set(doc);

        onProgress?.call('  ✅ Migrat: ${file.fileName} → $downloadUrl');

        items.add(FieldPhotoMigrationItem(
          storagePath: file.storagePath,
          fileName: file.fileName,
          programareId: file.programareId,
          downloadUrl: downloadUrl,
        ));
      } catch (e) {
        onProgress?.call('  ❌ Eroare la ${file.storagePath}: $e');
        items.add(FieldPhotoMigrationItem(
          storagePath: file.storagePath,
          fileName: file.fileName,
          programareId: file.programareId,
          error: e.toString(),
        ));
      }
    }

    onProgress?.call('');
    onProgress?.call('=== SUMAR FINAL ===');
    final migrated = items.where((i) => !i.alreadyInFirestore && !i.skipped && !i.hasError).length;
    final skipped = items.where((i) => i.alreadyInFirestore || i.skipped).length;
    final errors = items.where((i) => i.hasError).length;
    onProgress?.call('✅ Migrate: $migrated poze');
    onProgress?.call('⏭ Sărite (deja existau): $skipped poze');
    onProgress?.call('❌ Erori: $errors poze');

    return FieldPhotoMigrationResult(items: items, dryRun: false);
  }
}
