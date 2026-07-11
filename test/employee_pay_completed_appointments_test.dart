import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/features/hr/employee_financial_models.dart';
import 'package:devizpro_ultra/features/hr/employee_pay_eligibility.dart';
import 'package:devizpro_ultra/features/programari/appointment_models.dart';
import 'package:devizpro_ultra/features/programari/appointment_status_utils.dart';

void main() {
  Appointment appointment(String id, String status) => Appointment.fromMap({
        'id': id,
        'status': status,
        'scheduled_date': '2026-07-10T00:00:00.000',
      });

  EmployeePayEntry entry(String id, String appointmentId, double amount) =>
      EmployeePayEntry(
        id: id,
        employeeId: 'emp-1',
        employeeName: 'Angajat test',
        appointmentId: appointmentId,
        appointmentTitle: 'Programare test',
        appointmentDate: '2026-07-10',
        jobId: '',
        jobTitle: '',
        amountDue: amount,
        currency: 'RON',
        notes: '',
        createdAt: DateTime(2026, 7, 10),
        createdBy: '',
      );

  group('appointment status normalization', () {
    test('keeps completed aliases compatible', () {
      expect(normalizeAppointmentStatus('finalizata'), 'finalizata');
      expect(normalizeAppointmentStatus('done'), 'finalizata');
      expect(normalizeAppointmentStatus('completed'), 'finalizata');
    });

    test('does not treat incomplete or unknown statuses as completed', () {
      for (final status in [
        'planificata',
        'in_curs',
        'amanata',
        'anulata',
        '',
        'necunoscut',
      ]) {
        expect(isCompletedAppointmentStatus(status), isFalse, reason: status);
      }
    });
  });

  group('employee pay eligibility', () {
    test('includes only entries for completed appointments', () {
      final entries = [
        entry('pay-final', 'appt-final', 100),
        entry('pay-planned', 'appt-planned', 20),
        entry('pay-progress', 'appt-progress', 30),
        entry('pay-postponed', 'appt-postponed', 40),
        entry('pay-cancelled', 'appt-cancelled', 50),
        entry('pay-empty', '', 60),
        entry('pay-missing', 'appt-missing', 70),
      ];
      final appointments = [
        appointment('appt-final', 'finalizata'),
        appointment('appt-planned', 'planificata'),
        appointment('appt-progress', 'in_curs'),
        appointment('appt-postponed', 'amanata'),
        appointment('appt-cancelled', 'anulata'),
      ];

      final filtered = filterPayEntriesForCompletedAppointments(
        entries,
        appointments,
      );

      expect(filtered.map((item) => item.id), ['pay-final']);
      expect(
        calculateDueByEmployeeForCompletedAppointments(entries, appointments),
        {'emp-1': 100},
      );
    });

    test('recalculation follows transitions into and out of completed', () {
      final entries = [entry('pay-1', 'appt-1', 125)];

      expect(
        filterPayEntriesForCompletedAppointments(
          entries,
          [appointment('appt-1', 'planificata')],
        ),
        isEmpty,
      );
      expect(
        filterPayEntriesForCompletedAppointments(
          entries,
          [appointment('appt-1', 'completed')],
        ),
        hasLength(1),
      );
      for (final status in ['in_curs', 'amanata', 'anulata']) {
        expect(
          filterPayEntriesForCompletedAppointments(
            entries,
            [appointment('appt-1', status)],
          ),
          isEmpty,
          reason: status,
        );
      }
    });
  });
}
