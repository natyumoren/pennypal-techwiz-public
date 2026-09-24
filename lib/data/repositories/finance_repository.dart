import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/formatters.dart';
import '../database.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart';

/// Transactions, categories, budgets and savings goals for one student.
class FinanceRepository {
  FinanceRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  Database get _sql => _db.db;
  String newId() => _uuid.v4();

  // ------------------------------------------------------------ categories
  Future<List<Category>> categories(String userId) async {
    final rows = await _sql.query('Categories',
        where: "CategoryType = 'expense' AND (IsDefault = 1 OR CreatedBy = ?)",
        whereArgs: [userId],
        orderBy: 'IsDefault DESC, CategoryName');
    return rows.map(Category.fromMap).toList();
  }

  Future<Category> addCategory(String userId, String name, String icon) async {
    final existing = await _sql.query('Categories',
        where:
            "CategoryName = ? COLLATE NOCASE AND (IsDefault = 1 OR CreatedBy = ?)",
        whereArgs: [name.trim(), userId]);
    if (existing.isNotEmpty) {
      throw StateError('A category called "${name.trim()}" already exists.');
    }
    final c = Category(
        id: newId(), name: name.trim(), icon: icon, createdBy: userId);
    await _sql.transaction((txn) async {
      await txn.insert('Categories', c.toMap());
      await AppDatabase.enqueueSync(txn,
          entity: 'Categories', recordId: c.id, userId: userId);
    });
    return c;
  }

  /// Custom categories can be removed; their expenses move to Miscellaneous.
  Future<void> deleteCategory(String userId, String categoryId) async {
    await _sql.transaction((txn) async {
      await txn.update('Transactions', {'CategoryId': 'cat-misc'},
          where: 'CategoryId = ? AND UserId = ?',
          whereArgs: [categoryId, userId]);
      await txn.delete('Budgets',
          where: 'CategoryId = ? AND UserId = ?',
          whereArgs: [categoryId, userId]);
      await txn.delete('Categories',
          where: 'CategoryId = ? AND CreatedBy = ? AND IsDefault = 0',
          whereArgs: [categoryId, userId]);
      await AppDatabase.enqueueSync(txn,
          entity: 'Categories',
          recordId: categoryId,
          operation: 'delete',
          userId: userId);
    });
  }

  // ---------------------------------------------------------- transactions
  Future<List<TransactionRecord>> transactions(String userId) async {
    final rows = await _sql.query('Transactions',
        where: 'UserId = ?',
        whereArgs: [userId],
        orderBy: 'Date DESC, CreatedAt DESC');
    return rows.map(TransactionRecord.fromMap).toList();
  }

  Future<void> saveTransaction(TransactionRecord t) async {
    await _sql.transaction((txn) async {
      await txn.insert('Transactions', t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await AppDatabase.enqueueSync(txn,
          entity: 'Transactions', recordId: t.id, userId: t.userId);
    });
  }

  Future<void> deleteTransaction(TransactionRecord t) async {
    await _sql.transaction((txn) async {
      await txn.delete('Transactions',
          where: 'TransactionId = ? AND UserId = ?',
          whereArgs: [t.id, t.userId]);
      await AppDatabase.enqueueSync(txn,
          entity: 'Transactions',
          recordId: t.id,
          operation: 'delete',
          userId: t.userId);
    });
  }

  // --------------------------------------------------------------- budgets
  Future<List<Budget>> budgets(String userId) async {
    final rows = await _sql.query('Budgets',
        where: 'UserId = ?', whereArgs: [userId], orderBy: 'Month DESC');
    return rows.map(Budget.fromMap).toList();
  }

  /// Creates or updates the budget for (month, category). Only one budget
  /// may exist per month and category (enforced by a unique index as well).
  Future<Budget> saveBudget({
    String? id,
    required String userId,
    required String month,
    String? categoryId,
    required double limit,
    required int threshold,
  }) async {
    final existing = await _sql.query('Budgets',
        where: categoryId == null
            ? 'UserId = ? AND Month = ? AND CategoryId IS NULL'
            : 'UserId = ? AND Month = ? AND CategoryId = ?',
        whereArgs: [userId, month, if (categoryId != null) categoryId]);
    final existingId =
        existing.isEmpty ? null : existing.first['BudgetId'] as String;
    if (id != null && existingId != null && existingId != id) {
      throw StateError('A budget for this category and month already exists.');
    }
    final b = Budget(
      id: id ?? existingId ?? newId(),
      userId: userId,
      month: month,
      categoryId: categoryId,
      limitAmount: limit,
      alertThreshold: threshold,
      createdAt: existing.isEmpty
          ? Fmt.nowIso()
          : existing.first['CreatedAt'] as String,
    );
    await _sql.transaction((txn) async {
      await txn.insert('Budgets', b.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await AppDatabase.enqueueSync(txn,
          entity: 'Budgets', recordId: b.id, userId: userId);
    });
    return b;
  }

  Future<void> deleteBudget(Budget b) async {
    await _sql.transaction((txn) async {
      await txn.delete('Budgets', where: 'BudgetId = ?', whereArgs: [b.id]);
      await AppDatabase.enqueueSync(txn,
          entity: 'Budgets',
          recordId: b.id,
          operation: 'delete',
          userId: b.userId);
    });
  }

  // ---------------------------------------------------------- savings goals
  Future<List<SavingsGoal>> goals(String userId) async {
    final rows = await _sql.query('SavingsGoals',
        where: 'UserId = ?',
        whereArgs: [userId],
        orderBy: "Status = 'completed', TargetDate");
    return rows.map(SavingsGoal.fromMap).toList();
  }

  Future<void> saveGoal(SavingsGoal g) async {
    await _sql.transaction((txn) async {
      await txn.insert('SavingsGoals', g.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await AppDatabase.enqueueSync(txn,
          entity: 'SavingsGoals', recordId: g.id, userId: g.userId);
    });
  }

  Future<void> deleteGoal(SavingsGoal g) async {
    await _sql.transaction((txn) async {
      await txn.delete('SavingsGoals', where: 'GoalId = ?', whereArgs: [g.id]);
      await AppDatabase.enqueueSync(txn,
          entity: 'SavingsGoals',
          recordId: g.id,
          operation: 'delete',
          userId: g.userId);
    });
  }
}

