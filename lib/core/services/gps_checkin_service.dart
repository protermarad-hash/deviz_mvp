import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';

class GpsCheckinRecord {
  const GpsCheckinRecord({
    required this.id,
    required this.appointmentId,
    required this.employeeId,
    required this.employeeName,
    required this.tipCheckin,
    required this.latitudine,
    required this.longitudine,
    required this.timestamp,
    this.accuracy,
    this.adresaGeocodata,
    this.distantaFataDeLocatie,
    this.esteInRaza = true,
  });

  final String id;
  final String appointmentId;
  final String employeeId;
  final String employeeName;
  /// 'check_in' | 'check_out'
  final String tipCheckin;
  final double latitudine;
  final double longitudine;
  final double? accuracy;
  final String? adresaGeocodata;
  final DateTime timestamp;
  final double? distantaFataDeLocatie;
  final bool esteInRaza;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'appointment_id': appointmentId,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'tip_checkin': tipCheckin,
        'latitudine': latitudine,
        'longitudine': longitudine,
        'accuracy': accuracy,
        'adresa_geocodata': adresaGeocodata,
        'timestamp': timestamp.toIso8601String(),
        'distanta_fata_de_locatie': distantaFataDeLocatie,
        'este_in_raza': esteInRaza,
      };

  factory GpsCheckinRecord.fromMap(Map<String, dynamic> m) => GpsCheckinRecord(
        id: (m['id'] ?? '').toString(),
        appointmentId: (m['appointment_id'] ?? '').toString(),
        employeeId: (m['employee_id'] ?? '').toString(),
        employeeName: (m['employee_name'] ?? '').toString(),
        tipCheckin: (m['tip_checkin'] ?? 'check_in').toString(),
        latitudine: (m['latitudine'] as num? ?? 0).toDouble(),
        longitudine: (m['longitudine'] as num? ?? 0).toDouble(),
        accuracy: (m['accuracy'] as num?)?.toDouble(),
        adresaGeocodata: m['adresa_geocodata'] as String?,
        timestamp: DateTime.tryParse((m['timestamp'] ?? '').toString()) ??
            DateTime.now(),
        distantaFataDeLocatie:
            (m['distanta_fata_de_locatie'] as num?)?.toDouble(),
        esteInRaza: (m['este_in_raza'] as bool? ?? true),
      );
}

class GpsCheckinResult {
  const GpsCheckinResult.success({
    this.record,
    this.inRaza = true,
    this.distanta,
  })  : success = true,
        error = null;

  const GpsCheckinResult.error(this.error)
      : success = false,
        record = null,
        inRaza = false,
        distanta = null;

  final bool success;
  final GpsCheckinRecord? record;
  final bool inRaza;
  final double? distanta;
  final String? error;
}

class GpsCheckinService {
  GpsCheckinService._();
  static final GpsCheckinService instance = GpsCheckinService._();

  static const double _razaAcceptata = 500.0;
  static const String _localKey = 'gps_checkins_v1';
  final Uuid _uuid = const Uuid();

  // ── Check-in ─────────────────────────────────────────────────────────────

  Future<GpsCheckinResult> checkIn({
    required String appointmentId,
    required String adresaLocatie,
  }) async {
    return _doCheckin(
      appointmentId: appointmentId,
      adresaLocatie: adresaLocatie,
      tip: 'check_in',
    );
  }

  Future<GpsCheckinResult> checkOut({
    required String appointmentId,
    String adresaLocatie = '',
  }) async {
    return _doCheckin(
      appointmentId: appointmentId,
      adresaLocatie: adresaLocatie,
      tip: 'check_out',
    );
  }

  Future<GpsCheckinResult> _doCheckin({
    required String appointmentId,
    required String adresaLocatie,
    required String tip,
  }) async {
    // 1. Verifică și solicită permisiuni
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const GpsCheckinResult.error(
          'Permisiunea GPS a fost refuzata. Activati din setarile telefonului.');
    }

    // 2. Verifică dacă serviciul GPS e activ
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const GpsCheckinResult.error(
          'GPS-ul este dezactivat. Activati localizarea din setarile telefonului.');
    }

    // 3. Obține poziția curentă
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      return GpsCheckinResult.error('Nu am putut obtine pozitia GPS: $e');
    }

    // 4. Geocodare inversă (adresa lizibilă din coordonate)
    String? adresaGeo;
    try {
      final placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if ((p.street ?? '').isNotEmpty) p.street!,
          if ((p.locality ?? '').isNotEmpty) p.locality!,
        ];
        if (parts.isNotEmpty) adresaGeo = parts.join(', ');
      }
    } catch (e) {
      debugPrint('[GpsCheckin] geocodare inversă (adresă) eșuată: $e');
    }

    // 5. Calculează distanța față de adresa programării
    double? distanta;
    bool inRaza = true;
    if (adresaLocatie.trim().isNotEmpty) {
      try {
        final locations = await locationFromAddress(adresaLocatie.trim());
        if (locations.isNotEmpty) {
          distanta = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            locations.first.latitude,
            locations.first.longitude,
          );
          inRaza = distanta <= _razaAcceptata;
        }
      } catch (e) {
        debugPrint('[GpsCheckin] calcul distanță față de adresă eșuat: $e');
      }
    }

    // 6. Creează și salvează înregistrarea
    final record = GpsCheckinRecord(
      id: _uuid.v4(),
      appointmentId: appointmentId,
      employeeId: FirebaseAuth.instance.currentUser?.uid ?? '',
      employeeName:
          FirebaseAuth.instance.currentUser?.displayName ?? 'Tehnician',
      tipCheckin: tip,
      latitudine: position.latitude,
      longitudine: position.longitude,
      accuracy: position.accuracy,
      adresaGeocodata: adresaGeo,
      timestamp: DateTime.now(),
      distantaFataDeLocatie: distanta,
      esteInRaza: inRaza,
    );

    await _saveRecord(record);
    return GpsCheckinResult.success(
        record: record, inRaza: inRaza, distanta: distanta);
  }

  // ── Citire ───────────────────────────────────────────────────────────────

  Future<List<GpsCheckinRecord>> listForAppointment(
      String appointmentId) async {
    final all = await _readAllLocal();
    return all
        .where((r) => r.appointmentId == appointmentId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Returnează ultimul check-in activ (check_in fara check_out ulterior).
  Future<GpsCheckinRecord?> getActiveCheckin(String appointmentId) async {
    final records = await listForAppointment(appointmentId);
    final checkins =
        records.where((r) => r.tipCheckin == 'check_in').toList();
    final checkouts =
        records.where((r) => r.tipCheckin == 'check_out').toList();
    if (checkins.isEmpty) return null;
    final lastCheckin = checkins.first;
    if (checkouts.isEmpty) return lastCheckin;
    final lastCheckout = checkouts.first;
    return lastCheckin.timestamp.isAfter(lastCheckout.timestamp)
        ? lastCheckin
        : null;
  }

  // ── Persistență ──────────────────────────────────────────────────────────

  Future<void> _saveRecord(GpsCheckinRecord record) async {
    await _writeLocal(record);
    await OfflineSyncRuntime.instance.queueGpsCheckinUpsert(record.toMap());
    if (FirebaseBootstrap.isInitialized) {
      FirebaseFirestore.instance
          .collection(FirebaseCollections.gpsCheckins)
          .doc(record.id)
          .set(record.toMap())
          .catchError((e) {
        debugPrint('[GPS] ❌ Firestore: $e');
      });
    }
  }

  Future<void> _writeLocal(GpsCheckinRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _readAllLocal();
    all.removeWhere((r) => r.id == record.id);
    all.insert(0, record);
    // Păstrăm max 200 înregistrări locale
    final trimmed = all.length > 200 ? all.sublist(0, 200) : all;
    await prefs.setString(
        _localKey, jsonEncode(trimmed.map((r) => r.toMap()).toList()));
  }

  Future<List<GpsCheckinRecord>> _readAllLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey) ?? '[]';
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) =>
              GpsCheckinRecord.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
