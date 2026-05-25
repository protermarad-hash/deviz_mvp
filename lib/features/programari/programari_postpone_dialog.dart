import 'package:flutter/material.dart';

/// Dialog pentru introducerea motivului amânării unei programări.
class ProgramariPostponeReasonDialog extends StatefulWidget {
  const ProgramariPostponeReasonDialog({super.key});

  @override
  State<ProgramariPostponeReasonDialog> createState() =>
      _ProgramariPostponeReasonDialogState();
}

class _ProgramariPostponeReasonDialogState
    extends State<ProgramariPostponeReasonDialog> {
  late final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Amana programarea'),
      content: TextField(
        textCapitalization: TextCapitalization.sentences,
        controller: _reasonController,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Motiv amanare (optional)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop(_reasonController.text.trim());
          },
          child: const Text('Amana'),
        ),
      ],
    );
  }
}
