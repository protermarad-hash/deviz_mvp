/// Logica pură (fără dependință de Flutter/widget state) pentru navigarea
/// "interval anterior" / "interval următor" din calendarul Programări.
///
/// Extrasă separat pentru a fi testabilă direct (fără a instanția
/// `_ProgramariPageState`), la fel ca `programari_calendar_placement.dart`.
///
/// Bug reparat aici: pasul de navigare era hardcodat la 7 zile, indiferent
/// de câte zile sunt afișate curent (`_calendarVisibleDays`). Rămăsese
/// invizibil cât timp implicitul era 7 zile pentru toată lumea — a devenit
/// vizibil după ce ecranele înguste au primit implicit 1 zi.
class CalendarIntervalNavigation {
  const CalendarIntervalNavigation._();

  /// Doar vizualizarea pe 7 zile rămâne ancorată la luni (săptămână
  /// completă); restul valorilor (1/3/5) sunt o fereastră continuă care
  /// pornește chiar din `_calendarFocusDate`.
  static bool usesWeekAnchor(int visibleDayCount) => visibleDayCount == 7;

  static DateTime nextFocusDate({
    required DateTime currentFocusDate,
    required int visibleDayCount,
  }) =>
      _shiftedFocusDate(
        currentFocusDate: currentFocusDate,
        visibleDayCount: visibleDayCount,
        direction: 1,
      );

  static DateTime previousFocusDate({
    required DateTime currentFocusDate,
    required int visibleDayCount,
  }) =>
      _shiftedFocusDate(
        currentFocusDate: currentFocusDate,
        visibleDayCount: visibleDayCount,
        direction: -1,
      );

  static DateTime _shiftedFocusDate({
    required DateTime currentFocusDate,
    required int visibleDayCount,
    required int direction,
  }) {
    final baseDate = usesWeekAnchor(visibleDayCount)
        ? startOfWeekMonday(currentFocusDate)
        : dateOnly(currentFocusDate);
    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day + direction * visibleDayCount,
    );
  }

  static DateTime dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime startOfWeekMonday(DateTime value) {
    final day = dateOnly(value);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }
}
