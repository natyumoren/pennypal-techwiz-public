/// Row of the Users table joined with the matching UserProfiles row.
class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String mobile;
  final String role; // 'student' | 'admin'
  final bool isActive;
  final String createdAt;
  final String? lastLogin;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.mobile,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.lastLogin,
  });

  bool get isAdmin => role == 'admin';

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  factory AppUser.fromMap(Map<String, Object?> m) => AppUser(
        id: m['UserId'] as String,
        fullName: m['FullName'] as String,
        email: m['Email'] as String,
        mobile: m['MobileNumber'] as String,
        role: m['Role'] as String,
        isActive: (m['IsActive'] as int? ?? 1) == 1,
        createdAt: m['CreatedAt'] as String,
        lastLogin: m['LastLogin'] as String?,
      );
}

class UserProfile {
  final String id;
  final String userId;
  final String? studentStatus;
  final String currency;
  final bool notificationsOn;
  final String? profileImage;

  const UserProfile({
    required this.id,
    required this.userId,
    this.studentStatus,
    this.currency = 'USD',
    this.notificationsOn = true,
    this.profileImage,
  });

  factory UserProfile.fromMap(Map<String, Object?> m) => UserProfile(
        id: m['ProfileId'] as String,
        userId: m['UserId'] as String,
        studentStatus: m['StudentStatus'] as String?,
        currency: m['CurrencyPreference'] as String? ?? 'USD',
        notificationsOn: (m['NotificationPreference'] as int? ?? 1) == 1,
        profileImage: m['ProfileImage'] as String?,
      );

  Map<String, Object?> toMap() => {
        'ProfileId': id,
        'UserId': userId,
        'StudentStatus': studentStatus,
        'CurrencyPreference': currency,
        'NotificationPreference': notificationsOn ? 1 : 0,
        'ProfileImage': profileImage,
      };

  UserProfile copyWith(
          {String? studentStatus, String? currency, bool? notificationsOn}) =>
      UserProfile(
        id: id,
        userId: userId,
        studentStatus: studentStatus ?? this.studentStatus,
        currency: currency ?? this.currency,
        notificationsOn: notificationsOn ?? this.notificationsOn,
        profileImage: profileImage,
      );
}
