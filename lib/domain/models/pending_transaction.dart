class PendingTransactionStatus {
  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String ignored = 'ignored';
}

class PendingTransaction {
  final String id;
  final double amount;
  final String transactionType; // 'debit'
  final String? sender;
  final String? bankName;
  final String? accountIdentifier;
  final String? payeeIdentifier;
  final String? parsedPayee;
  final String? referenceId;
  final int smsTimestamp; // Milliseconds since epoch
  final String rawSms;
  final String status; // 'pending', 'confirmed', 'ignored'
  final int createdAt; // Milliseconds since epoch
  final String fingerprint;
  final String? suggestedPaymentMethod;

  PendingTransaction({
    required this.id,
    required this.amount,
    this.transactionType = 'debit',
    this.sender,
    this.bankName,
    this.accountIdentifier,
    this.payeeIdentifier,
    this.parsedPayee,
    this.referenceId,
    required this.smsTimestamp,
    required this.rawSms,
    this.status = PendingTransactionStatus.pending,
    required this.createdAt,
    required this.fingerprint,
    this.suggestedPaymentMethod,
  });

  bool get isPending => status == PendingTransactionStatus.pending;
  bool get isConfirmed => status == PendingTransactionStatus.confirmed;
  bool get isIgnored => status == PendingTransactionStatus.ignored;

  static String computeFingerprint({
    String? referenceId,
    String? accountIdentifier,
    String? payeeIdentifier,
    required double amount,
    required int smsTimestamp,
  }) {
    if (referenceId != null && referenceId.trim().isNotEmpty) {
      return 'REF_${referenceId.trim().toUpperCase()}';
    }
    final acct = accountIdentifier?.trim().toUpperCase() ?? 'NA';
    final payee = payeeIdentifier?.trim().toLowerCase() ?? 'NA';
    final amt = amount.toStringAsFixed(2);
    // Bucket to 5-minute interval (300,000 ms)
    final timeBucket = smsTimestamp ~/ 300000;
    return 'FP_${acct}_${payee}_${amt}_$timeBucket';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'transaction_type': transactionType,
      'sender': sender ?? '',
      'bank_name': bankName,
      'account_identifier': accountIdentifier,
      'payee_identifier': payeeIdentifier,
      'parsed_payee': parsedPayee,
      'reference_id': referenceId,
      'sms_timestamp': smsTimestamp,
      'raw_sms': rawSms,
      'status': status,
      'created_at': createdAt,
      'fingerprint': fingerprint,
    };
  }

  factory PendingTransaction.fromMap(Map<String, dynamic> map) {
    int parseTime(dynamic val) {
      if (val is int) return val;
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed.millisecondsSinceEpoch;
        final asInt = int.tryParse(val);
        if (asInt != null) return asInt;
      }
      return DateTime.now().millisecondsSinceEpoch;
    }

    final amount = (map['amount'] as num).toDouble();
    final smsTime = parseTime(map['sms_timestamp']);
    final ref = map['reference_id'] as String?;
    final acct = map['account_identifier'] as String?;
    final payeeId = map['payee_identifier'] as String?;

    return PendingTransaction(
      id: map['id'] as String,
      amount: amount,
      transactionType: map['transaction_type'] as String? ?? 'debit',
      sender: map['sender'] as String?,
      bankName: map['bank_name'] as String?,
      accountIdentifier: acct,
      payeeIdentifier: payeeId,
      parsedPayee: map['parsed_payee'] as String?,
      referenceId: ref,
      smsTimestamp: smsTime,
      rawSms: map['raw_sms'] as String? ?? '',
      status: map['status'] as String? ?? PendingTransactionStatus.pending,
      createdAt: parseTime(map['created_at']),
      fingerprint: map['fingerprint'] as String? ??
          computeFingerprint(
            referenceId: ref,
            accountIdentifier: acct,
            payeeIdentifier: payeeId,
            amount: amount,
            smsTimestamp: smsTime,
          ),
      suggestedPaymentMethod: map['suggested_payment_method'] as String?,
    );
  }

  PendingTransaction copyWith({
    String? id,
    double? amount,
    String? transactionType,
    String? sender,
    String? bankName,
    String? accountIdentifier,
    String? payeeIdentifier,
    String? parsedPayee,
    String? referenceId,
    int? smsTimestamp,
    String? rawSms,
    String? status,
    int? createdAt,
    String? fingerprint,
    String? suggestedPaymentMethod,
  }) {
    return PendingTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      sender: sender ?? this.sender,
      bankName: bankName ?? this.bankName,
      accountIdentifier: accountIdentifier ?? this.accountIdentifier,
      payeeIdentifier: payeeIdentifier ?? this.payeeIdentifier,
      parsedPayee: parsedPayee ?? this.parsedPayee,
      referenceId: referenceId ?? this.referenceId,
      smsTimestamp: smsTimestamp ?? this.smsTimestamp,
      rawSms: rawSms ?? this.rawSms,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      fingerprint: fingerprint ?? this.fingerprint,
      suggestedPaymentMethod: suggestedPaymentMethod ?? this.suggestedPaymentMethod,
    );
  }
}
