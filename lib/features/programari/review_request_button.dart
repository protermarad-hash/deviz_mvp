import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'review_request_service.dart';

/// Buton reutilizabil pentru cerere recenzie Google prin WhatsApp.
///
/// Afișează starea corectă în funcție de dacă cererea a fost deja trimisă.
/// Se integrează în pagina de detalii a oricărei programări / lucrări.
///
/// ─── INTEGRARE ÎN programari_page.dart ────────────────────────────────────
/// 1. Importă: import 'review_request_button.dart';
///             import 'review_request_service.dart';
///
/// 2. Adaugă câmpurile la modelul de programare (appointment.toMap / fromMap):
///    reviewRequestFields: ReviewRequestFields.fromMap(map)
///
/// 3. Plasează widget-ul în secțiunea de detalii a programării:
///
///    ReviewRequestButton(
///      appointmentId: appointment.id,
///      clientPhone: client?.phone,
///      clientName: client?.name,
///      currentUserId: _currentUserId, // din FieldAuthService sau FirebaseAuth
///      reviewFields: ReviewRequestFields.fromMap(appointment.toMap()),
///      onFieldsUpdated: (updated) async {
///        // Salvează câmpurile prin repository-ul tău existent:
///        final newMap = {...appointment.toMap(), ...updated.toMap()};
///        await _repo.saveAppointment(AppointmentModel.fromMap(newMap));
///      },
///    )
/// ──────────────────────────────────────────────────────────────────────────
class ReviewRequestButton extends StatefulWidget {
  final String appointmentId;
  final String? clientPhone;
  final String? clientName;
  final String? currentUserId;
  final ReviewRequestFields reviewFields;

  /// Apelat după trimitere cu câmpurile actualizate, pentru a le persista
  /// prin repository-ul principal al aplicației (cu queue offline).
  final Future<void> Function(ReviewRequestFields updated) onFieldsUpdated;

  const ReviewRequestButton({
    super.key,
    required this.appointmentId,
    required this.clientPhone,
    required this.clientName,
    required this.currentUserId,
    required this.reviewFields,
    required this.onFieldsUpdated,
  });

  @override
  State<ReviewRequestButton> createState() => _ReviewRequestButtonState();
}

class _ReviewRequestButtonState extends State<ReviewRequestButton> {
  bool _loading = false;

  bool get _hasPhone =>
      widget.clientPhone != null && widget.clientPhone!.trim().isNotEmpty;

  Future<void> _handleSend({bool isResend = false}) async {
    if (!_hasPhone) {
      _showNoPhoneDialog();
      return;
    }

    if (widget.reviewFields.hasSent && !isResend) {
      final confirmed = await _showResendConfirmDialog();
      if (!confirmed || !mounted) return;
    }

    setState(() => _loading = true);

    final message =
        ReviewRequestService.buildMessage(clientName: widget.clientName);
    bool openedWhatsApp = false;
    String? errorText;

    try {
      openedWhatsApp = await ReviewRequestService.launchWhatsApp(
        rawPhone: widget.clientPhone!,
        message: message,
      );
    } catch (e) {
      errorText = e.toString();
    }

    final updated = ReviewRequestFields(
      sentAt: DateTime.now(),
      sentBy: widget.currentUserId,
      count: widget.reviewFields.count + 1,
      method: openedWhatsApp ? 'whatsapp' : 'browser',
      lastMessage: message,
      lastError: errorText,
    );

    // Persistă în Firestore (best-effort, fire-and-forget)
    ReviewRequestService.persistToFirestore(
      appointmentId: widget.appointmentId,
      fields: updated,
    );

    // Persistă prin repository-ul principal (cu queue offline)
    try {
      await widget.onFieldsUpdated(updated);
    } catch (e) {
      debugPrint('[ReviewRequestButton] ❌ onFieldsUpdated error: $e');
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (errorText != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nu s-a putut deschide WhatsApp: $errorText'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          openedWhatsApp
              ? 'WhatsApp s-a deschis. Apasă Send pentru a trimite mesajul.'
              : 'S-a deschis în browser. Apasă Send în WhatsApp Web.',
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showNoPhoneDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.phone_disabled_outlined, color: Colors.orange),
        title: const Text('Număr de telefon lipsă'),
        content: const Text(
          'Clientul nu are număr de telefon salvat.\n\n'
          'Adaugă numărul de telefon în fișa clientului și încearcă din nou.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showResendConfirmDialog() async {
    final fields = widget.reviewFields;
    final dateStr = fields.sentAt != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(fields.sentAt!)
        : '—';
    final times = fields.count == 1 ? 'o dată' : 'de ${fields.count} ori';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_outlined,
            color: Colors.amber.shade700, size: 32),
        title: const Text('Cerere deja trimisă'),
        content: Text(
          'Cererea de recenzie a fost deja trimisă la $dateStr ($times).\n\n'
          'Trimiți din nou?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Nu'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Da, retrimite'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.reviewFields;

    if (fields.hasSent) {
      return _SentState(
        sentAt: fields.sentAt!,
        count: fields.count,
        loading: _loading,
        onResend: () => _handleSend(isResend: true),
      );
    }

    return OutlinedButton.icon(
      onPressed: _loading ? null : () => _handleSend(),
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.star_rate_outlined, size: 18),
      label: const Text('Cere recenzie Google'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.green.shade700,
        side: BorderSide(color: Colors.green.shade400),
      ),
    );
  }
}

class _SentState extends StatelessWidget {
  final DateTime sentAt;
  final int count;
  final bool loading;
  final VoidCallback onResend;

  const _SentState({
    required this.sentAt,
    required this.count,
    required this.loading,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd.MM.yyyy').format(sentAt);
    final times = count == 1 ? '' : ' (trimis de $count ori)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 15, color: Colors.green.shade600),
            const SizedBox(width: 5),
            Text(
              'Cerere recenzie trimisă la $dateStr$times',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.green.shade700,
                  ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: loading ? null : onResend,
          icon: loading
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              : const Icon(Icons.refresh, size: 14),
          label: const Text('Retrimite'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
            textStyle: const TextStyle(fontSize: 12),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
