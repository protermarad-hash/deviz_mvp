import 'package:flutter/material.dart';

import '../offer_commercial_package_models.dart';
import '../offer_standard_catalog_models.dart';
import 'offer_commercial_package_clause_dialog.dart';
import 'offer_commercial_package_labor_dialog.dart';
import 'offer_commercial_package_material_dialog.dart';

class OfferCommercialPackageTemplateEditorDialog extends StatefulWidget {
  const OfferCommercialPackageTemplateEditorDialog({
    this.existing,
    required this.laborTemplates,
    required this.clauseTemplates,
  });

  final OfferCommercialPackageTemplate? existing;
  final List<OfferLaborTemplate> laborTemplates;
  final List<OfferCommercialClauseTemplate> clauseTemplates;

  @override
  State<OfferCommercialPackageTemplateEditorDialog> createState() =>
      OfferCommercialPackageTemplateEditorDialogState();
}

class OfferCommercialPackageTemplateEditorDialogState
    extends State<OfferCommercialPackageTemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isActive = true;
  List<OfferCommercialPackageMaterialTemplate> _materials =
      <OfferCommercialPackageMaterialTemplate>[];
  List<OfferCommercialPackageLaborTemplate> _labor =
      <OfferCommercialPackageLaborTemplate>[];
  List<OfferCommercialPackageClauseTemplate> _clauses =
      <OfferCommercialPackageClauseTemplate>[];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _descriptionController.text = existing.description;
      _isActive = existing.isActive;
      _materials = existing.materials.map((item) => item.copyWith()).toList();
      _labor = existing.standardLabor.map((item) => item.copyWith()).toList();
      _clauses =
          existing.commercialClauses.map((item) => item.copyWith()).toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addMaterial(
      [OfferCommercialPackageMaterialTemplate? existing]) async {
    final saved = await showDialog<OfferCommercialPackageMaterialTemplate>(
      context: context,
      builder: (context) => OfferCommercialPackageMaterialDialog(
        existing: existing,
      ),
    );
    if (saved == null) {
      return;
    }
    setState(() {
      if (existing == null) {
        _materials = [..._materials, saved];
      } else {
        _materials = _materials
            .map((item) => item.id == existing.id ? saved : item)
            .toList(growable: false);
      }
    });
  }

  Future<void> _addLabor(
      [OfferCommercialPackageLaborTemplate? existing]) async {
    final saved = await showDialog<OfferCommercialPackageLaborTemplate>(
      context: context,
      builder: (context) => OfferCommercialPackageLaborDialog(
        existing: existing,
        laborTemplates: widget.laborTemplates,
      ),
    );
    if (saved == null) {
      return;
    }
    setState(() {
      if (existing == null) {
        _labor = [..._labor, saved];
      } else {
        _labor = _labor
            .map((item) => item.id == existing.id ? saved : item)
            .toList(growable: false);
      }
    });
  }

  Future<void> _addClause(
      [OfferCommercialPackageClauseTemplate? existing]) async {
    final saved = await showDialog<OfferCommercialPackageClauseTemplate>(
      context: context,
      builder: (context) => OfferCommercialPackageClauseDialog(
        existing: existing,
        clauseTemplates: widget.clauseTemplates,
      ),
    );
    if (saved == null) {
      return;
    }
    setState(() {
      if (existing == null) {
        _clauses = [..._clauses, saved];
      } else {
        _clauses = _clauses
            .map((item) => item.id == existing.id ? saved : item)
            .toList(growable: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Adaugă pachet comercial'
            : 'Editează pachet comercial',
      ),
      content: SizedBox(
        width: 860,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _nameController,
                  decoration:
                      const InputDecoration(labelText: 'Denumire pachet'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Completează denumirea pachetului.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descriere'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: const Text('Activ'),
                ),
                _packageSection<OfferCommercialPackageMaterialTemplate>(
                  title: 'Materiale standard',
                  onAdd: () => _addMaterial(),
                  items: _materials,
                  itemLabel: (item) =>
                      '${item.name} • ${item.quantity.toStringAsFixed(2)} ${item.unit} • ${item.unitPrice.toStringAsFixed(2)}',
                  onEdit: (item) => _addMaterial(item),
                  onDelete: (item) => setState(
                    () => _materials = _materials
                        .where((row) => row.id != item.id)
                        .toList(growable: false),
                  ),
                ),
                _packageSection<OfferCommercialPackageLaborTemplate>(
                  title: 'Manoperă standard',
                  onAdd: () => _addLabor(),
                  items: _labor,
                  itemLabel: (item) =>
                      '${item.name} • ${item.quantity.toStringAsFixed(2)} ${item.unit} • ${item.unitPrice.toStringAsFixed(2)}',
                  onEdit: (item) => _addLabor(item),
                  onDelete: (item) => setState(
                    () => _labor = _labor
                        .where((row) => row.id != item.id)
                        .toList(growable: false),
                  ),
                ),
                _packageSection<OfferCommercialPackageClauseTemplate>(
                  title: 'Condiții comerciale',
                  onAdd: () => _addClause(),
                  items: _clauses,
                  itemLabel: (item) => item.title,
                  onEdit: (item) => _addClause(item),
                  onDelete: (item) => setState(
                    () => _clauses = _clauses
                        .where((row) => row.id != item.id)
                        .toList(growable: false),
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
            if (!_formKey.currentState!.validate()) {
              return;
            }
            final now = DateTime.now();
            Navigator.of(context).pop(
              OfferCommercialPackageTemplate(
                id: widget.existing?.id ??
                    'package-template-${now.microsecondsSinceEpoch}',
                name: _nameController.text.trim(),
                description: _descriptionController.text.trim(),
                isActive: _isActive,
                materials: _materials,
                standardLabor: _labor,
                commercialClauses: _clauses,
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

  Widget _packageSection<T>({
    required String title,
    required VoidCallback onAdd,
    required List<T> items,
    required String Function(T item) itemLabel,
    required Future<void> Function(T item) onEdit,
    required void Function(T item) onDelete,
  }) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Adaugă'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('Nu există elemente în această secțiune.')
            else
              Column(
                children: items
                    .map(
                      (item) => ListTile(
                        title: Text(itemLabel(item)),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              onPressed: () => onEdit(item),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              onPressed: () => onDelete(item),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}



