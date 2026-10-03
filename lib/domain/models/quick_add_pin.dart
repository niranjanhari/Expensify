class QuickAddPin {
  final String id;
  final String? storeId;
  final String? tagId;
  final double amount;
  final String? description;
  final String paymentMethod;
  final bool isPinned;
  final bool isHidden;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  QuickAddPin({
    required this.id,
    this.storeId,
    this.tagId,
    required this.amount,
    this.description,
    this.paymentMethod = 'Cash',
    this.isPinned = true,
    this.isHidden = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'store_id': storeId,
      'tag_id': tagId,
      'amount': amount,
      'description': description,
      'payment_method': paymentMethod,
      'is_pinned': isPinned ? 1 : 0,
      'is_hidden': isHidden ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory QuickAddPin.fromMap(Map<String, dynamic> map) {
    return QuickAddPin(
      id: map['id'] as String,
      storeId: map['store_id'] as String?,
      tagId: map['tag_id'] as String?,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      paymentMethod: map['payment_method'] as String? ?? 'Cash',
      isPinned: (map['is_pinned'] as int?) == 1,
      isHidden: (map['is_hidden'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
    );
  }
}
