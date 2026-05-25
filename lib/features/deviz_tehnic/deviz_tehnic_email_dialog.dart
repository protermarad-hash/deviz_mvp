import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/company_profile.dart';
import '../../core/document_file_service.dart';
import 'deviz_tehnic_models.dart';

/// Dialog pentru trimiterea unui deviz tehnic pe email.
/// Preia automat subiectul și corpul dintr-un template, editabile de utilizator.
class DevizTehnicEmailDialog extends StatefulWidget {
  const DevizTehnicEmailDialog({
    super.key,
    required this.deviz,
    required this.company,
    required this.currentUserName,
    this.recipientEmail = '',
    this.pdfPath = '',
  });

  final DevizTehnicRecord deviz;
  final CompanyProfile company;
  final String currentUserName;
  final String recipientEmail;
  final String pdfPath;

  @override
  State<DevizTehnicEmailDialog> createState() =>
      _DevizTehnicEmailDialogState();
}

class _DevizTehnicEmailDialogState extends State<DevizTehnicEmailDialog> {
  late TextEditingController _toCtrl;
  late TextEditingController _subjectCtrl;
  late TextEditingController _bodyCtrl;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _toCtrl = TextEditingController(text: widget.recipientEmail);
    _subjectCtrl = TextEditingController(text: _buildSubject());
    _bodyCtrl = TextEditingController(text: _buildBody());
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  String _buildSubject() {
    final nr = widget.deviz.numar.isNotEmpty
        ? widget.deviz.numar
        : widget.deviz.titlu;
    return '${widget.deviz.tipDocument.label} - $nr';
  }

  String _buildBody() {
    final clientName = widget.deviz.clientName;
    final nr = widget.deviz.numar.isNotEmpty
        ? widget.deviz.numar
        : widget.deviz.titlu;
    final companyName = widget.company.companyName;
    final senderName = widget.currentUserName.isNotEmpty
        ? widget.currentUserName
        : widget.company.contactName;
    final phone = widget.company.phone;
    final email = widget.company.email;
    final tipLabel = widget.deviz.tipDocument.label.toLowerCase();
    final salut = clientName.trim().isEmpty ? '' : ', $clientName';

    return '''Bună ziua$salut,

Vă transmitem atașat $tipLabel nostru $nr${widget.deviz.titlu.isNotEmpty && widget.deviz.titlu != nr ? ' — ${widget.deviz.titlu}' : ''}.

Documentul conține detaliile lucrărilor propuse, precum și condițiile tehnice și comerciale aplicabile la data emiterii. Vă rugăm să îl analizați, iar pentru orice clarificări sau modificări necesare ne puteți contacta.

${widget.deviz.zileValabilitate > 0 ? 'Documentul este valabil ${widget.deviz.zileValabilitate} de zile de la data emiterii.\n\n' : ''}Cu stimă,

$senderName
$companyName
Telefon: $phone
Email: $email''';
  }

  Future<void> _trimitePeEmail() async {
    final to = _toCtrl.text.trim();
    final subject = _subjectCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completează adresa de email a destinatarului.'),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final encodedTo = Uri.encodeComponent(to);
      final encodedSubject = Uri.encodeComponent(subject);
      final encodedBody = Uri.encodeComponent(body);
      final uri = Uri.parse(
        'mailto:$encodedTo?subject=$encodedSubject&body=$encodedBody',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!mounted) return;
        final pdfName =
            widget.pdfPath.split(RegExp(r'[\\/]')).last;
        if (widget.pdfPath.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Clientul de email a fost deschis. Atașează manual PDF-ul: $pdfName',
              ),
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'Copiază calea',
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: widget.pdfPath)),
              ),
            ),
          );
        }
        if (mounted) Navigator.of(context).pop(true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Nu am putut deschide clientul de email. Folosiți Share pentru a trimite PDF-ul.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sharePdf() async {
    if (widget.pdfPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generează mai întâi PDF-ul documentului.'),
        ),
      );
      return;
    }
    try {
      await DocumentFileService.shareFile(
        widget.pdfPath,
        subject: _subjectCtrl.text.trim(),
        text: 'PDF ${widget.deviz.tipDocument.label.toLowerCase()} atașat.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare share: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pdfName = widget.pdfPath.isNotEmpty
        ? widget.pdfPath.split(RegExp(r'[\\/]')).last
        : null;

    return AlertDialog(
      title: Text('Trimite ${widget.deviz.tipDocument.label.toLowerCase()} pe email'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _toCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Către (email)',
                  hintText: 'email@exemplu.com',
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
                minLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Mesaj',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              if (pdfName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined,
                        size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'PDF: $pdfName',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (widget.pdfPath.isNotEmpty &&
                  DocumentFileService.isMobilePlatform) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Text(
                    'Pe mobil, folosiți butonul Share pentru a trimite PDF-ul direct pe WhatsApp, Gmail sau altă aplicație.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Anulează'),
        ),
        if (widget.pdfPath.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _sending ? null : _sharePdf,
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share PDF'),
          ),
        FilledButton.icon(
          onPressed: _sending ? null : _trimitePeEmail,
          icon: _sending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.email_outlined, size: 18),
          label: Text(_sending ? 'Se deschide...' : 'Deschide email'),
        ),
      ],
    );
  }
}
