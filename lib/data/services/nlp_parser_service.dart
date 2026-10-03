class ParsedSentenceCandidate {
  final double amount;
  final String store;
  final String tag;
  final String description;
  final String paymentMethod;
  final double confidence;

  ParsedSentenceCandidate({
    required this.amount,
    required this.store,
    required this.tag,
    required this.description,
    required this.paymentMethod,
    required this.confidence,
  });
}

class NlpParserService {
  static ParsedSentenceCandidate parseSentence(String text, {List<String> knownStores = const []}) {
    final lower = text.toLowerCase();

    // 1. Amount Extraction (e.g. ₹150, rs 80, 250.50, 80)
    double extractedAmount = 0.0;
    final amtMatch = RegExp(r'(?:₹|rs\.?|inr)?\s*(\d+(?:\.\d{1,2})?)(?:\s*(?:rs|rupees|bucks))?', caseSensitive: false)
        .firstMatch(lower);
    if (amtMatch != null && amtMatch.group(1) != null) {
      extractedAmount = double.tryParse(amtMatch.group(1)!) ?? 0.0;
    } else {
      final numMatch = RegExp(r'\b(\d+)\b').firstMatch(lower);
      if (numMatch != null && numMatch.group(1) != null) {
        extractedAmount = double.tryParse(numMatch.group(1)!) ?? 0.0;
      }
    }

    // 2. Payment Method
    String detectedPm = 'Cash';
    if (lower.contains('gpay') || lower.contains('google pay')) {
      detectedPm = 'GPay';
    } else if (lower.contains('upi') || lower.contains('phonepe') || lower.contains('paytm')) {
      detectedPm = 'UPI';
    } else if (lower.contains('card') || lower.contains('credit') || lower.contains('debit')) {
      detectedPm = 'Card';
    } else if (lower.contains('bank') || lower.contains('transfer') || lower.contains('neft')) {
      detectedPm = 'Bank Transfer';
    } else if (lower.contains('cash')) {
      detectedPm = 'Cash';
    }

    // 3. Known Store Matching
    String? detectedStore;
    for (final s in knownStores) {
      if (lower.contains(s.toLowerCase())) {
        detectedStore = s;
        break;
      }
    }

    if (detectedStore == null) {
      final prepMatch = RegExp(r'\b(?:at|from|to)\s+([a-zA-Z0-9\s&]+?)(?:\s+(?:for|using|with|via|on|in|rs|₹|\d|$))', caseSensitive: false)
          .firstMatch(text);
      if (prepMatch != null && prepMatch.group(1) != null) {
        final cand = prepMatch.group(1)!.trim();
        if (cand.isNotEmpty && cand.split(' ').length <= 4) {
          detectedStore = cand;
        }
      }
    }

    // 4. Category Prediction via keywords
    String detectedTag = 'Misc';
    if (lower.contains('canteen') || lower.contains('lunch') || lower.contains('dinner') || lower.contains('breakfast') || lower.contains('coffee') || lower.contains('food') || lower.contains('swiggy') || lower.contains('zomato') || lower.contains('tea') || lower.contains('snack')) {
      detectedTag = 'Food';
    } else if (lower.contains('uber') || lower.contains('ola') || lower.contains('bus') || lower.contains('metro') || lower.contains('fuel') || lower.contains('auto') || lower.contains('petrol')) {
      detectedTag = 'Transport';
    } else if (lower.contains('recharge') || lower.contains('bill') || lower.contains('wifi') || lower.contains('internet') || lower.contains('electricity')) {
      detectedTag = 'Bills';
    } else if (lower.contains('amazon') || lower.contains('shopping') || lower.contains('clothes') || lower.contains('shoes') || lower.contains('flipkart')) {
      detectedTag = 'Shopping';
    } else if (lower.contains('movie') || lower.contains('cinema') || lower.contains('netflix') || lower.contains('spotify') || lower.contains('game')) {
      detectedTag = 'Entertainment';
    } else if (lower.contains('medicine') || lower.contains('doctor') || lower.contains('health') || lower.contains('pharmacy')) {
      detectedTag = 'Health';
    } else if (lower.contains('book') || lower.contains('course') || lower.contains('tuition') || lower.contains('education') || lower.contains('college')) {
      detectedTag = 'Education';
    } else if (lower.contains('rent')) {
      detectedTag = 'Rent';
    }

    // 5. Description Extraction: look for 'for <desc>'
    String detectedDesc = text.trim();
    final descMatch = RegExp(r'\bfor\s+([a-zA-Z0-9\s&]+?)(?:\s+(?:at|using|with|via|on|in|rs|₹|\d|$))', caseSensitive: false)
        .firstMatch(text);
    if (descMatch != null && descMatch.group(1) != null) {
      detectedDesc = descMatch.group(1)!.trim();
    }

    return ParsedSentenceCandidate(
      amount: extractedAmount,
      store: detectedStore ?? 'Unspecified Merchant',
      tag: detectedTag,
      description: detectedDesc,
      paymentMethod: detectedPm,
      confidence: extractedAmount > 0 ? 0.88 : 0.50,
    );
  }
}
