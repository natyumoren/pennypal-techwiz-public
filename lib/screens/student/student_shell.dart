import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../state/finance_state.dart';
import 'budget_screen.dart';
import 'dashboard_screen.dart';
import 'goals_screen.dart';
import 'more_screen.dart';
import 'transaction_form_screen.dart';
import 'transactions_screen.dart';

/// Main student navigation. Bottom navigation bar on phones, navigation
/// rail on tablets and the web.
class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => StudentShellState();
}

class StudentShellState extends State<StudentShell> {
  int _index = 0;

  static const _destinations = [
    (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'History'),
    (Icons.pie_chart_outline_rounded, Icons.pie_chart_rounded, 'Budget'),
    (Icons.savings_outlined, Icons.savings_rounded, 'Goals'),
    (Icons.menu_rounded, Icons.menu_open_rounded, 'More'),
  ];

  void select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceState>();
    final wide =
        MediaQuery.sizeOf(context).width >= AppConfig.wideLayoutBreakpoint;
    final pages = [
      DashboardScreen(onNavigate: select),
      const TransactionsScreen(),
      const BudgetScreen(),
      const GoalsScreen(),
      const MoreScreen(),
    ];
    final body = finance.loading
        ? const Center(child: CircularProgressIndicator())
        : IndexedStack(index: _index, children: pages);

    final fab = (_index <= 1)
        ? FloatingActionButton.extended(
            onPressed: () => showAddTransactionSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
            tooltip: 'Add income or expense',
          )
        : null;

    if (wide) {
      return Scaffold(
        floatingActionButton: fab,
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: select,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Text('P',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                    icon: Icon(d.$1),
                    selectedIcon: Icon(d.$2),
                    label: Text(d.$3)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      floatingActionButton: fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: select,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
                icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
        ],
      ),
    );
  }
}

Future<void> showAddTransactionSheet(BuildContext context) async {
  final type = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.arrow_downward)),
          title: const Text('Add income'),
          subtitle: const Text('Allowance, scholarship, job, gift...'),
          onTap: () => Navigator.pop(ctx, 'income'),
        ),
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.arrow_upward)),
          title: const Text('Add expense'),
          subtitle: const Text('Food, transport, books, fun...'),
          onTap: () => Navigator.pop(ctx, 'expense'),
        ),
        const SizedBox(height: 12),
      ]),
    ),
  );
  if (type != null && context.mounted) {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => TransactionFormScreen(type: type)));
  }
}
