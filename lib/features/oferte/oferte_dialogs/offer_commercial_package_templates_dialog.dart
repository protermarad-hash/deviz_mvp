import 'package:flutter/material.dart';

import '../offer_commercial_package_models.dart';
import '../offer_standard_catalog_models.dart';
import 'offer_commercial_package_template_editor_dialog.dart';

class OfferCommercialPackageTemplatesDialog extends StatefulWidget {
  const OfferCommercialPackageTemplatesDialog({
    required this.items,
    required this.laborTemplates,
    required this.clauseTemplates,
    required this.onSave,
  });

  final List<OfferCommercialPackageTemplate> items;
  final List<OfferLaborTemplate> laborTemplates;
  final List<OfferCommercialClauseTemplate> clauseTemplates;
  final Future<void> Function(OfferCommercialPackageTemplate item) onSave;

  @override
  State<OfferCommercialPackageTemplatesDialog> createState() =>
      OfferCommercialPackageTemplatesDialogState();
}

class OfferCommercialPackageTemplatesDialogState
    extends State<OfferCommercialPackageTemplatesDialog> {
  bool _saving = false;

  Future<void> _editTemplate([OfferCommercialPackageTemplate? existing]) async {
    final saved = await showDialog<OfferCommercialPackageTemplate>(
      context: context,
      builder: (context) => OfferCommercialPackageTemplateEditorDialog(
        existing: existing,
        laborTemplates: widget.laborTemplates,
        clauseTemplates: widget.clauseTemplates,
      ),
    );
    if (saved == null || _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(saved);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [...widget.items]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return AlertDialog(
      title: const Text('Pachete comerciale standard'),
      content: SizedBox(
        width: 820,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _editTemplate(),
                icon: const Icon(Icons.add),
                label: const Text('Adaugă'),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: items.isEmpty
                  ? const Center(
                      child: Text('Nu există pachete comerciale standard.'),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.description.trim().isEmpty ? '-' : item.description.trim()}\n'
                            'Materiale: ${item.materials.length} • Manoperă standard: ${item.standardLabor.length} • Condiții: ${item.commercialClauses.length}\n'
                            'Status: ${item.isActive ? 'Activ' : 'Inactiv'}',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: 'Editează',
                            onPressed:
                                _saving ? null : () => _editTemplate(item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Închide'),
        ),
      ],
    );
  }
}

