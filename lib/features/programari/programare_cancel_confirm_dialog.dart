import 'package:flutter/material.dart';

/// Dialog de confirmare pentru anularea rapidă a unei programări.
///
/// Returnează `true` prin `Navigator.pop` dacă utilizatorul confirmă anularea,
/// `false` (sau `null` la dismiss) în caz contrar. Extras din `_quickCancel`
/// pentru a putea fi testat izolat, în același stil ca
/// [ProgramariPostponeReasonDialog].
class ProgramariCancelConfirmDialog extends StatelessWidget {
  const ProgramariCancelConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Anulează programarea'),
      content: const Text('Sigur anulezi această programare?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Nu'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Anulează programarea'),
        ),
      ],
    );
  }
}
