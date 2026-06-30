import 'package:flutter/material.dart';

import '../../features/programari/servicii/serviciu_prestat_models.dart';

/// Câmp text cu autocompletare din catalogul de servicii prestate.
///
/// Comportament:
///  - Text liber: utilizatorul poate scrie ORICE titlu (nu doar din catalog).
///    Textul scris ajunge direct în [controller] (de obicei `titleController`).
///  - Sugestii: pe măsură ce tastează, primește servicii filtrate după denumire
///    (case-insensitive, doar cele active).
///  - La selectarea unei sugestii → [onServiceSelected] cu serviciul (și prețul).
///    Dacă scrie liber fără să aleagă → titlu normal, fără preț precompletat.
///
/// Bazat pe pattern-ul [ClientAutocompleteField] (`Autocomplete<T>`), dar cu
/// [controller] extern ca textul liber să fie persistat de părinte.
class ServiciuAutocompleteField extends StatefulWidget {
  const ServiciuAutocompleteField({
    super.key,
    required this.controller,
    required this.servicii,
    required this.onServiceSelected,
    this.labelText = 'Titlu programare',
    this.helperText,
    this.enabled = true,
  });

  /// Controller-ul textului (de regulă `titleController` din editor).
  final TextEditingController controller;

  /// Lista serviciilor din catalog (se filtrează intern doar cele active).
  final List<ServiciuPrestat> servicii;

  /// Apelat când utilizatorul alege un serviciu din listă.
  final void Function(ServiciuPrestat) onServiceSelected;

  final String labelText;
  final String? helperText;
  final bool enabled;

  @override
  State<ServiciuAutocompleteField> createState() =>
      _ServiciuAutocompleteFieldState();
}

class _ServiciuAutocompleteFieldState extends State<ServiciuAutocompleteField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Iterable<ServiciuPrestat> _suggest(TextEditingValue value) {
    final q = value.text.trim().toLowerCase();
    if (q.isEmpty) return const Iterable<ServiciuPrestat>.empty();
    return widget.servicii
        .where((s) => s.activ && s.denumire.toLowerCase().contains(q))
        .take(12);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Autocomplete<ServiciuPrestat>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      displayStringForOption: (s) => s.denumire,
      optionsBuilder: _suggest,
      onSelected: widget.onServiceSelected,
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300, maxWidth: 420),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final s = options.elementAt(i);
                  final pret = s.pretSugerat > 0
                      ? '${s.pretSugerat.toStringAsFixed(2)} ${s.moneda}'
                      : 'Fără preț';
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onSelected(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.design_services_outlined,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.denumire,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              pret,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
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
          enabled: widget.enabled,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: widget.labelText,
            helperText: widget.helperText,
            suffixIcon: ListenableBuilder(
              listenable: textCtrl,
              builder: (_, __) => textCtrl.text.isNotEmpty && widget.enabled
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Golește titlul',
                      onPressed: textCtrl.clear,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
    );
  }
}
