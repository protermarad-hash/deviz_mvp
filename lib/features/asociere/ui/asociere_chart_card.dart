import 'package:flutter/material.dart';

class AsociereChartSeries {
  const AsociereChartSeries(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

class AsociereChartCard extends StatelessWidget {
  const AsociereChartCard({
    super.key,
    required this.title,
    required this.series,
    this.unit = 'RON',
  });

  final String title;
  final List<AsociereChartSeries> series;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final finite = series.where((item) => item.value.isFinite).toList();
    final max = finite.fold<double>(0,
        (value, item) => item.value.abs() > value ? item.value.abs() : value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (finite.isEmpty || max == 0)
              const SizedBox(
                height: 140,
                child: Center(
                    child: Text('Nu există date pentru perioada selectată.')),
              )
            else
              SizedBox(
                height: 180,
                child: LayoutBuilder(builder: (context, constraints) {
                  final width =
                      (constraints.maxWidth / finite.length).clamp(44.0, 92.0);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: finite.map((item) {
                        final height = 120 * item.value.abs() / max;
                        return Tooltip(
                          message:
                              '${item.label}: ${item.value.toStringAsFixed(2)} $unit',
                          child: SizedBox(
                            width: width,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(item.value.toStringAsFixed(0),
                                    style:
                                        Theme.of(context).textTheme.labelSmall),
                                const SizedBox(height: 4),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: width * .55,
                                  height: height.clamp(4, 120),
                                  decoration: BoxDecoration(
                                    color: item.color,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}
