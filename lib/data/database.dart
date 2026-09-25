import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../core/formatters.dart';
import 'seed_data.dart';

/// Primary-key column of every synced table. Used by the sync queue to find
/// the row behind a queued change.
const tablePrimaryKeys = <String, String>{
  'Users': 'UserId',
  'UserProfiles': 'ProfileId',
  'Categories': 'CategoryId',
  'Transactions': 'TransactionId',
  'Budgets': 'BudgetId',
  'SavingsGoals': 'GoalId',
  'Reports': 'ReportId',
  'LearningContent': 'ContentId',
  'Notifications': 'NotificationId',
  'SupportQueries': 'QueryId',
  'Feedback': 'FeedbackId',
  'AppSettings': 'SettingKey',
};

/// Local SQLite database: the offline cache and the source of truth on the
/// device. Works on Android/iOS (sqflite) and on the Web (sqflite wasm).
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const schemaAsset = 'database/pennypal_schema.sql';
  static const _version = 1;

  /// Opens (and on first launch creates + seeds) the database.
  /// [factory], [path] and [schemaSql] are overridable for tests.
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
    String? schemaSql,
    bool seedDemoData = true,
  }) async {
    final dbFactory =
        factory ?? (kIsWeb ? databaseFactoryFfiWeb : databaseFactory);
    final dbPath = path ??
        (kIsWeb
            ? 'pennypal.db'
            : p.join(await dbFactory.getDatabasesPath(), 'pennypal.db'));
    final sql = schemaSql ?? await rootBundle.loadString(schemaAsset);

    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          final batch = db.batch();
          for (final stmt in splitSqlScript(sql)) {
            batch.execute(stmt);
          }
          await batch.commit(noResult: true);
          await SeedData.apply(db, includeDemoStudent: seedDemoData);
        },
      ),
    );
    return AppDatabase._(db);
  }

  /// Records a local change so [SyncService] can push it to the cloud later.
  /// Older queue entries for the same record are replaced, so repeated edits
  /// while offline are sent once (no duplicate sync attempts).
  static Future<void> enqueueSync(
    DatabaseExecutor ex, {
    required String entity,
    required String recordId,
    String operation = 'upsert',
    String? userId,
  }) async {
    await ex.delete('SyncQueue',
        where: 'EntityName = ? AND RecordId = ?',
        whereArgs: [entity, recordId]);
    await ex.insert('SyncQueue', {
      'EntityName': entity,
      'RecordId': recordId,
      'Operation': operation,
      'UserId': userId,
      'CreatedAt': Fmt.nowIso(),
    });
  }

  Future<int> pendingSyncCount() async => Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM SyncQueue')) ??
      0;

  Future<void> close() => db.close();
}

/// Splits a SQL script into statements: strips `--` comments, drops PRAGMAs
/// (applied in onConfigure) and splits on `;`.
List<String> splitSqlScript(String script) {
  final noComments = script
      .split('\n')
      .map((line) {
        final i = line.indexOf('--');
        return i >= 0 ? line.substring(0, i) : line;
      })
      .join('\n');
  return noComments
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && !s.toUpperCase().startsWith('PRAGMA'))
      .toList();
}
