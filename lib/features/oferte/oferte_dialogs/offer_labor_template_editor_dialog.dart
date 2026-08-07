import 'package:flutter/material.dart';

import '../offer_standard_catalog_models.dart';

class OfferLaborTemplateEditorDialog extends StatefulWidget {
  const OfferLaborTemplateEditorDialog({this.existing});

  final OfferLaborTemplate? existing;

  @override
  State<OfferLaborTemplateEditorDialog> createState() =>
      OfferLaborTemplateEditorDialogState();
}

class OfferLaborTemplateEditorDialogState
    extends State<OfferLaborTemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _unitController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _includedServicesController = TextEditingController();
  final _suggestedProductKeywordsController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _categoryController.text = existing.category;
      _descriptionController.text = existing.description;
      _unitController.text = existing.unit;
      _quantityController.text = existing.defaultQuantity.toStringAsFixed(2);
      _unitPriceController.text = existing.defaultUnitPrice.toStringAsFixed(2);
      _includedServicesController.text = existing.includedServices;
      _suggestedProductKeywordsController.text =
          existing.suggestedProductKeywords;
      _notesController.text = existing.notes;
      _isActive = existing.isActive;
    } else {
      _categoryController.text = 'servicii_baza';
      _unitController.text = 'ore';
      _quantityController.text = '1';
      _unitPriceController.text = '0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _unitController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _includedServicesController.dispose();
    _suggestedProductKeywordsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double _asDouble(String raw, [double fallback = 0]) {
    return double.tryParse(raw.replaceAll(',', '.').trim()) ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Adaugă șablon manoperă'
            : 'Editează șablon manoperă',
      ),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Denumire'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Completează denumirea.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Categorie serviciu',
                    helperText:
                        'Exemple: montaj, traseu_frigorific, pif, servicii_baza',
                  ),
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
                        decoration: const InputDecoration(
                          labelText: 'Cantitate implicită',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _unitPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Preț unitar implicit',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _includedServicesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Servicii incluse implicite',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _suggestedProductKeywordsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Cuvinte-cheie sugestie produse',
                    helperText:
                        'Separate prin virgula: ex. aer conditionat, 12000 btu, inverter',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Conditii comerciale / note',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: const Text('Activ'),
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
            final now = DateTime.now();
            Navigator.of(context).pop(
              OfferLaborTemplate(
                id: widget.existing?.id ??
                    'labor-template-${now.microsecondsSinceEpoch}',
                name: _nameController.text.trim(),
                category: _categoryController.text.trim(),
                description: _descriptionController.text.trim(),
                unit: _unitController.text.trim().isEmpty
                    ? 'ore'
                    : _unitController.text.trim(),
                defaultQuantity: _asDouble(_quantityController.text, 1),
                defaultUnitPrice: _asDouble(_unitPriceController.text, 0),
                isActive: _isActive,
                notes: _notesController.text.trim(),
                includedServices: _includedServicesController.text.trim(),
                suggestedProductKeywords:
                    _suggestedProductKeywordsController.text.trim(),
                createdAt: widget.existing?.createdAt ?? now,
                updatedAt: now,
              ),
            );
          },
          child: const Text('Salvează'),
        ),
      ],
    );
  }
}
