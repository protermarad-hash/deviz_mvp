import 'package:flutter/material.dart';

import '../../features/partners/partner_models.dart';

/// Widget reutilizabil pentru căutare/selecție partener/colaborator cu autocompletare.
///
/// Înlocuiește [DropdownButtonFormField<String>] pentru parteneri oriunde în aplicație.
/// Utilizatorul tastează (minim 1 caracter) și primește sugestii filtrate după
/// nume, localitate, telefon sau CUI.
class PartnerAutocompleteField extends StatelessWidget {
  const PartnerAutocompleteField({
    super.key,
    required this.partners,
    this.initialPartner,
    this.labelText = 'Partener',
    this.helperText,
    required this.onPartnerSelected,
    this.onCreateNew,
    this.enabled = true,
  });

  final List<PartnerRecord> partners;
  final PartnerRecord? initialPartner;
  final String labelText;
  final String? helperText;
  final void Function(PartnerRecord?) onPartnerSelected;

  /// Callback opțional pentru butonul "Adaugă nou".
  /// Dacă este null, butonul nu apare.
  final VoidCallback? onCreateNew;
  final bool enabled;

  Iterable<PartnerRecord> _suggest(TextEditingValue textEditingValue) {
    final q = textEditingValue.text.trim().toLowerCase();
    if (q.isEmpty) return const Iterable<PartnerRecord>.empty();
    return partners.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.city.toLowerCase().contains(q) ||
          p.phone.toLowerCase().contains(q) ||
          (p.cui.isNotEmpty && p.cui.toLowerCase().contains(q)) ||
          (p.county.isNotEmpty && p.county.toLowerCase().contains(q)) ||
          (p.contactPerson.isNotEmpty &&
              p.contactPerson.toLowerCase().contains(q));
    }).take(12);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Autocomplete<PartnerRecord>(
            initialValue: initialPartner != null
                ? TextEditingValue(text: initialPartner!.name)
                : null,
            displayStringForOption: (p) => p.name,
            optionsBuilder: _suggest,
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 300,
                      maxWidth: 420,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (_, i) {
                        final p = options.elementAt(i);
                        final parts = <String>[
                          if (p.city.trim().isNotEmpty) p.city.trim(),
                          if (p.county.trim().isNotEmpty) p.county.trim(),
                          if (p.cui.trim().isNotEmpty) 'CUI: ${p.cui.trim()}',
                          if (p.contactPerson.trim().isNotEmpty)
                            p.contactPerson.trim(),
                          if (p.phone.trim().isNotEmpty) p.phone.trim(),
                        ];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onSelected(p),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.handshake_outlined,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          p.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (parts.isNotEmpty)
                                          Text(
                                            parts.join(' · '),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            fieldViewBuilder: (ctx, textCtrl, focusNode, onFieldSubmitted) {
              return TextFormField(
                controller: textCtrl,
                focusNode: focusNode,
                enabled: enabled,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: labelText,
                  helperText: helperText,
                  suffixIcon: ListenableBuilder(
                    listenable: textCtrl,
                    builder: (_, __) => textCtrl.text.isNotEmpty && enabled
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            tooltip: 'Golește selecția',
                            onPressed: () {
                              textCtrl.clear();
                              onPartnerSelected(null);
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                onFieldSubmitted: (_) => onFieldSubmitted(),
              );
            },
            onSelected: onPartnerSelected,
          ),
        ),
        if (onCreateNew != null) ...[
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: enabled ? onCreateNew : null,
            icon: const Icon(Icons.add_outlined, size: 14),
            label: const Text('Nou'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
          ),
        ],
      ],
    );
  }
}
