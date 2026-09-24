// FAZA 1 — ecran "Import materiale din factura": upload XML e-Factura,
// parsare server-side, PREVIEW editabil, salvare pentru verificare.
//
// IMPORTANT (Faza 1): niciun buton din acest ecran nu scrie in
// JobRecord.materials. Butonul final e explicit "Salveaza factura pentru
// verificare", NU "Importa in lucrare" — alocarea efectiva in lucrare este
// Faza 2, neaprobata inca.

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/auth/app_role_policy.dart';
import '../job_models.dart';
import 'supplier_invoice_models.dart';
import 'supplier_invoice_parser_client.dart';
import 'supplier_invoice_repository.dart';

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
      AppRolePolicy.canAccessOffice(AppRolePolicy.fromRoleKey(widget.roleKey));

  String? _fileName;
  Uint8List? _xmlBytes;
  String? _fileHash;

  bool _isParsing = false;
  bool _isSaving = false;
  String? _errorMessage;

  SupplierInvoiceParsedHeader? _header;
  List<SupplierInvoicePreviewLine> _lines =
      const <SupplierInvoicePreviewLine>[];

  bool get _allSelected => _lines.isNotEmpty && _lines.every((l) => l.selected);

  int get _selectedCount => _lines.where((l) => l.selected).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import materiale din factura')),
      body: !_isAuthorized
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aceasta functie este disponibila doar pentru rolul admin/office.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _header == null
              ? _buildPickStep(context)
              : _buildPreviewStep(context),
    );
  }

  // ── Pasul 1: alegere fisier XML ─────────────────────────────────────

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
              'PDF/imagini nu sunt suportate in aceasta versiune.',
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
    setState(() {
      _errorMessage = null;
    });
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
      // Decodare UTF-8 corecta (diacritice romanesti in denumiri de
      // furnizor/produse) — NU String.fromCharCodes (ar corupe orice
      // caracter multi-byte). BOM (des generat de instrumente Windows)
      // e eliminat defensiv daca e prezent.
      var xmlText = utf8.decode(bytes, allowMalformed: false);
      if (xmlText.isNotEmpty && xmlText.codeUnitAt(0) == 0xFEFF) {
        xmlText = xmlText.substring(1);
      }
      final hash = _repository.computeSha256(bytes);
      final parseResult = await _parserClient.parseXml(xmlText);
      if (!mounted) return;
      setState(() {
        _fileHash = hash;
        _header = parseResult.header;
        _lines = parseResult.lines;
        _isParsing = false;
      });
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
                    for (final line in _lines) {
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
                onPressed: (_isSaving || _selectedCount == 0)
                    ? null
                    : _onSaveForReview,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Salveaza factura pentru verificare'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLineCard(SupplierInvoicePreviewLine line) {
    final theme = Theme.of(context);
    return Card(
      color: line.hasProblem
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.25)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: line.selected,
                  onChanged: (checked) =>
                      setState(() => line.selected = checked ?? false),
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
                    label: 'Cantitate',
                    value: line.quantity,
                    onChanged: (v) => line.quantity = v,
                  ),
                  _textField(
                    label: 'UM',
                    value: line.unit ?? '',
                    onChanged: (v) =>
                        line.unit = v.trim().isEmpty ? null : v.trim(),
                  ),
                  _numberField(
                    label: 'Pret fara TVA',
                    value: line.unitPriceNoVat,
                    onChanged: (v) => line.unitPriceNoVat = v,
                  ),
                  SizedBox(
                    width: 130,
                    child: Text(
                      'Valoare: '
                      '${line.currentLineTotalNoVat?.toStringAsFixed(2) ?? '—'} '
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
  }) {
    return SizedBox(
      width: 90,
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: onChanged,
      ),
    );
  }

  Widget _numberField({
    required String label,
    required double? value,
    required ValueChanged<double?> onChanged,
  }) {
    return SizedBox(
      width: 110,
      child: TextFormField(
        initialValue: value?.toString() ?? '',
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
      _header = null;
      _lines = const <SupplierInvoicePreviewLine>[];
      _errorMessage = null;
    });
  }

  Future<void> _onSaveForReview() async {
    final xmlBytes = _xmlBytes;
    final hash = _fileHash;
    final header = _header;
    if (xmlBytes == null || hash == null || header == null) return;

    setState(() => _isSaving = true);

    try {
      final duplicate = await _repository.findByFileHash(hash);
      if (!mounted) return;
      if (duplicate != null) {
        setState(() => _isSaving = false);
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Factura deja importata'),
            content: Text(
              'Aceasta factura a fost deja importata anterior.\n\n'
              'Numar factura: ${duplicate.invoiceNumber}\n'
              'Furnizor: ${duplicate.supplierName}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Am inteles'),
              ),
            ],
          ),
        );
        return;
      }

      final selected = _lines.where((l) => l.selected).toList(growable: false);
      final invoiceId = await _repository.saveForReview(
        xmlBytes: xmlBytes,
        sourceFileHash: hash,
        header: header,
        selectedLines: selected,
        jobId: widget.job.id,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Factura salvata pentru verificare (${selected.length} linii). ID: $invoiceId')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Eroare la salvare: $error';
      });
    }
  }
}
