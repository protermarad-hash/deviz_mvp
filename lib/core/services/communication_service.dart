import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Serviciu central pentru comunicare cu clienți/parteneri.
/// Deschide aplicații externe (WhatsApp, telefon, email) — nu blochează UI.
class CommunicationService {
  CommunicationService._();
  static final CommunicationService instance = CommunicationService._();

  // ── WhatsApp ────────────────────────────────────────────────────────────────

  Future<bool> sendWhatsApp({
    required String phone,
    required String message,
  }) async {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return false;
    final encoded = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$normalized?text=$encoded');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      }
      debugPrint('[CommunicationService] canLaunchUrl=false pentru: $url');
    } catch (e) {
      debugPrint('[CommunicationService] sendWhatsApp eroare: $e');
    }
    return false;
  }

  // ── Telefon ─────────────────────────────────────────────────────────────────

  Future<bool> callPhone(String phone) async {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return false;
    final url = Uri(scheme: 'tel', path: normalized);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      }
      debugPrint('[CommunicationService] canLaunchUrl=false pentru: $url');
    } catch (e) {
      debugPrint('[CommunicationService] callPhone eroare: $e');
    }
    return false;
  }

  // ── Email ───────────────────────────────────────────────────────────────────

  Future<bool> sendEmail({
    required String email,
    required String subject,
    String body = '',
  }) async {
    final url = Uri(
      scheme: 'mailto',
      path: email.trim(),
      queryParameters: <String, String>{
        'subject': subject,
        if (body.isNotEmpty) 'body': body,
      },
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      }
      debugPrint('[CommunicationService] canLaunchUrl=false pentru: $url');
    } catch (e) {
      debugPrint('[CommunicationService] sendEmail eroare: $e');
    }
    return false;
  }

  // ── Normalizare număr telefon ────────────────────────────────────────────────

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('+')) return digits.replaceFirst('+', '');
    if (digits.startsWith('07') || digits.startsWith('02') || digits.startsWith('03')) {
      return '4$digits';
    }
    if (digits.startsWith('4')) return digits;
    return '4$digits';
  }

  // ── Mesaje pre-definite ──────────────────────────────────────────────────────

  String mesajConfirmareProgramare({
    required String numeClient,
    required String dataOra,
    required String titluLucrare,
    required String numeTechnician,
    String telefonFirma = '0749 025 610',
    String? adresaLocatie,
  }) {
    final locRow =
        adresaLocatie != null && adresaLocatie.trim().isNotEmpty
            ? '\nLocatie: ${adresaLocatie.trim()}'
            : '';
    return 'Buna ziua, ${numeClient.trim().isEmpty ? 'domn/doamna' : numeClient.trim()}!\n\n'
        'Va confirmam programarea:\n'
        'Data si ora: $dataOra\n'
        'Lucrare: $titluLucrare$locRow\n'
        'Tehnician: $numeTechnician\n\n'
        'Pentru modificari sau intrebari sunati la: $telefonFirma.\n\n'
        'Cu respect,\nSC PRO TERM SRL';
  }

  String mesajReminderZiUrmatoare({
    required String numeClient,
    required String ora,
    required String titluLucrare,
    required String numeTechnician,
    String telefonFirma = '0749 025 610',
  }) {
    return 'Buna ziua, ${numeClient.trim().isEmpty ? 'domn/doamna' : numeClient.trim()}!\n\n'
        'Va reamintim ca maine avem programat:\n'
        'Ora: $ora\n'
        '$titluLucrare\n'
        'Tehnicianul $numeTechnician va sosi la ora indicata.\n\n'
        'SC PRO TERM SRL — $telefonFirma';
  }

  String mesajFinalizareLucrare({
    required String numeClient,
    required String titluLucrare,
    String telefonFirma = '0749 025 610',
  }) {
    return 'Buna ziua, ${numeClient.trim().isEmpty ? 'domn/doamna' : numeClient.trim()}!\n\n'
        'Lucrarea "$titluLucrare" a fost finalizata.\n'
        'Va multumim ca ati ales SC PRO TERM SRL!\n\n'
        'Pentru orice intrebari sunati la $telefonFirma.';
  }

  String mesajAlertaGarantie({
    required String numeClient,
    required String marcaModel,
    required String dataExpirare,
    String telefonFirma = '0749 025 610',
  }) {
    return 'Buna ziua, ${numeClient.trim().isEmpty ? 'domn/doamna' : numeClient.trim()}!\n\n'
        'Va informam ca garantia echipamentului $marcaModel '
        'expira pe $dataExpirare.\n'
        'Va recomandam un service de verificare pentru a pastra '
        'echipamentul in parametri optimi.\n\n'
        'Contactati-ne la $telefonFirma pentru programare.\n\n'
        'SC PRO TERM SRL';
  }

  String mesajOfertaAcceptata({
    required String numeClient,
    required String numarOferta,
    required double valoare,
    String telefonFirma = '0749 025 610',
  }) {
    return 'Buna ziua, ${numeClient.trim().isEmpty ? 'domn/doamna' : numeClient.trim()}!\n\n'
        'Oferta $numarOferta in valoare de '
        '${valoare.toStringAsFixed(2)} RON a fost inregistrata ca acceptata.\n'
        'Va vom contacta curand pentru programarea lucrarii.\n\n'
        'SC PRO TERM SRL — $telefonFirma';
  }
}
