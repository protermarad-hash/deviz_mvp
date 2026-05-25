import 'package:flutter/material.dart';

import '../clients/client_models.dart';
import '../jobs/job_models.dart';
import 'product_catalog_service.dart';
import 'product_sales_models.dart';

class WarrantyCertificateEditorDialog extends StatefulWidget {
  const WarrantyCertificateEditorDialog({
    super.key,
    required this.initial,
    this.clients = const <ClientRecord>[],
    this.jobs = const <JobRecord>[],
    this.allowSourceTypeChange = false,
  });

  final WarrantyCertificateRecord initial;
  final List<ClientRecord> clients;
  final List<JobRecord> jobs;
  final bool allowSourceTypeChange;

  @override
  State<WarrantyCertificateEditorDialog> createState() =>
      _WarrantyCertificateEditorDialogState();
}

class _WarrantyCertificateEditorDialogState
    extends State<WarrantyCertificateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _seriesController;
  late final TextEditingController _numberController;
  late final TextEditingController _equipmentTypeController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _serialIndoorController;
  late final TextEditingController _serialOutdoorController;
  late final TextEditingController _invoiceController;
  late final TextEditingController _warrantyMonthsController;
  late final TextEditingController _sellerNameController;
  late final TextEditingController _sellerAddressController;
  late final TextEditingController _sellerEmailController;
  late final TextEditingController _sellerPhoneController;
  late final TextEditingController _sellerTaxIdController;
  late WarrantyCertificateSourceType _sourceType;
  late String _selectedBuyerClientId;
  late String _selectedJobId;
  late final TextEditingController _buyerNameController;
  late final TextEditingController _buyerAddressController;
  late final TextEditingController _buyerPhoneController;
  late final TextEditingController _buyerTaxIdController;
  late final TextEditingController _installerNameController;
  late final TextEditingController _installerAddressController;
  late final TextEditingController _installerEmailController;
  late final TextEditingController _installerPhoneController;
  late final TextEditingController _installerTaxIdController;
  late final TextEditingController _installerPersonsController;
  late final TextEditingController _termsController;

  DateTime? _documentDate;
  DateTime? _saleDate;
  DateTime? _installationDate;
  DateTime? _warrantyStartDate;
  DateTime? _warrantyEndDate;
  late String _status;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _seriesController = TextEditingController(text: initial.certificateSeries);
    _numberController = TextEditingController(text: initial.certificateNumber);
    _equipmentTypeController =
        TextEditingController(text: initial.equipmentType);
    _brandController = TextEditingController(text: initial.brand);
    _modelController = TextEditingController(text: initial.model);
    _serialIndoorController =
        TextEditingController(text: initial.serialNumberIndoor);
    _serialOutdoorController =
        TextEditingController(text: initial.serialNumberOutdoor);
    _invoiceController = TextEditingController(text: initial.invoiceNumber);
    _warrantyMonthsController =
        TextEditingController(text: initial.warrantyMonths.toString());
    _sellerNameController = TextEditingController(text: initial.sellerName);
    _sellerAddressController =
        TextEditingController(text: initial.sellerAddress);
    _sellerEmailController = TextEditingController(text: initial.sellerEmail);
    _sellerPhoneController = TextEditingController(text: initial.sellerPhone);
    _sellerTaxIdController = TextEditingController(text: initial.sellerTaxId);
    _sourceType = initial.sourceType;
    _selectedBuyerClientId = initial.buyerClientId;
    _selectedJobId = initial.jobId;
    _buyerNameController = TextEditingController(text: initial.buyerName);
    _buyerAddressController = TextEditingController(text: initial.buyerAddress);
    _buyerPhoneController = TextEditingController(text: initial.buyerPhone);
    _buyerTaxIdController = TextEditingController(text: initial.buyerTaxOrCnp);
    _installerNameController =
        TextEditingController(text: initial.installerName);
    _installerAddressController =
        TextEditingController(text: initial.installerAddress);
    _installerEmailController =
        TextEditingController(text: initial.installerEmail);
    _installerPhoneController =
        TextEditingController(text: initial.installerPhone);
    _installerTaxIdController =
        TextEditingController(text: initial.installerTaxId);
    _installerPersonsController =
        TextEditingController(text: initial.installerPersons);
    _termsController = TextEditingController(text: initial.termsText);
    _documentDate = initial.documentDate;
    _saleDate = initial.saleDate;
    _installationDate = initial.installationDate;
    _warrantyStartDate = initial.warrantyStartDate;
    _warrantyEndDate = initial.warrantyEndDate;
    _status = normalizeWarrantyCertificateStatus(initial.status);
  }

  @override
  void dispose() {
    _seriesController.dispose();
    _numberController.dispose();
    _equipmentTypeController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialIndoorController.dispose();
    _serialOutdoorController.dispose();
    _invoiceController.dispose();
    _warrantyMonthsController.dispose();
    _sellerNameController.dispose();
    _sellerAddressController.dispose();
    _sellerEmailController.dispose();
    _sellerPhoneController.dispose();
    _sellerTaxIdController.dispose();
    _buyerNameController.dispose();
    _buyerAddressController.dispose();
    _buyerPhoneController.dispose();
    _buyerTaxIdController.dispose();
    _installerNameController.dispose();
    _installerAddressController.dispose();
    _installerEmailController.dispose();
    _installerPhoneController.dispose();
    _installerTaxIdController.dispose();
    _installerPersonsController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedJob = _selectedJob();
    final coverage = ProductCatalogService().coverageStatusForCertificate(
      widget.initial.copyWith(
        sourceType: _sourceType,
        buyerClientId: _selectedBuyerClientId,
        jobId: selectedJob?.id ?? _selectedJobId,
        jobTitle: selectedJob?.title ?? widget.initial.jobTitle,
        documentDate: _documentDate,
        saleDate: _saleDate,
        installationDate: _installationDate,
        warrantyMonths: _parseInt(_warrantyMonthsController.text, fallback: 24),
        warrantyStartDate: _warrantyStartDate,
        warrantyEndDate: _warrantyEndDate,
      ),
    );
    return AlertDialog(
      title: const Text('Certificat de garantie'),
      content: SizedBox(
        width: 980,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (widget.allowSourceTypeChange)
                  SizedBox(
                    width: 220,
                    child:
                        DropdownButtonFormField<WarrantyCertificateSourceType>(
                      initialValue: _sourceType,
                      decoration:
                          const InputDecoration(labelText: 'Sursa talon'),
                      items: WarrantyCertificateSourceType.values
                          .map(
                            (item) =>
                                DropdownMenuItem<WarrantyCertificateSourceType>(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _sourceType = value);
                      },
                    ),
                  ),
                if (widget.clients.isNotEmpty)
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedBuyerClientId.trim().isEmpty
                          ? null
                          : _selectedBuyerClientId,
                      decoration: const InputDecoration(
                        labelText: 'Client alocat',
                      ),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('Fara client alocat'),
                        ),
                        ...widget.clients.map(
                          (client) => DropdownMenuItem<String>(
                            value: client.id,
                            child: Text(
                              client.name.trim().isEmpty
                                  ? client.id
                                  : client.name,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedBuyerClientId = value ?? '';
                          _applySelectedClient();
                        });
                      },
                    ),
                  ),
                if (widget.jobs.isNotEmpty)
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          _selectedJobId.trim().isEmpty ? null : _selectedJobId,
                      decoration: const InputDecoration(
                        labelText: 'Lucrare asociata',
                      ),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('Fara lucrare asociata'),
                        ),
                        ...widget.jobs.map(
                          (job) => DropdownMenuItem<String>(
                            value: job.id,
                            child: Text(
                              job.title.trim().isEmpty
                                  ? (job.jobCode.trim().isEmpty
                                      ? job.id
                                      : job.jobCode)
                                  : '${job.jobCode.trim().isEmpty ? job.id : job.jobCode} | ${job.title}',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedJobId = value ?? '';
                          _applySelectedJob();
                        });
                      },
                    ),
                  ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _seriesController,
                    decoration: const InputDecoration(labelText: 'Serie'),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _numberController,
                    decoration: const InputDecoration(labelText: 'Numar'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _DateField(
                    label: 'Data document',
                    value: _documentDate,
                    onTap: () async {
                      final picked = await _pickDate(_documentDate);
                      if (picked == null) return;
                      setState(() => _documentDate = picked);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _DateField(
                    label: 'Data vanzare',
                    value: _saleDate,
                    onTap: () async {
                      final picked = await _pickDate(_saleDate);
                      if (picked == null) return;
                      setState(() => _saleDate = picked);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _DateField(
                    label: 'Data instalare',
                    value: _installationDate,
                    onTap: () async {
                      final picked = await _pickDate(_installationDate);
                      if (picked == null) return;
                      setState(() => _installationDate = picked);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _warrantyMonthsController,
                    decoration:
                        const InputDecoration(labelText: 'Garantie luni'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _DateField(
                    label: 'Start garantie',
                    value: _warrantyStartDate,
                    onTap: () async {
                      final picked = await _pickDate(_warrantyStartDate);
                      if (picked == null) return;
                      setState(() => _warrantyStartDate = picked);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _DateField(
                    label: 'Sfarsit garantie',
                    value: _warrantyEndDate,
                    onTap: () async {
                      final picked = await _pickDate(_warrantyEndDate);
                      if (picked == null) return;
                      setState(() => _warrantyEndDate = picked);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status operational',
                    ),
                    items: warrantyCertificateStatusOptions
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item,
                            child: Text(warrantyCertificateStatusLabel(item)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _status = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Status garantie',
                    ),
                    child: Text(coverage.label),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _equipmentTypeController,
                    decoration:
                        const InputDecoration(labelText: 'Tip echipament'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _brandController,
                    decoration: const InputDecoration(labelText: 'Brand'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _modelController,
                    decoration: const InputDecoration(labelText: 'Model'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _invoiceController,
                    decoration: const InputDecoration(labelText: 'Factura'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _serialIndoorController,
                    decoration: const InputDecoration(labelText: 'Serie UI'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _serialOutdoorController,
                    decoration: const InputDecoration(labelText: 'Serie UE'),
                  ),
                ),
                SizedBox(
                  width: 472,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _sellerNameController,
                    decoration:
                        const InputDecoration(labelText: 'Vanzator - denumire'),
                  ),
                ),
                SizedBox(
                  width: 472,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _sellerAddressController,
                    decoration:
                        const InputDecoration(labelText: 'Vanzator - adresa'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _sellerEmailController,
                    decoration:
                        const InputDecoration(labelText: 'Vanzator - email'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _sellerPhoneController,
                    decoration:
                        const InputDecoration(labelText: 'Vanzator - telefon'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _sellerTaxIdController,
                    decoration:
                        const InputDecoration(labelText: 'Vanzator - CUI/CIF'),
                  ),
                ),
                SizedBox(
                  width: 472,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _buyerNameController,
                    decoration:
                        const InputDecoration(labelText: 'Cumparator - nume'),
                  ),
                ),
                SizedBox(
                  width: 472,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _buyerAddressController,
                    decoration:
                        const InputDecoration(labelText: 'Cumparator - adresa'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _buyerPhoneController,
                    decoration: const InputDecoration(
                        labelText: 'Cumparator - telefon'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _buyerTaxIdController,
                    decoration: const InputDecoration(
                        labelText: 'Cumparator - CUI/CNP'),
                  ),
                ),
                SizedBox(
                  width: 472,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _installerNameController,
                    decoration: const InputDecoration(
                        labelText: 'Instalator - denumire'),
                  ),
                ),
                SizedBox(
                  width: 472,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _installerAddressController,
                    decoration:
                        const InputDecoration(labelText: 'Instalator - adresa'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _installerEmailController,
                    decoration:
                        const InputDecoration(labelText: 'Instalator - email'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _installerPhoneController,
                    decoration: const InputDecoration(
                        labelText: 'Instalator - telefon'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _installerTaxIdController,
                    decoration: const InputDecoration(
                        labelText: 'Instalator - CUI/CIF'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _installerPersonsController,
                    decoration:
                        const InputDecoration(labelText: 'Persoane instalare'),
                  ),
                ),
                SizedBox(
                  width: 956,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _termsController,
                    minLines: 8,
                    maxLines: 16,
                    decoration: const InputDecoration(
                      labelText: 'Condiții de garanție',
                    ),
                  ),
                ),
                SizedBox(
                  width: 956,
                  child: _WarrantyTicketsSection(
                    tickets: widget.initial.warrantyServiceTickets,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Salveaza'),
        ),
      ],
    );
  }

  Future<DateTime?> _pickDate(DateTime? initial) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
  }

  ClientRecord? _selectedClient() {
    final id = _selectedBuyerClientId.trim();
    if (id.isEmpty) return null;
    for (final item in widget.clients) {
      if (item.id == id) return item;
    }
    return null;
  }

  JobRecord? _selectedJob() {
    final id = _selectedJobId.trim();
    if (id.isEmpty) return null;
    for (final item in widget.jobs) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _applySelectedClient() {
    final client = _selectedClient();
    if (client == null) {
      return;
    }
    final addressParts = <String>[
      client.address.trim(),
      client.city.trim(),
      client.county.trim(),
    ].where((item) => item.isNotEmpty).toList(growable: false);
    _buyerNameController.text = client.name.trim();
    _buyerAddressController.text = addressParts.join(', ');
    _buyerPhoneController.text = client.phone.trim();
    _buyerTaxIdController.text = client.cui.trim();
  }

  void _applySelectedJob() {
    final job = _selectedJob();
    if (job == null) {
      return;
    }
    if (_selectedBuyerClientId.trim().isEmpty &&
        job.clientId.trim().isNotEmpty) {
      _selectedBuyerClientId = job.clientId.trim();
    }
    _applySelectedClient();
    if (_buyerAddressController.text.trim().isEmpty) {
      final addressParts = <String>[
        job.location.trim(),
        job.city.trim(),
        job.county.trim(),
      ].where((item) => item.isNotEmpty).toList(growable: false);
      _buyerAddressController.text = addressParts.join(', ');
    }
    if (_buyerPhoneController.text.trim().isEmpty) {
      _buyerPhoneController.text = job.contactPhone.trim();
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final selectedJob = _selectedJob();
    final effectiveBuyerClientId = _selectedBuyerClientId.trim().isNotEmpty
        ? _selectedBuyerClientId.trim()
        : selectedJob?.clientId.trim() ?? '';
    Navigator.of(context).pop(
      widget.initial.copyWith(
        sourceType: _sourceType,
        buyerClientId: effectiveBuyerClientId,
        jobId: selectedJob?.id ?? _selectedJobId.trim(),
        jobTitle: selectedJob == null
            ? widget.initial.jobTitle
            : selectedJob.title.trim().isNotEmpty
                ? (selectedJob.jobCode.trim().isEmpty
                    ? selectedJob.title.trim()
                    : '${selectedJob.jobCode.trim()} | ${selectedJob.title.trim()}')
                : (selectedJob.jobCode.trim().isEmpty
                    ? widget.initial.jobTitle
                    : selectedJob.jobCode.trim()),
        certificateSeries: _seriesController.text.trim(),
        certificateNumber: _numberController.text.trim(),
        documentDate: _documentDate,
        equipmentType: _equipmentTypeController.text.trim(),
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        serialNumberIndoor: _serialIndoorController.text.trim(),
        serialNumberOutdoor: _serialOutdoorController.text.trim(),
        invoiceNumber: _invoiceController.text.trim(),
        saleDate: _saleDate,
        warrantyMonths: _parseInt(_warrantyMonthsController.text, fallback: 24),
        warrantyStartDate: _warrantyStartDate,
        warrantyEndDate: _warrantyEndDate,
        sellerName: _sellerNameController.text.trim(),
        sellerAddress: _sellerAddressController.text.trim(),
        sellerEmail: _sellerEmailController.text.trim(),
        sellerPhone: _sellerPhoneController.text.trim(),
        sellerTaxId: _sellerTaxIdController.text.trim(),
        buyerName: _buyerNameController.text.trim(),
        buyerAddress: _buyerAddressController.text.trim(),
        buyerPhone: _buyerPhoneController.text.trim(),
        buyerTaxOrCnp: _buyerTaxIdController.text.trim(),
        installerName: _installerNameController.text.trim(),
        installerAddress: _installerAddressController.text.trim(),
        installerEmail: _installerEmailController.text.trim(),
        installerPhone: _installerPhoneController.text.trim(),
        installerTaxId: _installerTaxIdController.text.trim(),
        installerPersons: _installerPersonsController.text.trim(),
        installationDate: _installationDate,
        termsText: _termsController.text.trim(),
        status: normalizeWarrantyCertificateStatus(_status),
        updatedAt: DateTime.now(),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          value == null
              ? '-'
              : '${value!.day.toString().padLeft(2, '0')}.${value!.month.toString().padLeft(2, '0')}.${value!.year}',
        ),
      ),
    );
  }
}

class _WarrantyTicketsSection extends StatelessWidget {
  const _WarrantyTicketsSection({
    required this.tickets,
  });

  final List<WarrantyServiceTicketRecord> tickets;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Istoric interventii / taloane',
        ),
        child: Text(
          'Nu exista inca interventii legate de certificat. Taloanele se alimenteaza din reclamatii si rapoarte service.',
        ),
      );
    }
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Istoric interventii / taloane',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tickets.map((ticket) {
          final parts = <String>[
            if (ticket.receivedDate != null)
              'Primire: ${_dateLabel(ticket.receivedDate)}',
            if (ticket.completedDate != null)
              'Finalizare: ${_dateLabel(ticket.completedDate)}',
            if (ticket.repairReportNumber.trim().isNotEmpty)
              'Fisa: ${ticket.repairReportNumber.trim()}',
            if (ticket.serviceSignatureLabel.trim().isNotEmpty)
              'Service: ${ticket.serviceSignatureLabel.trim()}',
          ];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.defect.trim().isEmpty
                      ? 'Interventie garantie'
                      : ticket.defect.trim(),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(parts.isEmpty ? '-' : parts.join(' | ')),
                if (ticket.description.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(ticket.description.trim()),
                  ),
              ],
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

int _parseInt(String? raw, {int fallback = 0}) {
  return int.tryParse((raw ?? '').trim()) ?? fallback;
}

String _dateLabel(DateTime? value) {
  if (value == null) return '-';
  return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
}
