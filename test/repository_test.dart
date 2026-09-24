import 'package:flutter_test/flutter_test.dart';
import 'package:pennypal/core/config.dart';
import 'package:pennypal/core/formatters.dart';
import 'package:pennypal/data/database.dart';
import 'package:pennypal/data/models/savings_goal.dart';
import 'package:pennypal/data/models/transaction.dart';
import 'package:pennypal/data/repositories/admin_repository.dart';
import 'package:pennypal/data/repositories/auth_repository.dart';
import 'package:pennypal/data/repositories/engagement_repository.dart';
import 'package:pennypal/data/repositories/finance_repository.dart';
import 'package:pennypal/state/finance_state.dart';

import 'test_helpers.dart';

void main() {
  late AppDatabase db;
  late AuthRepository auth;
  late FinanceRepository finance;
  late EngagementRepository engagement;

  setUp(() async {
    db = await openTestDatabase();
    auth = AuthRepository(db);
    finance = FinanceRepository(db);
    engagement = EngagementRepository(db);
  });

  tearDown(() => db.close());

  test('schema script splits into statements without comments', () {
    final stmts = splitSqlScript('-- a;comment\nCREATE TABLE a(x); -- trailing\nPRAGMA x;');
    expect(stmts, ['CREATE TABLE a(x)']);
  });

  group('Auth', () {
    test('pre-configured admin and demo student can log in', () async {
      final admin = await auth.login(AppConfig.adminEmail, AppConfig.adminPassword);
      expect(admin.isAdmin, isTrue);
      final student = await auth.login(
          AppConfig.demoStudentEmail.toUpperCase(), AppConfig.demoStudentPassword);
      expect(student.isAdmin, isFalse);
      expect(student.lastLogin, isNotNull);
    });

    test('rejects wrong password', () async {
      expect(() => auth.login(AppConfig.adminEmail, 'nope'),
          throwsA(isA<AuthException>()));
    });

    test('registers a student and prevents duplicates', () async {
      final u = await auth.register(
          fullName: 'Grace Hopper',
          email: 'grace@uni.edu',
          mobile: '+1 555 010 0300',
          password: 'Compiler#1');
      expect(u.role, 'student');
      expect(u.mobile, '+15550100300');
      final profile = await auth.profileFor(u.id);
      expect(profile.currency, 'USD');
      expect(
          () => auth.register(
              fullName: 'Grace', email: 'GRACE@uni.edu', mobile: '5550100', password: 'Compiler#1'),
          throwsA(isA<AuthException>()));
      // Registration is queued for cloud sync.
      expect(await db.pendingSyncCount(), greaterThan(0));
    });

    test('deactivated students cannot log in', () async {
      await AdminRepository(db).setActive('user-student-0001', false);
      expect(() => auth.login(AppConfig.demoStudentEmail, AppConfig.demoStudentPassword),
          throwsA(isA<AuthException>()));
    });
  });

  group('Finance', () {
    test('demo data is seeded', () async {
      final txs = await finance.transactions('user-student-0001');
      expect(txs.length, greaterThan(20));
      expect(await finance.categories('user-student-0001'), hasLength(8));
      expect(await finance.goals('user-student-0001'), hasLength(3));
    });

    test('one budget per month and category', () async {
      final month = Fmt.monthKey(DateTime.now());
      final b = await finance.saveBudget(
          userId: 'user-student-0001', month: month, categoryId: 'cat-transport',
          limit: 50, threshold: 80);
      // Saving again for the same category updates rather than duplicates.
      final again = await finance.saveBudget(
          userId: 'user-student-0001', month: month, categoryId: 'cat-transport',
          limit: 70, threshold: 90);
      expect(again.id, b.id);
      final all = (await finance.budgets('user-student-0001'))
          .where((x) => x.categoryId == 'cat-transport' && x.month == month);
      expect(all.single.limitAmount, 70);
    });

    test('repeated offline edits collapse into one sync queue entry', () async {
      final t = TransactionRecord(
          id: 'tx-sync', userId: 'user-student-0001', type: 'expense', amount: 3,
          categoryId: 'cat-food', date: Fmt.isoDate(DateTime.now()), createdAt: Fmt.nowIso());
      final before = await db.pendingSyncCount();
      await finance.saveTransaction(t);
      await finance.saveTransaction(t);
      await finance.deleteTransaction(t);
      expect(await db.pendingSyncCount(), before + 1);
    });

    test('deleting a custom category moves expenses to Miscellaneous', () async {
      final c = await finance.addCategory('user-student-0001', 'Gym', 'sport');
      await finance.saveTransaction(TransactionRecord(
          id: 'tx-gym', userId: 'user-student-0001', type: 'expense', amount: 20,
          categoryId: c.id, date: Fmt.isoDate(DateTime.now()), createdAt: Fmt.nowIso()));
      await finance.deleteCategory('user-student-0001', c.id);
      final t = (await finance.transactions('user-student-0001')).firstWhere((t) => t.id == 'tx-gym');
      expect(t.categoryId, 'cat-misc');
    });
  });

  group('FinanceState', () {
    late FinanceState state;
    setUp(() async {
      state = FinanceState(
        userId: 'user-student-0001',
        finance: finance,
        engagement: engagement,
        currencyOf: () => 'USD',
        notificationsEnabled: () => false,
      );
      await state.load();
    });

    test('an expense over a category limit raises an alert and notification', () async {
      final unread = state.unreadCount;
      final alerts = await state.saveTransaction(TransactionRecord(
          id: state.newId(), userId: state.userId, type: 'expense', amount: 500,
          categoryId: 'cat-food', description: 'Big grocery run',
          date: Fmt.isoDate(DateTime.now()), createdAt: Fmt.nowIso()));
      expect(alerts.where((a) => a.exceeded), isNotEmpty);
      expect(state.unreadCount, greaterThan(unread));
    });

    test('contributions reach milestones and complete the goal', () async {
      final g = state.goals.firstWhere((g) => g.name == 'Emergency fund');
      final done = await state.contribute(g, g.remaining);
      expect(done.isCompleted, isTrue);
      expect(done.milestones, containsAll(SavingsGoal.milestoneSteps));
      expect(state.completedGoals.map((g) => g.id), contains(g.id));
    });

    test('chat context summarises the month', () {
      final ctx = state.chatContext();
      expect(ctx.monthIncome, greaterThan(0));
      expect(ctx.budgetLines, isNotEmpty);
    });
  });

  group('Admin & support', () {
    test('statistics and support replies', () async {
      final admin = AdminRepository(db);
      final stats = await admin.stats();
      expect(stats.students, 1);
      expect(stats.transactions, greaterThan(20));

      await engagement.submitQuery('user-student-0001', 'Help', 'How do I export a report?');
      final q = (await engagement.allQueries()).firstWhere((q) => q.subject == 'Help');
      expect(q.userName, 'Ada Student');
      await engagement.respondToQuery(q, 'Use Reports > Export.', 'resolved');
      final mine = await engagement.queriesFor('user-student-0001');
      expect(mine.firstWhere((x) => x.id == q.id).adminResponse, 'Use Reports > Export.');
      final notes = await engagement.notifications('user-student-0001');
      expect(notes.first.title, contains('Support replied'));
    });

    test('deleting a student cascades to their records', () async {
      await AdminRepository(db).deleteStudent('user-student-0001');
      expect(await finance.transactions('user-student-0001'), isEmpty);
      expect(await finance.goals('user-student-0001'), isEmpty);
    });
  });
}
