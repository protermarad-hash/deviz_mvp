import 'package:flutter/material.dart';

import '../../partners/partner_models.dart';

/// Autosearch pentru "Personal salvat" din registrul partenerului —
/// înlocuiește dropdown-ul simplu cu căutare pe măsură ce se tastează
/// (regula UI permanentă din CLAUDE.md pentru câmpuri de selecție).
///
/// Extras separat din `partner_worker_dialog.dart` (regula dimensiune
/// fișiere — widget de sine stătător, fără stare partajată cu dialogul).
class PartnerWorkerAutocomplete extends StatelessWidget {
  const PartnerWorkerAutocomplete({
    super.key,
    required this.controller,
    required this.options,
    required this.onSelected,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<PartnerWorkerRecord> options;
  final void Function(PartnerWorkerRecord) onSelected;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return TextField(
        textCapitalization: TextCapitalization.sentences,
        controller: controller,
        decoration: const InputDecoration(labelText: 'Nume complet'),
        onChanged: onChanged,
      );
    }
    return Autocomplete<PartnerWorkerRecord>(
      initialValue: TextEditingValue(text: controller.text),
      displayStringForOption: (option) => option.fullName,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return options;
        return options.where(
          (o) => o.fullName.toLowerCase().contains(query),
        );
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, fieldCtrl, focusNode, onSubmit) {
        // Sincronizează controller-ul extern (folosit la salvare) cu cel
        // intern al Autocomplete direct din callback-ul TextField —
        // NU prin addListener() pe fieldCtrl (controller-ul intern al
        // Autocomplete poate fi recreat/disposed între rebuild-uri,
        // provocând "TextEditingController was used after being disposed").
        if (fieldCtrl.text != controller.text) {
          fieldCtrl.text = controller.text;
        }
        return TextField(
          controller: fieldCtrl,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nume complet',
            helperText: 'Caută în personalul salvat al partenerului',
          ),
          onChanged: (value) {
            controller.text = value;
            onChanged(value);
          },
        );
      },
    );
  }
}
