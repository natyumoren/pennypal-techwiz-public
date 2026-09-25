import 'package:flutter_test/flutter_test.dart';
import 'package:pennypal/core/formatters.dart';
import 'package:pennypal/data/models/budget.dart';
import 'package:pennypal/data/models/category.dart';
import 'package:pennypal/data/models/savings_goal.dart';
import 'package:pennypal/data/models/transaction.dart';
import 'package:pennypal/services/analytics.dart';
import 'package:pennypal/services/budget_monitor.dart';
import 'package:pennypal/services/categorizer.dart';
import 'package:pennypal/services/chatbot_service.dart';

const cats = [
  Category(id: 'cat-food', name: 'Food', icon: 'food', isDefault: true),
  Category(id: 'cat-transport', name: 'Transport', icon: 'transport', isDefault: true),
  Category(id: 'cat-education', name: 'Education', icon: 'education', isDefault: true),
  Category(id: 'cat-entertainment', name: 'Entertainment', icon: 'entertainment', isDefault: true),
  Category(id: 'cat-misc', name: 'Miscellaneous', icon: 'misc', isDefault: true),
];

final month = Fmt.monthKey(DateTime.now());
final today = Fmt.isoDate(DateTime.now());

TransactionRecord tx(String id, String type, double amount,
        {String? cat, String? desc, String? date}) =>
    TransactionRecord(
        id: id,
        userId: 'u',
        type: type,
        amount: amount,
        categoryId: cat,
        description: desc,
        date: date ?? today,
        createdAt: Fmt.nowIso());

Budget budget(String id, double limit, {String? cat, int threshold = 80}) =>
    Budget(
        id: id,
        userId: 'u',
        month: month,
        categoryId: cat,
        limitAmount: limit,
        alertThreshold: threshold,
        createdAt: Fmt.nowIso());

void main() {
  group('ExpenseCategorizer', () {
    test('keyword match', () {
      expect(ExpenseCategorizer.suggest('Uber to campus', cats)?.category.id, 'cat-transport');
      expect(ExpenseCategorizer.suggest('Netflix', cats)?.category.id, 'cat-entertainment');
      expect(ExpenseCategorizer.suggest('Chemistry textbook', cats)?.category.id, 'cat-education');
    });

    test('fuzzy match tolerates typos', () {
      expect(ExpenseCategorizer.suggest('piza night', cats)?.category.id, 'cat-food');
    });

    test('learns from history', () {
      final history = [tx('1', 'expense', 5, cat: 'cat-misc', desc: 'Weekly club dues')];
      expect(
          ExpenseCategorizer.suggest('weekly club dues', cats, history: history)?.category.id,
          'cat-misc');
    });

    test('returns null for gibberish or short text', () {
      expect(ExpenseCategorizer.suggest('zzqx', cats), isNull);
      expect(ExpenseCategorizer.suggest('a', cats), isNull);
    });
  });

  group('Analytics', () {
    final txs = [
      tx('1', 'income', 500),
      tx('2', 'expense', 100, cat: 'cat-food'),
      tx('3', 'expense', 50, cat: 'cat-transport'),
      tx('4', 'expense', 30, cat: 'cat-food', date: '2000-01-05'),
    ];

    test('summaries and category totals', () {
      final s = Analytics.summarize(Analytics.inMonth(txs, month));
      expect(s.income, 500);
      expect(s.expense, 150);
      expect(s.balance, 350);
      final byCat = Analytics.spendByCategory(txs);
      expect(byCat.keys.first, 'cat-food');
      expect(byCat['cat-food'], 130);
    });

    test('budget usage for overall and category budgets', () {
      final usage = Analytics.budgetUsage(
          [budget('b1', 200), budget('b2', 80, cat: 'cat-food')], txs, month);
      expect(usage.first.budget.isOverall, isTrue);
      expect(usage.first.spent, 150);
      expect(usage.first.remaining, 50);
      final food = usage.firstWhere((u) => u.budget.categoryId == 'cat-food');
      expect(food.isOver, isTrue);
    });
  });

  group('BudgetMonitor', () {
    final budgets = [budget('b1', 100, cat: 'cat-food')];
    final catMap = {for (final c in cats) c.id: c};

    test('alerts once when crossing the threshold', () {
      final before = [tx('1', 'expense', 70, cat: 'cat-food')];
      final after = [...before, tx('2', 'expense', 15, cat: 'cat-food')];
      final alerts = BudgetMonitor.check(
          budgets: budgets, before: before, after: after, month: month,
          categories: catMap, currency: 'USD');
      expect(alerts, hasLength(1));
      expect(alerts.first.exceeded, isFalse);

      // Another small expense still under 100% -> no repeated alert.
      final again = BudgetMonitor.check(
          budgets: budgets, before: after,
          after: [...after, tx('3', 'expense', 5, cat: 'cat-food')],
          month: month, categories: catMap, currency: 'USD');
      expect(again, isEmpty);
    });

    test('alerts when the limit is exceeded', () {
      final before = [tx('1', 'expense', 90, cat: 'cat-food')];
      final after = [...before, tx('2', 'expense', 20, cat: 'cat-food')];
      final alerts = BudgetMonitor.check(
          budgets: budgets, before: before, after: after, month: month,
          categories: catMap, currency: 'USD');
      expect(alerts.single.exceeded, isTrue);
    });

    test('other categories do not trigger alerts', () {
      final alerts = BudgetMonitor.check(
          budgets: budgets, before: const [],
          after: [tx('1', 'expense', 500, cat: 'cat-transport')],
          month: month, categories: catMap, currency: 'USD');
      expect(alerts, isEmpty);
    });
  });

  group('SavingsGoal', () {
    final g = SavingsGoal(
      id: 'g',
      userId: 'u',
      name: 'Laptop',
      targetAmount: 1000,
      currentAmount: 400,
      targetDate: Fmt.isoDate(DateTime.now().add(const Duration(days: 400))),
      monthlyContribution: 100,
      createdAt: Fmt.nowIso(),
    );

    test('remaining, progress and completion estimate', () {
      expect(g.remaining, 600);
      expect(g.progress, closeTo(0.4, 1e-9));
      expect(g.monthsToGo, 6);
      expect(g.isBehindSchedule, isFalse);
    });

    test('no monthly contribution means no estimate', () {
      final g2 = g.copyWith(monthlyContribution: 0);
      expect(g2.monthsToGo, isNull);
      expect(g2.isBehindSchedule, isTrue);
    });
  });

  group('RuleBasedAdvisor', () {
    const ctx = ChatContext(
      currency: 'USD',
      monthIncome: 500,
      monthExpense: 300,
      topCategories: {'Food': 150, 'Transport': 60},
      budgetLines: ['Overall: 300.00 of 400.00 (75%)'],
      goalLines: [],
    );

    test('answers with the student data', () {
      expect(RuleBasedAdvisor.answer('How am I doing this month?', ctx), contains('200.00'));
      expect(RuleBasedAdvisor.answer('how much on food?', ctx), contains('150.00'));
    });

    test('declines investment advice', () {
      expect(RuleBasedAdvisor.answer('Should I buy bitcoin?', ctx),
          contains('financial adviser'));
    });
  });
}
