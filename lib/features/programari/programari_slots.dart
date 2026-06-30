import 'package:flutter/material.dart';

/// Slot orar vizual pentru calendarul Programări.
///
/// IMPORTANT: sloturile sunt DOAR organizare vizuală — nu restricționează
/// durata sau ora programărilor. O programare poate începe/termina la orice
/// oră; benzile colorate ajută doar la citirea rapidă a zilei.
class ProgramareSlot {
  final int startHour;
  final int endHour;
  final String label;
  final Color backgroundColor;

  const ProgramareSlot({
    required this.startHour,
    required this.endHour,
    required this.label,
    required this.backgroundColor,
  });

  /// Etichetă scurtă pentru chips/selector (ex: "09-12").
  String get rangeLabel =>
      '${startHour.toString().padLeft(2, '0')}-${endHour.toString().padLeft(2, '0')}';

  /// True dacă ora dată (0-23) cade în acest slot [startHour, endHour).
  bool containsHour(int hour) => hour >= startHour && hour < endHour;
}

/// Cele 4 sloturi standard ale zilei de lucru.
const List<ProgramareSlot> kProgramareSloturi = [
  ProgramareSlot(
    startHour: 9,
    endHour: 12,
    label: 'Slot 1 (09-12)',
    backgroundColor: Color(0xFFFFF3E0), // portocaliu foarte deschis
  ),
  ProgramareSlot(
    startHour: 12,
    endHour: 15,
    label: 'Slot 2 (12-15)',
    backgroundColor: Color(0xFFE3F2FD), // albastru foarte deschis
  ),
  ProgramareSlot(
    startHour: 15,
    endHour: 18,
    label: 'Slot 3 (15-18)',
    backgroundColor: Color(0xFFE8F5E9), // verde foarte deschis
  ),
  ProgramareSlot(
    startHour: 18,
    endHour: 21,
    label: 'Slot 4 (18-21)',
    backgroundColor: Color(0xFFFCE4EC), // roz foarte deschis
  ),
];

/// Orele care delimitează sloturile (9, 12, 15, 18, 21) — folosite pentru
/// liniile de separare mai groase în calendar.
final Set<int> kProgramareSlotBoundaries = {
  for (final slot in kProgramareSloturi) ...[slot.startHour, slot.endHour],
};
