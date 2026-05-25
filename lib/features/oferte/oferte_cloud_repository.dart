import 'offer_models.dart';

abstract class OferteCloudRepository {
  Future<List<OfferRecord>> listOffers();
  Stream<List<OfferRecord>> watchOffers();
  Future<void> upsertOffer(OfferRecord offer);
  Future<void> deleteOffer(String offerId);
}
