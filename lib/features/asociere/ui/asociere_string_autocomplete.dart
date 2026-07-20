import 'package:flutter/material.dart';

/// Câmp de căutare/selecție cu autocomplete pentru valori text (lucrător,
/// calificare) — respectă regula permanentă „toate dropdown-urile noi au
/// autosearch". Permite și valori libere (ce tastează utilizatorul), nu doar
/// din listă. Mirror al pattern-ului din partner_autocomplete_field.dart.
class AsociereStringAutocomplete extends StatelessWidget {
  const AsociereStringAutocomplete({
    super.key,
    required this.label,
    required this.optiuni,
    required this.value,
    required this.onChanged,
    this.helper,
  });

  final String label;
  final List<String> optiuni;
  final String value;
  final ValueChanged<String> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: value),
      optionsBuilder: (t) {
        final q = t.text.trim().toLowerCase();
        if (q.isEmpty) return optiuni;
        return optiuni.where((o) => o.toLowerCase().contains(q));
      },
      onSelected: onChanged,
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: onChanged,
        );
      },
    );
  }
}
