class RecurringExpense {
  final String id;
  final String description;
  final double amount;
  final String? storeId;
  final String? tagId;
  final String frequency;
  final DateTime nextDueDate;
  final bool active;
  final String paymentMethod;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  // Joined fields
  final String? storeName;
  final String? tagName;

  RecurringExpense({
    required this.id,
    required this.description,
    required this.amount,
    this.storeId,
    this.tagId,
    this.frequency = 'Monthly',
    required this.nextDueDate,
    this.active = true,
    this.paymentMethod = 'Cash',
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.storeName,
    this.tagName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'store_id': storeId,
      'tag_id': tagId,
      'frequency': frequency,
      'next_due_date': '${nextDueDate.year.toString().padLeft(4, '0')}-${nextDueDate.month.toString().padLeft(2, '0')}-${nextDueDate.day.toString().padLeft(2, '0')}',
      'active': active ? 1 : 0,
      'payment_method': paymentMethod,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory RecurringExpense.fromMap(Map<String, dynamic> map) {
    return RecurringExpense(
      id: map['id'] as String,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      storeId: map['store_id'] as String?,
      tagId: map['tag_id'] as String?,
      frequency: map['frequency'] as String? ?? 'Monthly',
      nextDueDate: DateTime.parse(map['next_due_date'] as String),
      active: (map['active'] as int?) == 1,
      paymentMethod: map['payment_method'] as String? ?? 'Cash',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
      storeName: map['store_name'] as String?,
      tagName: map['tag_name'] as String?,
    );
  }
}
