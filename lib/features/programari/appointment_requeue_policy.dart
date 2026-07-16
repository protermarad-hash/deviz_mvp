import 'appointment_models.dart';

/// Rezultatul clasificării programărilor „local-only" (prezente în cache-ul local,
/// dar absente din rezultatul query-ului cloud) pentru decizia de re-queue.
///
/// Face parte din fix-ul anti-resurecție: NU mai re-încărcăm orbește în Firestore
/// orice programare care lipsește din cloud. Doar programările cu adevărat noi
/// (create offline, niciodată confirmate în cloud) sau cu o modificare offline în
/// așteptare se re-cozează necondiționat. Restul (confirmate cândva în cloud, dar
/// acum absente) se verifică determinist cu `.doc(id).get()` înainte de orice
/// decizie — vezi [AppointmentRequeuePlan.verifyExistence].
class AppointmentRequeuePlan {
  const AppointmentRequeuePlan({
    required this.requeueNow,
    required this.verifyExistence,
  });

  /// Programări de re-cozat imediat (fluxul actual, neschimbat):
  /// - „neconfirmate" (create offline, niciodată văzute în cloud), SAU
  /// - cu un upsert offline în așteptare în coadă (modificare legitimă de sincronizat).
  final List<Appointment> requeueNow;

  /// Programări „confirmate" cândva în cloud, acum absente din rezultat și fără
  /// upsert în așteptare. NU se re-cozează; se verifică întâi cu `.doc(id).get()`:
  /// dacă documentul există → doar actualizare locală; dacă nu există → ștergere
  /// reală, se elimină din cache local. La eroare de rețea → se sare (fail-safe).
  final List<Appointment> verifyExistence;
}

/// Împarte [localOnlyItems] în „de re-cozat acum" vs „de verificat existența".
///
/// Regula (pură, deterministă, testabilă):
/// - un id este „confirmat" dacă NU apare în [unconfirmedIds]
///   (cache-ul preexistent, dinainte de acest fix, e implicit confirmat — nu are
///   intrare în registrul de neconfirmate);
/// - `requeueNow` = itemele neconfirmate SAU cu upsert în așteptare
///   ([pendingUpsertIds]);
/// - `verifyExistence` = restul (confirmate ȘI fără upsert în așteptare).
AppointmentRequeuePlan planLocalOnlyRequeue({
  required List<Appointment> localOnlyItems,
  required Set<String> unconfirmedIds,
  required Set<String> pendingUpsertIds,
}) {
  final requeueNow = <Appointment>[];
  final verifyExistence = <Appointment>[];
  for (final item in localOnlyItems) {
    final isUnconfirmed = unconfirmedIds.contains(item.id);
    final hasPendingUpsert = pendingUpsertIds.contains(item.id);
    if (isUnconfirmed || hasPendingUpsert) {
      requeueNow.add(item);
    } else {
      verifyExistence.add(item);
    }
  }
  return AppointmentRequeuePlan(
    requeueNow: requeueNow,
    verifyExistence: verifyExistence,
  );
}
