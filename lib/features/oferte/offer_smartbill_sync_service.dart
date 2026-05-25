import '../../core/company_profile.dart';
import '../../core/integrations/smartbill_service.dart';
import '../../core/smartbill_settings.dart';
import '../clients/client_models.dart';
import 'offer_currency_converter.dart';
import 'offer_models.dart';
import 'offer_smartbill_models.dart';

class OfferSmartBillSyncService {
  OfferSmartBillSyncService({SmartBillService? smartBillService})
      : _smartBillService = smartBillService ?? SmartBillService();

  final SmartBillService _smartBillService;

  Future<OfferRecord> issueEstimate({
    required OfferRecord offer,
    required CompanyProfile companyProfile,
    required ClientRecord? billingClient,
  }) async {
    final settings = _validatedSettings(companyProfile.smartBillSettings);
    final client = _validatedBillingClient(billingClient);
    final taxes = await _smartBillService.fetchTaxes(settings);
    final payload = _buildEstimatePayload(
      offer: offer,
      settings: settings,
      client: client,
      taxes: taxes,
    );
    final response = await _smartBillService.issueEstimate(settings, payload);
    return offer.copyWith(
      smartBillEstimate: offer.smartBillEstimate.copyWith(
        syncStatus: OfferSmartBillSyncStatus.issued,
        seriesName: response.series,
        number: response.number,
        documentUrl: response.documentUrl,
        documentViewUrl: response.documentViewUrl,
        publicUrl: response.publicUrl,
        documentId: response.documentId,
        isDraft: settings.useEstimateDraft,
        issuedAt: DateTime.now(),
        lastSyncedAt: DateTime.now(),
        lastError: '',
      ),
      updatedAt: DateTime.now(),
    );
  }

  Future<OfferRecord> issueInvoice({
    required OfferRecord offer,
    required CompanyProfile companyProfile,
    required ClientRecord? billingClient,
  }) async {
    final settings = _validatedSettings(companyProfile.smartBillSettings);
    final client = _validatedBillingClient(billingClient);
    final taxes = await _smartBillService.fetchTaxes(settings);
    final payload = _buildInvoicePayload(
      offer: offer,
      settings: settings,
      client: client,
      taxes: taxes,
    );
    final response = await _smartBillService.issueInvoice(settings, payload);
    return offer.copyWith(
      smartBillInvoice: offer.smartBillInvoice.copyWith(
        syncStatus: OfferSmartBillSyncStatus.issued,
        seriesName: response.series,
        number: response.number,
        documentUrl: response.documentUrl,
        documentViewUrl: response.documentViewUrl,
        publicUrl: response.publicUrl,
        documentId: response.documentId,
        isDraft: settings.useInvoiceDraft,
        issuedAt: DateTime.now(),
        lastSyncedAt: DateTime.now(),
        lastError: '',
      ),
      updatedAt: DateTime.now(),
    );
  }

  Future<OfferRecord> refreshInvoicePaymentStatus({
    required OfferRecord offer,
    required CompanyProfile companyProfile,
  }) async {
    final settings = _validatedSettings(companyProfile.smartBillSettings);
    final invoice = offer.smartBillInvoice;
    if (!invoice.hasDocument) {
      throw SmartBillOfferSyncException(
        'Factura SmartBill nu a fost emisa inca pentru aceasta oferta.',
      );
    }
    final paymentStatus = await _smartBillService.fetchInvoicePaymentStatus(
      settings,
      seriesName: invoice.seriesName,
      number: invoice.number,
    );
    return offer.copyWith(
      smartBillInvoice: invoice.copyWith(
        lastSyncedAt: DateTime.now(),
        lastError: '',
        paymentStatus: invoice.paymentStatus.copyWith(
          invoiceTotalAmount: paymentStatus.invoiceTotalAmount,
          paidAmount: paymentStatus.paidAmount,
          unpaidAmount: paymentStatus.unpaidAmount,
          checkedAt: DateTime.now(),
        ),
      ),
      updatedAt: DateTime.now(),
    );
  }

  OfferRecord markEstimateSyncError(OfferRecord offer, Object error) {
    return offer.copyWith(
      smartBillEstimate: offer.smartBillEstimate.copyWith(
        syncStatus: OfferSmartBillSyncStatus.error,
        lastSyncedAt: DateTime.now(),
        lastError: error.toString().trim(),
      ),
      updatedAt: DateTime.now(),
    );
  }

  OfferRecord markInvoiceSyncError(OfferRecord offer, Object error) {
    return offer.copyWith(
      smartBillInvoice: offer.smartBillInvoice.copyWith(
        syncStatus: OfferSmartBillSyncStatus.error,
        lastSyncedAt: DateTime.now(),
        lastError: error.toString().trim(),
      ),
      updatedAt: DateTime.now(),
    );
  }

  SmartBillSettings _validatedSettings(SmartBillSettings settings) {
    if (!settings.enabled) {
      throw SmartBillOfferSyncException(
        'Integrarea SmartBill este dezactivata in Setari firma.',
      );
    }
    if (!settings.isConfigured) {
      throw SmartBillOfferSyncException(
        'Completeaza email, token si CIF in setarile SmartBill.',
      );
    }
    return settings;
  }

  ClientRecord _validatedBillingClient(ClientRecord? client) {
    if (client == null) {
      throw SmartBillOfferSyncException(
        'Oferta nu are un client comercial valid pentru emitere SmartBill.',
      );
    }
    if (client.name.trim().isEmpty) {
      throw SmartBillOfferSyncException('Clientul nu are nume completat.');
    }
    if (client.address.trim().isEmpty ||
        client.city.trim().isEmpty ||
        client.county.trim().isEmpty) {
      throw SmartBillOfferSyncException(
        'Clientul trebuie sa aiba adresa, localitate si judet completate pentru emiterea SmartBill.',
      );
    }
    return client;
  }

  Map<String, dynamic> _buildEstimatePayload({
    required OfferRecord offer,
    required SmartBillSettings settings,
    required ClientRecord client,
    required List<SmartBillTaxInfo> taxes,
  }) {
    final products = _buildProducts(
      offer: offer,
      taxes: taxes,
      currency: _resolvedCurrency(offer),
    );
    return <String, dynamic>{
      'companyVatCode': settings.companyVatCode.trim(),
      'client': _buildClientPayload(client),
      'issueDate': _formatDate(offer.issueDate),
      'seriesName': settings.estimateSeriesName.trim(),
      'isDraft': settings.useEstimateDraft,
      'currency': _resolvedCurrency(offer),
      if (_resolvedExchangeRate(offer) > 0)
        'exchangeRate': _resolvedExchangeRate(offer),
      'dueDate': _formatDate(offer.validUntil ?? offer.issueDate),
      if (offer.notes.trim().isNotEmpty) 'mentions': offer.notes.trim(),
      'products': products,
    };
  }

  Map<String, dynamic> _buildInvoicePayload({
    required OfferRecord offer,
    required SmartBillSettings settings,
    required ClientRecord client,
    required List<SmartBillTaxInfo> taxes,
  }) {
    final payload = <String, dynamic>{
      'companyVatCode': settings.companyVatCode.trim(),
      'client': _buildClientPayload(client),
      'issueDate': _formatDate(offer.issueDate),
      'seriesName': settings.invoiceSeriesName.trim(),
      'isDraft': settings.useInvoiceDraft,
      'currency': _resolvedCurrency(offer),
      if (_resolvedExchangeRate(offer) > 0)
        'exchangeRate': _resolvedExchangeRate(offer),
      'dueDate': _formatDate(offer.validUntil ?? offer.issueDate),
      'deliveryDate': _formatDate(offer.issueDate),
      if (offer.notes.trim().isNotEmpty) 'mentions': offer.notes.trim(),
    };

    if (offer.smartBillEstimate.hasDocument) {
      payload.addAll(<String, dynamic>{
        'useEstimateDetails': true,
        'estimate': <String, dynamic>{
          'seriesName': offer.smartBillEstimate.seriesName,
          'number': offer.smartBillEstimate.number,
          'useStock': false,
        },
      });
      return payload;
    }

    payload['products'] = _buildProducts(
      offer: offer,
      taxes: taxes,
      currency: _resolvedCurrency(offer),
    );
    return payload;
  }

  Map<String, dynamic> _buildClientPayload(ClientRecord client) {
    final vatCode =
        client.type == ClientType.persoanaFizica ? '-' : client.cui.trim();
    return <String, dynamic>{
      'name': client.name.trim(),
      if (vatCode.isNotEmpty) 'vatCode': vatCode,
      if (client.regCom.trim().isNotEmpty) 'regCom': client.regCom.trim(),
      'address': client.address.trim(),
      'city': client.city.trim(),
      'county': client.county.trim(),
      'country': 'Romania',
      if (client.email.trim().isNotEmpty) 'email': client.email.trim(),
      if (client.contactPerson.trim().isNotEmpty)
        'contact': client.contactPerson.trim(),
      if (client.phone.trim().isNotEmpty) 'phone': client.phone.trim(),
      if (client.bank.trim().isNotEmpty) 'bank': client.bank.trim(),
      if (client.iban.trim().isNotEmpty) 'iban': client.iban.trim(),
      'isTaxPayer': client.type == ClientType.persoanaJuridica,
      'saveToDb': false,
    };
  }

  List<Map<String, dynamic>> _buildProducts({
    required OfferRecord offer,
    required List<SmartBillTaxInfo> taxes,
    required String currency,
  }) {
    final lines = buildCommercialOfferLines(offer.lines)
        .where((line) => line.name.trim().isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      throw SmartBillOfferSyncException(
        'Oferta nu contine pozitii comerciale care pot fi emise in SmartBill.',
      );
    }

    final tax = _resolveTax(offer.vatPercent, taxes);
    return lines.map((line) {
      final quantity = line.quantity <= 0 ? 1.0 : line.quantity;
      final unitPrice = line.unitPrice > 0
          ? line.unitPrice
          : (line.effectiveLineTotal > 0
              ? line.effectiveLineTotal / quantity
              : 0);
      final product = <String, dynamic>{
        'name': line.name.trim(),
        if (line.id.trim().isNotEmpty && !line.id.startsWith('__'))
          'code': line.id.trim(),
        if (line.description.trim().isNotEmpty)
          'productDescription': line.description.trim(),
        'isDiscount': false,
        'measuringUnitName':
            line.unit.trim().isEmpty ? 'buc' : line.unit.trim(),
        'currency': currency,
        'quantity': quantity,
        'price': unitPrice,
        'isTaxIncluded': false,
        'saveToDb': false,
        'isService': line.lineType != OfferLineType.material,
      };
      if (offer.vatPercent > 0) {
        if (tax == null) {
          throw SmartBillOfferSyncException(
            'Nu exista in SmartBill o cota TVA compatibila cu ${offer.vatPercent.toStringAsFixed(2)}%.',
          );
        }
        product['taxName'] = tax.name;
        product['taxPercentage'] = tax.percentage;
      }
      return product;
    }).toList(growable: false);
  }

  SmartBillTaxInfo? _resolveTax(
    double vatPercent,
    List<SmartBillTaxInfo> taxes,
  ) {
    if (vatPercent <= 0) {
      return null;
    }
    for (final tax in taxes) {
      if ((tax.percentage - vatPercent).abs() < 0.001) {
        return tax;
      }
    }
    return null;
  }

  String _resolvedCurrency(OfferRecord offer) {
    return OfferCurrencyConverter.normalizeCurrency(offer.currency);
  }

  double _resolvedExchangeRate(OfferRecord offer) {
    final currency = _resolvedCurrency(offer);
    if (currency == 'RON') {
      return 1;
    }
    return offer.effectiveExchangeRate > 0 ? offer.effectiveExchangeRate : 0;
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class SmartBillOfferSyncException implements Exception {
  SmartBillOfferSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}
