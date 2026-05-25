String _safe(String? v) => v?.trim() ?? '';

String miniOfferHtml({
  required String recipientName,
  required String companyName,
  required String agentName,
  required String message,
}) {
  final safeRecipient =
      _safe(recipientName).isEmpty ? 'Salut' : 'Salut ${_safe(recipientName)},';
  return '''
<html>
  <body style="font-family:Arial,Helvetica,sans-serif;color:#222;line-height:1.4;">
    <div style="max-width:680px;margin:0 auto;">
      <div style="padding:8px 0">
        <img src="cid:companylogo" alt="$companyName" style="height:48px;object-fit:contain"> 
      </div>
      <p>$safeRecipient</p>
      <p>${_safe(message)}</p>
      <p>Agent: ${_safe(agentName)}</p>
      <p>Gasiti documentul PDF atasat la acest email.</p>
      <p>Cu stima,<br>$companyName<br><a href="https://pro-term.ro">pro-term.ro</a></p>
    </div>
  </body>
</html>
''';
}

String warrantyCertificateHtml({
  required String recipientName,
  required String companyName,
  required String certificateNumber,
  required String message,
}) {
  final safeRecipient = _safe(recipientName).isEmpty
      ? 'Buna ziua'
      : 'Buna ziua ${_safe(recipientName)}';
  return '''
<html>
  <body style="font-family:Arial,Helvetica,sans-serif;color:#222;line-height:1.4;">
    <div style="max-width:680px;margin:0 auto;">
      <div style="padding:8px 0">
        <img src="cid:companylogo" alt="$companyName" style="height:48px;object-fit:contain"> 
      </div>
      <p>$safeRecipient,</p>
      <p>${_safe(message)}</p>
      <p>Numar certificat: <strong>${_safe(certificateNumber)}</strong></p>
      <p>Va stam la dispozitie pentru clarificari.</p>
      <p>Cu stima,<br>$companyName<br><a href="https://pro-term.ro">pro-term.ro</a></p>
    </div>
  </body>
</html>
''';
}

String warrantyInterventionHtml({
  required String recipientName,
  required String companyName,
  required String reportNumber,
  required String message,
}) {
  final safeRecipient = _safe(recipientName).isEmpty
      ? 'Buna ziua'
      : 'Buna ziua ${_safe(recipientName)}';
  return '''
<html>
  <body style="font-family:Arial,Helvetica,sans-serif;color:#222;line-height:1.4;">
    <div style="max-width:680px;margin:0 auto;">
      <div style="padding:8px 0">
        <img src="cid:companylogo" alt="$companyName" style="height:48px;object-fit:contain"> 
      </div>
      <p>$safeRecipient,</p>
      <p>${_safe(message)}</p>
      <p>Proces-verbal: <strong>${_safe(reportNumber)}</strong></p>
      <p>Va rugam confirmati primirea sau comunicati orice nelamuriri.</p>
      <p>Cu stima,<br>$companyName<br><a href="https://pro-term.ro">pro-term.ro</a></p>
    </div>
  </body>
</html>
''';
}

String agfrReportHtml({
  required String recipientName,
  required String companyName,
  required String reportNumber,
  required String message,
}) {
  final safeRecipient = _safe(recipientName).isEmpty
      ? 'Buna ziua'
      : 'Buna ziua ${_safe(recipientName)}';
  return '''
<html>
  <body style="font-family:Arial,Helvetica,sans-serif;color:#222;line-height:1.4;">
    <div style="max-width:680px;margin:0 auto;">
      <div style="padding:8px 0">
        <img src="cid:companylogo" alt="$companyName" style="height:48px;object-fit:contain"> 
      </div>
      <p>$safeRecipient,</p>
      <p>${_safe(message)}</p>
      <p>Proces-verbal AGFR: <strong>${_safe(reportNumber)}</strong></p>
      <p>Multumim,</p>
      <p>Cu stima,<br>$companyName<br><a href="https://pro-term.ro">pro-term.ro</a></p>
    </div>
  </body>
</html>
''';
}
