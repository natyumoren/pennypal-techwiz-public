import 'dart:math';

class SavingsGoal {
  static const milestoneSteps = [25, 50, 75, 100];

  final String id;
  final String userId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String targetDate; // yyyy-MM-dd
  final double monthlyContribution;
  final String status; // active | completed
  final List<int> milestones; // % milestones reached / marked
  final String createdAt;
  final String? completedAt;

  const SavingsGoal({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.monthlyContribution,
    this.status = 'active',
    this.milestones = const [],
    required this.createdAt,
    this.completedAt,
  });

  bool get isCompleted => status == 'completed';
  double get remaining => max(0, targetAmount - currentAmount);
  double get progress =>
      targetAmount == 0 ? 0 : (currentAmount / targetAmount).clamp(0, 1);

  /// Months still needed at the planned monthly contribution, or null when
  /// no contribution is planned.
  int? get monthsToGo {
    if (remaining <= 0) return 0;
    if (monthlyContribution <= 0) return null;
    return (remaining / monthlyContribution).ceil();
  }

  DateTime? get estimatedCompletion {
    final m = monthsToGo;
    if (m == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month + m, now.day);
  }

  /// True when the estimate lands after the target date.
  bool get isBehindSchedule {
    final est = estimatedCompletion;
    if (est == null) return remaining > 0;
    return est.isAfter(DateTime.parse(targetDate));
  }

  /// Monthly amount needed to hit the target date.
  double get requiredMonthly {
    final now = DateTime.now();
    final target = DateTime.parse(targetDate);
    final months =
        max(1, (target.year - now.year) * 12 + target.month - now.month);
    return remaining / months;
  }

  factory SavingsGoal.fromMap(Map<String, Object?> m) => SavingsGoal(
        id: m['GoalId'] as String,
        userId: m['UserId'] as String,
        name: m['GoalName'] as String,
        targetAmount: (m['TargetAmount'] as num).toDouble(),
        currentAmount: (m['CurrentAmount'] as num).toDouble(),
        targetDate: m['TargetDate'] as String,
        monthlyContribution: (m['MonthlyContribution'] as num).toDouble(),
        status: m['Status'] as String? ?? 'active',
        milestones: ((m['Milestones'] as String?) ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toList(),
        createdAt: m['CreatedAt'] as String,
        completedAt: m['CompletedAt'] as String?,
      );

  Map<String, Object?> toMap() => {
        'GoalId': id,
        'UserId': userId,
        'GoalName': name,
        'TargetAmount': targetAmount,
        'CurrentAmount': currentAmount,
        'TargetDate': targetDate,
        'MonthlyContribution': monthlyContribution,
        'Status': status,
        'Milestones': milestones.join(','),
        'CreatedAt': createdAt,
        'CompletedAt': completedAt,
      };

  SavingsGoal copyWith({
    String? name,
    double? targetAmount,
    double? currentAmount,
    String? targetDate,
    double? monthlyContribution,
    String? status,
    List<int>? milestones,
    String? completedAt,
  }) =>
      SavingsGoal(
        id: id,
        userId: userId,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        targetDate: targetDate ?? this.targetDate,
        monthlyContribution: monthlyContribution ?? this.monthlyContribution,
        status: status ?? this.status,
        milestones: milestones ?? this.milestones,
        createdAt: createdAt,
        completedAt: completedAt ?? this.completedAt,
      );
}
