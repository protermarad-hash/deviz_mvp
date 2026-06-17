import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../cloud/firebase_bootstrap.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTO-UPDATE IN-APP (fără Play Store/Store) — distribuire via Firebase
// Storage + Firestore. Vezi ghidul de upload manual în
// docs/ghid_actualizare_apk.md.
//
// Document Firestore: colecția `app_config`, documentul `version_info`:
// {
//   latestVersion:     "1.1.0",
//   latestBuildNumber: 3,
//   apkUrl:            "https://firebasestorage.googleapis.com/.../app-release.apk?...",
//   windowsExeUrl:     "https://firebasestorage.googleapis.com/.../proterm-setup.exe?...",
//   releaseNotes:      "Ce e nou în această versiune",
//   forceUpdate:       false   // NU implementat încă — rezervat pentru viitor
// }
// ─────────────────────────────────────────────────────────────────────────────

/// Informațiile despre cea mai nouă versiune disponibilă, citite din
/// Firestore `app_config/version_info`.
class AppVersionInfo {
  const AppVersionInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.apkUrl,
    required this.windowsExeUrl,
    required this.releaseNotes,
    required this.forceUpdate,
  });

  final String latestVersion;
  final int latestBuildNumber;
  /// URL descărcare APK (Android). Poate fi gol dacă nu există release Android.
  final String apkUrl;
  /// URL descărcare installer Windows (.exe / setup.exe). Poate fi gol dacă
  /// nu există release Windows. Câmp nou — backward compatible (default '').
  final String windowsExeUrl;
  final String releaseNotes;
  // Rezervat pentru viitor — SETAT FALSE acum.
  final bool forceUpdate;

  factory AppVersionInfo.fromMap(Map<String, dynamic> map) {
    int parseInt(dynamic raw) {
      if (raw is num) return raw.toInt();
      return int.tryParse('${raw ?? ''}'.trim()) ?? 0;
    }

    bool parseBool(dynamic raw) {
      if (raw is bool) return raw;
      return '${raw ?? ''}'.trim().toLowerCase() == 'true';
    }

    return AppVersionInfo(
      latestVersion:
          (map['latestVersion'] ?? map['latest_version'] ?? '').toString().trim(),
      latestBuildNumber: parseInt(
        map['latestBuildNumber'] ?? map['latest_build_number'],
      ),
      apkUrl: (map['apkUrl'] ?? map['apk_url'] ?? '').toString().trim(),
      windowsExeUrl:
          (map['windowsExeUrl'] ?? map['windows_exe_url'] ?? '').toString().trim(),
      releaseNotes:
          (map['releaseNotes'] ?? map['release_notes'] ?? '').toString().trim(),
      forceUpdate: parseBool(map['forceUpdate'] ?? map['force_update']),
    );
  }
}

/// Rezultatul verificării — versiunea instalată vs. cea mai nouă disponibilă.
class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.needsUpdate,
    required this.info,
    required this.installedVersion,
    required this.installedBuildNumber,
  });

  final bool needsUpdate;
  final AppVersionInfo info;
  final String installedVersion;
  final int installedBuildNumber;
}

/// Verifică în Firestore dacă există o versiune mai nouă a aplicației decât
/// cea instalată pe dispozitiv — best-effort, nu blochează niciodată
/// pornirea aplicației și nu aruncă excepții către apelant.
class AppVersionChecker {
  AppVersionChecker._();
  static final AppVersionChecker instance = AppVersionChecker._();

  static const String _collectionName = 'app_config';
  static const String _docId = 'version_info';

  bool get _isCloudAvailable => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection(_collectionName);

  /// Returnează `null` dacă nu se poate verifica (offline, Firestore
  /// indisponibil, document inexistent/invalid, sau platforma curentă nu are
  /// URL de descărcare configurat).
  Future<AppUpdateCheckResult?> checkForUpdate() async {
    if (!_isCloudAvailable) return null;
    if (kIsWeb) return null;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final installedBuildNumber =
          int.tryParse(packageInfo.buildNumber.trim()) ?? 0;

      final doc = await _collection.doc(_docId).get();
      if (!doc.exists || doc.data() == null) return null;

      final info = AppVersionInfo.fromMap(doc.data()!);
      if (info.latestBuildNumber <= 0) return null;

      // Verifică că există URL de descărcare pentru platforma curentă.
      final bool hasUrlForPlatform =
          (Platform.isAndroid && info.apkUrl.isNotEmpty) ||
          (Platform.isWindows && info.windowsExeUrl.isNotEmpty);
      if (!hasUrlForPlatform) return null;

      final needsUpdate = info.latestBuildNumber > installedBuildNumber;
      return AppUpdateCheckResult(
        needsUpdate: needsUpdate,
        info: info,
        installedVersion: packageInfo.version,
        installedBuildNumber: installedBuildNumber,
      );
    } catch (e) {
      debugPrint('[AppVersionChecker] verificare versiune eșuată: $e');
      return null;
    }
  }
}
