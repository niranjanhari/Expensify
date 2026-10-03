class AccountBalance {
  final String id;
  final double baselineAmount;
  final DateTime setAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  AccountBalance({
    required this.id,
    required this.baselineAmount,
    required this.setAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'baseline_amount': baselineAmount,
      'set_at': setAt.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory AccountBalance.fromMap(Map<String, dynamic> map) {
    return AccountBalance(
      id: map['id'] as String,
      baselineAmount: (map['baseline_amount'] as num).toDouble(),
      setAt: DateTime.parse(map['set_at'] as String),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
    );
  }
}

class BalanceCalculation {
  final bool isConfigured;
  final double baselineAmount;
  final double currentBalance;
  final double expensesSinceBaseline;
  final DateTime? setAt;
  final String? notes;

  BalanceCalculation({
    required this.isConfigured,
    required this.baselineAmount,
    required this.currentBalance,
    required this.expensesSinceBaseline,
    this.setAt,
    this.notes,
  });
}
