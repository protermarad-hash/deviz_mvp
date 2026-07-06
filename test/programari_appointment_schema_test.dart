import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/features/programari/appointment_models.dart';

void main() {
  group('Appointment schema compatibility', () {
    test('reads build 58 camelCase date fields without moving date to today',
        () {
      final appointment = Appointment.fromMap({
        'id': 'appt-build58',
        'clientName': 'Client test',
        'scheduledDate': '2026-07-13T00:00:00.000',
        'startTime': '08:00',
        'endTime': '10:00',
        'teamId': 'team-1',
        'vehicleId': 'veh-1',
        'contactPhone': '0712345678',
      });

      expect(appointment.id, 'appt-build58');
      expect(appointment.scheduledDate, DateTime(2026, 7, 13));
      expect(appointment.startTime, '08:00');
      expect(appointment.endTime, '10:00');
      expect(appointment.primaryAssignedTeamId, 'team-1');
      expect(appointment.vehicleId, 'veh-1');
      expect(appointment.clientPhoneNumbers, ['0712345678']);
    });

    test('reads Firestore Timestamp scheduled_date used by cloud documents',
        () {
      final appointment = Appointment.fromMap({
        'id': 'appt-timestamp',
        'scheduled_date': Timestamp.fromDate(DateTime(2026, 7, 14, 9)),
        'start_time': '09:00',
        'end_time': '11:00',
      });

      expect(appointment.scheduledDate, DateTime(2026, 7, 14, 9));
      expect(appointment.effectiveStartDateTime, DateTime(2026, 7, 14, 9));
      expect(appointment.effectiveEndDateTime, DateTime(2026, 7, 14, 11));
    });
  });
}
