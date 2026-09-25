import '../core/formatters.dart';
import '../data/models/budget.dart';
import '../data/models/category.dart';
import '../data/models/transaction.dart';
import 'analytics.dart';

class BudgetAlert {
  final String title;
  final String message;
  final bool exceeded;
  const BudgetAlert(this.title, this.message, {this.exceeded = false});
}

/// Real-time spending alerts (SRS 1.5 "Real-Time Processing").
///
/// Compares budget usage before and after a change and reports only the
/// thresholds that were *crossed* by this change, so the student is alerted
/// once instead of on every later expense.
class BudgetMonitor {
  BudgetMonitor._();

  static List<BudgetAlert> check({
    required List<Budget> budgets,
    required List<TransactionRecord> before,
    required List<TransactionRecord> after,
    required String month,
    required Map<String, Category> categories,
    required String currency,
  }) {
    final prev = {
      for (final u in Analytics.budgetUsage(budgets, before, month)) u.budget.id: u
    };
    final alerts = <BudgetAlert>[];
    for (final now in Analytics.budgetUsage(budgets, after, month)) {
      final was = prev[now.budget.id];
      final wasRatio = was?.ratio ?? 0;
      final label = now.budget.isOverall
          ? 'monthly budget'
          : '${categories[now.budget.categoryId]?.name ?? 'category'} budget';
      final threshold = now.budget.alertThreshold / 100;
      if (now.ratio > 1 && wasRatio <= 1) {
        alerts.add(BudgetAlert(
          'Budget exceeded',
          'You have gone over your $label for ${Fmt.monthLabel(month)} by '
              '${Fmt.money(now.spent - now.budget.limitAmount, currency)}.',
          exceeded: true,
        ));
      } else if (now.ratio >= threshold && wasRatio < threshold && now.ratio <= 1) {
        alerts.add(BudgetAlert(
          'Approaching your limit',
          'You have used ${Fmt.percent(now.ratio)} of your $label. '
              '${Fmt.money(now.remaining, currency)} left for ${Fmt.monthLabel(month)}.',
        ));
      }
    }
    return alerts;
  }
}
