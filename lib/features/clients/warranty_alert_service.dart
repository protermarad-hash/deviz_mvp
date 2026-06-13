import 'package:flutter/material.dart';

import '../product_catalog/local_product_catalog_store.dart';
import '../product_catalog/product_sales_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WarrantyAlertService — detectare garanții care expiră în curând
// Sursa: LocalProductCatalogStore → WarrantyCertificateRecord.warrantyEndDate
// ─────────────────────────────────────────────────────────────────────────────

enum WarrantyAlertSeverity { expired, urgent, warning }

class WarrantyAlert {
  const WarrantyAlert({
    required this.certificate,
    required this.severity,
    required this.daysUntilExpiry,
  });

  final WarrantyCertificateRecord certificate;
  final WarrantyAlertSeverity severity;
  final int daysUntilExpiry;

  String get clientDisplay =>
      certificate.buyerName.trim().isNotEmpty ? certificate.buyerName.trim() : 'Client necunoscut';

  String get productDisplay {
    final parts = [certificate.brand.trim(), certificate.model.trim()].where((s) => s.isNotEmpty);
    return parts.isNotEmpty ? parts.join(' ') : 'Echipament';
  }

  String get expiryLabel {
    if (daysUntilExpiry < 0) return 'Expirată (${(-daysUntilExpiry)} zile)';
    if (daysUntilExpiry == 0) return 'Expiră azi';
    return 'Expiră în $daysUntilExpiry zile';
  }

  Color get severityColor {
    switch (severity) {
      case WarrantyAlertSeverity.expired:
        return const Color(0xFFC62828);
      case WarrantyAlertSeverity.urgent:
        return const Color(0xFFE65100);
      case WarrantyAlertSeverity.warning:
        return const Color(0xFFF57F17);
    }
  }

  IconData get severityIcon {
    switch (severity) {
      case WarrantyAlertSeverity.expired:
        return Icons.cancel_outlined;
      case WarrantyAlertSeverity.urgent:
        return Icons.warning_amber_outlined;
      case WarrantyAlertSeverity.warning:
        return Icons.schedule_outlined;
    }
  }
}

class WarrantyAlertResult {
  const WarrantyAlertResult({
    required this.expired,
    required this.urgent,
    required this.warning,
  });

  final List<WarrantyAlert> expired;
  final List<WarrantyAlert> urgent;
  final List<WarrantyAlert> warning;

  List<WarrantyAlert> get all => [...expired, ...urgent, ...warning];
  int get totalCount => expired.length + urgent.length + warning.length;
  bool get hasAlerts => totalCount > 0;

  WarrantyAlertSeverity? get worstSeverity {
    if (expired.isNotEmpty) return WarrantyAlertSeverity.expired;
    if (urgent.isNotEmpty) return WarrantyAlertSeverity.urgent;
    if (warning.isNotEmpty) return WarrantyAlertSeverity.warning;
    return null;
  }

  static const empty = WarrantyAlertResult(expired: [], urgent: [], warning: []);
}

class WarrantyAlertService {
  WarrantyAlertService._();
  static final WarrantyAlertService instance = WarrantyAlertService._();

  final _store = LocalProductCatalogStore();

  /// Returnează toate alertele de garanție grupate pe severitate.
  Future<WarrantyAlertResult> loadAlerts() async {
    try {
      final certs = await _store.listWarrantyCertificates();
      return _compute(certs);
    } catch (e) {
      debugPrint('[WarrantyAlert] ❌ loadAlerts error: $e');
      return WarrantyAlertResult.empty;
    }
  }

  /// Returnează alertele pentru un client specific.
  Future<WarrantyAlertResult> loadAlertsForClient(String clientId, String clientName) async {
    try {
      final all = await _store.listWarrantyCertificates();
      final clientCerts = all.where((c) {
        if (clientId.isNotEmpty && c.buyerClientId.trim() == clientId.trim()) return true;
        if (clientName.isNotEmpty) {
          final a = c.buyerName.trim().toLowerCase();
          final b = clientName.trim().toLowerCase();
          if (a.isNotEmpty && b.isNotEmpty && (a == b || a.contains(b) || b.contains(a))) return true;
        }
        return false;
      }).toList();
      return _compute(clientCerts);
    } catch (_) {
      return WarrantyAlertResult.empty;
    }
  }

  WarrantyAlertResult _compute(List<WarrantyCertificateRecord> certs) {
    final now = DateTime.now();
    final expired = <WarrantyAlert>[];
    final urgent = <WarrantyAlert>[];
    final warning = <WarrantyAlert>[];

    for (final cert in certs) {
      final end = cert.warrantyEndDate;
      if (end == null) continue;
      final days = end.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (days < 0) {
        expired.add(WarrantyAlert(certificate: cert, severity: WarrantyAlertSeverity.expired, daysUntilExpiry: days));
      } else if (days <= 7) {
        urgent.add(WarrantyAlert(certificate: cert, severity: WarrantyAlertSeverity.urgent, daysUntilExpiry: days));
      } else if (days <= 30) {
        warning.add(WarrantyAlert(certificate: cert, severity: WarrantyAlertSeverity.warning, daysUntilExpiry: days));
      }
    }

    expired.sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));
    urgent.sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));
    warning.sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));

    return WarrantyAlertResult(expired: expired, urgent: urgent, warning: warning);
  }
}
