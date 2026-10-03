class Expense {
  final String id;
  final double amount;
  final DateTime date;
  final String? time;
  final String? description;
  final String? storeId;
  final String? tagId;
  final String paymentMethod;
  final bool isRecurring;
  final String? recurringExpenseId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  // Attached joined data for UI display
  final String? storeName;
  final String? tagName;

  Expense({
    required this.id,
    required this.amount,
    required this.date,
    this.time,
    this.description,
    this.storeId,
    this.tagId,
    this.paymentMethod = 'Cash',
    this.isRecurring = false,
    this.recurringExpenseId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.storeName,
    this.tagName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'time': time,
      'description': description,
      'store_id': storeId,
      'tag_id': tagId,
      'payment_method': paymentMethod,
      'is_recurring': isRecurring ? 1 : 0,
      'recurring_expense_id': recurringExpenseId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      time: map['time'] as String?,
      description: map['description'] as String?,
      storeId: map['store_id'] as String?,
      tagId: map['tag_id'] as String?,
      paymentMethod: map['payment_method'] as String? ?? 'Cash',
      isRecurring: (map['is_recurring'] as int?) == 1,
      recurringExpenseId: map['recurring_expense_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
      storeName: map['store_name'] as String?,
      tagName: map['tag_name'] as String?,
    );
  }
}

