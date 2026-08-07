import 'package:flutter/material.dart';

import '../company_cost_profile_models.dart';

class CompanyCostProfileDialog extends StatefulWidget {
  const CompanyCostProfileDialog({required this.initial});

  final CompanyCostProfile initial;

  @override
  State<CompanyCostProfileDialog> createState() =>
      CompanyCostProfileDialogState();
}

class CompanyCostProfileDialogState extends State<CompanyCostProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _administrativeController;
  late final TextEditingController _rentController;
  late final TextEditingController _utilitiesController;
  late final TextEditingController _fuelController;
  late final TextEditingController _telecomController;
  late final TextEditingController _accountingController;
  late final TextEditingController _softwareController;
  late final TextEditingController _leasingController;
  late final TextEditingController _insuranceController;
  late final TextEditingController _otherIndirectController;
  late final TextEditingController _productiveEmployeesController;
  late final TextEditingController _productiveHoursController;
  late final TextEditingController _productivityCoefficientController;
  late final TextEditingController _employerContributionController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _administrativeController = TextEditingController(
      text: initial.administrativeMonthlyCosts.toStringAsFixed(2),
    );
    _rentController =
        TextEditingController(text: initial.rent.toStringAsFixed(2));
    _utilitiesController =
        TextEditingController(text: initial.utilities.toStringAsFixed(2));
    _fuelController =
        TextEditingController(text: initial.generalFuel.toStringAsFixed(2));
    _telecomController =
        TextEditingController(text: initial.telecomInternet.toStringAsFixed(2));
    _accountingController =
        TextEditingController(text: initial.accounting.toStringAsFixed(2));
    _softwareController = TextEditingController(
        text: initial.softwareLicenses.toStringAsFixed(2));
    _leasingController = TextEditingController(
      text: initial.operationalLeasing.toStringAsFixed(2),
    );
    _insuranceController =
        TextEditingController(text: initial.insurance.toStringAsFixed(2));
    _otherIndirectController = TextEditingController(
      text: initial.otherIndirectCosts.toStringAsFixed(2),
    );
    _productiveEmployeesController = TextEditingController(
      text: initial.productiveEmployeeCount.toString(),
    );
    _productiveHoursController = TextEditingController(
      text: initial.productiveHoursPerMonth.toStringAsFixed(2),
    );
    _productivityCoefficientController = TextEditingController(
      text: initial.productivityCoefficient.toStringAsFixed(2),
    );
    _employerContributionController = TextEditingController(
      text: initial.employerContributionPercent.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _administrativeController.dispose();
    _rentController.dispose();
    _utilitiesController.dispose();
    _fuelController.dispose();
    _telecomController.dispose();
    _accountingController.dispose();
    _softwareController.dispose();
    _leasingController.dispose();
    _insuranceController.dispose();
    _otherIndirectController.dispose();
    _productiveEmployeesController.dispose();
    _productiveHoursController.dispose();
    _productivityCoefficientController.dispose();
    _employerContributionController.dispose();
    super.dispose();
  }

  double _asDouble(String raw, [double fallback = 0]) {
    return double.tryParse(raw.replaceAll(',', '.').trim()) ?? fallback;
  }

  int _asInt(String raw, [int fallback = 0]) {
    return int.tryParse(raw.trim()) ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final preview = CompanyCostProfile(
      administrativeMonthlyCosts: _asDouble(_administrativeController.text, 0),
      rent: _asDouble(_rentController.text, 0),
      utilities: _asDouble(_utilitiesController.text, 0),
      generalFuel: _asDouble(_fuelController.text, 0),
      telecomInternet: _asDouble(_telecomController.text, 0),
      accounting: _asDouble(_accountingController.text, 0),
      softwareLicenses: _asDouble(_softwareController.text, 0),
      operationalLeasing: _asDouble(_leasingController.text, 0),
      insurance: _asDouble(_insuranceController.text, 0),
      otherIndirectCosts: _asDouble(_otherIndirectController.text, 0),
      productiveEmployeeCount: _asInt(_productiveEmployeesController.text, 0),
      productiveHoursPerMonth: _asDouble(_productiveHoursController.text, 168),
      productivityCoefficient:
          _asDouble(_productivityCoefficientController.text, 1),
      employerContributionPercent:
          _asDouble(_employerContributionController.text, 2.25),
    );
    return AlertDialog(
      title: const Text('Costuri reale societate'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _costRow(
                  _administrativeController,
                  'Cheltuieli administrative lunare',
                ),
                const SizedBox(height: 8),
                _costRow(_rentController, 'Chirie'),
                const SizedBox(height: 8),
                _costRow(_utilitiesController, 'Utilitati'),
                const SizedBox(height: 8),
                _costRow(_fuelController, 'Combustibil general'),
                const SizedBox(height: 8),
                _costRow(_telecomController, 'Telefonie / internet'),
                const SizedBox(height: 8),
                _costRow(_accountingController, 'Contabilitate'),
                const SizedBox(height: 8),
                _costRow(_softwareController, 'Software / licente'),
                const SizedBox(height: 8),
                _costRow(_leasingController, 'Leasinguri / rate operationale'),
                const SizedBox(height: 8),
                _costRow(_insuranceController, 'Asigurari'),
                const SizedBox(height: 8),
                _costRow(_otherIndirectController, 'Alte costuri indirecte'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _productiveEmployeesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Numar angajati productivi',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _productiveHoursController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Ore productive lunare standard',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _productivityCoefficientController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Coeficient productivitate',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _employerContributionController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Contributii angajator %',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Total indirect lunar: ${preview.totalIndirectMonthlyCost.toStringAsFixed(2)} • '
                    'Ore productive efective: ${preview.effectiveProductiveHoursPerMonth.toStringAsFixed(2)}',
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
          onPressed: () {
            Navigator.of(context).pop(
              widget.initial.copyWith(
                administrativeMonthlyCosts:
                    _asDouble(_administrativeController.text, 0),
                rent: _asDouble(_rentController.text, 0),
                utilities: _asDouble(_utilitiesController.text, 0),
                generalFuel: _asDouble(_fuelController.text, 0),
                telecomInternet: _asDouble(_telecomController.text, 0),
                accounting: _asDouble(_accountingController.text, 0),
                softwareLicenses: _asDouble(_softwareController.text, 0),
                operationalLeasing: _asDouble(_leasingController.text, 0),
                insurance: _asDouble(_insuranceController.text, 0),
                otherIndirectCosts: _asDouble(_otherIndirectController.text, 0),
                productiveEmployeeCount:
                    _asInt(_productiveEmployeesController.text, 0),
                productiveHoursPerMonth:
                    _asDouble(_productiveHoursController.text, 168),
                productivityCoefficient:
                    _asDouble(_productivityCoefficientController.text, 1),
                employerContributionPercent:
                    _asDouble(_employerContributionController.text, 2.25),
                updatedAt: DateTime.now(),
              ),
            );
          },
          child: const Text('Salveaza'),
        ),
      ],
    );
  }

  Widget _costRow(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }
}
