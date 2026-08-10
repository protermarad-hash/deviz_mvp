import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/widgets/app_card.dart';
import '../../reclamatii/signature_capture_page.dart';
import '../clauza_catalog_repository.dart';
import '../offer_acceptance_clauses_dialog.dart';
import '../offer_acceptance_models.dart';
import '../offer_currency_converter.dart';
import '../offer_models.dart';
import '../oferta_detaliu_page.dart' show OfertaDetaliuPage;

/// Formular acceptare client (clauze + semnătură acceptare) și semnăturile
/// client/emitent, pentru [OfertaDetaliuPage].
mixin OffertaDetaliuAcceptanceMixin on State<OfertaDetaliuPage> {
  OfferRecord get offer;
  set offer(OfferRecord value);

  /// Furnizate de [_OfertaDetaliuPageState].
  bool get saving;
  String formatDate(DateTime? value);

  Uint8List? _decodeSignature(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }
    try {
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveOperationalMetadata(OfferRecord next) async {
    final saved = next.copyWith(updatedAt: DateTime.now());
    await widget.onSaveOffer(saved);
    setState(() => offer = saved);
  }

  Future<void> _captureSignature({
    required String title,
    required bool isClient,
  }) async {
    final bytes =
        await Navigator.of(context, rootNavigator: true).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SignatureCapturePage(title: title),
      ),
    );
    if (!mounted || bytes == null) {
      return;
    }
    final encoded = base64Encode(bytes);
    final next = isClient
        ? offer.copyWith(
            clientSignatureBase64: encoded,
            agreementAcceptedAt: DateTime.now(),
            clearAgreementAcceptedAt: false,
          )
        : offer.copyWith(
            issuerSignatureBase64: encoded,
          );
    await _saveOperationalMetadata(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isClient
              ? 'Semnatura clientului a fost salvata.'
              : 'Semnatura emitentului a fost salvata.',
        ),
      ),
    );
  }

  Future<void> _clearSignature({required bool isClient}) async {
    final next = isClient
        ? offer.copyWith(
            clientSignatureBase64: '',
            agreementAcceptedAt: null,
            clearAgreementAcceptedAt: true,
          )
        : offer.copyWith(
            issuerSignatureBase64: '',
          );
    await _saveOperationalMetadata(next);
  }

  // ---------------------------------------------------------------------------
  // Formular de Acceptare Ofertă
  // ---------------------------------------------------------------------------

  List<OfferAcceptanceClause> _resolvedAcceptanceClauses() {
    if (offer.acceptanceClauses.isNotEmpty) return offer.acceptanceClauses;
    // Generează clauze default cu totalul ofertei (CU TVA), convertit în
    // moneda ofertei — identic cu caseta „VALOARE TOTALĂ" din formular.
    final totalStr = OfferCurrencyConverter.convertRonToOfferCurrency(
      ronAmount: offer.totalValue,
      currency: offer.currency,
      effectiveRate: offer.effectiveExchangeRate,
    ).toStringAsFixed(2);
    return OfferAcceptanceClause.defaults(
      totalLabel: totalStr,
      currency: OfferCurrencyConverter.normalizeCurrency(offer.currency),
    );
  }

  Future<void> _openAcceptanceClausesEditor() async {
    final base = _resolvedAcceptanceClauses();
    // Adaugă clauzele custom din catalog care nu există deja pe ofertă
    // (după titlu, case-insensitive), TOATE nebifate (enabled=false) — devin
    // disponibile pentru selectare rapidă fără retastare.
    final existingTitles =
        base.map((c) => c.title.toLowerCase().trim()).toSet();
    final catalog = await ClauzaCatalogRepository.instance.listClauzeCustom();
    if (!mounted) return;
    var nextOrder =
        base.fold<int>(0, (m, c) => c.sortOrder > m ? c.sortOrder : m);
    final extra = catalog
        .where((c) => !existingTitles.contains(c.title.toLowerCase().trim()))
        .map((c) => c.copyWith(enabled: false, sortOrder: ++nextOrder))
        .toList();
    final current = [...base, ...extra];
    final updated = await OfferAcceptanceClausesDialog.show(context, current);
    if (updated == null || !mounted) return;
    final next = offer.copyWith(acceptanceClauses: updated);
    await _saveOperationalMetadata(next);
  }

  Future<void> _captureAcceptanceSignature() async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (_) =>
            const SignatureCapturePage(title: 'Semnătură acceptare ofertă'),
      ),
    );
    if (bytes == null || !mounted) return;
    final b64 = base64Encode(bytes);
    final next = offer.copyWith(
      acceptanceFormSignatureBase64: b64,
      acceptanceFormSignedAt: DateTime.now(),
    );
    await _saveOperationalMetadata(next);
  }

  Future<void> _clearAcceptanceSignature() async {
    final next = offer.copyWith(
      acceptanceFormSignatureBase64: '',
      clearAcceptanceFormSignedAt: true,
    );
    await _saveOperationalMetadata(next);
  }

  Widget buildAcceptanceFormCard() {
    final cs = Theme.of(context).colorScheme;
    final isSigned = offer.isAcceptanceSigned;
    final signedDate = isSigned && offer.acceptanceFormSignedAt != null
        ? formatDate(offer.acceptanceFormSignedAt)
        : null;

    // Decodează semnătura pentru preview
    Uint8List? sigBytes;
    if (isSigned && offer.acceptanceFormSignatureBase64.isNotEmpty) {
      sigBytes = _decodeSignature(offer.acceptanceFormSignatureBase64);
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titlu card
          Row(
            children: [
              Icon(Icons.article_outlined, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Formular de Acceptare Ofertă',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSigned
                      ? Colors.green.shade50
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSigned ? Colors.green.shade300 : cs.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSigned
                          ? Icons.check_circle_outline
                          : Icons.pending_outlined,
                      size: 14,
                      color: isSigned
                          ? Colors.green.shade700
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSigned
                          ? 'Semnat${signedDate != null ? " · $signedDate" : ""}'
                          : 'Nesemnat',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSigned
                            ? Colors.green.shade700
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Mini-contract cu clauze comerciale pre-setate, trimis împreună cu oferta pentru acceptare și semnare.',
            style: AppTypography.caption(context)
                ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
          ),

          const SizedBox(height: 14),

          // Preview semnătură dacă există
          if (sigBytes != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Semnătură client acceptare',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: cs.outline),
                  ),
                  const SizedBox(height: 4),
                  Image.memory(sigBytes, height: 60, fit: BoxFit.contain),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Butoane acțiuni
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: saving ? null : _openAcceptanceClausesEditor,
                icon: const Icon(Icons.tune_outlined, size: 16),
                label: const Text('Editează clauze'),
              ),
              FilledButton.tonal(
                onPressed: saving ? null : _captureAcceptanceSignature,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.draw_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(isSigned ? 'Resemnează pe loc' : 'Semnează pe loc'),
                  ],
                ),
              ),
              if (isSigned)
                TextButton.icon(
                  onPressed: saving ? null : _clearAcceptanceSignature,
                  icon: Icon(Icons.clear, size: 16, color: cs.error),
                  label: Text('Resetează semnătura',
                      style: TextStyle(color: cs.error)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget signatureCard({
    required String title,
    required String raw,
    required bool isClient,
    String subtitle = '',
  }) {
    final bytes = _decodeSignature(raw);
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 10),
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: bytes == null
                ? Text(
                    'Fara semnatura',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                : Image.memory(bytes, fit: BoxFit.contain),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _captureSignature(
                  title: title,
                  isClient: isClient,
                ),
                icon: const Icon(Icons.draw_outlined),
                label: const Text('Semnează'),
              ),
              OutlinedButton.icon(
                onPressed: raw.trim().isEmpty
                    ? null
                    : () => _clearSignature(isClient: isClient),
                icon: const Icon(Icons.restart_alt_outlined),
                label: const Text('Resetează'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
