import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/deviz_theme_controller.dart';
import '../../core/app_theme_preset.dart';
import '../../core/company_profile.dart';
import '../../core/integrations/smartbill_service.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/repositories/app_data_repository.dart';
import '../../core/repositories/local_app_data_repository.dart';
import '../../core/smartbill_settings.dart';
import '../../core/widgets/help_button.dart';
import '../../core/help_content.dart';

class CompanySettingsPage extends StatefulWidget {
  const CompanySettingsPage({
    super.key,
    required this.repository,
  });

  final AppDataRepository repository;

  @override
  State<CompanySettingsPage> createState() => _CompanySettingsPageState();
}

class _CompanySettingsPageState extends State<CompanySettingsPage> {
  final SmartBillService _smartBillService = SmartBillService();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _contactEmail = TextEditingController();
  final _website = TextEditingController();
  final _cui = TextEditingController();
  final _trade = TextEditingController();
  final _bank = TextEditingController();
  final _iban = TextEditingController();
  final _contact = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _county = TextEditingController();
  String _currency = 'RON';
  String _language = 'RO';
  final _smartBillUsername = TextEditingController();
  final _smartBillToken = TextEditingController();
  final _smartBillVatCode = TextEditingController();
  final _smartBillConsumptionWarehouse = TextEditingController();
  final _smartBillConsumptionSeries = TextEditingController();
  final _defaultVat = TextEditingController();
  final _defaultProfit = TextEditingController();
  final _defaultOverhead = TextEditingController();
  final _corporateTaxCustomPercent = TextEditingController();
  String _corporateTaxType = 'profit_16';
  final _agfrTechnicianName = TextEditingController();
  final _agfrTechnicianCertificateNumber = TextEditingController();
  final _agfrCompanyAuthorizationNumber = TextEditingController();
  String _logoBase64 = '';
  AppThemePreset _appThemePreset = AppThemePreset.proTerm;
  bool _askEveryTime = false;
  PdfVisualTemplate _pdfVisualTemplate = PdfVisualTemplate.classic;
  String _defaultPdfFolder = '';
  String _offersFolder = '';
  String _jobsFolder = '';
  String _hrPayslipsFolder = '';
  String _hrStatementsFolder = '';
  String _hrAccountingReportsFolder = '';
  String _leaveRequestsFolder = '';
  String _attendanceReportsFolder = '';
  String _travelOrdersFolder = '';
  bool _loading = true;
  String _dataSourceLabel = 'local_cache';
  String? _fallbackReason;
  bool _smartBillEnabled = false;
  bool _smartBillInvoiceDraft = false;
  bool _smartBillEstimateDraft = false;
  bool _smartBillSendEmailOnIssue = false;
  bool _testingSmartBill = false;
  bool _loadingSmartBillCatalog = false;
  String _smartBillInvoiceSeries = '';
  String _smartBillEstimateSeries = '';
  String _smartBillStatus = '';
  List<SmartBillSeriesInfo> _smartBillInvoiceSeriesOptions =
      const <SmartBillSeriesInfo>[];
  List<SmartBillSeriesInfo> _smartBillEstimateSeriesOptions =
      const <SmartBillSeriesInfo>[];
  List<SmartBillTaxInfo> _smartBillTaxes = const <SmartBillTaxInfo>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _contactEmail.dispose();
    _website.dispose();
    _cui.dispose();
    _trade.dispose();
    _bank.dispose();
    _iban.dispose();
    _contact.dispose();
    _address.dispose();
    _city.dispose();
    _county.dispose();
    _smartBillUsername.dispose();
    _smartBillToken.dispose();
    _smartBillVatCode.dispose();
    _smartBillConsumptionWarehouse.dispose();
    _smartBillConsumptionSeries.dispose();
    _defaultVat.dispose();
    _defaultProfit.dispose();
    _defaultOverhead.dispose();
    _corporateTaxCustomPercent.dispose();
    _agfrTechnicianName.dispose();
    _agfrTechnicianCertificateNumber.dispose();
    _agfrCompanyAuthorizationNumber.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await widget.repository.loadCompanyProfile();
    _syncCompanyProfileDataSource();
    if (!mounted) return;
    setState(() {
      _name.text = profile.companyName;
      _phone.text = profile.phone;
      _email.text = profile.email;
      _contactEmail.text = profile.contactEmail;
      _website.text = profile.website;
      _cui.text = profile.cui;
      _trade.text = profile.tradeRegister;
      _bank.text = profile.bank;
      _iban.text = profile.iban;
      _contact.text = profile.contactName;
      _address.text = profile.address;
      _city.text = profile.city;
      _county.text = profile.county;
      _currency = profile.currency.isEmpty ? 'RON' : profile.currency;
      _language = profile.language.isEmpty ? 'RO' : profile.language;
      _smartBillEnabled = profile.smartBillSettings.enabled;
      _smartBillUsername.text = profile.smartBillSettings.username;
      _smartBillToken.text = profile.smartBillSettings.token;
      _smartBillVatCode.text = profile.smartBillSettings.companyVatCode.isEmpty
          ? profile.cui
          : profile.smartBillSettings.companyVatCode;
      _smartBillInvoiceSeries = profile.smartBillSettings.invoiceSeriesName;
      _smartBillEstimateSeries = profile.smartBillSettings.estimateSeriesName;
      _smartBillInvoiceDraft = profile.smartBillSettings.useInvoiceDraft;
      _smartBillEstimateDraft = profile.smartBillSettings.useEstimateDraft;
      _smartBillSendEmailOnIssue = profile.smartBillSettings.sendEmailOnIssue;
      _smartBillConsumptionWarehouse.text =
          profile.smartBillSettings.consumptionWarehouseName;
      _smartBillConsumptionSeries.text =
          profile.smartBillSettings.consumptionSeriesName;
      _logoBase64 = profile.logoBase64;
      _appThemePreset = profile.appThemePreset;
      _askEveryTime = profile.pdfExportSettings.askEveryTime;
      _pdfVisualTemplate = profile.pdfExportSettings.visualTemplate;
      _defaultPdfFolder = profile.pdfExportSettings.defaultPdfFolder;
      _offersFolder = profile.pdfExportSettings.offersFolder;
      _jobsFolder = profile.pdfExportSettings.jobsFolder;
      _hrPayslipsFolder = profile.pdfExportSettings.hrPayslipsFolder;
      _hrStatementsFolder = profile.pdfExportSettings.hrStatementsFolder;
      _hrAccountingReportsFolder =
          profile.pdfExportSettings.hrAccountingReportsFolder;
      _leaveRequestsFolder = profile.pdfExportSettings.leaveRequestsFolder;
      _attendanceReportsFolder =
          profile.pdfExportSettings.attendanceReportsFolder;
      _travelOrdersFolder = profile.pdfExportSettings.travelOrdersFolder;
      _defaultVat.text = profile.defaultVatPercent.toStringAsFixed(2);
      _defaultProfit.text = profile.defaultProfitPercent.toStringAsFixed(2);
      _defaultOverhead.text = profile.defaultOverheadPercent.toStringAsFixed(2);
      _corporateTaxType = profile.corporateTaxType;
      _corporateTaxCustomPercent.text =
          profile.corporateTaxPercent.toStringAsFixed(2);
      _agfrTechnicianName.text = profile.agfrTechnicianName;
      _agfrTechnicianCertificateNumber.text =
          profile.agfrTechnicianCertificateNumber;
      _agfrCompanyAuthorizationNumber.text =
          profile.agfrCompanyAuthorizationNumber;
      _loading = false;
    });
  }

  void _syncCompanyProfileDataSource() {
    final repository = widget.repository;
    if (repository is LocalAppDataRepository) {
      _dataSourceLabel = repository.lastCompanyProfileDataSourceLabel;
      final reason = repository.lastCompanyProfileFallbackReason.trim();
      _fallbackReason = reason.isEmpty ? null : reason;
      return;
    }
    _dataSourceLabel = 'cloud';
    _fallbackReason = null;
  }

  static const Map<String, String> _taxTypeLabels = {
    'profit_16': 'Impozit pe profit (16%)',
    'micro_1': 'Impozit micro (1%)',
    'micro_3': 'Impozit micro (3%)',
    'custom': 'Personalizat',
  };

  static const Map<String, double> _taxTypePercents = {
    'profit_16': 16.0,
    'micro_1': 1.0,
    'micro_3': 3.0,
  };

  double get _effectiveCorporateTaxPercent {
    if (_corporateTaxType == 'custom') {
      return double.tryParse(
              _corporateTaxCustomPercent.text.replaceAll(',', '.').trim()) ??
          16.0;
    }
    return _taxTypePercents[_corporateTaxType] ?? 16.0;
  }

  Future<void> _save() async {
    final profile = CompanyProfile(
      companyName: _name.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      contactEmail: _contactEmail.text.trim(),
      website: _website.text.trim(),
      cui: _cui.text.trim(),
      tradeRegister: _trade.text.trim(),
      bank: _bank.text.trim(),
      iban: _iban.text.trim(),
      contactName: _contact.text.trim(),
      address: _address.text.trim(),
      city: _city.text.trim(),
      county: _county.text.trim(),
      logoBase64: _logoBase64.trim(),
      currency: _currency,
      language: _language,
      appThemePreset: _appThemePreset,
      pdfExportSettings: PdfExportSettings(
        askEveryTime: _askEveryTime,
        visualTemplate: _pdfVisualTemplate,
        defaultPdfFolder: _defaultPdfFolder.trim(),
        offersFolder: _offersFolder.trim(),
        jobsFolder: _jobsFolder.trim(),
        hrPayslipsFolder: _hrPayslipsFolder.trim(),
        hrStatementsFolder: _hrStatementsFolder.trim(),
        hrAccountingReportsFolder: _hrAccountingReportsFolder.trim(),
        leaveRequestsFolder: _leaveRequestsFolder.trim(),
        attendanceReportsFolder: _attendanceReportsFolder.trim(),
        travelOrdersFolder: _travelOrdersFolder.trim(),
      ),
      smartBillSettings: _currentSmartBillSettings(),
      defaultVatPercent:
          double.tryParse(_defaultVat.text.replaceAll(',', '.').trim()) ?? 21.0,
      defaultProfitPercent:
          double.tryParse(_defaultProfit.text.replaceAll(',', '.').trim()) ??
              15.0,
      defaultOverheadPercent:
          double.tryParse(_defaultOverhead.text.replaceAll(',', '.').trim()) ??
              0.0,
      corporateTaxType: _corporateTaxType,
      corporateTaxPercent: _effectiveCorporateTaxPercent,
      agfrTechnicianName: _agfrTechnicianName.text.trim(),
      agfrTechnicianCertificateNumber:
          _agfrTechnicianCertificateNumber.text.trim(),
      agfrCompanyAuthorizationNumber:
          _agfrCompanyAuthorizationNumber.text.trim(),
    );
    await widget.repository.saveCompanyProfile(profile);
    if (!mounted) return;
    DevizThemeScope.maybeOf(context)?.applyCompanyProfile(profile);
    _syncCompanyProfileDataSource();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Setarile firmei au fost salvate.')),
    );
  }

  SmartBillSettings _currentSmartBillSettings() {
    return SmartBillSettings(
      enabled: _smartBillEnabled,
      username: _smartBillUsername.text.trim(),
      token: _smartBillToken.text.trim(),
      companyVatCode: _smartBillVatCode.text.trim(),
      invoiceSeriesName: _smartBillInvoiceSeries.trim(),
      estimateSeriesName: _smartBillEstimateSeries.trim(),
      useInvoiceDraft: _smartBillInvoiceDraft,
      useEstimateDraft: _smartBillEstimateDraft,
      sendEmailOnIssue: _smartBillSendEmailOnIssue,
      consumptionWarehouseName: _smartBillConsumptionWarehouse.text.trim(),
      consumptionSeriesName: _smartBillConsumptionSeries.text.trim(),
    );
  }

  Future<void> _testSmartBillConnection() async {
    setState(() {
      _testingSmartBill = true;
      _smartBillStatus = '';
    });
    try {
      final result = await _smartBillService.probeConfiguration(
        _currentSmartBillSettings(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _smartBillInvoiceSeriesOptions = result.invoiceSeries;
        _smartBillEstimateSeriesOptions = result.estimateSeries;
        _smartBillTaxes = result.taxes;
        if (_smartBillInvoiceSeries.trim().isEmpty &&
            result.invoiceSeries.isNotEmpty) {
          _smartBillInvoiceSeries = result.invoiceSeries.first.name;
        }
        if (_smartBillEstimateSeries.trim().isEmpty &&
            result.estimateSeries.isNotEmpty) {
          _smartBillEstimateSeries = result.estimateSeries.first.name;
        }
        _smartBillStatus =
            'Conexiune SmartBill valida. Facturi: ${result.invoiceSeries.length}, proforme: ${result.estimateSeries.length}, cote TVA: ${result.taxes.length}.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conexiunea SmartBill este valida.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _smartBillStatus = 'Test SmartBill esuat: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _testingSmartBill = false);
      }
    }
  }

  Future<void> _loadSmartBillCatalog() async {
    setState(() {
      _loadingSmartBillCatalog = true;
      _smartBillStatus = '';
    });
    try {
      final result = await _smartBillService.probeConfiguration(
        _currentSmartBillSettings(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _smartBillInvoiceSeriesOptions = result.invoiceSeries;
        _smartBillEstimateSeriesOptions = result.estimateSeries;
        _smartBillTaxes = result.taxes;
        final invoiceMatch = result.invoiceSeries.any(
          (item) => item.name == _smartBillInvoiceSeries,
        );
        final estimateMatch = result.estimateSeries.any(
          (item) => item.name == _smartBillEstimateSeries,
        );
        if (!invoiceMatch && result.invoiceSeries.isNotEmpty) {
          _smartBillInvoiceSeries = result.invoiceSeries.first.name;
        }
        if (!estimateMatch && result.estimateSeries.isNotEmpty) {
          _smartBillEstimateSeries = result.estimateSeries.first.name;
        }
        _smartBillStatus =
            'Catalog SmartBill actualizat. Selecteaza seriile implicite pentru sincronizare.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Seriile si cotele TVA au fost actualizate.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _smartBillStatus = 'Nu am putut incarca seriile SmartBill: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingSmartBillCatalog = false);
      }
    }
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu am putut citi imaginea selectata.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _logoBase64 = base64Encode(bytes));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logo actualizat.')),
    );
  }

  void _clearLogo() {
    setState(() => _logoBase64 = '');
  }

  Future<void> _pickFolder(ValueSetter<String> onSelected) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Alege folderul pentru PDF-uri',
    );
    if (result == null || result.trim().isEmpty) return;
    if (!mounted) return;
    setState(() => onSelected(result));
  }

  Widget _logoPreview() {
    if (_logoBase64.trim().isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Logo necompletat'),
      );
    }
    try {
      final bytes = _decodeLogo(_logoBase64);
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Image.memory(bytes, fit: BoxFit.contain),
      );
    } catch (_) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Logo invalid'),
      );
    }
  }

  Uint8List _decodeLogo(String value) {
    try {
      final bytes = UriData.parse(value).contentAsBytes();
      return Uint8List.fromList(bytes);
    } catch (_) {
      final bytes = base64Decode(value);
      return Uint8List.fromList(bytes);
    }
  }

  Widget _folderFieldResponsive({
    required String label,
    required String value,
    required ValueSetter<String> onChanged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final field = InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          child: Text(value.trim().isEmpty ? '-' : value.trim()),
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickFolder(onChanged),
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Alege folder'),
            ),
            OutlinedButton.icon(
              onPressed: value.trim().isEmpty
                  ? null
                  : () => setState(() => onChanged('')),
              icon: const Icon(Icons.clear_outlined),
              label: const Text('Goleste'),
            ),
          ],
        );
        final content = constraints.maxWidth < 720
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  field,
                  const SizedBox(height: 8),
                  actions,
                ],
              )
            : Row(
                children: [
                  Expanded(child: field),
                  const SizedBox(width: 8),
                  actions,
                ],
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            content,
          ],
        );
      },
    );
  }

  Widget _responsivePair({
    required Widget left,
    required Widget right,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            children: [
              left,
              const SizedBox(height: 8),
              right,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 8),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _themePreviewCard(BuildContext context) {
    final previewTheme = buildAppTheme(_appThemePreset);
    final scheme = previewTheme.colorScheme;
    final brand = previewTheme.extension<AppBrandTheme>();
    final previewColors = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.surface,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: brand?.shellHeaderGradient,
        border: Border.all(color: brand?.shellLineColor ?? scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _appThemePreset.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: brand?.shellAccentGradient,
                ),
                child: const Text(
                  'Preview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_appThemePreset.description),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: previewColors
                .map(
                  (color) => Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          if (_appThemePreset == AppThemePreset.proTerm) ...[
            const SizedBox(height: 10),
            Text(
              'Presetul ProVentaris Signature pune accent pe rosu energic, albastru tehnic si accente reci inspirate din logo-ul HVAC.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _smartBillSeriesDropdown({
    required String label,
    required String value,
    required List<SmartBillSeriesInfo> options,
    required ValueChanged<String> onChanged,
    required String emptyHint,
  }) {
    if (options.isEmpty) {
      return TextField(
        textCapitalization: TextCapitalization.sentences,
        controller: TextEditingController(text: value)
          ..selection = TextSelection.collapsed(offset: value.length),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          helperText: emptyHint,
        ),
      );
    }
    final dropdownValue =
        options.any((item) => item.name == value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: dropdownValue,
      decoration: InputDecoration(
        labelText: label,
        helperText: emptyHint,
      ),
      items: options
          .map(
            (item) => DropdownMenuItem<String>(
              value: item.name,
              child: Text('${item.name} • urmatorul ${item.nextNumber}'),
            ),
          )
          .toList(growable: false),
      onChanged: (selected) {
        if (selected == null) {
          return;
        }
        setState(() => onChanged(selected));
      },
    );
  }

  Widget _buildSmartBillSection(BuildContext context) {
    final smartBillConfigured = _currentSmartBillSettings().isConfigured;
    final statusColor = _smartBillStatus.toLowerCase().contains('esuat') ||
            _smartBillStatus.toLowerCase().contains('nu am putut')
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SmartBill',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Baza pentru sincronizare facturi/proforme: credențiale, CIF, serii implicite și validare directă în contul SmartBill.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(_smartBillEnabled
                      ? 'Sincronizare activă'
                      : 'Sincronizare inactivă'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(smartBillConfigured
                      ? 'Credențiale completate'
                      : 'Credențiale incomplete'),
                  visualDensity: VisualDensity.compact,
                ),
                if (_smartBillInvoiceSeriesOptions.isNotEmpty)
                  Chip(
                    label: Text(
                        'Serii facturi: ${_smartBillInvoiceSeriesOptions.length}'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (_smartBillEstimateSeriesOptions.isNotEmpty)
                  Chip(
                    label: Text(
                        'Serii proforme: ${_smartBillEstimateSeriesOptions.length}'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (_smartBillTaxes.isNotEmpty)
                  Chip(
                    label: Text('Cote TVA: ${_smartBillTaxes.length}'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activeaza SmartBill'),
              subtitle: const Text(
                'Pregateste sincronizarea documentelor comerciale catre SmartBill.',
              ),
              value: _smartBillEnabled,
              onChanged: (value) => setState(() => _smartBillEnabled = value),
            ),
            const SizedBox(height: 8),
            _responsivePair(
              left: TextField(
                controller: _smartBillUsername,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email utilizator SmartBill',
                  helperText: 'Emailul contului SmartBill Cloud.',
                ),
              ),
              right: TextField(
                controller: _smartBillVatCode,
                decoration: const InputDecoration(
                  labelText: 'CIF firma SmartBill',
                  helperText: 'Ex: RO12345678',
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _smartBillToken,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Token API SmartBill',
                helperText: 'Contul Meu > Integrari > API token.',
              ),
            ),
            const SizedBox(height: 12),
            _responsivePair(
              left: _smartBillSeriesDropdown(
                label: 'Serie implicită facturi',
                value: _smartBillInvoiceSeries,
                options: _smartBillInvoiceSeriesOptions,
                onChanged: (value) => _smartBillInvoiceSeries = value,
                emptyHint:
                    'Poți încărca automat seriile sau scrie manual seria.',
              ),
              right: _smartBillSeriesDropdown(
                label: 'Serie implicită proforme',
                value: _smartBillEstimateSeries,
                options: _smartBillEstimateSeriesOptions,
                onChanged: (value) => _smartBillEstimateSeries = value,
                emptyHint:
                    'Poți încărca automat seriile sau scrie manual seria.',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Emite facturile ca draft'),
              subtitle: const Text(
                'Util pentru validare internă înainte de emiterea finală în SmartBill.',
              ),
              value: _smartBillInvoiceDraft,
              onChanged: (value) =>
                  setState(() => _smartBillInvoiceDraft = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Emite proformele ca draft'),
              value: _smartBillEstimateDraft,
              onChanged: (value) =>
                  setState(() => _smartBillEstimateDraft = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Solicită trimitere email la emitere'),
              subtitle: const Text(
                'Va fi folosită ulterior când sincronizarea emite documente direct prin API.',
              ),
              value: _smartBillSendEmailOnIssue,
              onChanged: (value) =>
                  setState(() => _smartBillSendEmailOnIssue = value),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 4),
            Text(
              'Bon de consum',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Configurează gestiunea și seria folosite când materialele consumate dintr-o programare sunt trimise ca bon de consum în SmartBill.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _smartBillConsumptionWarehouse,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Gestiune bon consum',
                hintText: 'ex: MATERIALE-Cantitativ valorica',
                helperText: 'Exact cum apare în SmartBill → Gestiuni',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _smartBillConsumptionSeries,
              decoration: const InputDecoration(
                labelText: 'Serie bon consum',
                hintText: 'ex: BC',
                helperText: 'Seria documentului bon de consum din SmartBill',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      _testingSmartBill ? null : _testSmartBillConnection,
                  icon: _testingSmartBill
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_done_outlined),
                  label: const Text('Testează conexiunea'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _loadingSmartBillCatalog ? null : _loadSmartBillCatalog,
                  icon: _loadingSmartBillCatalog
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_outlined),
                  label: const Text('Încarcă serii și TVA'),
                ),
              ],
            ),
            if (_smartBillStatus.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _smartBillStatus,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: statusColor),
              ),
            ],
            if (_smartBillTaxes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Cote TVA disponibile',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _smartBillTaxes
                    .map(
                      (tax) => Chip(
                        label: Text(
                            '${tax.name} ${tax.percentage.toStringAsFixed(tax.percentage.truncateToDouble() == tax.percentage ? 0 : 2)}%'),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setări firmă'),
        actions: [
          HelpButton(content: AppHelp.setariFirma),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Chip(
                        label: Text('Sursa date: $_dataSourceLabel'),
                        visualDensity: VisualDensity.compact,
                      ),
                      const Chip(
                        label: Text('PDF export: setări locale device'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  if ((_fallbackReason ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Motiv fallback: $_fallbackReason',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Datele firmei și logo-ul sunt comune între device-uri. '
                    'Folderele PDF și opțiunile de export rămân locale pe device.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nume firmă'),
                  ),
                  const SizedBox(height: 8),
                  _responsivePair(
                    left: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Telefon'),
                    ),
                    right: TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(labelText: 'Email oficiu'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _responsivePair(
                    left: TextField(
                      controller: _contactEmail,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(labelText: 'Email contact'),
                    ),
                    right: TextField(
                      controller: _website,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(labelText: 'Website'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _responsivePair(
                    left: TextField(
                      controller: _cui,
                      decoration: const InputDecoration(labelText: 'CUI'),
                    ),
                    right: TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: _trade,
                      decoration: const InputDecoration(
                        labelText: 'Nr. registrul comerțului',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _responsivePair(
                    left: TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: _bank,
                      decoration: const InputDecoration(labelText: 'Bancă'),
                    ),
                    right: TextField(
                      controller: _iban,
                      decoration: const InputDecoration(labelText: 'IBAN'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _contact,
                    decoration: const InputDecoration(
                      labelText: 'Persoană de contact',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _address,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Adresă'),
                  ),
                  const SizedBox(height: 8),
                  _responsivePair(
                    left: TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: _city,
                      decoration: const InputDecoration(labelText: 'Oraș'),
                    ),
                    right: TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: _county,
                      decoration: const InputDecoration(labelText: 'Județ'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _logoPreview(),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _pickLogo,
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          _logoBase64.trim().isEmpty
                              ? 'Alege logo'
                              : 'Schimbă logo',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _logoBase64.trim().isEmpty ? null : _clearLogo,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Șterge logo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<AppThemePreset>(
                    initialValue: _appThemePreset,
                    decoration: const InputDecoration(
                      labelText: 'Tema aplicației',
                      helperText:
                          'Tema se aplică global și se păstrează în profilul firmei.',
                    ),
                    items: AppThemePreset.values
                        .map(
                          (preset) => DropdownMenuItem<AppThemePreset>(
                            value: preset,
                            child: Text(preset.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _appThemePreset = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  _themePreviewCard(context),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSmartBillSection(context),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Export PDF',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Întreabă de fiecare dată'),
                    subtitle: const Text(
                      'Dacă este activ, aplicația încearcă Save As înainte de salvarea automată.',
                    ),
                    value: _askEveryTime,
                    onChanged: (value) => setState(() => _askEveryTime = value),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<PdfVisualTemplate>(
                    initialValue: _pdfVisualTemplate,
                    decoration: const InputDecoration(
                      labelText: 'Șablon vizual PDF implicit',
                      border: OutlineInputBorder(),
                      helperText:
                          'Se aplică ofertelor și documentelor PDF compatibile.',
                    ),
                    items: PdfVisualTemplate.values
                        .map(
                          (template) => DropdownMenuItem<PdfVisualTemplate>(
                            value: template,
                            child: Text(template.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _pdfVisualTemplate = value);
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _pdfVisualTemplate.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _folderFieldResponsive(
                    label: 'Folder general PDF',
                    value: _defaultPdfFolder,
                    onChanged: (value) => _defaultPdfFolder = value,
                  ),
                  const SizedBox(height: 12),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 4),
                    title: const Text('Foldere dedicate pe categorie'),
                    subtitle: const Text(
                      'Optional: daca sunt completate, aceste foldere au prioritate fata de folderul general.',
                    ),
                    children: [
                      _folderFieldResponsive(
                        label: 'Oferte',
                        value: _offersFolder,
                        onChanged: (value) => _offersFolder = value,
                      ),
                      const SizedBox(height: 10),
                      _folderFieldResponsive(
                        label: 'Lucrări',
                        value: _jobsFolder,
                        onChanged: (value) => _jobsFolder = value,
                      ),
                      const SizedBox(height: 10),
                      _folderFieldResponsive(
                        label: 'Fluturași salariu',
                        value: _hrPayslipsFolder,
                        onChanged: (value) => _hrPayslipsFolder = value,
                      ),
                      const SizedBox(height: 10),
                      _folderFieldResponsive(
                        label: 'Stat de plata',
                        value: _hrStatementsFolder,
                        onChanged: (value) => _hrStatementsFolder = value,
                      ),
                      const SizedBox(height: 10),
                      _folderFieldResponsive(
                        label: 'Centralizatoare contabilitate',
                        value: _hrAccountingReportsFolder,
                        onChanged: (value) =>
                            _hrAccountingReportsFolder = value,
                      ),
                      const SizedBox(height: 10),
                      _folderFieldResponsive(
                        label: 'Cereri concediu',
                        value: _leaveRequestsFolder,
                        onChanged: (value) => _leaveRequestsFolder = value,
                      ),
                      const SizedBox(height: 10),
                      _folderFieldResponsive(
                        label: 'Rapoarte pontaj',
                        value: _attendanceReportsFolder,
                        onChanged: (value) => _attendanceReportsFolder = value,
                      ),
                      const SizedBox(height: 10),
                      _folderFieldResponsive(
                        label: 'Ordine de deplasare',
                        value: _travelOrdersFolder,
                        onChanged: (value) => _travelOrdersFolder = value,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Taxe și marje implicite',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Aceste valori se preiau automat în oferte, devize și lucrări. '
                    'Poți modifica per document dacă este nevoie.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _defaultVat,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'TVA implicit (%)',
                            suffixText: '%',
                            helperText: 'ex: 21, 19, 9, 5',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _defaultProfit,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Profit implicit (%)',
                            suffixText: '%',
                            helperText: 'ex: 15',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _defaultOverhead,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Regie implicit (%)',
                            suffixText: '%',
                            helperText: 'ex: 10',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _responsivePair(
                    left: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(labelText: 'Monedă'),
                      items: const [
                        DropdownMenuItem(value: 'RON', child: Text('RON — Leu românesc')),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR — Euro')),
                        DropdownMenuItem(value: 'USD', child: Text('USD — Dolar american')),
                        DropdownMenuItem(value: 'GBP', child: Text('GBP — Liră sterlină')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _currency = value);
                      },
                    ),
                    right: DropdownButtonFormField<String>(
                      initialValue: _language,
                      decoration: const InputDecoration(labelText: 'Limbă'),
                      items: const [
                        DropdownMenuItem(value: 'RO', child: Text('RO — Română')),
                        DropdownMenuItem(value: 'EN', child: Text('EN — Engleză')),
                        DropdownMenuItem(value: 'HU', child: Text('HU — Maghiară')),
                        DropdownMenuItem(value: 'DE', child: Text('DE — Germană')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _language = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Impozit pe profit / microîntreprindere',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Selectează tipul de impozit aplicabil firmei. Valoarea se preia automat în calculele de profitabilitate din modulul Lucrări.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  StatefulBuilder(
                    builder: (context, setTax) => Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: _taxTypeLabels.containsKey(_corporateTaxType)
                                ? _corporateTaxType
                                : 'profit_16',
                            decoration: const InputDecoration(
                              labelText: 'Tip impozit',
                            ),
                            items: _taxTypeLabels.entries
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e.key,
                                    child: Text(e.value),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _corporateTaxType = value);
                              setTax(() {});
                            },
                          ),
                        ),
                        if (_corporateTaxType == 'custom') ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _corporateTaxCustomPercent,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Procent personalizat (%)',
                                suffixText: '%',
                                helperText: 'ex: 10',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AGFR / F-Gas',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Date tehnicianului și autorizației firmei pentru rapoartele AGFR. '
                    'Aceste valori se preiau automat în toate documentele F-Gas generate.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _agfrTechnicianName,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Nume tehnician AGFR',
                      helperText: 'Ex: IONESCU ALEXANDRU-MIHAI',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _responsivePair(
                    left: TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: _agfrTechnicianCertificateNumber,
                      decoration: const InputDecoration(
                        labelText: 'Nr. certificat tehnician',
                        helperText: 'Ex: 1234/5678',
                      ),
                    ),
                    right: TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: _agfrCompanyAuthorizationNumber,
                      decoration: const InputDecoration(
                        labelText: 'Nr. autorizație firmă AGFR',
                        helperText: 'Ex: 1234/5678',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salvează'),
            ),
          ),
        ],
      ),
    );
  }
}
