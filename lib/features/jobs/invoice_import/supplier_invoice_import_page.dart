// FAZA 1 / FAZA 2 — ecran "Import materiale din factura": upload/reia XML
// e-Factura, parsare server-side sau reutilizare factura existenta,
// PREVIEW editabil, import confirmat in materialele lucrarii.
//
// FAZA 2: butonul final este "Importa in lucrare" — apasarea lui scrie
// efectiv materiale noi in JobRecord.materials (prin exact acelasi
// mecanism folosit de adaugarea manuala, `_persistJobMaterials` din
// lucrare_detalii_page.dart — NU o cale noua/paralela). Aceasta pagina
// NU scrie ea insasi in `materials`: construieste lista de linii noi si o
// intoarce parintelui prin `Navigator.pop`, care face salvarea efectiva
// (vezi `_openSupplierInvoiceImportPage` in lucrare_detalii_page.dart).

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/auth/app_role_policy.dart';
import '../../../core/auth_models.dart';
import '../../master/master_local_store.dart';
import '../../materials/materials_catalog_service.dart';
import '../job_models.dart';
import 'supplier_invoice_catalog_matcher.dart';
import 'supplier_invoice_job_material_mapper.dart';
import 'supplier_invoice_models.dart';
import 'supplier_invoice_parser_client.dart';
import 'supplier_invoice_repository.dart';

/// Rezultatul intors de acest ecran catre pagina lucrarii, dupa ce
/// utilizatorul a confirmat importul. Parintele face salvarea reala in
/// `JobRecord.materials` si, doar dupa succes, actualizeaza metadata
/// facturii (linkedJobIds/status) si creeaza materialele noi in catalog.
class SupplierInvoiceImportOutcome {
  const SupplierInvoiceImportOutcome({
    required this.invoiceId,
    required this.newMaterialRows,
    required this.materialsToCreateInCatalog,
  });

  final String invoiceId;
  final List<Map<String, dynamic>> newMaterialRows;
  final List<MasterMaterial> materialsToCreateInCatalog;
}

class SupplierInvoiceImportPage extends StatefulWidget {
  const SupplierInvoiceImportPage({
    super.key,
    required this.job,
    this.roleKey,
  });

  final JobRecord job;
  final String? roleKey;

  @override
  State<SupplierInvoiceImportPage> createState() =>
      _SupplierInvoiceImportPageState();
}

class _SupplierInvoiceImportPageState extends State<SupplierInvoiceImportPage> {
  final SupplierInvoiceParserClient _parserClient =
      SupplierInvoiceParserClient();
  final SupplierInvoiceRepository _repository = SupplierInvoiceRepository();

  bool get _isAuthorized =>
      AppRolePolicy.fromRoleKey(widget.roleKey) == UserRole.admin;

  String? _fileName;

  bool _isParsing = false;
  bool _isSaving = false;
  String? _errorMessage;

  /// Non-null dupa orice parsare reusita — id-ul canonic, calculat
  /// server-side. FAZA "persist invoice metadata server-side": serverul
  /// garanteaza ca documentul Firestore + liniile sunt deja persistate
  /// (fresh-creat sau reutilizat) inainte ca acest id sa ajunga la client,
  /// deci nu mai exista o stare intermediara "id cunoscut, dar metadata
  /// inca nescrisa" de urmarit separat.
  String? _invoiceId;

  SupplierInvoiceParsedHeader? _header;
  List<SupplierInvoicePreviewLine> _lines =
      const <SupplierInvoicePreviewLine>[];

  bool get _allSelected =>
      _selectableLines.isNotEmpty && _selectableLines.every((l) => l.selected);

  Iterable<SupplierInvoicePreviewLine> get _selectableLines =>
      _lines.where((l) => !l.alreadyImported);

  List<SupplierInvoicePreviewLine> get _selectedValidLines => _lines
      .where((l) => l.selected && l.isValidForJobImport)
      .toList(growable: false);

  int get _selectedCount => _lines.where((l) => l.selected).length;

  bool get _canImport =>
      !_isSaving &&
      _selectedValidLines.isNotEmpty &&
      _lines.where((l) => l.selected).every((l) => l.isValidForJobImport);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import materiale din factura')),
      body: !_isAuthorized
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aceasta functie este disponibila doar pentru administrator.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _header == null
              ? _buildPickStep(context)
              : _buildPreviewStep(context),
    );
  }

  // ── Pasul 1: alegere fisier XML (sau reutilizare factura existenta) ──

  Widget _buildPickStep(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Lucrare: ${widget.job.title.isEmpty ? widget.job.jobCode : widget.job.title}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Aceasta faza accepta DOAR fisiere XML e-Factura (format UBL). '
              'PDF/imagini nu sunt suportate in aceasta versiune. Daca '
              'factura a mai fost importata (acelasi fisier), va fi '
              'reutilizata automat — nu se creeaza duplicat.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_isParsing)
              const CircularProgressIndicator()
            else
              FilledButton.icon(
                onPressed: _pickAndParseFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Alege fisier XML e-Factura'),
              ),
            if (_fileName != null) ...[
              const SizedBox(height: 12),
              Text('Fisier: $_fileName'),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndParseFile() async {
    setState(() => _errorMessage = null);
    final result = await FilePicker.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const <String>['xml'],
    );
    if (!mounted || result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _errorMessage = 'Nu am putut citi continutul fisierului.');
      return;
    }

    setState(() {
      _isParsing = true;
      _fileName = picked.name;
    });

    try {
      // FAZA "reconcile prin server" — NU mai exista niciun shortcut care
      // sare peste server. Motiv (audit hash/dedup, vezi raportul
      // dedicat): shortcut-ul vechi decidea reutilizarea PE BAZA hash-ului
      // local (bytes brute, poate include BOM), ceea ce putea sari peste
      // apelul catre parseSupplierInvoiceXml — si deci peste
      // auto-repararea `source.xml` in Storage daca lipsea, chiar daca
      // documentul Firestore exista deja. Acum, la FIECARE alegere de
      // fisier: server-ul e apelat intotdeauna, iar `invoiceId`-ul lui e
      // singura autoritate pentru identitatea facturii.
      //
      // `localHash` (bytes brute) NU mai decide nimic — e pastrat STRICT
      // ca diagnostic (util doar la depanare: confirma daca hash-ul local
      // coincide sau nu cu cel canonic, ex. cazul BOM).
      final localHash = _repository.computeSha256(bytes);
      debugPrint('[InvoiceImport] localHash (diagnostic, bytes brute)=$localHash');

      final xmlText = decodeXmlBytesToUtf8Text(bytes);
      final parseResult = await _parserClient.parseXml(xmlText);
      if (!mounted) return;

      final bomMismatch = localHash != parseResult.invoiceId;
      if (bomMismatch) {
        debugPrint('[InvoiceImport] localHash difera de invoiceId server '
            '(probabil BOM) — invoiceId server ramane autoritar.');

        // Fallback LEGACY — DOAR cand localHash difera de invoiceId-ul
        // canonic (cazul BOM): mai verificam si dupa hash-ul vechi (bytes
        // brute), pentru cazul rar in care aceeasi factura fizica a fost
        // deja importata de o versiune anterioara a aplicatiei (care
        // folosea hash-ul pe bytes brute ca invoiceId). Daca gasim un
        // document legacy, il reutilizam — NU cream un al doilea document
        // Firestore pentru aceeasi factura. `source.xml` deja persistat
        // server-side sub id-ul canonic ramane, in acest caz rar, orfan la
        // path-ul canonic — acceptabil prin design (vezi nota FAZA 6
        // despre fisiere orfane deterministe), NU necesita curatare.
        final legacyExisting =
            await _repository.loadExistingInvoiceByHash(localHash);
        if (legacyExisting != null) {
          if (!mounted) return;
          debugPrint('[InvoiceImport] factura legacy gasita dupa localHash '
              '— reutilizata, fara duplicat.');
          _applyLoadedInvoice(legacyExisting);
          return;
        }
      }

      // FAZA "persist invoice metadata server-side" — `parseResult` este
      // AUTORITAR si complet: serverul a persistat deja (creat sau
      // reutilizat, idempotent) atat `source.xml` in Storage cat si
      // documentul `supplier_invoices/{invoiceId}` + liniile in Firestore,
      // INAINTE de a raspunde (vezi parseSupplierInvoiceXml). Nu mai e
      // nevoie de niciun apel Firestore suplimentar aici pentru cazul
      // canonic — liniile primite au deja `lineDocId` populat corect,
      // fresh-creat sau reutilizat.
      assert(parseResult.invoicePersisted, 'serverul garanteaza acest lucru sau arunca');
      setState(() {
        _invoiceId = parseResult.invoiceId;
        _header = parseResult.header;
        _lines = parseResult.lines;
        _isParsing = false;
      });
      _markAlreadyImportedLines();
    } on SupplierInvoiceParseException catch (error) {
      if (!mounted) return;
      setState(() {
        _isParsing = false;
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isParsing = false;
        _errorMessage = 'Eroare neasteptata la parsare: $error';
      });
    }
  }

  void _applyLoadedInvoice(SupplierInvoiceLoaded loaded) {
    setState(() {
      _invoiceId = loaded.invoiceId;
      _header = loaded.header;
      _lines = loaded.lines;
      _isParsing = false;
    });
    _markAlreadyImportedLines();
  }

  /// FAZA 2 pct. 9 — marcheaza liniile deja importate in LUCRAREA
  /// CURENTA (dupa sourceInvoiceId + lineDocId), le deselecteaza si le
  /// exclude din selectie ("deja importata", nu doar dupa denumire).
  void _markAlreadyImportedLines() {
    final invoiceId = _invoiceId;
    if (invoiceId == null) return;
    final alreadyImported = alreadyImportedLineDocIds(
      jobMaterials: widget.job.materials,
      invoiceId: invoiceId,
    );
    if (alreadyImported.isEmpty) return;
    setState(() {
      for (final line in _lines) {
        if (line.lineDocId != null &&
            alreadyImported.contains(line.lineDocId)) {
          line.alreadyImported = true;
          line.selected = false;
        }
      }
    });
  }

  // ── Pasul 2: preview editabil ───────────────────────────────────────

  Widget _buildPreviewStep(BuildContext context) {
    final header = _header!;
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  header.supplierName ?? '(furnizor necunoscut)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (header.supplierTaxId != null)
                  Text('CUI: ${header.supplierTaxId}'),
                Text(
                  'Factura ${header.invoiceNumber ?? '(numar necunoscut)'} '
                  '${header.invoiceDate != null ? '• ${header.invoiceDate}' : ''}',
                ),
                if (header.totalWithoutVat != null)
                  Text(
                    'Total fara TVA (din XML): '
                    '${header.totalWithoutVat!.toStringAsFixed(2)} '
                    '${header.currency ?? ''}',
                  ),
                if (_invoiceId != null)
                  Text(
                    'Factura salvata (id: $_invoiceId).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Checkbox(
                value: _allSelected,
                onChanged: (checked) {
                  setState(() {
                    for (final line in _selectableLines) {
                      line.selected = checked ?? false;
                    }
                  });
                },
              ),
              const Text('Selecteaza toate'),
              const Spacer(),
              Text('$_selectedCount / ${_lines.length} selectate'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _lines.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _buildLineCard(_lines[index]),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              TextButton(
                onPressed: _isSaving ? null : _resetToPickStep,
                child: const Text('Renunta'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _canImport ? _onConfirmImportPressed : null,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_add_check_outlined),
                label: const Text('Importa in lucrare'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLineCard(SupplierInvoicePreviewLine line) {
    final theme = Theme.of(context);
    final disabled = line.alreadyImported;
    return Card(
      color: disabled
          ? theme.colorScheme.surfaceContainerHighest
          : (line.hasProblem
              ? theme.colorScheme.errorContainer.withValues(alpha: 0.25)
              : null),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: line.selected,
                  onChanged: disabled
                      ? null
                      : (checked) =>
                          setState(() => line.selected = checked ?? false),
                ),
                if (disabled)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text('Deja importata'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (line.supplierProductCode != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(line.supplierProductCode!),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                Expanded(
                  child: TextFormField(
                    initialValue: line.displayName,
                    enabled: !disabled,
                    decoration: const InputDecoration(
                      labelText: 'Denumire',
                      isDense: true,
                    ),
                    onChanged: (value) => line.editedName = value,
                  ),
                ),
              ],
            ),
            if (line.rawName != line.displayName)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 2),
                child: Text(
                  'Text original din factura: "${line.rawName}"',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _numberField(
                    label: 'Cantitate facturata',
                    value: line.quantity,
                    enabled: !disabled,
                    onChanged: (v) => line.quantity = v,
                  ),
                  _numberField(
                    label: 'Cantitate alocata',
                    value: line.allocatedQty,
                    enabled: !disabled,
                    onChanged: (v) => line.allocatedQty = v,
                  ),
                  _textField(
                    label: 'UM',
                    value: line.friendlyUnit,
                    enabled: !disabled,
                    onChanged: (v) =>
                        line.unit = v.trim().isEmpty ? null : v.trim(),
                  ),
                  _numberField(
                    label: 'Pret fara TVA',
                    value: line.unitPriceNoVat,
                    enabled: !disabled,
                    onChanged: (v) => line.unitPriceNoVat = v,
                  ),
                  SizedBox(
                    width: 140,
                    child: Text(
                      'Valoare alocata: '
                      '${line.allocatedLineTotalNoVat?.toStringAsFixed(2) ?? '—'} '
                      '${line.currency ?? ''}',
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      'TVA: ${line.vatRate != null ? '${line.vatRate!.toStringAsFixed(0)}%' : '—'}',
                    ),
                  ),
                ],
              ),
            ),
            if (!disabled && line.jobImportBlockReason != null)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 4),
                child: Text(
                  line.jobImportBlockReason!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            if (line.warnings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 4),
                child: Text(
                  line.warnings.join(' '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _textField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    bool enabled = true,
  }) {
    return SizedBox(
      width: 90,
      child: TextFormField(
        initialValue: value,
        enabled: enabled,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: onChanged,
      ),
    );
  }

  Widget _numberField({
    required String label,
    required double? value,
    required ValueChanged<double?> onChanged,
    bool enabled = true,
  }) {
    return SizedBox(
      width: 130,
      child: TextFormField(
        initialValue: value?.toString() ?? '',
        enabled: enabled,
        decoration: InputDecoration(labelText: label, isDense: true),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (text) {
          final normalized = text.trim().replaceAll(',', '.');
          onChanged(normalized.isEmpty ? null : double.tryParse(normalized));
        },
      ),
    );
  }

  void _resetToPickStep() {
    setState(() {
      _fileName = null;
      _invoiceId = null;
      _header = null;
      _lines = const <SupplierInvoicePreviewLine>[];
      _errorMessage = null;
    });
  }

  Future<void> _onConfirmImportPressed() async {
    final selected = _selectedValidLines;
    if (selected.isEmpty) return;

    final totalValue = selected.fold<double>(
      0,
      (sum, l) => sum + (l.allocatedLineTotalNoVat ?? 0),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirma importul'),
        content: Text(
          'Vor fi adaugate ${selected.length} pozitii in lucrare, '
          'in valoare totala de ${totalValue.toStringAsFixed(2)} RON fara TVA.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirma importul'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    debugPrint('IMPORT_STEP_01 confirm pressed t=${DateTime.now().toIso8601String()} selectedCount=${selected.length}');

    await _doImport(selected);
  }

  Future<void> _doImport(List<SupplierInvoicePreviewLine> selected) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    debugPrint('IMPORT_STEP_02 validation done t=${DateTime.now().toIso8601String()} selectedCount=${selected.length}');

    try {
      final invoiceId = _invoiceId;
      final header = _header;
      if (invoiceId == null || invoiceId.isEmpty || header == null) {
        throw StateError('Factura nu este pregatita pentru import.');
      }
      // FAZA "persist invoice metadata server-side" — `invoiceId` +
      // metadata Firestore (`supplier_invoices/{id}` + liniile) sunt DEJA
      // persistate server-side, garantat, de la momentul parsarii (vezi
      // parseSupplierInvoiceXml) — nu mai exista niciun apel
      // Firestore/Storage al clientului aici. Markerele IMPORT_STEP_02A-D
      // (care bracketau tranzactia Firestore client-side) au fost
      // eliminate odata cu acel cod — vezi supplier_invoice_repository.dart
      // (persistNewInvoice, eliminat complet).
      debugPrint('IMPORT_STEP_02E metadata deja persistata server-side t=${DateTime.now().toIso8601String()}');

      debugPrint('IMPORT_STEP_02F before MaterialsCatalogService.listMaterials t=${DateTime.now().toIso8601String()}');
      final catalog = await MaterialsCatalogService().listMaterials();
      debugPrint('IMPORT_STEP_02G after MaterialsCatalogService.listMaterials t=${DateTime.now().toIso8601String()} count=${catalog.length}');
      final matcher = SupplierInvoiceCatalogMatcher(catalog);
      final baseMillis = DateTime.now().millisecondsSinceEpoch;

      final newMaterialRows = <Map<String, dynamic>>[];
      final materialsToCreate = <MasterMaterial>[];

      debugPrint('IMPORT_STEP_02H before mapping loop t=${DateTime.now().toIso8601String()}');
      for (var i = 0; i < selected.length; i++) {
        final line = selected[i];
        final resolution = matcher.resolve(
          name: line.displayName,
          unit: line.friendlyUnit,
          price: line.unitPriceNoVat ?? 0,
        );
        if (resolution.toCreate != null) {
          materialsToCreate.add(resolution.toCreate!);
        }
        newMaterialRows.add(
          buildJobMaterialFromInvoiceLine(
            line: line,
            materialId: resolution.materialId,
            invoiceId: invoiceId,
            jobMaterialId: generateJobMaterialId(baseMillis, i),
          ),
        );
      }
      debugPrint('IMPORT_STEP_02I after mapping loop t=${DateTime.now().toIso8601String()}');

      debugPrint('IMPORT_STEP_03 materials mapped t=${DateTime.now().toIso8601String()} '
          'rowCount=${newMaterialRows.length} '
          'qtyType=${newMaterialRows.isNotEmpty ? newMaterialRows.first['qty'].runtimeType : 'n/a'} '
          'toCreateCount=${materialsToCreate.length}');

      if (!mounted) return;
      debugPrint('IMPORT_STEP_08 before navigator pop t=${DateTime.now().toIso8601String()} rowCount=${newMaterialRows.length}');
      Navigator.of(context).pop(
        SupplierInvoiceImportOutcome(
          invoiceId: invoiceId,
          newMaterialRows: newMaterialRows,
          materialsToCreateInCatalog: materialsToCreate,
        ),
      );
    } catch (error, stack) {
      debugPrint('IMPORT_STEP_ERROR t=${DateTime.now().toIso8601String()} '
          'exceptionType=${error.runtimeType} message=$error');
      debugPrint('$stack');
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Eroare la pregatirea importului: $error';
      });
    }
  }
}
