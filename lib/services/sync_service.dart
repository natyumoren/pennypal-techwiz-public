import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../data/database.dart';
import 'cloud_service.dart';

enum SyncStatus { localOnly, idle, syncing, offline, error }

/// Pushes the local SyncQueue to the cloud whenever the device is online.
/// Every local write is queued first (see [AppDatabase.enqueueSync]) so
/// students can keep adding expenses without connectivity.
class SyncService extends ChangeNotifier {
  SyncService(this._db, this._cloud);
  final AppDatabase _db;
  final CloudService _cloud;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  SyncStatus status = SyncStatus.localOnly;
  int pending = 0;
  DateTime? lastSynced;
  bool _running = false;
  bool _online = true;
  String? _userId;
  bool _isAdmin = false;

  /// Entries that failed this many times are skipped (kept for inspection)
  /// so one bad record never blocks the rest of the queue.
  static const maxAttempts = 5;

  /// Only the logged-in account's changes are pushed, so two students
  /// sharing a device never upload each other's records. The administrator
  /// also pushes shared content (lessons, settings, account status).
  void setUser(String? userId, {bool isAdmin = false}) {
    _userId = userId;
    _isAdmin = isAdmin;
    if (userId != null) unawaited(syncNow());
  }

  Future<void> start() async {
    pending = await _db.pendingSyncCount();
    if (!_cloud.isAvailable) {
      status = SyncStatus.localOnly;
      notifyListeners();
      return;
    }
    try {
      _online = _isOnline(await Connectivity().checkConnectivity());
      _sub = Connectivity().onConnectivityChanged.listen((r) {
        _online = _isOnline(r);
        if (_online) {
          syncNow();
        } else {
          status = SyncStatus.offline;
          notifyListeners();
        }
      });
    } catch (_) {
      _online = true; // plugin unavailable: just try.
    }
    status = _online ? SyncStatus.idle : SyncStatus.offline;
    notifyListeners();
    if (_online) unawaited(syncNow());
  }

  bool _isOnline(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);

  /// Called after local writes; refreshes the pending count and syncs if
  /// possible.
  Future<void> changed() async {
    pending = await _db.pendingSyncCount();
    notifyListeners();
    if (_cloud.isAvailable && _online) unawaited(syncNow());
  }

  Future<void> syncNow() async {
    if (_running ||
        _userId == null ||
        !_cloud.isAvailable ||
        !_cloud.isSignedIn) {
      pending = await _db.pendingSyncCount();
      notifyListeners();
      return;
    }
    _running = true;
    status = SyncStatus.syncing;
    notifyListeners();
    var failed = false;
    try {
      final queue = await _db.db.query('SyncQueue',
          where: _isAdmin
              ? 'Attempts < ?'
              : 'Attempts < ? AND UserId = ?',
          whereArgs: [maxAttempts, if (!_isAdmin) _userId],
          orderBy: 'QueueId',
          limit: 200);
      for (final item in queue) {
        final table = item['EntityName'] as String;
        final id = item['RecordId'] as String;
        final userId = item['UserId'] as String?;
        final queueId = item['QueueId'] as int;
        try {
          if (item['Operation'] == 'delete') {
            await _cloud.delete(userId, table, id);
          } else {
            final pk = tablePrimaryKeys[table]!;
            final rows = await _db.db
                .query(table, where: '$pk = ?', whereArgs: [id], limit: 1);
            if (rows.isNotEmpty) {
              await _cloud.upsert(userId, table, id, rows.first);
            }
          }
          await _db.db
              .delete('SyncQueue', where: 'QueueId = ?', whereArgs: [queueId]);
        } catch (e) {
          failed = true;
          await _db.db.rawUpdate(
              'UPDATE SyncQueue SET Attempts = Attempts + 1 WHERE QueueId = ?',
              [queueId]);
          debugPrint('Sync failed for $table/$id: $e');
          // Each document is independent, so carry on with the rest.
        }
      }
      if (!failed) lastSynced = DateTime.now();
    } finally {
      _running = false;
      pending = await _db.pendingSyncCount();
      status = failed ? SyncStatus.error : SyncStatus.idle;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
