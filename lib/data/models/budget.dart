class Budget {
  final String id;
  final String userId;
  final String month; // yyyy-MM
  final String? categoryId; // null = overall monthly budget
  final double limitAmount;
  final int alertThreshold; // percent
  final String createdAt;

  const Budget({
    required this.id,
    required this.userId,
    required this.month,
    this.categoryId,
    required this.limitAmount,
    this.alertThreshold = 80,
    required this.createdAt,
  });

  bool get isOverall => categoryId == null;

  factory Budget.fromMap(Map<String, Object?> m) => Budget(
        id: m['BudgetId'] as String,
        userId: m['UserId'] as String,
        month: m['Month'] as String,
        categoryId: m['CategoryId'] as String?,
        limitAmount: (m['LimitAmount'] as num).toDouble(),
        alertThreshold: m['AlertThreshold'] as int? ?? 80,
        createdAt: m['CreatedAt'] as String,
      );

  Map<String, Object?> toMap() => {
        'BudgetId': id,
        'UserId': userId,
        'Month': month,
        'CategoryId': categoryId,
        'LimitAmount': limitAmount,
        'AlertThreshold': alertThreshold,
        'CreatedAt': createdAt,
      };
}

/// A budget together with what has been spent against it.
class BudgetUsage {
  final Budget budget;
  final double spent;
  const BudgetUsage(this.budget, this.spent);

  double get remaining => budget.limitAmount - spent;
  double get ratio => budget.limitAmount == 0 ? 0 : spent / budget.limitAmount;
  bool get isOver => spent > budget.limitAmount;
  bool get isNearLimit => !isOver && ratio * 100 >= budget.alertThreshold;
}
