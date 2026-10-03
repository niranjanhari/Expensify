class PayeeIdentifierType {
  static const String bankAccount = 'bank_account';
  static const String upiId = 'upi_id';
  static const String merchantIdentifier = 'merchant_identifier';
}

class PayeeMapping {
  final String id;
  final String identifierType; // 'bank_account', 'upi_id', 'merchant_identifier'
  final String identifier; // e.g. "XX1234", "rahul@upi"
  final String payeeName; // e.g. "Rahul", "Swiggy"
  final String? defaultTagId;
  final DateTime createdAt;
  final DateTime updatedAt;

  PayeeMapping({
    required this.id,
    required this.identifierType,
    required this.identifier,
    required this.payeeName,
    this.defaultTagId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'identifier_type': identifierType,
      'identifier': identifier,
      'payee_name': payeeName,
      'default_tag_id': defaultTagId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory PayeeMapping.fromMap(Map<String, dynamic> map) {
    DateTime parseTime(dynamic val) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed.toLocal();
      }
      return DateTime.now();
    }

    return PayeeMapping(
      id: map['id'] as String,
      identifierType: map['identifier_type'] as String,
      identifier: map['identifier'] as String,
      payeeName: map['payee_name'] as String,
      defaultTagId: map['default_tag_id'] as String?,
      createdAt: parseTime(map['created_at']),
      updatedAt: parseTime(map['updated_at']),
    );
  }

  PayeeMapping copyWith({
    String? id,
    String? identifierType,
    String? identifier,
    String? payeeName,
    String? defaultTagId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PayeeMapping(
      id: id ?? this.id,
      identifierType: identifierType ?? this.identifierType,
      identifier: identifier ?? this.identifier,
      payeeName: payeeName ?? this.payeeName,
      defaultTagId: defaultTagId ?? this.defaultTagId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
