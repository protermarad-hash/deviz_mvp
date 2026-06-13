import 'package:flutter/material.dart';

import '../../core/repositories/app_data_repository.dart';
import '../../core/widgets/quick_add_client_dialog.dart';
import '../../features/clients/client_models.dart';

/// Widget reutilizabil pentru căutare/selecție client cu autocompletare.
///
/// Înlocuiește [DropdownButtonFormField<String>] pentru clienți oriunde în aplicație.
/// Utilizatorul tastează (minim 1 caracter) și primește sugestii filtrate după
/// nume, localitate, telefon sau CUI.
///
/// Exemplu de utilizare:
/// ```dart
/// ClientAutocompleteField(
///   clients: _clients,
///   initialClient: _clientRecordByIdMap[selectedClientId],
///   labelText: 'Beneficiar',
///   helperText: 'Clientul real al lucrării',
///   onClientSelected: (client) {
///     selectedClientId = client?.id ?? '';
///   },
///   onCreateNew: () async {
///     final created = await _openQuickCreateClientDialog();
///     // ...
///   },
/// )
/// ```
class ClientAutocompleteField extends StatelessWidget {
  const ClientAutocompleteField({
    super.key,
    required this.clients,
    this.initialClient,
    this.labelText = 'Client',
    this.helperText,
    required this.onClientSelected,
    this.onCreateNew,
    this.enabled = true,
    this.repository,
    this.tipEntitate = 'Client',
    this.onClientAdded,
  });

  final List<ClientRecord> clients;
  final ClientRecord? initialClient;
  final String labelText;
  final String? helperText;
  final void Function(ClientRecord?) onClientSelected;

  /// Callback opțional pentru butonul "Adaugă nou" — mecanism vechi (VoidCallback).
  /// Dacă este null și [repository] este furnizat, se generează automat butonul.
  final VoidCallback? onCreateNew;
  final bool enabled;

  /// Dacă furnizat, se afișează automat butonul "+ [tipEntitate] nou"
  /// care deschide [QuickAddClientSheet] (bottom sheet cu formular complet).
  final AppDataRepository? repository;

  /// Eticheta tipului de entitate afișată în buton și dialog (ex: 'Beneficiar', 'Partener').
  final String tipEntitate;

  /// Apelat după ce un client nou a fost creat și selectat via dialog rapid.
  /// Folosit de părinți pentru a actualiza lista locală + selecția curentă.
  final void Function(ClientRecord)? onClientAdded;

  Iterable<ClientRecord> _suggest(TextEditingValue textEditingValue) {
    final q = textEditingValue.text.trim().toLowerCase();
    if (q.isEmpty) return const Iterable<ClientRecord>.empty();
    return clients.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.city.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q) ||
          (c.cui.isNotEmpty && c.cui.toLowerCase().contains(q)) ||
          (c.county.isNotEmpty && c.county.toLowerCase().contains(q));
    }).take(12);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Autocomplete<ClientRecord>(
            initialValue: initialClient != null
                ? TextEditingValue(text: initialClient!.name)
                : null,
            displayStringForOption: (c) => c.name,
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
                        final c = options.elementAt(i);
                        final parts = <String>[
                          if (c.city.trim().isNotEmpty) c.city.trim(),
                          if (c.county.trim().isNotEmpty) c.county.trim(),
                          if (c.cui.trim().isNotEmpty) 'CUI: ${c.cui.trim()}',
                          if (c.phone.trim().isNotEmpty) c.phone.trim(),
                        ];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onSelected(c),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    c.type == ClientType.persoanaJuridica
                                        ? Icons.business_outlined
                                        : Icons.person_outlined,
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
                                          c.name,
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
                                              color: colorScheme.onSurfaceVariant,
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
                              onClientSelected(null);
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                onFieldSubmitted: (_) => onFieldSubmitted(),
              );
            },
            onSelected: onClientSelected,
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
        ] else if (repository != null && enabled) ...[
          const SizedBox(width: 8),
          Builder(
            builder: (ctx) => OutlinedButton.icon(
              onPressed: () async {
                final created = await showQuickAddClientDialog(
                  ctx,
                  repository: repository!,
                  tipEntitate: tipEntitate,
                );
                if (created != null) {
                  onClientSelected(created);
                  onClientAdded?.call(created);
                }
              },
              icon: const Icon(Icons.add_outlined, size: 14),
              label: Text('+ $tipEntitate'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                foregroundColor: const Color(0xFFC62828),
                side: const BorderSide(color: Color(0xFFC62828)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
