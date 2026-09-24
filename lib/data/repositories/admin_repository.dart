import 'package:sqflite/sqflite.dart';

import '../database.dart';
import '../models/user.dart';

/// Per-student summary shown in the admin user list.
class StudentSummary {
  final AppUser user;
  final int transactionCount;
  final double totalIncome;
  final double totalExpense;
  const StudentSummary(
      this.user, this.transactionCount, this.totalIncome, this.totalExpense);
}

class PlatformStats {
  final int students;
  final int activeStudents;
  final int newStudents30d;
  final int activeLast7d;
  final int transactions;
  final double totalIncome;
  final double totalExpense;
  final int goals;
  final int completedGoals;
  final int openQueries;
  final double averageRating;
  final Map<String, double> spendByCategory;
  final Map<String, int> transactionsByMonth;

  const PlatformStats({
    required this.students,
    required this.activeStudents,
    required this.newStudents30d,
    required this.activeLast7d,
    required this.transactions,
    required this.totalIncome,
    required this.totalExpense,
    required this.goals,
    required this.completedGoals,
    required this.openQueries,
    required this.averageRating,
    required this.spendByCategory,
    required this.transactionsByMonth,
  });
}

/// Queries used only by the administrator portal.
class AdminRepository {
  AdminRepository(this._db);
  final AppDatabase _db;
  Database get _sql => _db.db;

  Future<List<StudentSummary>> students() async {
    final rows = await _sql.rawQuery('''
      SELECT u.*,
        (SELECT COUNT(*) FROM Transactions t WHERE t.UserId = u.UserId) AS TxCount,
        (SELECT IFNULL(SUM(Amount),0) FROM Transactions t WHERE t.UserId = u.UserId AND t.Type='income') AS Income,
        (SELECT IFNULL(SUM(Amount),0) FROM Transactions t WHERE t.UserId = u.UserId AND t.Type='expense') AS Expense
      FROM Users u WHERE u.Role = 'student' ORDER BY u.CreatedAt DESC''');
    return rows
        .map((r) => StudentSummary(AppUser.fromMap(r), r['TxCount'] as int,
            (r['Income'] as num).toDouble(), (r['Expense'] as num).toDouble()))
        .toList();
  }

  Future<void> setActive(String userId, bool active) async {
    await _sql.transaction((txn) async {
      await txn.update('Users', {'IsActive': active ? 1 : 0},
          where: "UserId = ? AND Role = 'student'", whereArgs: [userId]);
      await AppDatabase.enqueueSync(txn,
          entity: 'Users', recordId: userId, userId: userId);
    });
  }

  /// Permanently removes a student and (via ON DELETE CASCADE) their data.
  Future<void> deleteStudent(String userId) async {
    await _sql.transaction((txn) async {
      await txn.delete('Users',
          where: "UserId = ? AND Role = 'student'", whereArgs: [userId]);
      await AppDatabase.enqueueSync(txn,
          entity: 'Users',
          recordId: userId,
          operation: 'delete',
          userId: userId);
    });
  }

  Future<PlatformStats> stats() async {
    Future<num> scalar(String sql, [List<Object?>? args]) async {
      final r = await _sql.rawQuery(sql, args);
      return (r.first.values.first as num?) ?? 0;
    }

    final now = DateTime.now();
    final d30 = now.subtract(const Duration(days: 30)).toIso8601String();
    final d7 = now.subtract(const Duration(days: 7)).toIso8601String();

    final byCategory = await _sql.rawQuery('''
      SELECT c.CategoryName AS Name, SUM(t.Amount) AS Total
      FROM Transactions t JOIN Categories c ON c.CategoryId = t.CategoryId
      WHERE t.Type = 'expense' GROUP BY c.CategoryName ORDER BY Total DESC''');
    final byMonth = await _sql.rawQuery('''
      SELECT substr(Date,1,7) AS Month, COUNT(*) AS N FROM Transactions
      GROUP BY Month ORDER BY Month DESC LIMIT 6''');

    return PlatformStats(
      students: (await scalar(
              "SELECT COUNT(*) FROM Users WHERE Role='student'"))
          .toInt(),
      activeStudents: (await scalar(
              "SELECT COUNT(*) FROM Users WHERE Role='student' AND IsActive=1"))
          .toInt(),
      newStudents30d: (await scalar(
              "SELECT COUNT(*) FROM Users WHERE Role='student' AND CreatedAt >= ?",
              [d30]))
          .toInt(),
      activeLast7d: (await scalar(
              "SELECT COUNT(*) FROM Users WHERE Role='student' AND LastLogin >= ?",
              [d7]))
          .toInt(),
      transactions:
          (await scalar('SELECT COUNT(*) FROM Transactions')).toInt(),
      totalIncome: (await scalar(
              "SELECT IFNULL(SUM(Amount),0) FROM Transactions WHERE Type='income'"))
          .toDouble(),
      totalExpense: (await scalar(
              "SELECT IFNULL(SUM(Amount),0) FROM Transactions WHERE Type='expense'"))
          .toDouble(),
      goals: (await scalar('SELECT COUNT(*) FROM SavingsGoals')).toInt(),
      completedGoals: (await scalar(
              "SELECT COUNT(*) FROM SavingsGoals WHERE Status='completed'"))
          .toInt(),
      openQueries: (await scalar(
              "SELECT COUNT(*) FROM SupportQueries WHERE Status != 'resolved'"))
          .toInt(),
      averageRating:
          (await scalar('SELECT IFNULL(AVG(Rating),0) FROM Feedback'))
              .toDouble(),
      spendByCategory: {
        for (final r in byCategory)
          r['Name'] as String: (r['Total'] as num).toDouble()
      },
      transactionsByMonth: {
        for (final r in byMonth.reversed)
          r['Month'] as String: (r['N'] as num).toInt()
      },
    );
  }
}
