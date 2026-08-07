import 'package:flutter/material.dart';

import '../offer_standard_catalog_models.dart';

class OfferCommercialClauseTemplateEditorDialog extends StatefulWidget {
  const OfferCommercialClauseTemplateEditorDialog({this.existing});

  final OfferCommercialClauseTemplate? existing;

  @override
  State<OfferCommercialClauseTemplateEditorDialog> createState() =>
      OfferCommercialClauseTemplateEditorDialogState();
}

class OfferCommercialClauseTemplateEditorDialogState
    extends State<OfferCommercialClauseTemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _categoryController = TextEditingController();
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _contentController.text = existing.content;
      _categoryController.text = existing.category;
      _isActive = existing.isActive;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Adaugă șablon comercial'
            : 'Editează șablon comercial',
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
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Titlu'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Completează titlul.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _categoryController,
                  decoration: const InputDecoration(labelText: 'Categorie'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _contentController,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Conținut'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Completează conținutul.';
                    }
                    return null;
                  },
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
              OfferCommercialClauseTemplate(
                id: widget.existing?.id ??
                    'clause-template-${now.microsecondsSinceEpoch}',
                title: _titleController.text.trim(),
                content: _contentController.text.trim(),
                isActive: _isActive,
                category: _categoryController.text.trim(),
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
