import 'dart:async';

import 'firebase_bootstrap.dart';

/// Rezultatul unei scrieri cloud lansate fără a bloca salvarea locală.
enum CloudPushOutcome {
  /// Serverul a confirmat scrierea.
  synced,

  /// Offline: scrierea rămâne în așteptare în SDK (Firestore o păstrează în
  /// cache-ul local și o trimite la reconectare).
  pendingOffline,

  /// Eroare sau timeout online (ex. permisiuni, rețea lentă).
  failed,
}

/// Lansează o scriere cloud FĂRĂ ca salvarea locală / UI să aștepte
/// confirmarea rețelei.
///
/// - offline: operația este pornită (Firestore o înregistrează local ca
///   scriere în așteptare), dar NU este așteptată → [CloudPushOutcome.pendingOffline];
/// - online: este așteptată cel mult [timeout] → [CloudPushOutcome.synced] sau
///   [CloudPushOutcome.failed].
///
/// Erorile apărute ulterior (inclusiv după timeout) sunt înregistrate în
/// [FirebaseBootstrap.registerRuntimeError], deci rămân observabile.
/// Apelantul decide ce face la `pendingOffline`/`failed` (ex. coada offline).
Future<CloudPushOutcome> pushToCloudWithoutBlocking(
  Future<void> Function() operation, {
  bool? online,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final Future<void> pending;
  try {
    pending = operation();
  } catch (error) {
    FirebaseBootstrap.registerRuntimeError(error);
    return CloudPushOutcome.failed;
  }
  // Orice eroare târzie este observată (nu rămâne „unhandled”).
  final observed = pending.catchError((Object error) {
    FirebaseBootstrap.registerRuntimeError(error);
  });

  if (!(online ?? FirebaseBootstrap.isOnline)) {
    unawaited(observed);
    return CloudPushOutcome.pendingOffline;
  }
  try {
    await pending.timeout(timeout);
    return CloudPushOutcome.synced;
  } catch (error) {
    FirebaseBootstrap.registerRuntimeError(error);
    unawaited(observed);
    return CloudPushOutcome.failed;
  }
}
