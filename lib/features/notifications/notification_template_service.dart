import 'notification_models.dart';

class NotificationTemplatePayload {
  const NotificationTemplatePayload({
    required this.subject,
    required this.emailText,
    required this.emailHtml,
    required this.pushTitle,
    required this.pushBody,
  });

  final String subject;
  final String emailText;
  final String emailHtml;
  final String pushTitle;
  final String pushBody;
}

class NotificationTemplateService {
  const NotificationTemplateService();

  NotificationTemplatePayload build({
    required NotificationEventType eventType,
    required String title,
    required String message,
    required String sourceLabel,
    required String sourceModule,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    final cleanTitle = title.trim().isEmpty ? eventType.label : title.trim();
    final cleanMessage = message.trim();
    final cleanSourceLabel =
        sourceLabel.trim().isEmpty ? '-' : sourceLabel.trim();
    final sourceModuleLabel =
        sourceModule.trim().isEmpty ? '-' : sourceModule.trim();
    final createdAt = _dateLabel(metadata['event_date'] ?? metadata['created_at']);
    final details = <String>[
      if (cleanMessage.isNotEmpty) cleanMessage,
      'Sursa: $cleanSourceLabel',
      'Modul: $sourceModuleLabel',
      if (createdAt.isNotEmpty) 'Data: $createdAt',
    ].join('\n');

    final html = '''
<html>
  <body style="font-family: Arial, sans-serif; color: #18212f; line-height: 1.5;">
    <h2 style="margin-bottom: 12px;">$cleanTitle</h2>
    <p style="margin: 0 0 12px 0;">${_escape(cleanMessage.isEmpty ? eventType.label : cleanMessage)}</p>
    <table style="border-collapse: collapse; margin-top: 12px;">
      <tr><td style="padding: 4px 8px 4px 0;"><strong>Eveniment</strong></td><td style="padding: 4px 0;">${_escape(eventType.label)}</td></tr>
      <tr><td style="padding: 4px 8px 4px 0;"><strong>Sursa</strong></td><td style="padding: 4px 0;">${_escape(cleanSourceLabel)}</td></tr>
      <tr><td style="padding: 4px 8px 4px 0;"><strong>Modul</strong></td><td style="padding: 4px 0;">${_escape(sourceModuleLabel)}</td></tr>
      ${createdAt.isEmpty ? '' : '<tr><td style="padding: 4px 8px 4px 0;"><strong>Data</strong></td><td style="padding: 4px 0;">${_escape(createdAt)}</td></tr>'}
    </table>
  </body>
</html>
''';

    return NotificationTemplatePayload(
      subject: cleanTitle,
      emailText: details,
      emailHtml: html,
      pushTitle: cleanTitle,
      pushBody: cleanMessage.isEmpty ? cleanSourceLabel : cleanMessage,
    );
  }

  String _dateLabel(dynamic raw) {
    final parsed = DateTime.tryParse((raw ?? '').toString());
    if (parsed == null) return '';
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day.$month.${parsed.year} $hour:$minute';
  }

  String _escape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
