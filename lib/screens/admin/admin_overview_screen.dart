import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/repositories/admin_repository.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';

class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  late Future<PlatformStats> _stats = context.read<AdminRepository>().stats();

  static const _palette = [
    Color(0xFFEF6C00), Color(0xFF1E88E5), Color(0xFF6A1B9A), Color(0xFFD81B60),
    Color(0xFF00897B), Color(0xFF5D4037), Color(0xFF2E7D32), Color(0xFF546E7A),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin overview'),
        actions: [
          IconButton(
              tooltip: 'Refresh',
              onPressed: () => setState(
                  () => _stats = context.read<AdminRepository>().stats()),
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<PlatformStats>(
        future: _stats,
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load statistics',
                message: '${snap.error}');
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final s = snap.data!;
          final cols = MediaQuery.sizeOf(context).width > 900 ? 4 : 2;
          return ResponsiveBody(
            child: ListView(padding: screenPadding, children: [
              GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  StatTile(label: 'Students', value: '${s.students}', caption: '${s.activeStudents} active accounts', icon: Icons.people, color: Colors.blue),
                  StatTile(label: 'New (30 days)', value: '${s.newStudents30d}', caption: '${s.activeLast7d} logged in this week', icon: Icons.person_add, color: Colors.teal),
                  StatTile(label: 'Transactions', value: '${s.transactions}', caption: 'recorded by all students', icon: Icons.receipt_long, color: Colors.indigo),
                  StatTile(label: 'Avg. rating', value: s.averageRating == 0 ? '–' : s.averageRating.toStringAsFixed(1), caption: 'from feedback', icon: Icons.star, color: Colors.amber.shade800),
                  StatTile(label: 'Income tracked', value: Fmt.compactMoney(s.totalIncome), icon: Icons.south_west, color: AppTheme.income),
                  StatTile(label: 'Expenses tracked', value: Fmt.compactMoney(s.totalExpense), icon: Icons.north_east, color: AppTheme.expense),
                  StatTile(label: 'Savings goals', value: '${s.goals}', caption: '${s.completedGoals} completed', icon: Icons.savings, color: Colors.green),
                  StatTile(label: 'Open support', value: '${s.openQueries}', caption: 'queries awaiting reply', icon: Icons.support_agent, color: s.openQueries > 0 ? AppTheme.warning : Colors.grey),
                ],
              ),
              const SectionHeader('Spending by category (all students)'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: s.spendByCategory.isEmpty
                      ? const EmptyState(icon: Icons.donut_large, title: 'No data yet', message: 'Statistics appear once students add expenses.')
                      : DonutChart(currency: 'USD', slices: [
                          for (final (i, e) in s.spendByCategory.entries.indexed)
                            ChartSlice(e.key, e.value, _palette[i % _palette.length]),
                        ]),
                ),
              ),
              const SectionHeader('Activity – transactions per month'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: s.transactionsByMonth.isEmpty
                      ? const Text('No activity yet.')
                      : Column(children: [
                          for (final e in s.transactionsByMonth.entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(children: [
                                SizedBox(width: 90, child: Text(Fmt.monthLabel(e.key).split(' ').first)),
                                Expanded(
                                  child: UsageBar(
                                    ratio: e.value /
                                        s.transactionsByMonth.values.reduce((a, b) => a > b ? a : b),
                                    threshold: 101,
                                  ),
                                ),
                                SizedBox(width: 44, child: Text('${e.value}', textAlign: TextAlign.right)),
                              ]),
                            ),
                        ]),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}
