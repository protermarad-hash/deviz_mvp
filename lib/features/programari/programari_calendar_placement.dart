import 'appointment_models.dart';

/// Plasarea unei programări în grila calendarului (zi cu mai multe programări
/// suprapuse). Calculează banda (lane) și intervalul vizual ocupat.
class CalendarPlacement {
  const CalendarPlacement({
    required this.item,
    required this.laneIndex,
    required this.laneCount,
    required this.visualStart,
    required this.visualEnd,
  });

  final Appointment item;
  final int laneIndex;
  final int laneCount;
  final DateTime visualStart;
  final DateTime visualEnd;
}
