import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dialoguri auto-conținute legate de documentele atașate programărilor.
// Extrase din programari_page.dart (Faza 1.3 refactor) — primesc date doar prin
// parametri și returnează rezultatul prin return value. NU referențiază starea
// paginii Programări.
// ─────────────────────────────────────────────────────────────────────────────

/// Cere utilizatorului o etichetă pentru un document atașat. Returnează textul
/// introdus (poate fi gol) sau `null` dacă se renunță.
Future<String?> promptLinkedDocumentLabel(
  BuildContext context, {
  required String title,
  required String initialValue,
  String? helperText,
}) async {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        textCapitalization: TextCapitalization.sentences,
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Eticheta document',
          helperText: helperText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Renunta'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            Navigator.of(dialogContext).pop(value);
          },
          child: const Text('Salveaza'),
        ),
      ],
    ),
  );
}
