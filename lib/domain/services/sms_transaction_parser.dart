import 'dart:math';
import '../models/pending_transaction.dart';

class ParsedTransaction {
  final double amount;
  final String transactionType;
  final String? bankName;
  final String? accountIdentifier;
  final String? payeeIdentifier;
  final String? parsedPayee;
  final String? referenceId;
  final String? suggestedPaymentMethod;
  final int smsTimestamp;

  const ParsedTransaction({
    required this.amount,
    this.transactionType = 'debit',
    this.bankName,
    this.accountIdentifier,
    this.payeeIdentifier,
    this.parsedPayee,
    this.referenceId,
    this.suggestedPaymentMethod,
    required this.smsTimestamp,
  });

  PendingTransaction toPendingTransaction({
    required String rawSender,
    required String rawSms,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final fingerprint = PendingTransaction.computeFingerprint(
      referenceId: referenceId,
      accountIdentifier: accountIdentifier,
      payeeIdentifier: payeeIdentifier,
      amount: amount,
      smsTimestamp: smsTimestamp,
    );

    return PendingTransaction(
      id: 'tx_${now}_${Random().nextInt(99999)}',
      amount: amount,
      transactionType: transactionType,
      sender: rawSender,
      bankName: bankName,
      accountIdentifier: accountIdentifier,
      payeeIdentifier: payeeIdentifier,
      parsedPayee: parsedPayee,
      referenceId: referenceId,
      smsTimestamp: smsTimestamp,
      rawSms: rawSms,
      status: PendingTransactionStatus.pending,
      createdAt: now,
      fingerprint: fingerprint,
    );
  }
}

class SmsTransactionParser {
  // Amount regex: ₹500, Rs. 1,250.50, INR 450, INR 1200.00
  static final RegExp _amountRegex = RegExp(
    r'(?:rs\.?|inr|₹)\s*([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  // Account / Card identifiers: A/c **1234, a/c ending 1234, card ending 4321, etc.
  static final List<RegExp> _accountRegexes = [
    RegExp(r'(?:a\/c|acct|account|card)\s*(?:no\.?)?\s*(?:ending\s*)?([x\*]*\d{3,4})\b', caseSensitive: false),
    RegExp(r'\b([x\*]{2,}\d{3,4})\b', caseSensitive: false),
  ];

  // UPI VPA pattern: e.g. someone@okaxis, merchant@icici, 9876543210@paytm
  static final RegExp _upiIdRegex = RegExp(
    r'\b([a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64})\b',
    caseSensitive: false,
  );

  // Reference / UTR pattern: UPI/321456789012, Ref No: 123456, UTR: 12345, Txn ID 123456
  static final List<RegExp> _referenceRegexes = [
    RegExp(r'(?:ref(?:\s*no\.?|\s*id)?|rrn|utr|txn\s*id|transaction\s*id)\s*[:\-#]?\s*([a-zA-Z0-9]{6,25})', caseSensitive: false),
    RegExp(r'\bupi\/(?:cr\/)?([0-9]{8,16})\b', caseSensitive: false),
  ];

  // Payee / Merchant clues
  // e.g. "paid to Rahul", "transferred to Swiggy", "by UPI to Swiggy", "to Swiggy", "at Starbucks", "info: VPA xyz"
  static final List<RegExp> _payeeRegexes = [
    RegExp(r'(?:paid\s+to|transferred\s+to|sent\s+to|transfer\s+to|payment\s+to|(?:by\s+)?upi\s+to|\bto)\s+([A-Za-z0-9\.\s&-]{2,30}?)(?=\s+(?:on|ref|upi|avl|bal|using|from|via|\.|\,|$))', caseSensitive: false),
    RegExp(r'(?:purchase\s+at|spent\s+at|at)\s+([A-Za-z0-9\.\s&-]{2,30}?)(?=\s+(?:on|ref|upi|avl|bal|using|from|via|\.|\,|$))', caseSensitive: false),
    RegExp(r'(?:to\s+vpa|vpa)\s+([a-zA-Z0-9.\-_]+@[a-zA-Z]+)', caseSensitive: false),
    RegExp(r'(?:info\/|info:)\s*([A-Za-z0-9\s]+?)(?=\/|\.|\,|$)', caseSensitive: false),
  ];

  static final Map<String, String> _senderBankMap = {
    'HDFC': 'HDFC Bank',
    'HDFCBK': 'HDFC Bank',
    'SBI': 'State Bank of India',
    'SBIN': 'State Bank of India',
    'ICICI': 'ICICI Bank',
    'ICICIB': 'ICICI Bank',
    'AXIS': 'Axis Bank',
    'AXISBK': 'Axis Bank',
    'KOTAK': 'Kotak Mahindra Bank',
    'KOTAKB': 'Kotak Mahindra Bank',
    'PNB': 'Punjab National Bank',
    'BOB': 'Bank of Baroda',
    'CANARA': 'Canara Bank',
    'UNIONB': 'Union Bank',
    'PAYTM': 'Paytm Payments Bank',
    'IDFC': 'IDFC First Bank',
    'YESB': 'Yes Bank',
    'INDUS': 'IndusInd Bank',
    'CREDPAY': 'CRED',
    'GPAY': 'Google Pay',
    'PHONEPE': 'PhonePe',
  };

  /// Parses text of an incoming SMS and extracts transaction attributes.
  static ParsedTransaction? parse(
    String body, {
    String? sender,
    int? timestampMs,
  }) {
    final clean = body.trim();
    if (clean.isEmpty) return null;

    // 1. Amount extraction (mandatory)
    final amountMatch = _amountRegex.firstMatch(clean);
    if (amountMatch == null) return null;

    final amountStr = amountMatch.group(1)?.replaceAll(',', '') ?? '';
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return null;

    // 2. Bank name from sender or body
    String? bankName = _detectBankName(sender, clean);

    // 3. Account identifier
    String? accountIdentifier;
    for (final reg in _accountRegexes) {
      final match = reg.firstMatch(clean);
      if (match != null) {
        accountIdentifier = match.group(1)?.trim();
        break;
      }
    }

    // 4. UPI ID
    String? payeeIdentifier;
    final upiMatch = _upiIdRegex.firstMatch(clean);
    if (upiMatch != null) {
      payeeIdentifier = upiMatch.group(1)?.trim().toLowerCase();
    }

    // 5. Reference ID
    String? referenceId;
    for (final reg in _referenceRegexes) {
      final match = reg.firstMatch(clean);
      if (match != null) {
        referenceId = match.group(1)?.trim();
        break;
      }
    }

    // 6. Payee candidate
    String? parsedPayee;
    for (final reg in _payeeRegexes) {
      final match = reg.firstMatch(clean);
      if (match != null) {
        final candidate = match.group(1)?.trim();
        if (candidate != null && candidate.isNotEmpty && candidate.length > 1) {
          final lowerCand = candidate.toLowerCase();
          if (lowerCand == 'your account' || lowerCand.startsWith('a/c') || lowerCand == 'account') {
            continue;
          }
          // If candidate looks like a UPI address
          if (candidate.contains('@')) {
            payeeIdentifier ??= candidate.toLowerCase();
            // derive clean name from upi prefix if sensible
            final parts = candidate.split('@');
            parsedPayee = _cleanPayeeName(parts[0]);
          } else {
            parsedPayee = _cleanPayeeName(candidate);
          }
          break;
        }
      }
    }

    // If no payee found but we have payeeIdentifier
    if (parsedPayee == null && payeeIdentifier != null) {
      final parts = payeeIdentifier.split('@');
      parsedPayee = _cleanPayeeName(parts[0]);
    }

    // 7. Suggested payment method
    String? suggestedPaymentMethod;
    final lower = clean.toLowerCase();
    if (payeeIdentifier != null || lower.contains('upi') || lower.contains('vpa')) {
      suggestedPaymentMethod = 'UPI';
    } else if (lower.contains('credit card') || lower.contains('card ending')) {
      suggestedPaymentMethod = 'Card';
    } else if (lower.contains('debit card')) {
      suggestedPaymentMethod = 'Debit Card';
    } else if (lower.contains('netbanking') || lower.contains('neft') || lower.contains('rtgs') || lower.contains('imps')) {
      suggestedPaymentMethod = 'Bank Transfer';
    }

    return ParsedTransaction(
      amount: amount,
      transactionType: 'debit',
      bankName: bankName,
      accountIdentifier: accountIdentifier,
      payeeIdentifier: payeeIdentifier,
      parsedPayee: parsedPayee,
      referenceId: referenceId,
      suggestedPaymentMethod: suggestedPaymentMethod,
      smsTimestamp: timestampMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  static String? _detectBankName(String? sender, String body) {
    if (sender != null) {
      final cleanSender = sender.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      for (final entry in _senderBankMap.entries) {
        if (cleanSender.contains(entry.key)) {
          return entry.value;
        }
      }
    }

    // Fallback: check body
    final upperBody = body.toUpperCase();
    for (final entry in _senderBankMap.entries) {
      if (upperBody.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  static String _cleanPayeeName(String input) {
    var s = input.trim();
    // remove leading symbols
    s = s.replaceAll(RegExp(r'^[:\-–—\.]+\s*'), '');
    // remove trailing words like "on", "using", "from", "ref"
    s = s.replaceAll(RegExp(r'\s+(?:on|ref|upi|avl|bal|using|from|via)$', caseSensitive: false), '');
    // remove punctuation
    s = s.replaceAll(RegExp(r'[,\.;]$'), '');
    return s.trim();
  }
}
