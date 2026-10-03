class Budget {
  final String id;
  final String? tagId;
  final double amount;
  final String period;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  // Joined tag name
  final String? tagName;

  Budget({
    required this.id,
    this.tagId,
    required this.amount,
    this.period = 'monthly',
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.tagName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tag_id': tagId,
      'amount': amount,
      'period': period,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      tagId: map['tag_id'] as String?,
      amount: (map['amount'] as num).toDouble(),
      period: map['period'] as String? ?? 'monthly',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
      tagName: map['tag_name'] as String?,
    );
  }
}

class BudgetProgress {
  final String id;
  final String? tagId;
  final String categoryName;
  final double budgetAmount;
  final double spentAmount;
  final double remainingAmount;
  final double percentageUsed;
  final String statusMessage;

  BudgetProgress({
    required this.id,
    this.tagId,
    required this.categoryName,
    required this.budgetAmount,
    required this.spentAmount,
    required this.remainingAmount,
    required this.percentageUsed,
    required this.statusMessage,
  });
}
