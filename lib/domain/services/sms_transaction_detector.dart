class SmsDetectionResult {
  final bool isTransaction;
  final bool isDebit;
  final double confidence;
  final String? reason;

  const SmsDetectionResult({
    required this.isTransaction,
    required this.isDebit,
    this.confidence = 0.0,
    this.reason,
  });

  @override
  String toString() {
    return 'SmsDetectionResult(isTransaction: $isTransaction, isDebit: $isDebit, confidence: $confidence, reason: $reason)';
  }
}

class SmsTransactionDetector {
  static final List<RegExp> _otpPatterns = [
    RegExp(r'\b(otp|one\s*time\s*password|verification\s*code|secret\s*code|login\s*code|do\s*not\s*share)\b', caseSensitive: false),
    RegExp(r'\b(code\s*is|use\s*otp|your\s*otp)\b', caseSensitive: false),
  ];

  static final List<RegExp> _promoPatterns = [
    RegExp(r'\b(apply\s*now|pre-?approved|instant\s*loan|personal\s*loan|congratulations|discount|flat\s*off|offer\s*valid|cashback\s*up\s*to|zero\s*interest)\b', caseSensitive: false),
    RegExp(r'\b(win|lottery|free\s*voucher|upgrade\s*your\s*card|promo\s*code|points\s*expir)\b', caseSensitive: false),
  ];

  static final List<RegExp> _debitPatterns = [
    RegExp(r'\b(debited|debit|withdrawn|spent|paid|payment\s*of|payment\s*to|sent\s*to|transferred\s*to|transfer\s*to|purchase\s*at|charged\s*to|deducted)\b', caseSensitive: false),
    RegExp(r'\b(vpa|upi\s*payment|txn\s*of|txn\s*successful)\b', caseSensitive: false),
  ];

  static final List<RegExp> _creditPatterns = [
    RegExp(r'\b(credited|credit|received|deposited|refund|cashback\s*received)\b', caseSensitive: false),
  ];

  static final RegExp _amountRegex = RegExp(
    r'(?:rs\.?|inr|₹)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  /// Evaluates an SMS text and returns transaction detection flags.
  static SmsDetectionResult detect(String body, {String? sender}) {
    final clean = body.trim();
    if (clean.isEmpty) {
      return const SmsDetectionResult(isTransaction: false, isDebit: false, reason: 'Empty body');
    }

    // 1. Check for OTP messages
    for (final pattern in _otpPatterns) {
      if (pattern.hasMatch(clean)) {
        return const SmsDetectionResult(
          isTransaction: false,
          isDebit: false,
          confidence: 0.95,
          reason: 'OTP detected',
        );
      }
    }

    // 2. Check for Promotional messages
    for (final pattern in _promoPatterns) {
      if (pattern.hasMatch(clean)) {
        return const SmsDetectionResult(
          isTransaction: false,
          isDebit: false,
          confidence: 0.90,
          reason: 'Promotional content detected',
        );
      }
    }

    // 3. Must contain an amount
    final hasAmount = _amountRegex.hasMatch(clean);
    if (!hasAmount) {
      return const SmsDetectionResult(
        isTransaction: false,
        isDebit: false,
        reason: 'No currency amount found',
      );
    }

    // 4. Check for Credit signals
    bool hasCreditSignal = false;
    for (final pattern in _creditPatterns) {
      if (pattern.hasMatch(clean)) {
        hasCreditSignal = true;
        break;
      }
    }

    // 5. Check for Debit signals
    bool hasDebitSignal = false;
    for (final pattern in _debitPatterns) {
      if (pattern.hasMatch(clean)) {
        hasDebitSignal = true;
        break;
      }
    }

    // If both credit and debit keywords match, determine priority based on wording
    if (hasCreditSignal && !hasDebitSignal) {
      return const SmsDetectionResult(
        isTransaction: true,
        isDebit: false,
        confidence: 0.85,
        reason: 'Credit transaction detected',
      );
    }

    if (hasDebitSignal) {
      return const SmsDetectionResult(
        isTransaction: true,
        isDebit: true,
        confidence: 0.90,
        reason: 'Debit transaction detected',
      );
    }

    // Balance only alert check (e.g., "Your available balance is Rs 500")
    if (clean.toLowerCase().contains('avl bal') ||
        clean.toLowerCase().contains('available balance') ||
        clean.toLowerCase().contains('clear bal')) {
      return const SmsDetectionResult(
        isTransaction: false,
        isDebit: false,
        confidence: 0.80,
        reason: 'Balance inquiry notification only',
      );
    }

    return const SmsDetectionResult(
      isTransaction: false,
      isDebit: false,
      reason: 'No clear debit or transaction pattern found',
    );
  }
}
