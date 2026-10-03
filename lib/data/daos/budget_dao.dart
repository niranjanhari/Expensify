import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../../domain/models/budget.dart';

class BudgetDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  Future<Budget> setBudget({
    required double amount,
    String? tagId,
    String period = 'monthly',
  }) async {
    if (amount <= 0.0) throw ArgumentError('Budget amount must be positive.');

    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc();

    // Check existing
    final existingQuery = tagId == null
        ? 'SELECT * FROM budgets WHERE tag_id IS NULL AND period = ? AND deleted_at IS NULL LIMIT 1'
        : 'SELECT * FROM budgets WHERE tag_id = ? AND period = ? AND deleted_at IS NULL LIMIT 1';
    final existingArgs = tagId == null ? [period] : [tagId, period];
    final existingRows = await db.rawQuery(existingQuery, existingArgs);

    if (existingRows.isNotEmpty) {
      final existingId = existingRows.first['id'] as String;
      await db.update(
        'budgets',
        {'amount': amount, 'updated_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [existingId],
      );
      return Budget(
        id: existingId,
        tagId: tagId,
        amount: amount,
        period: period,
        createdAt: DateTime.parse(existingRows.first['created_at'] as String),
        updatedAt: now,
      );
    }

    final newBudget = Budget(
      id: _uuid.v4(),
      tagId: tagId,
      amount: amount,
      period: period,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('budgets', newBudget.toMap());
    return newBudget;
  }

  Future<void> deleteBudget(String id) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'budgets',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Budget>> getAllBudgets() async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT b.*, t.name as tag_name
      FROM budgets b
      LEFT JOIN tags t ON b.tag_id = t.id
      WHERE b.deleted_at IS NULL
      ORDER BY b.tag_id ASC
    ''');
    return results.map((m) => Budget.fromMap(m)).toList();
  }

  Future<Map<String, dynamic>> getBudgetProgress() async {
    final db = await _dbHelper.database;
    final today = DateTime.now();
    final monthStartStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-01';
    final todayStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // 1. Overall month spending
    final overallRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total
      FROM expenses
      WHERE date >= ? AND date <= ? AND deleted_at IS NULL
    ''', [monthStartStr, todayStr]);
    final overallSpent = (overallRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // 2. Category spending
    final catRes = await db.rawQuery('''
      SELECT tag_id, COALESCE(SUM(amount), 0.0) as total
      FROM expenses
      WHERE date >= ? AND date <= ? AND tag_id IS NOT NULL AND deleted_at IS NULL
      GROUP BY tag_id
    ''', [monthStartStr, todayStr]);
    final catSpentMap = <String, double>{};
    for (final row in catRes) {
      catSpentMap[row['tag_id'] as String] = (row['total'] as num).toDouble();
    }

    final allBudgets = await getAllBudgets();
    BudgetProgress? overallProgress;
    final categoryProgresses = <BudgetProgress>[];

    for (final b in allBudgets) {
      if (b.tagId == null) {
        final spent = overallSpent;
        final rem = (b.amount - spent) > 0 ? (b.amount - spent) : 0.0;
        final pct = b.amount > 0 ? (spent / b.amount) * 100 : 0.0;
        final status = spent <= b.amount
            ? 'Overall spending is ${pct.toStringAsFixed(1)}% of your monthly target.'
            : 'Overall spending has exceeded target by ${(pct - 100).toStringAsFixed(1)}%.';

        overallProgress = BudgetProgress(
          id: b.id,
          tagId: null,
          categoryName: 'Overall',
          budgetAmount: b.amount,
          spentAmount: spent,
          remainingAmount: rem,
          percentageUsed: pct,
          statusMessage: status,
        );
      } else {
        final spent = catSpentMap[b.tagId] ?? 0.0;
        final rem = (b.amount - spent) > 0 ? (b.amount - spent) : 0.0;
        final pct = b.amount > 0 ? (spent / b.amount) * 100 : 0.0;
        final catName = b.tagName ?? 'Category';
        final status = spent <= b.amount
            ? '$catName spending is ${pct.toStringAsFixed(1)}% of planned limit.'
            : '$catName spending has reached ${pct.toStringAsFixed(1)}% of limit.';

        categoryProgresses.add(
          BudgetProgress(
            id: b.id,
            tagId: b.tagId,
            categoryName: catName,
            budgetAmount: b.amount,
            spentAmount: spent,
            remainingAmount: rem,
            percentageUsed: pct,
            statusMessage: status,
          ),
        );
      }
    }

    return {
      'has_budgets': allBudgets.isNotEmpty,
      'overall': overallProgress,
      'categories': categoryProgresses,
    };
  }
}
