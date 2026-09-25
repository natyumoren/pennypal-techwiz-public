import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models/misc.dart';
import '../../data/repositories/engagement_repository.dart';
import '../../services/analytics.dart';
import '../../services/report_service.dart';
import '../../state/finance_state.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';

/// Spending reports: summary, category breakdown, monthly trend, CSV export.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTimeRange _range = _preset('this');
  String _presetKey = 'this';
  List<ReportRecord> _history = [];

  static DateTimeRange _preset(String p) {
    final now = DateTime.now();
    return switch (p) {
      'last' => DateTimeRange(
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 0)),
      '3m' => DateTimeRange(start: DateTime(now.year, now.month - 2, 1), end: now),
      'year' => DateTimeRange(start: DateTime(now.year, 1, 1), end: now),
      _ => DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    };
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final f = context.read<FinanceState>();
    final h = await context.read<EngagementRepository>().reports(f.userId);
    if (mounted) setState(() => _history = h);
  }

  Future<void> _custom() async {
    final r = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: _range);
    if (r != null) {
      setState(() {
        _range = r;
        _presetKey = 'custom';
      });
    }
  }

  Future<void> _export(List txs) async {
    final f = context.read<FinanceState>();
    final repo = context.read<EngagementRepository>();
    final csv = ReportService.buildCsv(
      txs: txs.cast(),
      categories: f.categoryById,
      from: _range.start,
      to: _range.end,
      currency: f.currency,
    );
    final name =
        'pennypal_report_${Fmt.isoDate(_range.start)}_${Fmt.isoDate(_range.end)}.csv';
    try {
      await ReportService.share(csv, name);
      await repo.saveReport(ReportRecord(
        id: repo.newId(),
        userId: f.userId,
        reportType: _presetKey == 'custom' ? 'custom' : 'monthly',
        dateRange: '${Fmt.isoDate(_range.start)}..${Fmt.isoDate(_range.end)}',
        generatedOn: Fmt.nowIso(),
        fileUrl: name,
      ));
      await _loadHistory();
    } catch (e) {
      if (mounted) showSnack(context, 'Export failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceState>();
    final cur = f.currency;
    final txs = Analytics.inRange(f.transactions, _range.start, _range.end);
    final s = Analytics.summarize(txs);
    final byCat = Analytics.spendByCategory(txs);
    final days = _range.end.difference(_range.start).inDays + 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending reports'),
        actions: [
          IconButton(
            tooltip: 'Export CSV report',
            onPressed: txs.isEmpty ? null : () => _export(txs),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: ResponsiveBody(
        maxWidth: 900,
        child: ListView(padding: screenPadding, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in const [
              ('this', 'This month'),
              ('last', 'Last month'),
              ('3m', 'Last 3 months'),
              ('year', 'This year'),
            ])
              ChoiceChip(
                label: Text(p.$2),
                selected: _presetKey == p.$1,
                onSelected: (_) => setState(() {
                  _presetKey = p.$1;
                  _range = _preset(p.$1);
                }),
              ),
            ChoiceChip(
              avatar: const Icon(Icons.date_range, size: 18),
              label: Text(_presetKey == 'custom'
                  ? '${Fmt.shortDate(_range.start)} – ${Fmt.shortDate(_range.end)}'
                  : 'Custom'),
              selected: _presetKey == 'custom',
              onSelected: (_) => _custom(),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
              '${Fmt.prettyDate(Fmt.isoDate(_range.start))} – ${Fmt.prettyDate(Fmt.isoDate(_range.end))}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              StatTile(label: 'Income', value: Fmt.money(s.income, cur), icon: Icons.south_west, color: AppTheme.income),
              StatTile(label: 'Expenses', value: Fmt.money(s.expense, cur), icon: Icons.north_east, color: AppTheme.expense),
              StatTile(label: 'Net', value: Fmt.money(s.balance, cur), icon: Icons.balance, color: s.balance < 0 ? AppTheme.expense : Colors.blue),
              StatTile(label: 'Daily average', value: Fmt.money(s.expense / days, cur), icon: Icons.today, color: Colors.purple, caption: 'spent per day'),
            ],
          ),
          const SectionHeader('Expenses by category'),
          if (byCat.isEmpty)
            const Card(
                child: EmptyState(
                    icon: Icons.donut_large,
                    title: 'No expenses in this period',
                    message: 'Choose another period or add expenses.'))
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  DonutChart(currency: cur, slices: [
                    for (final e in byCat.entries)
                      ChartSlice(f.categoryById[e.key]?.name ?? 'Other', e.value,
                          f.categoryById[e.key]?.color ?? Colors.grey),
                  ]),
                  const Divider(height: 28),
                  for (final e in byCat.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        if (f.categoryById[e.key] != null)
                          CategoryAvatar(f.categoryById[e.key]!, radius: 14),
                        const SizedBox(width: 10),
                        Expanded(child: Text(f.categoryById[e.key]?.name ?? 'Other')),
                        Text(Fmt.money(e.value, cur),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        SizedBox(
                            width: 52,
                            child: Text(Fmt.percent(e.value / s.expense),
                                textAlign: TextAlign.right)),
                      ]),
                    ),
                ]),
              ),
            ),
          const SectionHeader('Last 6 months'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
              child: IncomeExpenseBars(
                  data: Analytics.monthlyTrend(f.transactions, 6), currency: cur),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: txs.isEmpty ? null : () => _export(txs),
            icon: const Icon(Icons.download),
            label: const Text('Generate & export report (CSV)'),
          ),
          if (_history.isNotEmpty) ...[
            const SectionHeader('Generated reports'),
            Card(
              child: Column(children: [
                for (final r in _history.take(5))
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(r.dateRange.replaceAll('..', ' → ')),
                    subtitle: Text('Generated ${Fmt.timeAgo(r.generatedOn)}'),
                    trailing: Text(r.reportType),
                  ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}
