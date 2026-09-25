import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../services/analytics.dart';

class ChartSlice {
  final String label;
  final double value;
  final Color color;
  const ChartSlice(this.label, this.value, this.color);
}

/// Donut chart with a readable legend. The whole chart is announced to
/// screen readers as a text summary.
class DonutChart extends StatelessWidget {
  const DonutChart(
      {super.key, required this.slices, required this.currency, this.size = 170});
  final List<ChartSlice> slices;
  final String currency;
  final double size;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    final summary = slices
        .map((s) => '${s.label} ${Fmt.money(s.value, currency)}')
        .join(', ');
    final chart = SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: size * 0.3,
          sections: [
            for (final s in slices)
              PieChartSectionData(
                  value: s.value,
                  color: s.color,
                  radius: size * 0.18,
                  showTitle: false),
          ],
        )),
        Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Total', style: TextStyle(fontSize: 12)),
          Text(Fmt.compactMoney(total, currency),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in slices.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: s.color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(s.label, overflow: TextOverflow.ellipsis)),
              Text(total == 0 ? '' : Fmt.percent(s.value / total),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
      ],
    );
    return Semantics(
      label: 'Spending chart. $summary',
      excludeSemantics: true,
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 360) {
          return Column(children: [chart, const SizedBox(height: 12), legend]);
        }
        return Row(children: [
          chart,
          const SizedBox(width: 20),
          Expanded(child: legend),
        ]);
      }),
    );
  }
}

/// Grouped bars: income vs expenses per month.
class IncomeExpenseBars extends StatelessWidget {
  const IncomeExpenseBars(
      {super.key, required this.data, required this.currency, this.height = 200});
  final Map<String, PeriodSummary> data; // monthKey -> summary
  final String currency;
  final double height;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final maxY = entries.fold<double>(
        1, (m, e) => max(m, max(e.value.income, e.value.expense)));
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Income and expenses by month. ${entries.map((e) => '${Fmt.monthLabel(e.key)}: income ${Fmt.money(e.value.income, currency)}, expenses ${Fmt.money(e.value.expense, currency)}').join('. ')}',
      excludeSemantics: true,
      child: Column(children: [
        SizedBox(
          height: height,
          child: BarChart(BarChartData(
            maxY: maxY * 1.15,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: cs.outlineVariant.withValues(alpha: .4), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
                  '${rodIndex == 0 ? 'Income' : 'Expenses'}\n${Fmt.money(rod.toY, currency)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: maxY / 4,
                  getTitlesWidget: (v, meta) => Text(
                      Fmt.compactMoney(v, currency).replaceAll('.00', ''),
                      style: const TextStyle(fontSize: 10)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= entries.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(Fmt.shortMonth(entries[i].key),
                          style: const TextStyle(fontSize: 11)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < entries.length; i++)
                BarChartGroupData(x: i, barsSpace: 4, barRods: [
                  BarChartRodData(
                      toY: entries[i].value.income,
                      color: AppTheme.income,
                      width: 12,
                      borderRadius: BorderRadius.circular(4)),
                  BarChartRodData(
                      toY: entries[i].value.expense,
                      color: AppTheme.expense,
                      width: 12,
                      borderRadius: BorderRadius.circular(4)),
                ]),
            ],
          )),
        ),
        const SizedBox(height: 8),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Key(color: AppTheme.income, label: 'Income'),
          SizedBox(width: 16),
          _Key(color: AppTheme.expense, label: 'Expenses'),
        ]),
      ]),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]);
}
