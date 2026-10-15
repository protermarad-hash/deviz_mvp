import '../../../core/cloud/cloud_push.dart';
import '../offer_models.dart';

/// Salvarea unei oferte, local întâi (același tipar ca `lucrareSaveJobWithSync`).
///
/// 1. [saveLocal] — oferta ajunge imediat în stocarea locală;
/// 2. [cloudUpsert] (dacă există) — scrierea cloud e așteptată cel mult
///    [cloudTimeout] prin [pushToCloudWithoutBlocking]. Pe un server
///    inaccesibil (DNS funcțional), `set()` nu se confirmă niciodată; înainte,
///    paginile așteptau la nesfârșit și oferta nu era salvată local;
/// 3. [queue] — coada offline: întotdeauna dacă [queueAlways], altfel doar
///    când scrierea cloud nu a fost confirmată.
///
/// Întoarce rezultatul scrierii cloud (`failed` când nu există cloud).
Future<CloudPushOutcome> offerSaveLocalFirst({
  required OfferRecord offer,
  required Future<void> Function(OfferRecord offer) saveLocal,
  required Future<void> Function(OfferRecord offer)? cloudUpsert,
  required Future<void> Function(OfferRecord offer) queue,
  bool queueAlways = true,
  bool? online,
  Duration cloudTimeout = const Duration(seconds: 10),
}) async {
  await saveLocal(offer);
  final outcome = cloudUpsert == null
      ? CloudPushOutcome.failed
      : await pushToCloudWithoutBlocking(
          () => cloudUpsert(offer),
          online: online,
          timeout: cloudTimeout,
        );
  if (queueAlways || outcome != CloudPushOutcome.synced) {
    await queue(offer);
  }
  return outcome;
}
