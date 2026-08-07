import 'package:flutter/material.dart';

import '../../crm/crm_models.dart';
import '../../crm/crm_repository.dart';
import '../offer_models.dart';
import '../oferta_detaliu_page.dart' show OfertaDetaliuPage;

/// Sincronizare CRM la schimbarea statusului unei oferte, pentru
/// [OfertaDetaliuPage]. Best-effort, fire-and-forget — nu blochează fluxul
/// principal de schimbare status dacă CRM-ul eșuează.
mixin OffertaDetaliuCrmMixin on State<OfertaDetaliuPage> {
  void syncCrmForOfferStatus(OfferRecord offer, OfferStatus newStatus) {
    if (newStatus == OfferStatus.sent) {
      _upsertCrmForOffer(offer, CrmStadiu.ofertaTrimisa);
    } else if (newStatus == OfferStatus.accepted) {
      _upsertCrmForOffer(offer, CrmStadiu.castigat,
          valoareFinala: offer.totalValue);
    } else if (newStatus == OfferStatus.rejected) {
      _upsertCrmForOffer(offer, CrmStadiu.pierdut);
    }
  }

  void _upsertCrmForOffer(OfferRecord offer, CrmStadiu stadiu,
      {double? valoareFinala}) {
    final repo = CrmRepository.instance;
    repo.listLocal().then((all) {
      final existing = all.cast<CrmRecord?>().firstWhere(
            (r) => r!.ofertaId == offer.id,
            orElse: () => null,
          );
      final now = DateTime.now();
      final CrmRecord updated;
      if (existing != null) {
        updated = existing.copyWith(
          stadiu: stadiu,
          valoareFinala: valoareFinala,
          updatedAt: now,
        );
      } else {
        updated = repo
            .createNew(
              titlu: offer.title.isNotEmpty
                  ? offer.title
                  : 'Oferta ${offer.id.substring(0, 8)}',
              clientName: offer.clientName,
              clientId: offer.clientId,
              stadiu: stadiu,
              valoareEstimata: offer.totalValue,
            )
            .copyWith(
              ofertaId: offer.id,
              valoareFinala: valoareFinala,
              updatedAt: now,
            );
      }
      repo.upsertCrmRecord(updated).catchError((e) {
        debugPrint('[CRM] ❌ _upsertCrmForOffer: $e');
      });
    }).catchError((e) {
      debugPrint('[CRM] ❌ listLocal for offer sync: $e');
    });
  }
}
