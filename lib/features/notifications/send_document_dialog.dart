import 'package:flutter/material.dart';

/// Generic dialog to edit recipient, subject and message for document sending.
/// Returns a map with keys: action ('queue'|'mailto'|'cancel'), to, subject, body
class SendDocumentDialog extends StatefulWidget {
  const SendDocumentDialog({
    super.key,
    required this.to,
    required this.subject,
    required this.body,
  });

  final String to;
  final String subject;
  final String body;

  @override
  State<SendDocumentDialog> createState() => _SendDocumentDialogState();
}

class _SendDocumentDialogState extends State<SendDocumentDialog> {
  late TextEditingController _toCtrl;
  late TextEditingController _subjectCtrl;
  late TextEditingController _bodyCtrl;
  bool _working = false; // ignore: prefer_final_fields

  @override
  void initState() {
    super.initState();
    _toCtrl = TextEditingController(text: widget.to);
    _subjectCtrl = TextEditingController(text: widget.subject);
    _bodyCtrl = TextEditingController(text: widget.body);
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _closeAs(String action) {
    if (_working) return;
    Navigator.of(context).pop({
      'action': action,
      'to': _toCtrl.text.trim(),
      'subject': _subjectCtrl.text.trim(),
      'body': _bodyCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Trimite document pe email'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _toCtrl,
                decoration: const InputDecoration(
                  labelText: 'Catre (email)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: _subjectCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subiect',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: _bodyCtrl,
                maxLines: 10,
                minLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Mesaj',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _working ? null : () => _closeAs('cancel'),
          child: const Text('Anulează'),
        ),
        TextButton(
          onPressed: _working ? null : () => _closeAs('mailto'),
          child: const Text('Deschide in Outlook'),
        ),
        FilledButton(
          onPressed: _working ? null : () => _closeAs('queue'),
          child: _working
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Trimite direct'),
        ),
      ],
    );
  }
}
