import 'package:flutter/material.dart';
import 'review_request_service.dart';

/// Rezultatul dialogului post-finalizare.
enum ReviewRequestDialogAction { send, skip }

/// Afișează un dialog post-finalizare lucrare cu opțiunea de a cere recenzie.
///
/// Apelează imediat după marcarea lucrării ca finalizată:
///
/// ─── INTEGRARE ÎN programari_page.dart ────────────────────────────────────
/// import 'review_request_dialog.dart';
/// import 'review_request_service.dart';
///
/// // Imediat după _repo.saveAppointment(...) cu status = 'finalizat':
/// if (mounted) {
///   await showReviewRequestDialog(
///     context: context,
///     appointmentId: appointment.id,
///     clientPhone: client?.phone,
///     clientName: client?.name,
///     currentUserId: _currentUserId,
///     onFieldsUpdated: (fields) async {
///       final newMap = {...appointment.toMap(), ...fields.toMap()};
///       await _repo.saveAppointment(AppointmentModel.fromMap(newMap));
///     },
///   );
/// }
/// ──────────────────────────────────────────────────────────────────────────
Future<ReviewRequestDialogAction> showReviewRequestDialog({
  required BuildContext context,
  required String appointmentId,
  required String? clientPhone,
  required String? clientName,
  required String? currentUserId,
  required Future<void> Function(ReviewRequestFields fields) onFieldsUpdated,
}) async {
  final hasPhone =
      clientPhone != null && clientPhone.trim().isNotEmpty;

  final action = await showDialog<ReviewRequestDialogAction>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ReviewRequestDialog(
      hasPhone: hasPhone,
      clientName: clientName,
    ),
  );

  if (action != ReviewRequestDialogAction.send) {
    return action ?? ReviewRequestDialogAction.skip;
  }

  if (!context.mounted) return ReviewRequestDialogAction.skip;

  if (!hasPhone) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Clientul nu are număr de telefon. Adaugă-l din fișa clientului.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
    return ReviewRequestDialogAction.skip;
  }

  final message =
      ReviewRequestService.buildMessage(clientName: clientName);
  bool openedWhatsApp = false;
  String? errorText;

  try {
    openedWhatsApp = await ReviewRequestService.launchWhatsApp(
      rawPhone: clientPhone!,
      message: message,
    );
  } catch (e) {
    errorText = e.toString();
  }

  final fields = ReviewRequestFields(
    sentAt: DateTime.now(),
    sentBy: currentUserId,
    count: 1,
    method: openedWhatsApp ? 'whatsapp' : 'browser',
    lastMessage: message,
    lastError: errorText,
  );

  // Fire-and-forget Firestore (best-effort)
  ReviewRequestService.persistToFirestore(
    appointmentId: appointmentId,
    fields: fields,
  );

  // Salvare prin repository cu queue offline
  try {
    await onFieldsUpdated(fields);
  } catch (e) {
    debugPrint('[ReviewRequestDialog] ❌ onFieldsUpdated error: $e');
  }

  if (!context.mounted) return ReviewRequestDialogAction.send;

  if (errorText != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Eroare la deschiderea WhatsApp: $errorText'),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          openedWhatsApp
              ? 'WhatsApp s-a deschis — apasă Send pentru a trimite.'
              : 'S-a deschis în browser — apasă Send în WhatsApp Web.',
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  return ReviewRequestDialogAction.send;
}

class _ReviewRequestDialog extends StatelessWidget {
  final bool hasPhone;
  final String? clientName;

  const _ReviewRequestDialog({
    required this.hasPhone,
    this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green.shade600),
          const SizedBox(width: 8),
          const Text('Lucrare finalizată!'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Dorești să trimiți o cerere de recenzie Google clientului?'),
          if (clientName != null && clientName!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Mesajul va fi trimis lui ${clientName!.trim()} pe WhatsApp.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ],
          if (!hasPhone) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_outlined,
                      size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Clientul nu are număr de telefon salvat.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(ReviewRequestDialogAction.skip),
          child: const Text('Nu acum'),
        ),
        FilledButton.icon(
          onPressed: hasPhone
              ? () =>
                  Navigator.of(context).pop(ReviewRequestDialogAction.send)
              : null,
          icon: const Icon(Icons.send_outlined, size: 16),
          label: const Text('Trimite pe WhatsApp'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green.shade700,
          ),
        ),
      ],
    );
  }
}
