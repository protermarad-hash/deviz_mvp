import 'package:flutter/material.dart';

import '../offer_commercial_package_models.dart';
import '../offer_standard_catalog_models.dart';

class OfferCommercialPackageLaborDialog extends StatefulWidget {
  const OfferCommercialPackageLaborDialog({
    this.existing,
    required this.laborTemplates,
  });

  final OfferCommercialPackageLaborTemplate? existing;
  final List<OfferLaborTemplate> laborTemplates;

  @override
  State<OfferCommercialPackageLaborDialog> createState() =>
      OfferCommercialPackageLaborDialogState();
}

class OfferCommercialPackageLaborDialogState
    extends State<OfferCommercialPackageLaborDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _unitController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  String? _selectedTemplateId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _selectedTemplateId = existing.laborTemplateId.trim().isEmpty
          ? null
          : existing.laborTemplateId;
      _nameController.text = existing.name;
      _descriptionController.text = existing.description;
      _unitController.text = existing.unit;
      _quantityController.text = existing.quantity.toStringAsFixed(2);
      _unitPriceController.text = existing.unitPrice.toStringAsFixed(2);
    } else {
      _unitController.text = 'ore';
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

  OfferLaborTemplate? _templateById(String? id) {
    final value = (id ?? '').trim();
    if (value.isEmpty) return null;
    for (final item in widget.laborTemplates) {
      if (item.id == value) return item;
    }
    return null;
  }

  void _applyTemplate(OfferLaborTemplate template) {
    _nameController.text = template.name;
    _descriptionController.text = template.description.trim().isEmpty
        ? template.notes.trim()
        : template.description.trim();
    _unitController.text = template.unit.trim().isEmpty ? 'ore' : template.unit;
    _quantityController.text = template.defaultQuantity.toStringAsFixed(2);
    _unitPriceController.text = template.defaultUnitPrice.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Adaugă manoperă standard'
            : 'Editează manoperă standard',
      ),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: _selectedTemplateId != null &&
                          widget.laborTemplates.any(
                            (item) => item.id == _selectedTemplateId,
                          )
                      ? _selectedTemplateId
                      : null,
                  decoration:
                      const InputDecoration(labelText: 'Șablon manoperă'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Fără șablon'),
                    ),
                    ...widget.laborTemplates
                        .where((item) =>
                            item.isActive || item.id == _selectedTemplateId)
                        .map(
                          (item) => DropdownMenuItem<String?>(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedTemplateId = value;
                      final template = _templateById(value);
                      if (template != null) {
                        _applyTemplate(template);
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Cantitate'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _unitPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
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
              OfferCommercialPackageLaborTemplate(
                id: widget.existing?.id ??
                    'pkg-labor-${DateTime.now().microsecondsSinceEpoch}',
                name: _nameController.text.trim(),
                description: _descriptionController.text.trim(),
                unit: _unitController.text.trim().isEmpty
                    ? 'ore'
                    : _unitController.text.trim(),
                quantity: _asDouble(_quantityController.text, 1),
                unitPrice: _asDouble(_unitPriceController.text, 0),
                laborTemplateId: (_selectedTemplateId ?? '').trim(),
              ),
            );
          },
          child: const Text('Salvează'),
        ),
      ],
    );
  }
}
