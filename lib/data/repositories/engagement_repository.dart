import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/formatters.dart';
import '../database.dart';
import '../models/misc.dart';

/// Notifications, learning content, feedback, support queries, reports and
/// app settings.
class EngagementRepository {
  EngagementRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  // --------------------------------------------------------- notifications
  Future<List<AppNotification>> notifications(String userId) async {
    final rows = await _db.db.query('Notifications',
        where: 'UserId = ?',
        whereArgs: [userId],
        orderBy: 'CreatedAt DESC',
        limit: 100);
    return rows.map(AppNotification.fromMap).toList();
  }

  Future<AppNotification> addNotification(
      String userId, String title, String message, String type) async {
    final n = AppNotification(
        id: _uuid.v4(),
        userId: userId,
        title: title,
        message: message,
        type: type,
        createdAt: Fmt.nowIso());
    await _db.db.insert('Notifications', n.toMap());
    return n;
  }

  Future<void> markAllRead(String userId) => _db.db.update(
      'Notifications', {'ReadStatus': 1},
      where: 'UserId = ?', whereArgs: [userId]);

  Future<void> markRead(String id) => _db.db.update(
      'Notifications', {'ReadStatus': 1},
      where: 'NotificationId = ?', whereArgs: [id]);

  Future<void> clearNotifications(String userId) =>
      _db.db.delete('Notifications', where: 'UserId = ?', whereArgs: [userId]);

  // -------------------------------------------------------------- learning
  Future<List<LearningItem>> learning({bool includeInactive = false}) async {
    final rows = await _db.db.query('LearningContent',
        where: includeInactive ? null : 'IsActive = 1', orderBy: 'Topic, Title');
    return rows.map(LearningItem.fromMap).toList();
  }

  Future<void> saveLearning(LearningItem item) async {
    await _db.db.transaction((txn) async {
      await txn.insert('LearningContent', item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await AppDatabase.enqueueSync(txn,
          entity: 'LearningContent', recordId: item.id);
    });
  }

  Future<void> deleteLearning(String id) async {
    await _db.db.transaction((txn) async {
      await txn.delete('LearningContent',
          where: 'ContentId = ?', whereArgs: [id]);
      await AppDatabase.enqueueSync(txn,
          entity: 'LearningContent', recordId: id, operation: 'delete');
    });
  }

  String newId() => _uuid.v4();

  // -------------------------------------------------------------- feedback
  Future<void> submitFeedback({
    String? userId,
    required String name,
    required String email,
    required int rating,
    required String comments,
  }) async {
    final f = FeedbackEntry(
        id: _uuid.v4(),
        userId: userId,
        name: name.trim(),
        email: email.trim(),
        rating: rating,
        comments: comments.trim(),
        submittedOn: Fmt.nowIso());
    await _db.db.transaction((txn) async {
      await txn.insert('Feedback', f.toMap());
      await AppDatabase.enqueueSync(txn,
          entity: 'Feedback', recordId: f.id, userId: userId);
    });
  }

  Future<List<FeedbackEntry>> allFeedback() async {
    final rows = await _db.db.query('Feedback', orderBy: 'SubmittedOn DESC');
    return rows.map(FeedbackEntry.fromMap).toList();
  }

  // --------------------------------------------------------------- support
  Future<void> submitQuery(String userId, String subject, String message) async {
    final q = SupportQuery(
        id: _uuid.v4(),
        userId: userId,
        subject: subject.trim(),
        message: message.trim(),
        submittedOn: Fmt.nowIso());
    await _db.db.transaction((txn) async {
      await txn.insert('SupportQueries', q.toMap());
      await AppDatabase.enqueueSync(txn,
          entity: 'SupportQueries', recordId: q.id, userId: userId);
    });
  }

  Future<List<SupportQuery>> queriesFor(String userId) async {
    final rows = await _db.db.query('SupportQueries',
        where: 'UserId = ?', whereArgs: [userId], orderBy: 'SubmittedOn DESC');
    return rows.map(SupportQuery.fromMap).toList();
  }

  Future<List<SupportQuery>> allQueries() async {
    final rows = await _db.db.rawQuery('''
      SELECT q.*, u.FullName FROM SupportQueries q
      LEFT JOIN Users u ON u.UserId = q.UserId
      ORDER BY CASE q.Status WHEN 'open' THEN 0 WHEN 'in_progress' THEN 1 ELSE 2 END,
               q.SubmittedOn DESC''');
    return rows.map(SupportQuery.fromMap).toList();
  }

  /// Admin reply. The student is notified in-app.
  Future<void> respondToQuery(
      SupportQuery q, String response, String status) async {
    await _db.db.transaction((txn) async {
      await txn.update(
          'SupportQueries', {'AdminResponse': response.trim(), 'Status': status},
          where: 'QueryId = ?', whereArgs: [q.id]);
      await txn.insert('Notifications', {
        'NotificationId': _uuid.v4(),
        'UserId': q.userId,
        'Title': 'Support replied: ${q.subject}',
        'Message': response.trim(),
        'Type': 'system',
        'ReadStatus': 0,
        'CreatedAt': Fmt.nowIso(),
      });
      await AppDatabase.enqueueSync(txn,
          entity: 'SupportQueries', recordId: q.id, userId: q.userId);
    });
  }

  // --------------------------------------------------------------- reports
  Future<ReportRecord> saveReport(ReportRecord r) async {
    await _db.db.insert('Reports', r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return r;
  }

  Future<List<ReportRecord>> reports(String userId) async {
    final rows = await _db.db.query('Reports',
        where: 'UserId = ?',
        whereArgs: [userId],
        orderBy: 'GeneratedOn DESC',
        limit: 20);
    return rows.map(ReportRecord.fromMap).toList();
  }

  // -------------------------------------------------------------- settings
  Future<Map<String, String>> settings() async {
    final rows = await _db.db.query('AppSettings');
    return {
      for (final r in rows)
        r['SettingKey'] as String: r['SettingValue'] as String
    };
  }

  Future<void> saveSetting(String key, String value) async {
    await _db.db.transaction((txn) async {
      await txn.insert('AppSettings', {'SettingKey': key, 'SettingValue': value},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await AppDatabase.enqueueSync(txn, entity: 'AppSettings', recordId: key);
    });
  }
}
