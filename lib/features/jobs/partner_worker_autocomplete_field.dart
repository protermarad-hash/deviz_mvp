import 'package:flutter/material.dart';

import '../partners/partner_models.dart';

/// Widget reutilizabil pentru căutare/selecție muncitor partener din catalog,
/// cu autocompletare — modelat direct pe
/// `lib/core/widgets/partner_autocomplete_field.dart` (PartnerAutocompleteField),
/// singurul pattern de căutare-cu-autocompletare găsit deja în aplicație
/// pentru selecții similare (client/partener/serviciu).
///
/// Înlocuiește un `DropdownButtonFormField` simplu (fără filtrare) — cerință
/// explicită: orice listă care poate deveni lungă trebuie să aibă
/// căutare/autosearch, nu doar un dropdown static.
class PartnerWorkerAutocompleteField extends StatelessWidget {
  const PartnerWorkerAutocompleteField({
    super.key,
    required this.workers,
    this.initialWorker,
    this.labelText = 'Personal salvat',
    this.helperText,
    required this.onWorkerSelected,
    this.onCreateNew,
    this.enabled = true,
  });

  /// Listă deja filtrată de apelant (ex: doar muncitorii partenerului
  /// selectat pe job și doar cei activi).
  final List<PartnerWorkerRecord> workers;
  final PartnerWorkerRecord? initialWorker;
  final String labelText;
  final String? helperText;
  final void Function(PartnerWorkerRecord?) onWorkerSelected;

  /// Callback opțional pentru butonul "Nou" (adaugă rapid în catalog).
  final VoidCallback? onCreateNew;
  final bool enabled;

  Iterable<PartnerWorkerRecord> _suggest(TextEditingValue textEditingValue) {
    final q = textEditingValue.text.trim().toLowerCase();
    if (q.isEmpty) return workers.take(12);
    return workers.where((w) {
      return w.fullName.toLowerCase().contains(q) ||
          w.role.toLowerCase().contains(q);
    }).take(12);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Autocomplete<PartnerWorkerRecord>(
            initialValue: initialWorker != null
                ? TextEditingValue(text: initialWorker!.fullName)
                : null,
            displayStringForOption: (w) => w.fullName,
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
                        final w = options.elementAt(i);
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onSelected(w),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.engineering_outlined,
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
                                          w.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (w.role.trim().isNotEmpty)
                                          Text(
                                            w.role.trim(),
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
                              onWorkerSelected(null);
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                onFieldSubmitted: (_) => onFieldSubmitted(),
              );
            },
            onSelected: onWorkerSelected,
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
