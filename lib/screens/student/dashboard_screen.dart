import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../services/analytics.dart';
import '../../services/sync_service.dart';
import '../../state/finance_state.dart';
import '../../state/session_state.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/transaction_tile.dart';
import 'chatbot_screen.dart';
import 'feedback_screen.dart';
import 'learning_screen.dart';
import 'notifications_screen.dart';
import 'reports_screen.dart';
import 'student_shell.dart';
import 'support_screen.dart';
import 'transaction_form_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  /// Switches the bottom-navigation tab (1 = history, 2 = budget, 3 = goals).
  final void Function(int) onNavigate;

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceState>();
    final session = context.watch<SessionState>();
    final cur = f.currency;
    final month = f.thisMonth;
    final balance = f.allTime.balance;
    final overall = f.usageFor(f.currentMonth).where((u) => u.budget.isOverall);
    final budgetStatus = overall.isEmpty ? null : overall.first;

    void push(Widget w) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hi, ${session.user?.firstName ?? 'there'} 👋'),
          Text(Fmt.monthLabel(f.currentMonth),
              style: Theme.of(context).textTheme.bodySmall),
        ]),
        actions: [
          const _SyncIndicator(),
          IconButton(
            tooltip: 'Notifications (${f.unreadCount} unread)',
            onPressed: () => push(const NotificationsScreen()),
            icon: Badge(
              isLabelVisible: f.unreadCount > 0,
              label: Text('${f.unreadCount}'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: f.load,
        child: ResponsiveBody(
          child: ListView(
            padding: screenPadding,
            children: [
              _BalanceCard(
                balance: balance,
                currency: cur,
                income: month.income,
                expense: month.expense,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 700 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: cols == 4 ? 2.1 : 1.45,
                  children: [
                    StatTile(
                        label: 'Total income',
                        value: Fmt.money(f.allTime.income, cur),
                        caption: '${Fmt.money(month.income, cur)} this month',
                        icon: Icons.arrow_downward_rounded,
                        color: AppTheme.income),
                    StatTile(
                        label: 'Total expenses',
                        value: Fmt.money(f.allTime.expense, cur),
                        caption: '${Fmt.money(month.expense, cur)} this month',
                        icon: Icons.arrow_upward_rounded,
                        color: AppTheme.expense),
                    StatTile(
                        label: 'Saved in goals',
                        value: Fmt.money(
                            f.goals.fold(0.0, (a, g) => a + g.currentAmount),
                            cur),
                        caption: '${f.activeGoals.length} active goal${f.activeGoals.length == 1 ? '' : 's'}',
                        icon: Icons.savings_outlined,
                        color: Colors.blue),
                    StatTile(
                        label: 'Budget status',
                        value: budgetStatus == null
                            ? 'Not set'
                            : '${Fmt.percent(budgetStatus.ratio)} used',
                        caption: budgetStatus == null
                            ? 'Tap Budget to create one'
                            : budgetStatus.isOver
                                ? '${Fmt.money(-budgetStatus.remaining, cur)} over'
                                : '${Fmt.money(budgetStatus.remaining, cur)} left',
                        icon: Icons.pie_chart_outline,
                        color: budgetStatus == null
                            ? Colors.grey
                            : AppTheme.usageColor(budgetStatus.ratio,
                                thresholdPercent:
                                    budgetStatus.budget.alertThreshold)),
                  ],
                );
              }),
              const SectionHeader('Quick actions'),
              _QuickActions(actions: [
                _Action(Icons.add_card, 'Add Income', AppTheme.income,
                    () => push(const TransactionFormScreen(type: 'income'))),
                _Action(Icons.shopping_cart_checkout, 'Add Expense',
                    AppTheme.expense,
                    () => push(const TransactionFormScreen(type: 'expense'))),
                _Action(Icons.pie_chart_rounded, 'Budget', Colors.indigo,
                    () => onNavigate(2)),
                _Action(Icons.receipt_long, 'History', Colors.teal,
                    () => onNavigate(1)),
                _Action(Icons.savings, 'Goals', Colors.green.shade700,
                    () => onNavigate(3)),
                _Action(Icons.insights, 'Reports', Colors.orange.shade800,
                    () => push(const ReportsScreen())),
                _Action(Icons.menu_book, 'Learning', Colors.purple,
                    () => push(const LearningScreen())),
                _Action(Icons.smart_toy_outlined, 'Ask Penny', Colors.blue,
                    () => push(const ChatbotScreen())),
                _Action(Icons.rate_review_outlined, 'Feedback', Colors.pink,
                    () => push(const FeedbackScreen())),
                _Action(Icons.support_agent, 'Support', Colors.brown,
                    () => push(const SupportScreen())),
              ]),
              const SectionHeader('Budget progress'),
              _BudgetSummary(onOpen: () => onNavigate(2)),
              const SectionHeader('Tips for you'),
              _Insights(insights: f.insights()),
              const SectionHeader('Where your money went this month'),
              const _SpendingChart(),
              SectionHeader('Recent transactions',
                  action: f.transactions.isEmpty
                      ? null
                      : TextButton(
                          onPressed: () => onNavigate(1),
                          child: const Text('See all'))),
              if (f.transactions.isEmpty)
                Card(
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No income or expenses yet',
                    message:
                        'Add your first income (like your allowance) and your daily expenses to see your summary here.',
                    action: FilledButton.icon(
                        onPressed: () => showAddTransactionSheet(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add transaction')),
                  ),
                )
              else
                Card(
                  child: Column(children: [
                    for (final t in f.transactions.take(5))
                      TransactionTile(transaction: t),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard(
      {required this.balance,
      required this.currency,
      required this.income,
      required this.expense});
  final double balance, income, expense;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E8E4E), Color(0xFF3BB273)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Available balance',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(Fmt.money(balance, currency),
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _mini('This month in', Fmt.money(income, currency),
                    Icons.south_west)),
            Expanded(
                child: _mini('This month out', Fmt.money(expense, currency),
                    Icons.north_east)),
          ]),
        ]),
      ),
    );
  }

  Widget _mini(String label, String value, IconData icon) => Row(children: [
        CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white24,
            child: Icon(icon, color: Colors.white, size: 18)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Colors.white))),
          ]),
        ),
      ]);
}

class _Action {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Action(this.icon, this.label, this.color, this.onTap);
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions});
  final List<_Action> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 700 ? 10 : (c.maxWidth > 420 ? 5 : 4);
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.82,
        children: [
          for (final a in actions)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: a.onTap,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: a.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16)),
                  child: Icon(a.icon, color: a.color),
                ),
                const SizedBox(height: 6),
                Text(a.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 12)),
              ]),
            ),
        ],
      );
    });
  }
}

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceState>();
    final usage = f.usageFor(f.currentMonth);
    if (usage.isEmpty) {
      return Card(
        child: EmptyState(
          icon: Icons.pie_chart_outline,
          title: 'No budget for this month',
          message:
              'Set a monthly budget and category limits to get alerts before you overspend.',
          action: OutlinedButton(
              onPressed: onOpen, child: const Text('Create a budget')),
        ),
      );
    }
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            for (final u in usage.take(4)) ...[
              Row(children: [
                Expanded(
                  child: Text(
                      u.budget.isOverall
                          ? 'Overall budget'
                          : f.categoryById[u.budget.categoryId]?.name ??
                              'Category',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text(
                    '${Fmt.money(u.spent, f.currency)} / ${Fmt.money(u.budget.limitAmount, f.currency)}'),
              ]),
              const SizedBox(height: 6),
              UsageBar(ratio: u.ratio, threshold: u.budget.alertThreshold),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  u.isOver
                      ? 'Over by ${Fmt.money(-u.remaining, f.currency)}'
                      : '${Fmt.money(u.remaining, f.currency)} left',
                  style: TextStyle(
                      fontSize: 12,
                      color: u.isOver
                          ? AppTheme.expense
                          : Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  const _Insights({required this.insights});
  final List<Insight> insights;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(children: [
        for (final i in insights.take(4))
          ListTile(
            leading: Icon(
              switch (i.level) {
                InsightLevel.good => Icons.emoji_events_outlined,
                InsightLevel.warning => Icons.warning_amber_rounded,
                InsightLevel.info => Icons.lightbulb_outline,
              },
              color: switch (i.level) {
                InsightLevel.good => AppTheme.income,
                InsightLevel.warning => AppTheme.warning,
                InsightLevel.info => Colors.blue,
              },
            ),
            title: Text(i.title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(i.message),
          ),
      ]),
    );
  }
}

class _SpendingChart extends StatelessWidget {
  const _SpendingChart();

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceState>();
    final byCat = Analytics.spendByCategory(
        Analytics.inMonth(f.transactions, f.currentMonth));
    if (byCat.isEmpty) {
      return const Card(
        child: EmptyState(
          icon: Icons.donut_large,
          title: 'No expenses this month',
          message: 'Your spending by category will appear here.',
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DonutChart(
          currency: f.currency,
          slices: [
            for (final e in byCat.entries)
              ChartSlice(f.categoryById[e.key]?.name ?? 'Other', e.value,
                  f.categoryById[e.key]?.color ?? Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final (icon, tip) = switch (sync.status) {
      SyncStatus.localOnly => (
          Icons.phone_android,
          'Saved on this device (cloud sync not configured)'
        ),
      SyncStatus.syncing => (Icons.sync, 'Syncing...'),
      SyncStatus.offline => (
          Icons.cloud_off_outlined,
          'Offline – ${sync.pending} change(s) will sync when you reconnect'
        ),
      SyncStatus.error => (Icons.sync_problem, 'Sync failed – will retry'),
      SyncStatus.idle => sync.pending > 0
          ? (Icons.cloud_upload_outlined, '${sync.pending} change(s) waiting to sync')
          : (Icons.cloud_done_outlined, 'All changes synced'),
    };
    return IconButton(
      tooltip: tip,
      icon: Icon(icon),
      onPressed: () {
        showSnack(context, tip);
        sync.syncNow();
      },
    );
  }
}
