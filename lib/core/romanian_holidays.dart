import 'package:flutter/material.dart';

// Verificare Paște Ortodox (algoritm Julian Calendar):
// 2024: 5 mai   ✓
// 2025: 20 apr  ✓
// 2026: 12 apr  ✓
// 2027: 2 mai   ✓
// 2028: 16 apr  ✓

enum DayType { workday, saturday, holiday, sunday }

class HolidayColors {
  HolidayColors._();

  // Duminici + Sărbători legale
  static const Color sundayHoliday = Color(0xFFFFEBEE);
  static const Color sundayHolidayBorder = Color(0xFFEF9A9A);
  static const Color sundayHolidayText = Color(0xFFC62828);

  // Sâmbete
  static const Color saturday = Color(0xFFFFF8E1);
  static const Color saturdayBorder = Color(0xFFFFCC80);
  static const Color saturdayText = Color(0xFFE65100);

  // Zile lucrătoare (normal)
  static const Color workday = Colors.transparent;
}

class RomanianHolidays {
  RomanianHolidays._();

  // ── PAȘTE ORTODOX (algoritm Julian Calendar) ────────
  static DateTime orthodoxEaster(int year) {
    final a = year % 4;
    final b = year % 7;
    final c = year % 19;
    final d = (19 * c + 15) % 30;
    final e = (2 * a + 4 * b - d + 34) % 7;
    final month = (d + e + 114) ~/ 31;
    final day = ((d + e + 114) % 31) + 1;
    // Adaugă 13 zile (diferența calendar Julian→Gregorian)
    return DateTime(year, month, day).add(const Duration(days: 13));
  }

  // ── SĂRBĂTORI FIXE ──────────────────────
  static List<DateTime> fixedHolidays(int year) => [
        DateTime(year, 1, 1), // Anul Nou
        DateTime(year, 1, 2), // A doua zi de Anul Nou
        DateTime(year, 1, 24), // Ziua Unirii Principatelor
        DateTime(year, 5, 1), // Ziua Muncii
        DateTime(year, 6, 1), // Ziua Copilului
        DateTime(year, 8, 15), // Sfânta Maria Mare
        DateTime(year, 11, 30), // Sfântul Andrei
        DateTime(year, 12, 1), // Ziua Națională
        DateTime(year, 12, 25), // Crăciun
        DateTime(year, 12, 26), // A doua zi de Crăciun
      ];

  // ── SĂRBĂTORI MOBILE (bazate pe Paște Ortodox) ───────
  static List<DateTime> movableHolidays(int year) {
    final easter = orthodoxEaster(year);
    return [
      easter.subtract(const Duration(days: 2)), // Vinerea Mare
      easter, // Paște
      easter.add(const Duration(days: 1)), // Lunea Paștelui
      easter.add(const Duration(days: 49)), // Rusalii
      easter.add(const Duration(days: 50)), // A doua zi de Rusalii
    ];
  }

  // ── TOATE SĂRBĂTORILE PENTRU UN AN ────────────────
  static Set<String> holidaysForYear(int year) {
    final all = [
      ...fixedHolidays(year),
      ...movableHolidays(year),
    ];
    return all.map((d) => _key(d)).toSet();
  }

  // ── CACHE PENTRU 10 ANI (2024-2034) ─────────────────
  static final Map<int, Set<String>> _cache = {};

  static Set<String> _getForYear(int year) {
    return _cache.putIfAbsent(year, () => holidaysForYear(year));
  }

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  // ─ API PUBLICĂ ───────────────────────────

  static bool isHoliday(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return _getForYear(d.year).contains(_key(d));
  }

  static bool isSunday(DateTime date) => date.weekday == DateTime.sunday;

  static bool isSaturday(DateTime date) => date.weekday == DateTime.saturday;

  static DayType getDayType(DateTime date) {
    if (isHoliday(date)) return DayType.holiday;
    if (isSunday(date)) return DayType.sunday;
    if (isSaturday(date)) return DayType.saturday;
    return DayType.workday;
  }

  // Nume sărbătoare (pentru tooltip)
  static String? holidayName(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final year = d.year;
    final easter = orthodoxEaster(year);
    final namedHolidays = {
      _key(DateTime(year, 1, 1)): 'Anul Nou',
      _key(DateTime(year, 1, 2)): 'A doua zi de Anul Nou',
      _key(DateTime(year, 1, 24)): 'Ziua Unirii Principatelor',
      _key(DateTime(year, 5, 1)): 'Ziua Muncii',
      _key(DateTime(year, 6, 1)): 'Ziua Copilului',
      _key(DateTime(year, 8, 15)): 'Sfânta Maria Mare',
      _key(DateTime(year, 11, 30)): 'Sfântul Andrei',
      _key(DateTime(year, 12, 1)): 'Ziua Națională',
      _key(DateTime(year, 12, 25)): 'Crăciun',
      _key(DateTime(year, 12, 26)): 'A doua zi de Crăciun',
      _key(easter.subtract(const Duration(days: 2))): 'Vinerea Mare',
      _key(easter): 'Paște',
      _key(easter.add(const Duration(days: 1))): 'Lunea Paștelui',
      _key(easter.add(const Duration(days: 49))): 'Rusalii',
      _key(easter.add(const Duration(days: 50))): 'A doua zi de Rusalii',
    };
    return namedHolidays[_key(d)];
  }
}
