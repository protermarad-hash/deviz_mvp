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

import 'dart:convert';
import 'dart:typed_data';

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
  Uint8List? _xmlBytes;
  String? _fileHash;

  bool _isParsing = false;
  bool _isSaving = false;
  String? _errorMessage;

  /// Non-null doar dupa ce factura a fost persistata (import nou) sau
  /// incarcata dintr-un document existent (reutilizare, FAZA 2 pct. 14).
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
      _xmlBytes = bytes;
    });

    try {
      final hash = _repository.computeSha256(bytes);

      // FAZA 2 pct. 14 — daca factura exista deja (indiferent de lucrare),
      // o reutilizam direct, fara sa re-parsam/re-uploadam.
      final existing = await _repository.loadExistingInvoiceByHash(hash);
      if (existing != null) {
        if (!mounted) return;
        _applyLoadedInvoice(existing, hash);
        return;
      }

      var xmlText = utf8.decode(bytes, allowMalformed: false);
      if (xmlText.isNotEmpty && xmlText.codeUnitAt(0) == 0xFEFF) {
        xmlText = xmlText.substring(1);
      }
      final parseResult = await _parserClient.parseXml(xmlText);
      if (!mounted) return;
      setState(() {
        _fileHash = hash;
        _invoiceId = null;
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

  void _applyLoadedInvoice(SupplierInvoiceLoaded loaded, String hash) {
    setState(() {
      _fileHash = hash;
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
            if (!disabled &&
                line.allocatedQty != null &&
                line.quantity != null &&
                line.allocatedQty! > line.quantity!)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 4),
                child: Text(
                  'Atentie: cantitatea alocata depaseste cantitatea facturata pe aceasta linie.',
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
      _xmlBytes = null;
      _fileHash = null;
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
      builder: (_) => AlertDialog(
        title: const Text('Confirma importul'),
        content: Text(
          'Vor fi adaugate ${selected.length} pozitii in lucrare, '
          'in valoare totala de ${totalValue.toStringAsFixed(2)} RON fara TVA.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirma importul'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _doImport(selected);
  }

  Future<void> _doImport(List<SupplierInvoicePreviewLine> selected) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      var invoiceId = _invoiceId;
      if (invoiceId == null) {
        final xmlBytes = _xmlBytes;
        final hash = _fileHash;
        final header = _header;
        if (xmlBytes == null || hash == null || header == null) {
          throw StateError('Factura nu este pregatita pentru import.');
        }
        final persisted = await _repository.persistNewInvoice(
          xmlBytes: xmlBytes,
          sourceFileHash: hash,
          header: header,
          allLines: _lines,
        );
        invoiceId = persisted.invoiceId;
        if (!mounted) return;
        setState(() => _invoiceId = invoiceId);
      }

      final catalog = await MaterialsCatalogService().listMaterials();
      final matcher = SupplierInvoiceCatalogMatcher(catalog);
      final baseMillis = DateTime.now().millisecondsSinceEpoch;

      final newMaterialRows = <Map<String, dynamic>>[];
      final materialsToCreate = <MasterMaterial>[];

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

      if (!mounted) return;
      Navigator.of(context).pop(
        SupplierInvoiceImportOutcome(
          invoiceId: invoiceId,
          newMaterialRows: newMaterialRows,
          materialsToCreateInCatalog: materialsToCreate,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Eroare la pregatirea importului: $error';
      });
    }
  }
}
