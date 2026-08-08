import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/pdf_export_settings.dart';
import '../offer_models.dart';
import '../offer_pdf_service.dart';
import '../oferta_detaliu_page.dart' show OfertaDetaliuPage;

/// Selector rapid pentru șablonul PDF și curățarea PDF-urilor vechi ale
/// ofertei, pentru [OfertaDetaliuPage].
mixin OffertaDetaliuPdfMixin on State<OfertaDetaliuPage> {
  /// Furnizate de [_OfertaDetaliuPageState] — starea șablonului PDF e
  /// partajată cu fluxul de generare PDF (rămas în clasa principală).
  bool get saving;
  bool get exportingPdf;
  bool get converting;
  bool get pdfTemplateLoaded;
  set pdfTemplateLoaded(bool value);
  PdfVisualTemplate get selectedPdfTemplate;
  set selectedPdfTemplate(PdfVisualTemplate value);

  Future<void> loadPdfTemplatePreference() async {
    final profile = await widget.repository.loadCompanyProfile();
    if (!mounted) return;
    setState(() {
      selectedPdfTemplate = profile.pdfExportSettings.visualTemplate;
      pdfTemplateLoaded = true;
    });
  }

  Widget buildPdfTemplateSelectorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sablon PDF',
              style: AppTypography.headingSmall(context),
            ),
            const SizedBox(height: 6),
            Text(
              'Selector rapid pentru generare, Save As si Share direct din aceasta oferta.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<PdfVisualTemplate>(
              initialValue: selectedPdfTemplate,
              decoration: const InputDecoration(
                labelText: 'Model document',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: PdfVisualTemplate.values
                  .map(
                    (template) => DropdownMenuItem<PdfVisualTemplate>(
                      value: template,
                      child: Text(template.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (saving || exportingPdf || converting)
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => selectedPdfTemplate = value);
                    },
            ),
            const SizedBox(height: 6),
            Text(
              selectedPdfTemplate.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// Șterge toate fișierele PDF vechi ale ofertei din același director ca [newPath].
  /// Fiecare generare creează un fișier cu timestamp unic — le curățăm pe cele vechi.
  void cleanupOldOfferPdfs({required String newPath, required OfferRecord offer}) {
    if (newPath.isEmpty) return;
    try {
      final newFile = File(newPath);
      final dir = newFile.parent;
      if (!dir.existsSync()) return;
      final prefix = OfferPdfService.exportFilePrefix(offer).toLowerCase();
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last.toLowerCase();
        if (name == newFile.uri.pathSegments.last.toLowerCase()) continue;
        if (name.startsWith(prefix) && name.endsWith('.pdf')) {
          try {
            entity.deleteSync();
          } catch (_) {/* intenționat ignorat: ștergere best-effort PDF temporar vechi */}
        }
      }
    } catch (_) {/* intenționat ignorat: curățare best-effort director PDF-uri vechi */}
  }
}
