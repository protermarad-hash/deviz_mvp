import 'package:flutter/material.dart';

import '../integrations/anaf_company_lookup_service.dart';

class AnafCompanyAutofillSection extends StatefulWidget {
  const AnafCompanyAutofillSection({
    super.key,
    required this.cuiController,
    required this.nameController,
    this.tradeRegisterController,
    this.phoneController,
    this.ibanController,
    this.addressController,
    this.cityController,
    this.countyController,
    this.buttonLabel = 'Preia date',
    this.lookupDisabled = false,
    this.disabledMessage =
        'Preluarea ANAF este disponibila doar pentru persoana juridica noua.',
    this.onDataApplied,
  });

  final TextEditingController cuiController;
  final TextEditingController nameController;
  final TextEditingController? tradeRegisterController;
  final TextEditingController? phoneController;
  final TextEditingController? ibanController;
  final TextEditingController? addressController;
  final TextEditingController? cityController;
  final TextEditingController? countyController;
  final String buttonLabel;
  final bool lookupDisabled;
  final String disabledMessage;
  final ValueChanged<AnafCompanyData>? onDataApplied;

  @override
  State<AnafCompanyAutofillSection> createState() =>
      _AnafCompanyAutofillSectionState();
}

class _AnafCompanyAutofillSectionState extends State<AnafCompanyAutofillSection> {
  final AnafCompanyLookupService _service = const AnafCompanyLookupService();
  String? _message;
  bool _isError = false;
  bool _loading = false;

  String _buildSummary(AnafCompanyData company) {
    String boolLabel(bool? value, String yes, String no) {
      if (value == null) return '';
      return value ? yes : no;
    }

    final parts = <String>[
      if (company.registrationStatus.trim().isNotEmpty)
        'Stare: ${company.registrationStatus.trim()}',
      if (company.caenCode.trim().isNotEmpty)
        'CAEN: ${company.caenCode.trim()}',
      if (company.fiscalAuthority.trim().isNotEmpty)
        'Organ fiscal: ${company.fiscalAuthority.trim()}',
      if (company.legalForm.trim().isNotEmpty)
        'Forma juridica: ${company.legalForm.trim()}',
      if (company.organizationForm.trim().isNotEmpty)
        'Forma organizare: ${company.organizationForm.trim()}',
      if (company.ownershipForm.trim().isNotEmpty)
        'Forma proprietate: ${company.ownershipForm.trim()}',
      boolLabel(company.vatRegistered, 'Platitor TVA', 'Neplatitor TVA'),
      boolLabel(company.vatOnCash, 'TVA la incasare', 'Fara TVA la incasare'),
      boolLabel(company.splitVat, 'Split TVA activ', 'Fara split TVA'),
      boolLabel(company.inactive, 'Contribuabil inactiv', 'Contribuabil activ'),
      boolLabel(
        company.eFactura,
        'In Registrul RO e-Factura',
        'Nu figureaza in Registrul RO e-Factura',
      ),
    ].where((item) => item.trim().isNotEmpty).toList(growable: false);
    return parts.join(' | ');
  }

  Future<void> _lookup() async {
    if (_loading) return;
    if (widget.lookupDisabled) {
      setState(() {
        _isError = true;
        _message = widget.disabledMessage;
      });
      return;
    }

    setState(() {
      _loading = true;
      _isError = false;
      _message = 'Se interogheaza ANAF...';
    });

    final result = await _service.lookupByCui(widget.cuiController.text);
    if (!mounted) return;

    setState(() {
      _loading = false;
      _isError = !result.isSuccess;
      _message = result.message;
      final company = result.company;
      if (company == null) return;

      if (company.name.trim().isNotEmpty) {
        widget.nameController.text = company.name.trim();
      }
      if (company.cui.trim().isNotEmpty) {
        widget.cuiController.text = company.cui.trim();
      }
      if (company.tradeRegisterNumber.trim().isNotEmpty) {
        widget.tradeRegisterController?.text = company.tradeRegisterNumber.trim();
      }
      if (company.phone.trim().isNotEmpty) {
        widget.phoneController?.text = company.phone.trim();
      }
      if (company.iban.trim().isNotEmpty) {
        widget.ibanController?.text = company.iban.trim();
      }
      if (company.address.trim().isNotEmpty) {
        widget.addressController?.text = company.address.trim();
      }
      if (company.city.trim().isNotEmpty) {
        widget.cityController?.text = company.city.trim();
      }
      if (company.county.trim().isNotEmpty) {
        widget.countyController?.text = company.county.trim();
      }

      widget.onDataApplied?.call(company);
      final summary = _buildSummary(company);
      if (summary.isNotEmpty) {
        _message = '${result.message}\n$summary';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = _message?.trim() ?? '';
    final color = _isError ? Colors.orange.shade800 : Colors.green.shade800;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: widget.cuiController,
                decoration: const InputDecoration(labelText: 'CUI'),
              ),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _lookup,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(_loading ? 'Se preiau datele...' : widget.buttonLabel),
            ),
            const Text('Sursa oficiala: ANAF'),
          ],
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: color),
          ),
        ],
      ],
    );
  }
}
