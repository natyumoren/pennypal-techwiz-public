import 'package:uuid/uuid.dart';

import '../../core/formatters.dart';
import '../../core/security.dart';
import '../database.dart';
import '../models/user.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Registration, login and profile persistence for local accounts.
class AuthRepository {
  AuthRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<bool> emailExists(String email) async {
    final rows = await _db.db.query('Users',
        columns: ['UserId'],
        where: 'Email = ? COLLATE NOCASE',
        whereArgs: [email.trim()]);
    return rows.isNotEmpty;
  }

  Future<AppUser> register({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
    String? studentStatus,
  }) async {
    if (await emailExists(email)) {
      throw AuthException('An account with this email already exists.');
    }
    final userId = _uuid.v4();
    final profileId = _uuid.v4();
    final now = Fmt.nowIso();
    await _db.db.transaction((txn) async {
      await txn.insert('Users', {
        'UserId': userId,
        'FullName': fullName.trim(),
        'Email': email.trim().toLowerCase(),
        'MobileNumber': mobile.replaceAll(RegExp(r'[\s-]'), ''),
        'PasswordHash': PasswordHasher.hash(password),
        'Role': 'student',
        'IsActive': 1,
        'CreatedAt': now,
        'LastLogin': now,
      });
      await txn.insert('UserProfiles', {
        'ProfileId': profileId,
        'UserId': userId,
        'StudentStatus': studentStatus,
        'CurrencyPreference': 'USD',
        'NotificationPreference': 1,
      });
      await txn.insert('Notifications', {
        'NotificationId': _uuid.v4(),
        'UserId': userId,
        'Title': 'Welcome to PennyPal!',
        'Message':
            'Add your income first, then create a monthly budget so we can warn you before you overspend.',
        'Type': 'system',
        'ReadStatus': 0,
        'CreatedAt': now,
      });
      await AppDatabase.enqueueSync(txn,
          entity: 'Users', recordId: userId, userId: userId);
      await AppDatabase.enqueueSync(txn,
          entity: 'UserProfiles', recordId: profileId, userId: userId);
    });
    return (await findById(userId))!;
  }

  /// Returns the user when the credentials match; throws [AuthException]
  /// with a user-friendly message otherwise.
  Future<AppUser> login(String email, String password) async {
    final rows = await _db.db.query('Users',
        where: 'Email = ? COLLATE NOCASE', whereArgs: [email.trim()]);
    if (rows.isEmpty ||
        !PasswordHasher.verify(password, rows.first['PasswordHash'] as String)) {
      throw AuthException('Incorrect email or password.');
    }
    final user = AppUser.fromMap(rows.first);
    if (!user.isActive) {
      throw AuthException(
          'This account has been deactivated. Please contact support.');
    }
    await _db.db.update('Users', {'LastLogin': Fmt.nowIso()},
        where: 'UserId = ?', whereArgs: [user.id]);
    return (await findById(user.id))!;
  }

  Future<AppUser?> findById(String id) async {
    final rows =
        await _db.db.query('Users', where: 'UserId = ?', whereArgs: [id]);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  Future<UserProfile> profileFor(String userId) async {
    final rows = await _db.db
        .query('UserProfiles', where: 'UserId = ?', whereArgs: [userId]);
    if (rows.isNotEmpty) return UserProfile.fromMap(rows.first);
    final profile = UserProfile(id: _uuid.v4(), userId: userId);
    await _db.db.insert('UserProfiles', profile.toMap());
    return profile;
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _db.db.transaction((txn) async {
      await txn.update('UserProfiles', profile.toMap(),
          where: 'ProfileId = ?', whereArgs: [profile.id]);
      await AppDatabase.enqueueSync(txn,
          entity: 'UserProfiles',
          recordId: profile.id,
          userId: profile.userId);
    });
  }

  Future<void> updateUserDetails(String userId,
      {required String fullName, required String mobile}) async {
    await _db.db.transaction((txn) async {
      await txn.update(
          'Users',
          {
            'FullName': fullName.trim(),
            'MobileNumber': mobile.replaceAll(RegExp(r'[\s-]'), ''),
          },
          where: 'UserId = ?',
          whereArgs: [userId]);
      await AppDatabase.enqueueSync(txn,
          entity: 'Users', recordId: userId, userId: userId);
    });
  }

  Future<void> changePassword(
      String userId, String currentPassword, String newPassword) async {
    final rows = await _db.db.query('Users',
        columns: ['PasswordHash'], where: 'UserId = ?', whereArgs: [userId]);
    if (rows.isEmpty ||
        !PasswordHasher.verify(
            currentPassword, rows.first['PasswordHash'] as String)) {
      throw AuthException('Your current password is incorrect.');
    }
    await _db.db.update(
        'Users', {'PasswordHash': PasswordHasher.hash(newPassword)},
        where: 'UserId = ?', whereArgs: [userId]);
  }
}
