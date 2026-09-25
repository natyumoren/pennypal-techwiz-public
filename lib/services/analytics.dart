import '../core/formatters.dart';
import '../data/models/budget.dart';
import '../data/models/category.dart';
import '../data/models/savings_goal.dart';
import '../data/models/transaction.dart';

class PeriodSummary {
  final double income;
  final double expense;
  const PeriodSummary(this.income, this.expense);
  double get balance => income - expense;
  double get savingsRate => income <= 0 ? 0 : (income - expense) / income;
}

class Insight {
  final String title;
  final String message;
  final InsightLevel level;
  const Insight(this.title, this.message, this.level);
}

enum InsightLevel { good, info, warning }

/// Pure calculations used by the dashboard, budgets, reports and the
/// rule-based advisor. Kept free of Flutter so it is easy to unit test.
class Analytics {
  Analytics._();

  static List<TransactionRecord> inRange(
      List<TransactionRecord> txs, DateTime from, DateTime to) {
    final f = Fmt.isoDate(from), t = Fmt.isoDate(to);
    return txs
        .where((x) => x.date.compareTo(f) >= 0 && x.date.compareTo(t) <= 0)
        .toList();
  }

  static List<TransactionRecord> inMonth(
          List<TransactionRecord> txs, String month) =>
      txs.where((t) => t.month == month).toList();

  static PeriodSummary summarize(Iterable<TransactionRecord> txs) {
    var inc = 0.0, exp = 0.0;
    for (final t in txs) {
      if (t.isIncome) {
        inc += t.amount;
      } else {
        exp += t.amount;
      }
    }
    return PeriodSummary(inc, exp);
  }

  /// Expense totals per category id, largest first.
  static Map<String, double> spendByCategory(Iterable<TransactionRecord> txs) {
    final m = <String, double>{};
    for (final t in txs.where((t) => t.isExpense)) {
      final k = t.categoryId ?? 'cat-misc';
      m[k] = (m[k] ?? 0) + t.amount;
    }
    final sorted = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  /// Income/expense totals for the last [months] months (oldest first).
  static Map<String, PeriodSummary> monthlyTrend(
      List<TransactionRecord> txs, int months) {
    final now = DateTime.now();
    return {
      for (var i = months - 1; i >= 0; i--)
        Fmt.monthKey(DateTime(now.year, now.month - i, 1)): summarize(
            inMonth(txs, Fmt.monthKey(DateTime(now.year, now.month - i, 1)))),
    };
  }

  static List<BudgetUsage> budgetUsage(
      List<Budget> budgets, List<TransactionRecord> txs, String month) {
    final monthTx = inMonth(txs, month);
    final total = summarize(monthTx).expense;
    final byCat = spendByCategory(monthTx);
    return budgets
        .where((b) => b.month == month)
        .map((b) =>
            BudgetUsage(b, b.isOverall ? total : (byCat[b.categoryId] ?? 0)))
        .toList()
      ..sort((a, b) => a.budget.isOverall
          ? -1
          : b.budget.isOverall
              ? 1
              : b.ratio.compareTo(a.ratio));
  }

  /// Rule-based recommendations shown on the dashboard and used by the
  /// offline chatbot.
  static List<Insight> insights({
    required List<TransactionRecord> txs,
    required List<Budget> budgets,
    required List<SavingsGoal> goals,
    required Map<String, Category> categories,
    required String currency,
  }) {
    final out = <Insight>[];
    final now = DateTime.now();
    final month = Fmt.monthKey(now);
    final lastMonth = Fmt.monthKey(DateTime(now.year, now.month - 1, 1));
    final cur = summarize(inMonth(txs, month));
    final prev = summarize(inMonth(txs, lastMonth));
    String money(double v) => Fmt.money(v, currency);

    if (txs.isEmpty) {
      return const [
        Insight('Start tracking', 'Add your first income and expense to unlock personalised tips.', InsightLevel.info)
      ];
    }

    for (final u in budgetUsage(budgets, txs, month)) {
      final name = u.budget.isOverall
          ? 'your monthly budget'
          : 'your ${categories[u.budget.categoryId]?.name ?? 'category'} budget';
      if (u.isOver) {
        out.add(Insight('Over budget',
            'You are ${money(-u.remaining)} over $name. Pause optional spending in this area for the rest of the month.',
            InsightLevel.warning));
      } else if (u.isNearLimit) {
        out.add(Insight('Close to the limit',
            'You have used ${Fmt.percent(u.ratio)} of $name – ${money(u.remaining)} left.',
            InsightLevel.warning));
      }
    }

    if (cur.income > 0 && cur.expense > cur.income) {
      out.add(Insight('Spending more than you earn',
          'This month expenses (${money(cur.expense)}) are higher than income (${money(cur.income)}).',
          InsightLevel.warning));
    } else if (cur.income > 0 && cur.savingsRate >= 0.2) {
      out.add(Insight('Great saving!',
          'You kept ${Fmt.percent(cur.savingsRate)} of this month\'s income. Consider moving some into a savings goal.',
          InsightLevel.good));
    }

    final byCat = spendByCategory(inMonth(txs, month));
    if (byCat.isNotEmpty && cur.expense > 0) {
      final top = byCat.entries.first;
      final share = top.value / cur.expense;
      if (share >= 0.35) {
        out.add(Insight('Biggest category',
            '${categories[top.key]?.name ?? 'One category'} is ${Fmt.percent(share)} of your spending this month (${money(top.value)}).',
            InsightLevel.info));
      }
    }

    if (prev.expense > 0) {
      // Compare against the same point of last month.
      final dayRatio = now.day / DateTime(now.year, now.month + 1, 0).day;
      final expectedSoFar = prev.expense * dayRatio;
      if (expectedSoFar > 0 && cur.expense > expectedSoFar * 1.2) {
        out.add(Insight('Spending faster than last month',
            'You have spent ${money(cur.expense)} so far – about ${Fmt.percent(cur.expense / expectedSoFar - 1)} more than at this point last month.',
            InsightLevel.warning));
      }
    }

    if (budgets.where((b) => b.month == month).isEmpty) {
      out.add(const Insight('Set a budget',
          'Create a monthly budget to get alerts before you overspend.',
          InsightLevel.info));
    }

    for (final g in goals.where((g) => !g.isCompleted)) {
      if (g.isBehindSchedule) {
        out.add(Insight('"${g.name}" is behind schedule',
            'Save about ${money(g.requiredMonthly)} a month to reach it by ${Fmt.prettyDate(g.targetDate)}.',
            InsightLevel.info));
        break;
      }
    }

    if (out.isEmpty) {
      out.add(const Insight('On track',
          'Your spending is within your plan. Keep recording every expense!',
          InsightLevel.good));
    }
    return out;
  }
}
