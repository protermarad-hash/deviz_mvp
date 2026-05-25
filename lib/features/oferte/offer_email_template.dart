import 'package:flutter/material.dart';

import '../../core/company_profile.dart';
import 'offer_models.dart';

class OfferEmailTemplate {
  const OfferEmailTemplate._();

  /// Professional email subject template
  static String subject({required String offerNumber}) {
    return 'Ofertă comercială - $offerNumber';
  }

  /// Professional email body with company signature and template variables
  static String body({
    required String clientName,
    required String offerNumber,
    required String companyName,
    required String senderName,
    required String senderRole,
    required String companyPhone,
    required String companyEmail,
    required String companyAddress,
    required String companyWebsite,
  }) {
    final separator = clientName.trim().isEmpty ? '' : ', ';
    final addressLine =
        companyAddress.trim().isEmpty ? '' : 'Adresa: $companyAddress\n';
    final webLine =
        companyWebsite.trim().isEmpty ? '' : 'Web: $companyWebsite\n';

    return '''Bună ziua$separator$clientName,

  Vă transmitem atașat oferta noastră comercială $offerNumber, aferentă solicitării dumneavoastră.

  Oferta conține detaliile privind produsele / serviciile propuse, precum și condițiile comerciale aplicabile la data emiterii. Vă rugăm să o analizați, iar pentru orice clarificări sau ajustări necesare ne puteți contacta direct prin reply la acest email sau telefonic.

  În cazul în care sunteți de acord cu propunerea transmisă, vă rugăm să ne confirmați pentru a putea continua cu pașii următori.

  Cu stimă,

$senderName
$senderRole
$companyName
Telefon: $companyPhone
Email: $companyEmail
$addressLine$webLine''';
  }

  /// HTML version of email body with formatting and styling
  static String htmlBody({
    required String clientName,
    required String offerNumber,
    required String companyName,
    required String senderName,
    required String senderRole,
    required String companyPhone,
    required String companyEmail,
    required String companyAddress,
    required String companyWebsite,
    String companyLogoBase64 = '',
  }) {
    final separator = clientName.trim().isEmpty ? '' : ', ';
    final addressLine = companyAddress.trim().isEmpty
        ? ''
        : '<p style="margin: 2px 0;">Adresa: $companyAddress</p>';
    final webLine = companyWebsite.trim().isEmpty
        ? '<p style="margin: 2px 0;"><a href="https://pro-term.ro">pro-term.ro</a></p>'
        : '<p style="margin: 2px 0;"><a href="$companyWebsite">$companyWebsite</a></p>';

    final logoImg = companyLogoBase64.trim().isEmpty
        ? ''
        : '<div style="margin-bottom:8px"><img src="data:image/png;base64,$companyLogoBase64" alt="$companyName" style="max-height:64px; max-width:220px;"/></div>';

    return '''<html>
<body style="font-family: Arial, sans-serif; font-size: 13px; line-height: 1.5; color: #222;">
  $logoImg
  <p>Bună ziua$separator<strong>$clientName</strong>,</p>

  <p>Vă transmitem atașat <strong>oferta noastră comercială $offerNumber</strong>, aferentă solicitării dumneavoastră.</p>

  <p>Oferta conține detaliile privind produsele / serviciile propuse, precum și condițiile comerciale aplicabile la data emiterii. Vă rugăm să o analizați, iar pentru orice clarificări sau ajustări necesare ne puteți contacta direct prin reply la acest email sau telefonic.</p>

  <p>Dacă sunteți de acord cu propunerea transmisă, vă rugăm să ne confirmați pentru a putea continua cu pașii următori.</p>

  <div style="margin-top: 18px; padding-top: 12px; border-top: 1px solid #e6e6e6;">
    <p style="margin: 2px 0;"><strong>$senderName</strong></p>
    <p style="margin: 2px 0; color: #555;">$senderRole</p>
    <p style="margin: 6px 0; font-weight: 600;">$companyName</p>
    <p style="margin: 2px 0; color: #444;">Telefon: $companyPhone</p>
    <p style="margin: 2px 0; color: #444;">Email: $companyEmail</p>
    $addressLine
    $webLine
  </div>

  <p style="margin-top:10px; font-size:11px; color:#888;">Acest mesaj poate afișa sigla inline; dacă sigla nu este afișată, vă rugăm să acceptați imaginile din acest email sau folosiți opțiunea din aplicație pentru a copia HTML-ul și a-l insera manual în clientul dvs. de email.</p>
</body>
</html>''';
  }

  /// Precompile email parameters from offer and company data
  static Map<String, String> precompileParameters({
    required OfferRecord offer,
    required CompanyProfile company,
    required String currentUserEmail,
    String currentUserName = '',
    String currentUserRole = '',
    String recipientEmail = '',
  }) {
    final senderName = currentUserName.trim().isNotEmpty
        ? currentUserName.trim()
        : (company.contactName.trim().isNotEmpty
            ? company.contactName.trim()
            : currentUserEmail.trim());
    final senderRole = currentUserRole.trim().isNotEmpty
        ? currentUserRole.trim()
        : 'Departament comercial';
    return {
      'client_name': offer.contactPersonName.trim().isEmpty
          ? offer.clientName.trim()
          : offer.contactPersonName.trim(),
      'offer_number': offer.offerNumber.trim(),
      'company_name': company.companyName.trim(),
      'sender_name': senderName,
      'sender_role': senderRole,
      'company_phone': company.phone.trim(),
      'company_email': company.email.trim(),
      'company_address': company.address.trim(),
      'company_website': 'https://pro-term.ro', // fallback website
      'company_logo_base64': company.logoBase64.trim(),
      'recipient_email': recipientEmail.trim().isNotEmpty
          ? recipientEmail.trim()
          : offer.contactPersonEmail.trim(),
    };
  }

  /// Build complete email with subject and body
  static ({String subject, String body, String htmlBody}) buildComplete({
    required OfferRecord offer,
    required CompanyProfile company,
    required String currentUserEmail,
    String currentUserName = '',
    String currentUserRole = '',
    String recipientEmail = '',
  }) {
    final params = precompileParameters(
      offer: offer,
      company: company,
      currentUserEmail: currentUserEmail,
      currentUserName: currentUserName,
      currentUserRole: currentUserRole,
      recipientEmail: recipientEmail,
    );

    return (
      subject: OfferEmailTemplate.subject(
        offerNumber: params['offer_number']!,
      ),
      body: OfferEmailTemplate.body(
        clientName: params['client_name']!,
        offerNumber: params['offer_number']!,
        companyName: params['company_name']!,
        senderName: params['sender_name']!,
        senderRole: params['sender_role']!,
        companyPhone: params['company_phone']!,
        companyEmail: params['company_email']!,
        companyAddress: params['company_address']!,
        companyWebsite: params['company_website']!,
      ),
      htmlBody: OfferEmailTemplate.htmlBody(
        clientName: params['client_name']!,
        offerNumber: params['offer_number']!,
        companyName: params['company_name']!,
        senderName: params['sender_name']!,
        senderRole: params['sender_role']!,
        companyPhone: params['company_phone']!,
        companyEmail: params['company_email']!,
        companyAddress: params['company_address']!,
        companyWebsite: params['company_website']!,
        companyLogoBase64: params['company_logo_base64'] ?? '',
      ),
    );
  }
}

/// Dialog for sending offer emails with precompiled but editable fields
class OfferEmailSendDialog extends StatefulWidget {
  const OfferEmailSendDialog({
    super.key,
    required this.offer,
    required this.company,
    required this.currentUserEmail,
    required this.initialRecipientEmail,
    this.currentUserName = '',
    this.currentUserRole = '',
    this.attachmentPath = '',
    this.attachmentLabel = '',
    this.onSendEmail,
    this.onQueueEmail,
  });

  final OfferRecord offer;
  final CompanyProfile company;
  final String currentUserEmail;
  final String initialRecipientEmail;
  final String currentUserName;
  final String currentUserRole;
  final String attachmentPath;
  final String attachmentLabel;
  final Future<bool> Function(
    String recipientEmail,
    String subject,
    String bodyText,
    String bodyHtml,
    String attachmentPath,
  )? onSendEmail;
  final Future<bool> Function(
    String recipientEmail,
    String subject,
    String bodyText,
    String bodyHtml,
  )? onQueueEmail;

  @override
  State<OfferEmailSendDialog> createState() => _OfferEmailSendDialogState();
}

class _OfferEmailSendDialogState extends State<OfferEmailSendDialog> {
  late TextEditingController _toController;
  late TextEditingController _subjectController;
  late TextEditingController _bodyController;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final emailData = OfferEmailTemplate.buildComplete(
      offer: widget.offer,
      company: widget.company,
      currentUserEmail: widget.currentUserEmail,
      currentUserName: widget.currentUserName,
      currentUserRole: widget.currentUserRole,
      recipientEmail: widget.initialRecipientEmail,
    );
    final params = OfferEmailTemplate.precompileParameters(
      offer: widget.offer,
      company: widget.company,
      currentUserEmail: widget.currentUserEmail,
      currentUserName: widget.currentUserName,
      currentUserRole: widget.currentUserRole,
      recipientEmail: widget.initialRecipientEmail,
    );

    _toController = TextEditingController(text: params['recipient_email']!);
    _subjectController = TextEditingController(text: emailData.subject);
    _bodyController = TextEditingController(text: emailData.body);
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    final onSend = widget.onSendEmail;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (onSend == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Deschiderea clientului de email nu este configurată.'),
        ),
      );
      return;
    }

    final to = _toController.text.trim();
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();

    if (to.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Completează adresa de email a destinatarului.')),
      );
      return;
    }

    if (subject.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Completează subiectul emailului.')),
      );
      return;
    }

    if (body.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Completează mesajul emailului.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final emailData = OfferEmailTemplate.buildComplete(
        offer: widget.offer,
        company: widget.company,
        currentUserEmail: widget.currentUserEmail,
        currentUserName: widget.currentUserName,
        currentUserRole: widget.currentUserRole,
        recipientEmail: to,
      );

      final success = await onSend(
        to,
        subject,
        body,
        emailData.htmlBody,
        widget.attachmentPath,
      );

      if (!mounted) return;

      if (success) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Emailul a fost trimis cu succes.')),
        );
        navigator.pop(true);
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Nu am putut trimite emailul.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Eroare la trimiterea emailului: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Trimite oferta pe email'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _toController,
                decoration: const InputDecoration(
                  labelText: 'Catre (email)',
                  hintText: 'email@example.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subiect',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: _bodyController,
                maxLines: 10,
                minLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Mesaj',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Trimite direct folosește coada de email și atașează PDF-ul. Pe Windows, Outlook / client mail încearcă deschiderea unui draft cu PDF-ul atașat; dacă trimiterea directă nu este disponibilă, aplicația cade automat în acest fallback.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              if (widget.attachmentLabel.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'PDF: ${widget.attachmentLabel.trim()}',
                    style: const TextStyle(fontSize: 12),
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
        TextButton(
          onPressed: _sending
              ? null
              : () async {
                  final onQueue = widget.onQueueEmail;
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  if (onQueue == null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content:
                            Text('Trimiterea server-side nu este configurată.'),
                      ),
                    );
                    return;
                  }

                  final to = _toController.text.trim();
                  final subject = _subjectController.text.trim();
                  final body = _bodyController.text.trim();
                  setState(() => _sending = true);
                  try {
                    final ok = await onQueue(to, subject, body, '');
                    if (!mounted) return;
                    if (ok) {
                      navigator.pop(true);
                    }
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text('Eroare: $e')),
                    );
                  } finally {
                    if (mounted) setState(() => _sending = false);
                  }
                },
          child: const Text('Trimite direct'),
        ),
        FilledButton(
          onPressed: _sending ? null : _sendEmail,
          child: _sending
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Outlook / client mail'),
        ),
      ],
    );
  }
}
