import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../../domain/models/quick_add_pin.dart';
import '../../domain/models/quick_add_suggestion.dart';
import 'expense_dao.dart';

class QuickAddDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ExpenseDao _expenseDao = ExpenseDao();
  final Uuid _uuid = const Uuid();

  Future<List<QuickAddSuggestion>> getQuickAddSuggestions({
    int limit = 8,
    int daysLookback = 90,
  }) async {
    final db = await _dbHelper.database;
    final today = DateTime.now();
    final lookbackDate = today.subtract(Duration(days: daysLookback));
    final lookbackStr = '${lookbackDate.year.toString().padLeft(4, '0')}-${lookbackDate.month.toString().padLeft(2, '0')}-${lookbackDate.day.toString().padLeft(2, '0')}';

    final results = <QuickAddSuggestion>[];
    final seenKeys = <String>{};

    // 1. Fetch user-pinned items first
    final pinsRes = await db.rawQuery('''
      SELECT p.*, s.name as store_name, t.name as tag_name
      FROM quick_add_pins p
      LEFT JOIN stores s ON p.store_id = s.id
      LEFT JOIN tags t ON p.tag_id = t.id
      WHERE p.is_pinned = 1 AND p.is_hidden = 0 AND p.deleted_at IS NULL
      ORDER BY p.created_at DESC
    ''');

    for (final p in pinsRes) {
      final pin = QuickAddPin.fromMap(p);
      final storeName = p['store_name'] as String? ?? 'Unspecified';
      final tagName = p['tag_name'] as String? ?? 'Uncategorized';
      final desc = pin.description ?? '';
      final key = '${pin.storeId}_${pin.tagId}_${pin.amount}_${desc.toLowerCase()}';
      seenKeys.add(key);

      results.add(
        QuickAddSuggestion(
          pinId: pin.id,
          isPinned: true,
          amount: pin.amount,
          storeId: pin.storeId,
          storeName: storeName,
          tagId: pin.tagId,
          tagName: tagName,
          description: desc,
          paymentMethod: pin.paymentMethod,
          frequency: 1,
          score: 999.0,
          icon: QuickAddSuggestion.detectIcon(desc, storeName, tagName),
        ),
      );
    }

    // 2. Fetch hidden keys to filter out
    final hiddenRes = await db.rawQuery('''
      SELECT store_id, tag_id, amount, description
      FROM quick_add_pins
      WHERE is_hidden = 1 AND deleted_at IS NULL
    ''');
    final hiddenKeys = <String>{};
    for (final h in hiddenRes) {
      final sId = h['store_id'] as String?;
      final tId = h['tag_id'] as String?;
      final amt = (h['amount'] as num).toDouble();
      final desc = (h['description'] as String?)?.toLowerCase() ?? '';
      hiddenKeys.add('${sId}_${tId}_${amt}_$desc');
    }

    // 3. Query historical patterns grouped by (store_id, tag_id, amount, description)
    final expenseGroups = await db.rawQuery('''
      SELECT e.store_id, e.tag_id, e.amount, e.description, e.payment_method,
             s.name as store_name, t.name as tag_name,
             COUNT(e.id) as freq, MAX(e.date) as last_used
      FROM expenses e
      LEFT JOIN stores s ON e.store_id = s.id
      LEFT JOIN tags t ON e.tag_id = t.id
      WHERE e.date >= ? AND e.deleted_at IS NULL
      GROUP BY e.store_id, e.tag_id, e.amount, e.description, e.payment_method
    ''', [lookbackStr]);

    final autoSuggestions = <QuickAddSuggestion>[];
    for (final row in expenseGroups) {
      final sId = row['store_id'] as String?;
      final tId = row['tag_id'] as String?;
      final amt = (row['amount'] as num).toDouble();
      final desc = (row['description'] as String?)?.trim() ?? '';
      final key = '${sId}_${tId}_${amt}_${desc.toLowerCase()}';

      if (seenKeys.contains(key) || hiddenKeys.contains(key)) continue;

      final storeName = row['store_name'] as String? ?? 'Unspecified';
      final tagName = row['tag_name'] as String? ?? 'Uncategorized';
      final pm = row['payment_method'] as String? ?? 'Cash';
      final freq = (row['freq'] as num).toInt();

      final lastUsedStr = row['last_used'] as String?;
      final lastDate = lastUsedStr != null ? DateTime.tryParse(lastUsedStr) ?? today : today;
      final daysAgo = today.difference(lastDate).inDays.clamp(0, 9999);

      // Ranking Formula: Frequency * (1.0 / (1.0 + 0.05 * daysAgo))
      final recencyFactor = 1.0 / (1.0 + 0.05 * daysAgo);
      final score = freq * recencyFactor;

      autoSuggestions.add(
        QuickAddSuggestion(
          pinId: null,
          isPinned: false,
          amount: amt,
          storeId: sId,
          storeName: storeName,
          tagId: tId,
          tagName: tagName,
          description: desc,
          paymentMethod: pm,
          frequency: freq,
          score: score,
          icon: QuickAddSuggestion.detectIcon(desc, storeName, tagName),
        ),
      );
    }

    autoSuggestions.sort((a, b) => b.score.compareTo(a.score));

    final remaining = (limit - results.length).clamp(0, limit);
    results.addAll(autoSuggestions.take(remaining));
    return results;
  }

  Future<void> executeQuickAdd(QuickAddSuggestion item) async {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    await _expenseDao.createExpense(
      amount: item.amount,
      date: now,
      time: timeStr,
      description: item.description.isEmpty ? null : item.description,
      storeId: item.storeId,
      tagId: item.tagId,
      paymentMethod: item.paymentMethod,
    );
  }

  Future<void> pinQuickAddItem({
    required double amount,
    String? storeId,
    String? tagId,
    String? description,
    String paymentMethod = 'Cash',
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc();
    final pin = QuickAddPin(
      id: _uuid.v4(),
      amount: amount,
      storeId: storeId,
      tagId: tagId,
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      paymentMethod: paymentMethod,
      isPinned: true,
      isHidden: false,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('quick_add_pins', pin.toMap());
  }

  Future<void> hideQuickAddItem({
    required double amount,
    String? storeId,
    String? tagId,
    String? description,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc();
    final pin = QuickAddPin(
      id: _uuid.v4(),
      amount: amount,
      storeId: storeId,
      tagId: tagId,
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      paymentMethod: 'Cash',
      isPinned: false,
      isHidden: true,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('quick_add_pins', pin.toMap());
  }
}
