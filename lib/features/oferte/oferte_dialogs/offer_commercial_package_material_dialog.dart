import 'package:flutter/material.dart';

import '../offer_commercial_package_models.dart';

class OfferCommercialPackageMaterialDialog extends StatefulWidget {
  const OfferCommercialPackageMaterialDialog({this.existing});

  final OfferCommercialPackageMaterialTemplate? existing;

  @override
  State<OfferCommercialPackageMaterialDialog> createState() =>
      OfferCommercialPackageMaterialDialogState();
}

class OfferCommercialPackageMaterialDialogState
    extends State<OfferCommercialPackageMaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _unitController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _descriptionController.text = existing.description;
      _unitController.text = existing.unit;
      _quantityController.text = existing.quantity.toStringAsFixed(2);
      _unitPriceController.text = existing.unitPrice.toStringAsFixed(2);
    } else {
      _unitController.text = 'buc';
      _quantityController.text = '1';
      _unitPriceController.text = '0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _unitController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  double _asDouble(String raw, [double fallback = 0]) {
    return double.tryParse(raw.replaceAll(',', '.').trim()) ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.existing == null ? 'Adaugă material' : 'Editează material'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                textCapitalization: TextCapitalization.sentences,
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Denumire'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Completează denumirea.'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                textCapitalization: TextCapitalization.sentences,
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descriere'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: _unitController,
                      decoration: const InputDecoration(labelText: 'UM'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Cantitate'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _unitPriceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Preț unitar'),
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
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(
              OfferCommercialPackageMaterialTemplate(
                id: widget.existing?.id ??
                    'pkg-material-${DateTime.now().microsecondsSinceEpoch}',
                name: _nameController.text.trim(),
                description: _descriptionController.text.trim(),
                unit: _unitController.text.trim().isEmpty
                    ? 'buc'
                    : _unitController.text.trim(),
                quantity: _asDouble(_quantityController.text, 1),
                unitPrice: _asDouble(_unitPriceController.text, 0),
                materialId: widget.existing?.materialId ?? '',
              ),
            );
          },
          child: const Text('Salvează'),
        ),
      ],
    );
  }
}
