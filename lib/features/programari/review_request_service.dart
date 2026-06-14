// ignore_for_file: avoid_print
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CONFIGURARE — linkul de recenzie Google al firmei PRO TERM SRL
// Dacă linkul se schimbă, modifică DOAR această constantă.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
const String kGoogleReviewUrl = 'https://g.page/r/CXOlG4HYov2NEBM/review';

// Colecția Firestore unde sunt stocate programările / lucrările
const String kAppointmentsCollection = 'appointments';

/// Câmpurile Firestore pentru cererea de recenzie, stocate pe documentul programării.
/// Backward compatible: toate câmpurile sunt nullable, versiunile vechi le ignoră.
class ReviewRequestFields {
  final DateTime? sentAt;
  final String? sentBy;
  final int count;
  final String? method;
  final String? lastMessage;
  final String? lastError;

  const ReviewRequestFields({
    this.sentAt,
    this.sentBy,
    this.count = 0,
    this.method,
    this.lastMessage,
    this.lastError,
  });

  bool get hasSent => sentAt != null && count > 0;

  Map<String, dynamic> toMap() => {
        'review_request_sent_at':
            sentAt != null ? Timestamp.fromDate(sentAt!) : null,
        'review_request_sent_by': sentBy,
        'review_request_count': count,
        'review_request_method': method,
        'review_request_last_message': lastMessage,
        'review_request_last_error': lastError,
      };

  factory ReviewRequestFields.fromMap(Map<String, dynamic> map) {
    final ts = map['review_request_sent_at'];
    return ReviewRequestFields(
      sentAt: ts is Timestamp ? ts.toDate() : null,
      sentBy: map['review_request_sent_by'] as String?,
      count: (map['review_request_count'] as num?)?.toInt() ?? 0,
      method: map['review_request_method'] as String?,
      lastMessage: map['review_request_last_message'] as String?,
      lastError: map['review_request_last_error'] as String?,
    );
  }

  ReviewRequestFields copyWith({
    DateTime? sentAt,
    String? sentBy,
    int? count,
    String? method,
    String? lastMessage,
    String? lastError,
  }) =>
      ReviewRequestFields(
        sentAt: sentAt ?? this.sentAt,
        sentBy: sentBy ?? this.sentBy,
        count: count ?? this.count,
        method: method ?? this.method,
        lastMessage: lastMessage ?? this.lastMessage,
        lastError: lastError ?? this.lastError,
      );
}

/// Utilitar pentru cereri de recenzie Google prin WhatsApp.
/// Toate metodele sunt statice — nu necesită instanțiere.
class ReviewRequestService {
  ReviewRequestService._();

  /// Normalizează numărul de telefon românesc pentru URL-ul wa.me.
  ///
  /// Exemple de input acceptate:
  ///   "0712 345 678"  → "40712345678"
  ///   "0712-345-678"  → "40712345678"
  ///   "+40712345678"  → "40712345678"
  ///   "40712345678"   → "40712345678"
  ///   "0040712345678" → "40712345678"
  static String normalizePhone(String rawPhone) {
    var d = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
    if (d.startsWith('00')) d = d.substring(2); // 0040... → 40...
    if (d.startsWith('0')) d = '4$d'; // 07... → 407...
    return d;
  }

  /// Returnează true dacă numărul normalizat pare valid pentru WhatsApp.
  /// Numerele românești cu prefix 40 au 11 cifre.
  static bool isValidPhone(String normalized) =>
      normalized.length >= 10 && RegExp(r'^\d+$').hasMatch(normalized);

  /// Construiește mesajul de recenzie. Dacă există numele clientului,
  /// mesajul devine personalizat.
  static String buildMessage({String? clientName}) {
    final greeting =
        (clientName != null && clientName.trim().isNotEmpty)
            ? 'Bună ziua, ${clientName.trim()}!'
            : 'Bună ziua!';
    return '$greeting Vă mulțumim că ați ales PRO TERM.\n\n'
        'Dacă sunteți mulțumit de lucrare, ne ajută foarte mult o recenzie pe Google. '
        'Pentru o firmă locală, recomandările clienților contează enorm.\n\n'
        'Puteți lăsa recenzia aici:\n$kGoogleReviewUrl\n\n'
        'Vă mulțumim!';
  }

  /// Deschide WhatsApp cu mesajul precompletat.
  ///
  /// Returnează `true` dacă s-a deschis WhatsApp (aplicația nativă).
  /// Returnează `false` dacă s-a deschis în browser (WhatsApp Web).
  /// Aruncă [Exception] dacă niciuna nu funcționează.
  static Future<bool> launchWhatsApp({
    required String rawPhone,
    required String message,
  }) async {
    final phone = normalizePhone(rawPhone);

    if (!isValidPhone(phone)) {
      throw Exception(
          'Numărul de telefon nu este valid pentru WhatsApp: "$rawPhone"');
    }

    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$phone?text=$encoded');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true; // WhatsApp nativ sau browser — a mers
    }

    // Fallback simplu: încearcă fără text precompletat
    final fallback = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(fallback)) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
      return false;
    }

    throw Exception(
        'Nu s-a putut deschide WhatsApp sau browserul pentru "$rawPhone".');
  }

  /// Salvează câmpurile cererii de recenzie pe documentul de programare în Firestore.
  ///
  /// Fire-and-forget (nu blochează UI). Eroarea se loghează, nu se propagă.
  ///
  /// NOTĂ ARHITECTURALĂ: Această scriere ocolește queue-ul offline din cauza că
  /// sunt câmpuri de metadata pe un document existent. Dacă dispozitivul este
  /// offline, update-ul va fi pierdut. La re-sincronizare, pagina de programare
  /// ar trebui să re-salveze câmpurile prin repository-ul principal.
  static void persistToFirestore({
    required String appointmentId,
    required ReviewRequestFields fields,
    String collection = kAppointmentsCollection,
  }) {
    FirebaseFirestore.instance
        .collection(collection)
        .doc(appointmentId)
        .set(fields.toMap(), SetOptions(merge: true))
        .catchError((Object e) {
      debugPrint('[ReviewRequest] ❌ Eroare Firestore pentru $appointmentId: $e');
    });
  }
}
