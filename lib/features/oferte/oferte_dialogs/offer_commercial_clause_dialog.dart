import 'package:flutter/material.dart';

import '../offer_models.dart';
import '../offer_standard_catalog_models.dart';

class OfferCommercialClauseDialog extends StatefulWidget {
  const OfferCommercialClauseDialog({
    required this.templates,
    required this.initialSortOrder,
    this.existing,
  });

  final List<OfferCommercialClauseTemplate> templates;
  final int initialSortOrder;
  final OfferCommercialClause? existing;

  @override
  State<OfferCommercialClauseDialog> createState() =>
      OfferCommercialClauseDialogState();
}

class OfferCommercialClauseDialogState
    extends State<OfferCommercialClauseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String? _selectedTemplateId;
  String _category = '';

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _selectedTemplateId =
          existing.templateId.trim().isEmpty ? null : existing.templateId;
      _titleController.text = existing.title;
      _contentController.text = existing.content;
      _category = existing.category;
    } else if (widget.templates.length == 1) {
      final template = widget.templates.first;
      _selectedTemplateId = template.id;
      _applyTemplate(template);
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
    if (value.isEmpty) {
      return null;
    }
    for (final item in widget.templates) {
      if (item.id == value) {
        return item;
      }
    }
    return null;
  }

  void _applyTemplate(OfferCommercialClauseTemplate template) {
    _titleController.text = template.title.trim();
    _contentController.text = template.content.trim();
    _category = template.category.trim();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Adaugă condiție comercială'
            : 'Editează condiție comercială',
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
                          widget.templates.any(
                            (item) => item.id == _selectedTemplateId,
                          )
                      ? _selectedTemplateId
                      : null,
                  decoration:
                      const InputDecoration(labelText: 'Șablon comercial'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Fără șablon'),
                    ),
                    ...widget.templates
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
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Completează titlul condiției comerciale.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _contentController,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Conținut'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Completează conținutul condiției comerciale.';
                    }
                    return null;
                  },
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
              OfferCommercialClause(
                id: widget.existing?.id ??
                    'clause-${DateTime.now().microsecondsSinceEpoch}',
                title: _titleController.text.trim(),
                content: _contentController.text.trim(),
                templateId: (_selectedTemplateId ?? '').trim(),
                category: _category.trim(),
                sortOrder:
                    widget.existing?.sortOrder ?? widget.initialSortOrder,
              ),
            );
          },
          child: const Text('Salvează'),
        ),
      ],
    );
  }
}





