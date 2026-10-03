class QuickAddSuggestion {
  final String? pinId;
  final bool isPinned;
  final double amount;
  final String? storeId;
  final String storeName;
  final String? tagId;
  final String tagName;
  final String description;
  final String paymentMethod;
  final int frequency;
  final double score;
  final String icon;

  QuickAddSuggestion({
    this.pinId,
    required this.isPinned,
    required this.amount,
    this.storeId,
    required this.storeName,
    this.tagId,
    required this.tagName,
    required this.description,
    required this.paymentMethod,
    required this.frequency,
    required this.score,
    required this.icon,
  });

  static String detectIcon(String? description, String? storeName, String? tagName) {
    final text = '${description ?? ''} ${storeName ?? ''} ${tagName ?? ''}'.toLowerCase();
    if (text.contains('coffee') || text.contains('tea') || text.contains('cafe') || text.contains('chai')) {
      return '☕';
    }
    if (text.contains('lunch') || text.contains('dinner') || text.contains('food') || text.contains('canteen') || text.contains('burger') || text.contains('pizza') || text.contains('swiggy') || text.contains('zomato')) {
      return '🍛';
    }
    if (text.contains('bus') || text.contains('metro') || text.contains('train') || text.contains('uber') || text.contains('ola') || text.contains('fuel') || text.contains('auto')) {
      return '🚌';
    }
    if (text.contains('recharge') || text.contains('phone') || text.contains('wifi') || text.contains('bill')) {
      return '📱';
    }
    if (text.contains('movie') || text.contains('cinema') || text.contains('game') || text.contains('netflix')) {
      return '🍿';
    }
    if (text.contains('amazon') || text.contains('shopping') || text.contains('clothes')) {
      return '🛍️';
    }
    if (text.contains('medicine') || text.contains('pharmacy') || text.contains('doctor')) {
      return '💊';
    }
    if (text.contains('book') || text.contains('course') || text.contains('college')) {
      return '📚';
    }
    return '⚡';
  }
}
