import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Serviciu CENTRALIZAT care semnalează că aplicația rulează pe date locale
/// pentru că sesiunea cloud nu este validă.
///
/// Se activează în două situații:
///  1. Sesiunea de autentificare a căzut pe fallback local
///     (`authSourceLabel == 'local'`) — bridge-ul din
///     [FirestoreAuthWarningBanner] apelează [reportLocalAuthFallback].
///  2. Orice modul (Programări, Deviz tehnic, Oferte) prinde explicit o eroare
///     Firestore `permission-denied` în fallback-ul lui pe date locale și
///     apelează [reportCloudError].
///
/// Toate modulele afectate cheamă acest serviciu unic — NU există cod duplicat
/// de avertisment în fiecare fișier. Banner-ul persistent și dialogul de
/// re-login se conectează la notificatorii de aici.
class FirestoreAuthWarningService {
  FirestoreAuthWarningService._();

  static final FirestoreAuthWarningService instance =
      FirestoreAuthWarningService._();

  /// true când avertismentul trebuie afișat (fallback auth local SAU
  /// permission-denied confirmat).
  final ValueNotifier<bool> activeNotifier = ValueNotifier<bool>(false);

  /// true DOAR când un modul a prins explicit permission-denied de la Firestore.
  /// Gate strict pentru declanșarea dialogului de re-login (Task 2): o simplă
  /// stare offline NU îl activează.
  final ValueNotifier<bool> permissionDeniedNotifier =
      ValueNotifier<bool>(false);

  /// Ultimul mesaj de eroare cloud relevant (pentru diagnostic).
  String? lastPermissionError;

  /// Apelat de orice modul când prinde o eroare Firestore în fallback-ul lui pe
  /// date locale. Ridică avertismentul DOAR dacă eroarea e permission-denied.
  /// Returnează true dacă eroarea a fost identificată ca permission-denied.
  bool reportCloudError(Object error) {
    if (!_isPermissionDenied(error)) {
      return false;
    }
    lastPermissionError = _short(error);
    var changed = false;
    if (!permissionDeniedNotifier.value) {
      permissionDeniedNotifier.value = true;
      changed = true;
    }
    if (!activeNotifier.value) {
      activeNotifier.value = true;
      changed = true;
    }
    if (changed) {
      debugPrint(
        '[FirestoreAuthWarning] permission-denied detectat: $lastPermissionError',
      );
    }
    return true;
  }

  /// Apelat când sesiunea de autentificare rulează doar local
  /// (`authSourceLabel == 'local'`). Ridică avertismentul general, dar NU
  /// marchează permission-denied (re-login-ul rămâne gate-uit strict).
  void reportLocalAuthFallback() {
    if (!activeNotifier.value) {
      activeNotifier.value = true;
      debugPrint('[FirestoreAuthWarning] sesiune auth doar locală');
    }
  }

  /// Curăță avertismentul după o re-autentificare cloud reușită sau când
  /// `authSourceLabel` revine la 'cloud'.
  void clear() {
    lastPermissionError = null;
    if (permissionDeniedNotifier.value) {
      permissionDeniedNotifier.value = false;
    }
    if (activeNotifier.value) {
      activeNotifier.value = false;
      debugPrint('[FirestoreAuthWarning] avertisment curățat (cloud OK)');
    }
  }

  static bool _isPermissionDenied(Object error) {
    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      if (code.contains('permission-denied') ||
          code.contains('permission_denied') ||
          code == 'unauthenticated') {
        return true;
      }
    }
    final text = error.toString().toLowerCase();
    return text.contains('permission-denied') ||
        text.contains('permission_denied') ||
        text.contains('missing or insufficient permissions');
  }

  static String _short(Object error) {
    final raw = error.toString().replaceAll('\n', ' ').trim();
    if (raw.isEmpty) return 'permission-denied';
    return raw.length > 160 ? '${raw.substring(0, 160)}…' : raw;
  }
}
