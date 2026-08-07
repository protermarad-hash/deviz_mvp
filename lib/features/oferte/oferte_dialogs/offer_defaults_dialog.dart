import 'package:flutter/material.dart';

import '../offer_editor_defaults_store.dart';
import '../offer_models.dart';

class OfferDefaultsDialog extends StatefulWidget {
  const OfferDefaultsDialog({required this.initial});

  final OfferEditorDefaults initial;

  @override
  State<OfferDefaultsDialog> createState() => OfferDefaultsDialogState();
}

class OfferDefaultsDialogState extends State<OfferDefaultsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _vatController = TextEditingController();
  final _regieController = TextEditingController();
  final _profitController = TextEditingController();
  final _exchangeCommissionController = TextEditingController();

  late String _currency;
  late OfferExchangeRateSource _exchangeRateSource;

  @override
  void initState() {
    super.initState();
    _currency = widget.initial.currency;
    _exchangeRateSource = widget.initial.exchangeRateSource;
    _vatController.text = widget.initial.vatPercent.toStringAsFixed(2);
    _regieController.text = widget.initial.regiePercent.toStringAsFixed(2);
    _profitController.text = widget.initial.profitPercent.toStringAsFixed(2);
    _exchangeCommissionController.text =
        widget.initial.exchangeCommissionPercent.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _vatController.dispose();
    _regieController.dispose();
    _profitController.dispose();
    _exchangeCommissionController.dispose();
    super.dispose();
  }

  double _asDouble(String raw, [double fallback = 0]) {
    return double.tryParse(raw.replaceAll(',', '.').trim()) ?? fallback;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      OfferEditorDefaults(
        vatPercent: _asDouble(_vatController.text, 21),
        regiePercent: _asDouble(_regieController.text, 0),
        profitPercent: _asDouble(_profitController.text, 0),
        currency: _currency,
        exchangeRateSource: _exchangeRateSource,
        exchangeCommissionPercent:
            _asDouble(_exchangeCommissionController.text, 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Valori implicite ofertă'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration:
                          const InputDecoration(labelText: 'Monedă implicită'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'RON',
                          child: Text('RON'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'EUR',
                          child: Text('EUR'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'HUF',
                          child: Text('HUF'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _currency = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<OfferExchangeRateSource>(
                      initialValue: _exchangeRateSource,
                      decoration: const InputDecoration(
                          labelText: 'Sursa curs implicită'),
                      items: OfferExchangeRateSource.values
                          .map(
                            (item) => DropdownMenuItem<OfferExchangeRateSource>(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _exchangeRateSource = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _vatController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'TVA % implicit'),
                      validator: (value) {
                        final parsed = _asDouble(value ?? '', -1);
                        if (parsed < 0) return 'TVA trebuie să fie >= 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _regieController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Regie % implicită'),
                      validator: (value) {
                        final parsed = _asDouble(value ?? '', -1);
                        if (parsed < 0) return 'Regia trebuie să fie >= 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _profitController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Profit % implicit'),
                      validator: (value) {
                        final parsed = _asDouble(value ?? '', -1);
                        if (parsed < 0) return 'Profitul trebuie să fie >= 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _exchangeCommissionController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Comision curs % implicit'),
                      validator: (value) {
                        final parsed = _asDouble(value ?? '', -1);
                        if (parsed < 0) return 'Comisionul trebuie să fie >= 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Salvează'),
        ),
      ],
    );
  }
}
