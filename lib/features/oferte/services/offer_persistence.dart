import '../../../core/cloud/cloud_push.dart';
import '../offer_models.dart';

/// Salvarea unei oferte, local întâi (același tipar ca `lucrareSaveJobWithSync`).
///
/// 1. [saveLocal] — oferta ajunge imediat în stocarea locală;
/// 2. [cloudUpsert] (dacă există) — scrierea cloud e așteptată cel mult
///    [cloudTimeout] prin [pushToCloudWithoutBlocking]. Pe un server
///    inaccesibil (DNS funcțional), `set()` nu se confirmă niciodată; înainte,
///    paginile așteptau la nesfârșit și oferta nu era salvată local;
/// 3. [queue] — coada offline, ÎNAINTE de cloud (RC 120), întotdeauna.
///
/// Întoarce rezultatul scrierii cloud (`failed` când nu există cloud).
Future<CloudPushOutcome> offerSaveLocalFirst({
  required OfferRecord offer,
  required Future<void> Function(OfferRecord offer) saveLocal,
  required Future<void> Function(OfferRecord offer)? cloudUpsert,
  required Future<void> Function(OfferRecord offer) queue,
  bool? online,
  Duration cloudTimeout = const Duration(seconds: 10),
}) async {
  await saveLocal(offer);
  // Coada ÎNAINTE de cloud (RC 120): durabil la crash și protejat la merge; dacă
  // scrierea cloud reușește, elementul se confirmă idempotent (revizie).
  await queue(offer);
  return cloudUpsert == null
      ? CloudPushOutcome.failed
      : await pushToCloudWithoutBlocking(
          () => cloudUpsert(offer),
          online: online,
          timeout: cloudTimeout,
        );
}
