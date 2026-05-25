import 'offer_models.dart';

class OfferListFilter {
  const OfferListFilter._();

  static List<OfferRecord> apply({
    required List<OfferRecord> items,
    required String searchQuery,
    required OfferStatus? status,
    required String? clientId,
    required String Function(OfferRecord item) resolveClientName,
  }) {
    final query = searchQuery.trim().toLowerCase();
    final normalizedClientId = (clientId ?? '').trim();
    return items.where((item) {
      if (status != null && item.status != status) {
        return false;
      }
      if (normalizedClientId.isNotEmpty && item.clientId != normalizedClientId) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final clientName = resolveClientName(item).toLowerCase();
      final beneficiary = item.beneficiaryName.trim().toLowerCase();
      final commercialRecipient = item.commercialRecipientName.trim().toLowerCase();
      return item.offerNumber.toLowerCase().contains(query) ||
          item.title.toLowerCase().contains(query) ||
          clientName.contains(query) ||
          beneficiary.contains(query) ||
          commercialRecipient.contains(query) ||
          item.complaintNumber.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  static bool hasActiveFilters({
    required OfferStatus? status,
    required String? clientId,
    required String searchQuery,
  }) {
    return status != null ||
        (clientId ?? '').trim().isNotEmpty ||
        searchQuery.trim().isNotEmpty;
  }
}
