import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/company_profile.dart';
import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/widgets/app_card.dart';
import '../../../core/integrations/smartbill_service.dart';
import '../../../core/integrations/smartbill_stock_cache_service.dart';
import '../../../core/widgets/smartbill_bon_consum_dialog.dart';
import '../../clients/client_models.dart';
import '../offer_models.dart';
import '../offer_smartbill_models.dart';
import '../offer_smartbill_sync_service.dart';
import '../oferta_detaliu_page.dart' show OfertaDetaliuPage;

/// Secțiunea SmartBill din [OfertaDetaliuPage]: emitere proformă/factură,
/// bon de consum, afișare documente SmartBill asociate ofertei.
mixin OffertaDetaliuSmartbillMixin on State<OfertaDetaliuPage> {
  OfferRecord get offer;
  set offer(OfferRecord value);

  /// Furnizat de [_OfertaDetaliuPageState] — căutare client din lista widget.clients după id.
  ClientRecord? clientRecordById(String clientId);

  /// Furnizat de OffertaDetaliuFormattingMixin.
  String formatDate(DateTime? value);

  final OfferSmartBillSyncService _smartBillSyncService =
      OfferSmartBillSyncService();
  final SmartBillStockCacheService _stockCacheService =
      SmartBillStockCacheService();
  Map<String, SmartBillStockItem> _smartbillStock = {};
  bool _smartBillSyncing = false;
  bool _smartBillRefreshingStatus = false;

  /// Preia stocul SmartBill din cache (auto la deschidere).
  Future<void> loadSmartBillStock() async {
    try {
      final profile = await widget.repository.loadCompanyProfile();
      final settings = profile.smartBillSettings;
      if (!settings.isConsumptionConfigured) return;
      final stock = await _stockCacheService.syncIfStale(settings);
      if (!mounted) return;
      setState(() => _smartbillStock = stock);
    } catch (_) {
      // Silențios — stocul rămâne gol dacă SmartBill nu e configurat/accesibil
    }
  }

  ClientRecord? _resolveSmartBillBillingClient() {
    final candidates = <ClientRecord?>[
      clientRecordById(offer.commercialRecipientClientId),
      clientRecordById(offer.clientId),
      clientRecordById(offer.beneficiaryClientId),
    ];
    for (final candidate in candidates.whereType<ClientRecord>()) {
      return candidate;
    }
    return null;
  }

  Future<void> _persistSmartBillState(
    OfferRecord next, {
    String? snackMessage,
  }) async {
    await widget.onSaveOffer(next);
    if (!mounted) {
      return;
    }
    setState(() => offer = next);
    if ((snackMessage ?? '').trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(snackMessage!)),
      );
    }
  }

  Future<void> _issueSmartBillEstimate() async {
    if (_smartBillSyncing) {
      return;
    }
    setState(() => _smartBillSyncing = true);
    try {
      final profile = await widget.repository.loadCompanyProfile();
      final updated = await _smartBillSyncService.issueEstimate(
        offer: offer,
        companyProfile: profile,
        billingClient: _resolveSmartBillBillingClient(),
      );
      await _persistSmartBillState(
        updated,
        snackMessage:
            'Proforma SmartBill a fost emisa: ${updated.smartBillEstimate.seriesName}${updated.smartBillEstimate.number}.',
      );
    } catch (error) {
      final failed = _smartBillSyncService.markEstimateSyncError(offer, error);
      await _persistSmartBillState(failed);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Emiterea proformei SmartBill a esuat: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _smartBillSyncing = false);
      }
    }
  }

  Future<void> _issueSmartBillInvoice() async {
    if (_smartBillSyncing) {
      return;
    }
    setState(() => _smartBillSyncing = true);
    try {
      final profile = await widget.repository.loadCompanyProfile();
      final updated = await _smartBillSyncService.issueInvoice(
        offer: offer,
        companyProfile: profile,
        billingClient: _resolveSmartBillBillingClient(),
      );
      await _persistSmartBillState(
        updated,
        snackMessage:
            'Factura SmartBill a fost emisa: ${updated.smartBillInvoice.seriesName}${updated.smartBillInvoice.number}.',
      );
    } catch (error) {
      final failed = _smartBillSyncService.markInvoiceSyncError(offer, error);
      await _persistSmartBillState(failed);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Emiterea facturii SmartBill a esuat: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _smartBillSyncing = false);
      }
    }
  }

  Future<void> _refreshSmartBillInvoiceStatus() async {
    if (_smartBillRefreshingStatus) {
      return;
    }
    setState(() => _smartBillRefreshingStatus = true);
    try {
      final profile = await widget.repository.loadCompanyProfile();
      final updated = await _smartBillSyncService.refreshInvoicePaymentStatus(
        offer: offer,
        companyProfile: profile,
      );
      await _persistSmartBillState(
        updated,
        snackMessage: 'Statusul facturii SmartBill a fost actualizat.',
      );
    } catch (error) {
      final failed = _smartBillSyncService.markInvoiceSyncError(offer, error);
      await _persistSmartBillState(failed);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Nu am putut actualiza statusul SmartBill: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _smartBillRefreshingStatus = false);
      }
    }
  }

  Future<void> _openExternalSmartBillUrl(
    String rawUrl,
    String label,
  ) async {
    final value = rawUrl.trim();
    if (value.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(value);
    if (uri == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link invalid pentru $label.')),
      );
      return;
    }
    final canOpen = await canLaunchUrl(uri);
    if (canOpen) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nu am putut deschide linkul $label.')),
    );
  }

  /// Emite bon de consum SmartBill cu materialele din ofertă.
  Future<void> emiteBonConsum() async {
    // Extrage materialele din ofertă (linii de tip material cu cantitate > 0)
    final materiale = <BonConsumArticol>[];
    for (final line in offer.lines) {
      if (line.lineType != OfferLineType.material) continue;
      if (line.name.trim().isEmpty) continue;
      if (line.quantity <= 0) continue;
      materiale.add(BonConsumArticol(
        denumire: line.name.trim(),
        cantitate: line.quantity,
        um: line.unit.isNotEmpty ? line.unit : 'buc',
        pretUnitar: line.unitPrice,
      ));
    }

    if (materiale.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nu există materiale cu cantitate în ofertă.'),
        ),
      );
      return;
    }

    // Preia setările SmartBill
    CompanyProfile profile;
    try {
      profile = await widget.repository.loadCompanyProfile();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu s-a putut accesa profilul firmei.')),
      );
      return;
    }

    final settings = profile.smartBillSettings;
    if (!settings.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'SmartBill nu este configurat. Mergi la Setări → SmartBill.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    final titlu = offer.offerNumber.trim().isNotEmpty
        ? 'Ofertă ${offer.offerNumber}'
        : offer.title.trim().isNotEmpty
            ? offer.title.trim()
            : 'Ofertă client';

    final response = await showDialog<SmartBillConsumptionNoteResponse>(
      context: context,
      builder: (_) => SmartBillBonConsumDialog(
        settings: settings,
        articole: materiale,
        documentTitle: titlu,
        stockMap: _smartbillStock,
      ),
    );

    if (response != null && mounted) {
      final label = response.documentLabel.isNotEmpty
          ? response.documentLabel
          : 'emis cu succes';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bon de consum $label emis în SmartBill.'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  String _smartBillDocumentCaption(OfferSmartBillDocumentState document) {
    if (!document.hasDocument) {
      if (document.lastError.trim().isNotEmpty) {
        return '${document.syncStatus.label} • ${document.lastError.trim()}';
      }
      return document.syncStatus.label;
    }
    final issuedAt =
        document.issuedAt == null ? '' : ' • ${formatDate(document.issuedAt)}';
    final suffix = document.isDraft ? ' • ciorna' : '';
    return '${document.syncStatus.label} • ${document.seriesName}${document.number}$issuedAt$suffix';
  }

  Widget _buildSmartBillDocumentTile(OfferSmartBillDocumentState document) {
    final canOpenView = document.documentViewUrl.trim().isNotEmpty;
    final canOpenCloud = document.documentUrl.trim().isNotEmpty;
    final canOpenPublic = document.publicUrl.trim().isNotEmpty;
    final payment = document.paymentStatus;
    return AppCard(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            document.documentType.label,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            _smartBillDocumentCaption(document),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (payment.hasValues) ...[
            const SizedBox(height: 6),
            Text(
              'Total: ${payment.invoiceTotalAmount.toStringAsFixed(2)} • Incasat: ${payment.paidAmount.toStringAsFixed(2)} • Rest: ${payment.unpaidAmount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: canOpenView
                    ? () => _openExternalSmartBillUrl(
                          document.documentViewUrl,
                          document.documentType.label,
                        )
                    : null,
                icon: const Icon(Icons.open_in_new_outlined),
                label: const Text('Deschide document'),
              ),
              OutlinedButton.icon(
                onPressed: canOpenCloud
                    ? () => _openExternalSmartBillUrl(
                          document.documentUrl,
                          'document cloud',
                        )
                    : null,
                icon: const Icon(Icons.cloud_outlined),
                label: const Text('Cloud'),
              ),
              OutlinedButton.icon(
                onPressed: canOpenPublic
                    ? () => _openExternalSmartBillUrl(
                          document.publicUrl,
                          'link public',
                        )
                    : null,
                icon: const Icon(Icons.link_outlined),
                label: const Text('Link public'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSmartBillSection() {
    final billingClient = _resolveSmartBillBillingClient();
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SmartBill',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            billingClient == null
                ? 'Clientul comercial nu a fost gasit in nomenclator. Emiterea SmartBill va cere un client complet configurat.'
                : 'Client comercial pentru emitere: ${billingClient.name}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _smartBillSyncing ? null : _issueSmartBillEstimate,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Emite proforma'),
              ),
              FilledButton.tonalIcon(
                onPressed: _smartBillSyncing ? null : _issueSmartBillInvoice,
                icon: const Icon(Icons.request_quote_outlined),
                label: const Text('Emite factura'),
              ),
              OutlinedButton.icon(
                onPressed: (_smartBillRefreshingStatus ||
                        !offer.smartBillInvoice.hasDocument)
                    ? null
                    : _refreshSmartBillInvoiceStatus,
                icon: const Icon(Icons.sync_outlined),
                label: const Text('Actualizeaza status'),
              ),
            ],
          ),
          _buildSmartBillDocumentTile(offer.smartBillEstimate),
          _buildSmartBillDocumentTile(offer.smartBillInvoice),
        ],
      ),
    );
  }
}
