import 'package:flutter/material.dart';

/// Selector calendar de zile individuale, posibil neconsecutive (ex: luni +
/// miercuri + vineri), pentru pontaj rapid manoperă proprie. Spre deosebire
/// de `showDatePicker`, permite bifarea mai multor zile într-o singură
/// deschidere, apoi returnează întreaga selecție dintr-o dată.
Future<Set<DateTime>?> showMultiDayPickerDialog(
  BuildContext context, {
  required Set<DateTime> initialSelection,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDialog<Set<DateTime>>(
    context: context,
    builder: (context) => _MultiDayPickerDialog(
      initialSelection: initialSelection,
      firstDate: firstDate ?? DateTime(DateTime.now().year - 5),
      lastDate: lastDate ?? DateTime(DateTime.now().year + 5),
    ),
  );
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

class _MultiDayPickerDialog extends StatefulWidget {
  const _MultiDayPickerDialog({
    required this.initialSelection,
    required this.firstDate,
    required this.lastDate,
  });

  final Set<DateTime> initialSelection;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_MultiDayPickerDialog> createState() => _MultiDayPickerDialogState();
}

class _MultiDayPickerDialogState extends State<_MultiDayPickerDialog> {
  late Set<DateTime> _selected;
  late DateTime _visibleMonth;

  static const _weekDayLabels = ['L', 'Ma', 'Mi', 'J', 'V', 'S', 'D'];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection.map(_dateOnly).toSet();
    final anchor = _selected.isNotEmpty ? _selected.first : DateTime.now();
    _visibleMonth = DateTime(anchor.year, anchor.month);
  }

  bool _isSelectable(DateTime day) =>
      !day.isBefore(_dateOnly(widget.firstDate)) &&
      !day.isAfter(_dateOnly(widget.lastDate));

  void _toggleDay(DateTime day) {
    setState(() {
      if (_selected.contains(day)) {
        _selected.remove(day);
      } else {
        _selected.add(day);
      }
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  List<DateTime?> _buildMonthCells() {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // ISO: luni=1 ... duminică=7. Numărul de celule goale înaintea zilei 1.
    final leadingEmpty = firstOfMonth.weekday - 1;
    return [
      ...List<DateTime?>.filled(leadingEmpty, null),
      ...List<DateTime?>.generate(
          daysInMonth, (i) => DateTime(_visibleMonth.year, _visibleMonth.month, i + 1)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cells = _buildMonthCells();
    final monthLabel =
        '${_monthName(_visibleMonth.month)} ${_visibleMonth.year}';
    final sortedSelected = _selected.toList()..sort();

    return AlertDialog(
      title: const Text('Selectează zile lucrate'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(monthLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
            Row(
              children: _weekDayLabels
                  .map((label) => Expanded(
                        child: Center(
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: cells.map((day) {
                if (day == null) return const SizedBox.shrink();
                final selectable = _isSelectable(day);
                final isSelected = _selected.contains(day);
                final isToday = day == _dateOnly(DateTime.now());
                return Padding(
                  padding: const EdgeInsets.all(2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: selectable ? () => _toggleDay(day) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        border: isToday && !isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          color: !selectable
                              ? Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.4)
                              : isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : null,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_selected.length} zile selectate',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (sortedSelected.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: sortedSelected
                    .map((d) => InputChip(
                          label: Text(
                              '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}'),
                          onDeleted: () => _toggleDay(d),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _selected.isEmpty
              ? null
              : () => setState(() => _selected.clear()),
          child: const Text('Golește'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anulează'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Confirmă'),
        ),
      ],
    );
  }

  String _monthName(int month) {
    const names = [
      'Ianuarie',
      'Februarie',
      'Martie',
      'Aprilie',
      'Mai',
      'Iunie',
      'Iulie',
      'August',
      'Septembrie',
      'Octombrie',
      'Noiembrie',
      'Decembrie',
    ];
    return names[month - 1];
  }
}
