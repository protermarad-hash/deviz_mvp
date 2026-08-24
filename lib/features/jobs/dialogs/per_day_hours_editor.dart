import 'package:flutter/material.dart';

/// Listă de zile cu câmp de ore editabil INDIVIDUAL, folosită la
/// adăugarea în lot ("Zile individuale") — atât pentru manoperă proprie
/// cât și pentru personal partener (paritate structurală, cerință
/// explicită). Înainte, o singură valoare "Ore/zi" se aplica identic
/// tuturor zilelor selectate; acum fiecare zi are propriul câmp,
/// pre-completat cu valoarea implicită, dar liber suprascriptibil.
///
/// State-ul (controllerele per zi) trăiește ÎN acest widget (nu în
/// closure-ul StatefulBuilder al dialogului părinte), ca să nu se piardă
/// la fiecare `setDialogState` din jur. Părintele citește valorile
/// curente prin `onChanged` (apelat la fiecare tastare) și poate forța
/// aceeași valoare pe toate zilele prin `applyToAll()`, apelat via
/// `GlobalKey<PerDayHoursEditorState>`.
class PerDayHoursEditor extends StatefulWidget {
  const PerDayHoursEditor({
    super.key,
    required this.days,
    required this.initialHoursPerDay,
    required this.onChanged,
    required this.formatHours,
  });

  /// Zile deja sortate/normalizate (fără componentă de oră) — trebuie să
  /// fie EXACT aceleași valori `DateTime` folosite ulterior la generarea
  /// rândurilor, ca lookup-ul pe cheie să funcționeze.
  final List<DateTime> days;
  final double initialHoursPerDay;
  final void Function(Map<DateTime, double> hoursByDay) onChanged;
  final String Function(double) formatHours;

  @override
  State<PerDayHoursEditor> createState() => PerDayHoursEditorState();
}

class PerDayHoursEditorState extends State<PerDayHoursEditor> {
  late Map<DateTime, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = _buildControllers();
    // Raportează valorile inițiale imediat, ca "Ore totale" din părinte
    // să fie corect din primul frame (nu doar după prima tastare).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(currentValues);
    });
  }

  Map<DateTime, TextEditingController> _buildControllers() => {
        for (final day in widget.days)
          day: TextEditingController(
            text: widget.formatHours(widget.initialHoursPerDay),
          ),
      };

  @override
  void didUpdateWidget(covariant PerDayHoursEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameDays(oldWidget.days, widget.days)) return;
    // Zilele selectate s-au schimbat (utilizatorul a redeschis selectorul
    // de zile) — păstrează valorile existente pentru zilele care rămân,
    // adaugă valoarea implicită pentru zilele noi.
    final next = <DateTime, TextEditingController>{};
    for (final day in widget.days) {
      next[day] = _controllers.remove(day) ??
          TextEditingController(
            text: widget.formatHours(widget.initialHoursPerDay),
          );
    }
    for (final leftover in _controllers.values) {
      leftover.dispose();
    }
    _controllers = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(currentValues);
    });
  }

  bool _sameDays(List<DateTime> a, List<DateTime> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<DateTime, double> get currentValues => {
        for (final entry in _controllers.entries)
          entry.key:
              double.tryParse(entry.value.text.replaceAll(',', '.')) ?? 0,
      };

  /// Suprascrie ora TUTUROR zilelor cu `value` — apelat din butonul
  /// "Aplică la toate zilele" al dialogului părinte.
  void applyToAll(double value) {
    setState(() {
      for (final c in _controllers.values) {
        c.text = widget.formatHours(value);
      }
    });
    widget.onChanged(currentValues);
  }

  String _dayLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    if (widget.days.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.days.map((day) {
        final controller = _controllers[day];
        if (controller == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  _dayLabel(day),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Ore', isDense: true),
                  onChanged: (_) => widget.onChanged(currentValues),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
