import 'package:flutter/foundation.dart' hide Category;

import '../core/formatters.dart';
import '../data/models/budget.dart';
import '../data/models/category.dart';
import '../data/models/misc.dart';
import '../data/models/savings_goal.dart';
import '../data/models/transaction.dart';
import '../data/repositories/engagement_repository.dart';
import '../data/repositories/finance_repository.dart';
import '../services/analytics.dart';
import '../services/budget_monitor.dart';
import '../services/chatbot_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';

/// All financial data of the logged-in student, kept in memory for fast,
/// smooth screens and persisted through the repositories.
class FinanceState extends ChangeNotifier {
  FinanceState({
    required this.userId,
    required FinanceRepository finance,
    required EngagementRepository engagement,
    required this.currencyOf,
    required this.notificationsEnabled,
    SyncService? sync,
  })  : _finance = finance,
        _engagement = engagement,
        _sync = sync;

  final String userId;
  final FinanceRepository _finance;
  final EngagementRepository _engagement;
  final SyncService? _sync;
  final String Function() currencyOf;
  final bool Function() notificationsEnabled;

  bool loading = true;
  List<Category> categories = [];
  Map<String, Category> categoryById = {};
  List<TransactionRecord> transactions = [];
  List<Budget> budgets = [];
  List<SavingsGoal> goals = [];
  List<AppNotification> notifications = [];

  String get currency => currencyOf();
  String get currentMonth => Fmt.monthKey(DateTime.now());
  int get unreadCount => notifications.where((n) => !n.read).length;
  List<SavingsGoal> get activeGoals => goals.where((g) => !g.isCompleted).toList();
  List<SavingsGoal> get completedGoals => goals.where((g) => g.isCompleted).toList();

  PeriodSummary get allTime => Analytics.summarize(transactions);
  PeriodSummary get thisMonth =>
      Analytics.summarize(Analytics.inMonth(transactions, currentMonth));

  Budget? overallBudget(String month) {
    for (final b in budgets) {
      if (b.month == month && b.isOverall) return b;
    }
    return null;
  }

  List<BudgetUsage> usageFor(String month) =>
      Analytics.budgetUsage(budgets, transactions, month);

  /// New records get their id on the device so they can be saved offline.
  String newId() => _finance.newId();

  Category categoryOf(TransactionRecord t) =>
      categoryById[t.categoryId] ??
      const Category(id: 'cat-misc', name: 'Miscellaneous');

  Future<void> load() async {
    loading = true;
    notifyListeners();
    categories = await _finance.categories(userId);
    categoryById = {for (final c in categories) c.id: c};
    transactions = await _finance.transactions(userId);
    budgets = await _finance.budgets(userId);
    goals = await _finance.goals(userId);
    notifications = await _engagement.notifications(userId);
    loading = false;
    notifyListeners();
  }

  Future<void> _afterWrite() async {
    notifyListeners();
    await _sync?.changed();
  }

  Future<void> _notify(String title, String message, String type) async {
    final n = await _engagement.addNotification(userId, title, message, type);
    notifications = [n, ...notifications];
    if (notificationsEnabled()) await LocalNotifier.show(title, message);
  }

  // --------------------------------------------------------- transactions

  /// Saves (adds or edits) a transaction and returns any budget alerts the
  /// change triggered, so the UI can show them instantly.
  Future<List<BudgetAlert>> saveTransaction(TransactionRecord t) async {
    final before = transactions;
    await _finance.saveTransaction(t);
    transactions = [
      t,
      ...transactions.where((x) => x.id != t.id),
    ]..sort((a, b) {
        final d = b.date.compareTo(a.date);
        return d != 0 ? d : b.createdAt.compareTo(a.createdAt);
      });

    final alerts = <BudgetAlert>[];
    if (t.isExpense) {
      alerts.addAll(BudgetMonitor.check(
        budgets: budgets,
        before: before,
        after: transactions,
        month: t.month,
        categories: categoryById,
        currency: currency,
      ));
      for (final a in alerts) {
        await _notify(a.title, a.message, 'budget');
      }
    }
    await _afterWrite();
    return alerts;
  }

  Future<void> deleteTransaction(TransactionRecord t) async {
    await _finance.deleteTransaction(t);
    transactions = transactions.where((x) => x.id != t.id).toList();
    await _afterWrite();
  }

  // --------------------------------------------------------------- budgets
  Future<List<BudgetAlert>> saveBudget({
    String? id,
    required String month,
    String? categoryId,
    required double limit,
    required int threshold,
  }) async {
    final b = await _finance.saveBudget(
        id: id,
        userId: userId,
        month: month,
        categoryId: categoryId,
        limit: limit,
        threshold: threshold);
    budgets = [b, ...budgets.where((x) => x.id != b.id)];
    await _afterWrite();
    // Tell the student straight away if the new limit is already reached.
    final u = usageFor(month).where((u) => u.budget.id == b.id).firstOrNull;
    if (u != null && (u.isOver || u.isNearLimit)) {
      final label = b.isOverall
          ? 'monthly budget'
          : '${categoryById[b.categoryId]?.name} budget';
      return [
        BudgetAlert(
            u.isOver ? 'Already over budget' : 'Close to the limit',
            'You have already used ${Fmt.percent(u.ratio)} of this $label.',
            exceeded: u.isOver)
      ];
    }
    return const [];
  }

  Future<void> deleteBudget(Budget b) async {
    await _finance.deleteBudget(b);
    budgets = budgets.where((x) => x.id != b.id).toList();
    await _afterWrite();
  }

  /// Copies last month's budgets into [month] (skipping existing ones).
  Future<int> copyBudgets(String fromMonth, String toMonth) async {
    var n = 0;
    for (final b in budgets.where((b) => b.month == fromMonth).toList()) {
      final exists = budgets.any(
          (x) => x.month == toMonth && x.categoryId == b.categoryId);
      if (exists) continue;
      await saveBudget(
          month: toMonth,
          categoryId: b.categoryId,
          limit: b.limitAmount,
          threshold: b.alertThreshold);
      n++;
    }
    return n;
  }

  // ----------------------------------------------------------------- goals
  Future<void> saveGoal(SavingsGoal g) async {
    final updated = _applyMilestones(g);
    await _finance.saveGoal(updated);
    goals = [updated, ...goals.where((x) => x.id != g.id)];
    await _afterWrite();
  }

  /// Adds [amount] to a goal; optionally records it as a Savings expense.
  Future<SavingsGoal> contribute(SavingsGoal g, double amount,
      {bool recordAsExpense = false}) async {
    var updated = g.copyWith(currentAmount: g.currentAmount + amount);
    updated = _applyMilestones(updated);
    await _finance.saveGoal(updated);
    goals = [updated, ...goals.where((x) => x.id != g.id)];
    if (recordAsExpense) {
      await saveTransaction(TransactionRecord(
        id: _finance.newId(),
        userId: userId,
        type: 'expense',
        amount: amount,
        categoryId: 'cat-savings',
        description: 'Saved for "${g.name}"',
        date: Fmt.isoDate(DateTime.now()),
        paymentMode: 'Transfer',
        createdAt: Fmt.nowIso(),
      ));
    }
    for (final m in updated.milestones) {
      if (!g.milestones.contains(m)) {
        await _notify(
          m == 100 ? 'Goal completed! 🎉' : 'Milestone reached: $m%',
          m == 100
              ? 'You reached your "${g.name}" goal. It has been moved to your goal history.'
              : 'You are $m% of the way to "${g.name}". Keep going!',
          'goal',
        );
      }
    }
    await _afterWrite();
    return updated;
  }

  /// Manually marks / un-marks a milestone.
  Future<void> toggleMilestone(SavingsGoal g, int step) async {
    final ms = [...g.milestones];
    ms.contains(step) ? ms.remove(step) : ms.add(step);
    ms.sort();
    final updated = g.copyWith(milestones: ms);
    await _finance.saveGoal(updated);
    goals = [updated, ...goals.where((x) => x.id != g.id)];
    await _afterWrite();
  }

  /// Reached milestones are added automatically; reaching 100% completes
  /// the goal and archives it into the goal history.
  SavingsGoal _applyMilestones(SavingsGoal g) {
    final pct = g.progress * 100;
    final ms = {...g.milestones};
    for (final step in SavingsGoal.milestoneSteps) {
      if (pct >= step) ms.add(step);
    }
    final list = ms.toList()..sort();
    if (pct >= 100 && !g.isCompleted) {
      return g.copyWith(
          milestones: list, status: 'completed', completedAt: Fmt.nowIso());
    }
    if (pct < 100 && g.isCompleted) {
      // Target raised after completion: re-open the goal.
      return SavingsGoal.fromMap({
        ...g.copyWith(milestones: list).toMap(),
        'Status': 'active',
        'CompletedAt': null,
      });
    }
    return g.copyWith(milestones: list);
  }

  Future<void> deleteGoal(SavingsGoal g) async {
    await _finance.deleteGoal(g);
    goals = goals.where((x) => x.id != g.id).toList();
    await _afterWrite();
  }

  // ------------------------------------------------------------ categories
  Future<void> addCategory(String name, String icon) async {
    final c = await _finance.addCategory(userId, name, icon);
    categories = [...categories, c];
    categoryById[c.id] = c;
    await _afterWrite();
  }

  Future<void> deleteCategory(Category c) async {
    await _finance.deleteCategory(userId, c.id);
    await load();
    await _sync?.changed();
  }

  // --------------------------------------------------------- notifications
  Future<void> markAllRead() async {
    await _engagement.markAllRead(userId);
    notifications = await _engagement.notifications(userId);
    notifyListeners();
  }

  Future<void> clearNotifications() async {
    await _engagement.clearNotifications(userId);
    notifications = [];
    notifyListeners();
  }

  Future<void> refreshNotifications() async {
    notifications = await _engagement.notifications(userId);
    notifyListeners();
  }

  // --------------------------------------------------------------- chatbot
  ChatContext chatContext() {
    final month = currentMonth;
    final s = thisMonth;
    final byCat = Analytics.spendByCategory(Analytics.inMonth(transactions, month));
    return ChatContext(
      currency: currency,
      monthIncome: s.income,
      monthExpense: s.expense,
      topCategories: {
        for (final e in byCat.entries.take(5))
          categoryById[e.key]?.name ?? 'Other': e.value
      },
      budgetLines: [
        for (final u in usageFor(month))
          '${u.budget.isOverall ? 'Overall' : categoryById[u.budget.categoryId]?.name}: '
              '${u.spent.toStringAsFixed(2)} of ${u.budget.limitAmount.toStringAsFixed(2)} (${Fmt.percent(u.ratio)})'
      ],
      goalLines: [
        for (final g in activeGoals)
          '${g.name}: ${g.currentAmount.toStringAsFixed(0)} of ${g.targetAmount.toStringAsFixed(0)}, '
              '${g.monthlyContribution.toStringAsFixed(0)}/month, target ${g.targetDate}'
      ],
    );
  }

  List<Insight> insights() => Analytics.insights(
        txs: transactions,
        budgets: budgets,
        goals: goals,
        categories: categoryById,
        currency: currency,
      );
}

