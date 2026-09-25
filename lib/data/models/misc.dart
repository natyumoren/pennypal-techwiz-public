// Smaller entities: learning content, notifications, support queries,
// feedback and generated reports.

class LearningItem {
  final String id;
  final String title;
  final String topic;
  final String body;
  final String difficulty;
  final String? imageUrl; // icon key or URL
  final bool isActive;

  const LearningItem({
    required this.id,
    required this.title,
    required this.topic,
    required this.body,
    this.difficulty = 'Beginner',
    this.imageUrl,
    this.isActive = true,
  });

  factory LearningItem.fromMap(Map<String, Object?> m) => LearningItem(
        id: m['ContentId'] as String,
        title: m['Title'] as String,
        topic: m['Topic'] as String,
        body: m['Body'] as String,
        difficulty: m['DifficultyLevel'] as String? ?? 'Beginner',
        imageUrl: m['ImageUrl'] as String?,
        isActive: (m['IsActive'] as int? ?? 1) == 1,
      );

  Map<String, Object?> toMap() => {
        'ContentId': id,
        'Title': title,
        'Topic': topic,
        'Body': body,
        'DifficultyLevel': difficulty,
        'ImageUrl': imageUrl,
        'IsActive': isActive ? 1 : 0,
      };
}

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type; // budget | goal | system
  final bool read;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.read = false,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, Object?> m) => AppNotification(
        id: m['NotificationId'] as String,
        userId: m['UserId'] as String,
        title: m['Title'] as String,
        message: m['Message'] as String,
        type: m['Type'] as String,
        read: (m['ReadStatus'] as int? ?? 0) == 1,
        createdAt: m['CreatedAt'] as String,
      );

  Map<String, Object?> toMap() => {
        'NotificationId': id,
        'UserId': userId,
        'Title': title,
        'Message': message,
        'Type': type,
        'ReadStatus': read ? 1 : 0,
        'CreatedAt': createdAt,
      };
}

class SupportQuery {
  final String id;
  final String userId;
  final String subject;
  final String message;
  final String status; // open | in_progress | resolved
  final String? adminResponse;
  final String submittedOn;
  final String? userName; // joined for the admin view

  const SupportQuery({
    required this.id,
    required this.userId,
    required this.subject,
    required this.message,
    this.status = 'open',
    this.adminResponse,
    required this.submittedOn,
    this.userName,
  });

  factory SupportQuery.fromMap(Map<String, Object?> m) => SupportQuery(
        id: m['QueryId'] as String,
        userId: m['UserId'] as String,
        subject: m['Subject'] as String,
        message: m['Message'] as String,
        status: m['Status'] as String? ?? 'open',
        adminResponse: m['AdminResponse'] as String?,
        submittedOn: m['SubmittedOn'] as String,
        userName: m['FullName'] as String?,
      );

  Map<String, Object?> toMap() => {
        'QueryId': id,
        'UserId': userId,
        'Subject': subject,
        'Message': message,
        'Status': status,
        'AdminResponse': adminResponse,
        'SubmittedOn': submittedOn,
      };

  String get statusLabel => switch (status) {
        'in_progress' => 'In progress',
        'resolved' => 'Resolved',
        _ => 'Open',
      };
}

class FeedbackEntry {
  final String id;
  final String? userId;
  final String name;
  final String email;
  final int rating;
  final String comments;
  final String submittedOn;

  const FeedbackEntry({
    required this.id,
    this.userId,
    required this.name,
    required this.email,
    required this.rating,
    required this.comments,
    required this.submittedOn,
  });

  factory FeedbackEntry.fromMap(Map<String, Object?> m) => FeedbackEntry(
        id: m['FeedbackId'] as String,
        userId: m['UserId'] as String?,
        name: m['Name'] as String,
        email: m['Email'] as String,
        rating: m['Rating'] as int,
        comments: m['Comments'] as String,
        submittedOn: m['SubmittedOn'] as String,
      );

  Map<String, Object?> toMap() => {
        'FeedbackId': id,
        'UserId': userId,
        'Name': name,
        'Email': email,
        'Rating': rating,
        'Comments': comments,
        'SubmittedOn': submittedOn,
      };
}

class ReportRecord {
  final String id;
  final String userId;
  final String reportType;
  final String dateRange; // "from..to"
  final String generatedOn;
  final String? fileUrl;

  const ReportRecord({
    required this.id,
    required this.userId,
    required this.reportType,
    required this.dateRange,
    required this.generatedOn,
    this.fileUrl,
  });

  factory ReportRecord.fromMap(Map<String, Object?> m) => ReportRecord(
        id: m['ReportId'] as String,
        userId: m['UserId'] as String,
        reportType: m['ReportType'] as String,
        dateRange: m['DateRange'] as String,
        generatedOn: m['GeneratedOn'] as String,
        fileUrl: m['FileUrl'] as String?,
      );

  Map<String, Object?> toMap() => {
        'ReportId': id,
        'UserId': userId,
        'ReportType': reportType,
        'DateRange': dateRange,
        'GeneratedOn': generatedOn,
        'FileUrl': fileUrl,
      };
}
