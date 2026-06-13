import 'package:flutter/foundation.dart';

import '../cloud/firebase_bootstrap.dart';
import '../../features/jobs/job_models.dart';
import '../../features/notifications/notification_runtime_service.dart';
import '../../features/oferte/local_oferte_repository.dart';
import '../../features/oferte/offer_models.dart';

/// Declanșează notificări locale la schimbări de status pentru oferte și lucrări.
/// Apelat din repositories după upsert.
class StatusChangeNotifier {
  StatusChangeNotifier._();
  static final instance = StatusChangeNotifier._();

  // Stochează ultimele statusuri pentru a detecta schimbări reale
  final Map<String, String> _lastOfertaStatus = {};
  final Map<String, String> _lastJobStatus = {};

  /// Apelat după `upsertOffer()` — notifică dacă statusul s-a schimbat.
  Future<void> onOfertaStatusChanged(OfferRecord oferta) async {
    try {
      final prevStatus = _lastOfertaStatus[oferta.id];
      final newStatus = oferta.status.value;
      _lastOfertaStatus[oferta.id] = newStatus;

      // Nu notifica la prima încărcare sau la status identic
      if (prevStatus == null || prevStatus == newStatus) return;

      switch (oferta.status) {
        case OfferStatus.accepted:
          await NotificationRuntimeService.instance.showLocalNotification(
            title: '✅ Ofertă acceptată!',
            body:
                '${oferta.offerNumber} — ${oferta.clientName} · ${oferta.totalValue.toStringAsFixed(0)} RON',
            data: {'type': 'oferta', 'id': oferta.id, 'status': 'acceptata'},
          );
        case OfferStatus.rejected:
          await NotificationRuntimeService.instance.showLocalNotification(
            title: '❌ Ofertă respinsă',
            body: '${oferta.offerNumber} — ${oferta.clientName}',
            data: {'type': 'oferta', 'id': oferta.id, 'status': 'respinsa'},
          );
        case OfferStatus.sent:
          debugPrint(
              '[StatusChangeNotifier] Ofertă trimisă: ${oferta.offerNumber}');
        default:
          break;
      }
    } catch (e) {
      debugPrint('[StatusChangeNotifier] onOfertaStatusChanged error: $e');
    }
  }

  /// Apelat după `saveJob()` — notifică dacă statusul s-a schimbat.
  Future<void> onJobStatusChanged(JobRecord job) async {
    try {
      final prevStatus = _lastJobStatus[job.id];
      final newStatus = job.status.value;
      _lastJobStatus[job.id] = newStatus;

      if (prevStatus == null || prevStatus == newStatus) return;

      if (job.status == JobStatus.finalizata &&
          job.smartbillFacturaNumar.isEmpty) {
        await NotificationRuntimeService.instance.showLocalNotification(
          title: '🔔 Lucrare finalizată — de facturat',
          body:
              '${job.jobCode} · ${job.title} · ${job.totalReal.toStringAsFixed(0)} RON',
          data: {'type': 'job', 'id': job.id, 'action': 'facturare'},
        );
      } else if (job.status == JobStatus.inExecutie) {
        debugPrint(
            '[StatusChangeNotifier] Lucrare în execuție: ${job.jobCode}');
      }
    } catch (e) {
      debugPrint('[StatusChangeNotifier] onJobStatusChanged error: $e');
    }
  }

  /// Verificare la startup — oferte trimise de > 30 zile fără răspuns.
  Future<void> checkOfertaExpirate() async {
    if (!FirebaseBootstrap.isInitialized) return;
    try {
      final repo = LocalOferteRepository();
      final expirate = await repo.listExpirate(dupaZile: 30);
      if (expirate.isEmpty) return;
      await NotificationRuntimeService.instance.showLocalNotification(
        title: '⏰ ${expirate.length} oferte expirate',
        body: 'Necesită reactivare sau marcare respinsă',
        data: {'type': 'oferte', 'filter': 'expirate'},
      );
      debugPrint(
          '[StatusChangeNotifier] ${expirate.length} oferte expirate notificate');
    } catch (e) {
      debugPrint('[StatusChangeNotifier] checkOfertaExpirate error: $e');
    }
  }
}
