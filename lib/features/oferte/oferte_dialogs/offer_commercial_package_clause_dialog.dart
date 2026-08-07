import 'package:flutter/material.dart';

import '../offer_commercial_package_models.dart';
import '../offer_standard_catalog_models.dart';

class OfferCommercialPackageClauseDialog extends StatefulWidget {
  const OfferCommercialPackageClauseDialog({
    this.existing,
    required this.clauseTemplates,
  });

  final OfferCommercialPackageClauseTemplate? existing;
  final List<OfferCommercialClauseTemplate> clauseTemplates;

  @override
  State<OfferCommercialPackageClauseDialog> createState() =>
      OfferCommercialPackageClauseDialogState();
}

class OfferCommercialPackageClauseDialogState
    extends State<OfferCommercialPackageClauseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _category = '';
  String? _selectedTemplateId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _contentController.text = existing.content;
      _selectedTemplateId =
          existing.templateId.trim().isEmpty ? null : existing.templateId;
      _category = existing.category;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  OfferCommercialClauseTemplate? _templateById(String? id) {
    final value = (id ?? '').trim();
    if (value.isEmpty) return null;
    for (final item in widget.clauseTemplates) {
      if (item.id == value) return item;
    }
    return null;
  }

  void _applyTemplate(OfferCommercialClauseTemplate template) {
    _titleController.text = template.title;
    _contentController.text = template.content;
    _category = template.category;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.existing == null ? 'Adaugă condiție' : 'Editează condiție'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String?>(
                initialValue: _selectedTemplateId != null &&
                        widget.clauseTemplates.any(
                          (item) => item.id == _selectedTemplateId,
                        )
                    ? _selectedTemplateId
                    : null,
                decoration: const InputDecoration(labelText: 'Șablon condiție'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Fără șablon'),
                  ),
                  ...widget.clauseTemplates
                      .where((item) =>
                          item.isActive || item.id == _selectedTemplateId)
                      .map(
                        (item) => DropdownMenuItem<String?>(
                          value: item.id,
                          child: Text(item.title),
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
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titlu'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Completează titlul.' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                textCapitalization: TextCapitalization.sentences,
                controller: _contentController,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Conținut'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Completează conținutul.'
                    : null,
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
              OfferCommercialPackageClauseTemplate(
                id: widget.existing?.id ??
                    'pkg-clause-${DateTime.now().microsecondsSinceEpoch}',
                title: _titleController.text.trim(),
                content: _contentController.text.trim(),
                templateId: (_selectedTemplateId ?? '').trim(),
                category: _category.trim(),
              ),
            );
          },
          child: const Text('Salvează'),
        ),
      ],
    );
  }
}
