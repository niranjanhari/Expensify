import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../../domain/models/expense.dart';
import 'store_dao.dart';

class ExpenseDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final StoreDao _storeDao = StoreDao();
  final Uuid _uuid = const Uuid();

  Future<Expense> createExpense({
    required double amount,
    required DateTime date,
    String? time,
    String? description,
    String? storeId,
    String? tagId,
    String paymentMethod = 'Cash',
    bool isRecurring = false,
    String? recurringExpenseId,
  }) async {
    if (amount <= 0.0) throw ArgumentError('Expense amount must be greater than zero.');

    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc();
    final expense = Expense(
      id: _uuid.v4(),
      amount: amount,
      date: date,
      time: time,
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      storeId: storeId,
      tagId: tagId,
      paymentMethod: paymentMethod.trim().isEmpty ? 'Cash' : paymentMethod.trim(),
      isRecurring: isRecurring,
      recurringExpenseId: recurringExpenseId,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('expenses', expense.toMap());

    if (storeId != null) {
      await _storeDao.incrementUsage(storeId);
    }

    return expense;
  }

  Future<List<Expense>> getRecentExpenses({int limit = 10}) async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT e.*, s.name as store_name, t.name as tag_name
      FROM expenses e
      LEFT JOIN stores s ON e.store_id = s.id
      LEFT JOIN tags t ON e.tag_id = t.id
      WHERE e.deleted_at IS NULL
      ORDER BY e.date DESC, e.created_at DESC
      LIMIT ?
    ''', [limit]);
    return results.map((m) => Expense.fromMap(m)).toList();
  }

  Future<List<Expense>> getAllActiveExpenses() async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT e.*, s.name as store_name, t.name as tag_name
      FROM expenses e
      LEFT JOIN stores s ON e.store_id = s.id
      LEFT JOIN tags t ON e.tag_id = t.id
      WHERE e.deleted_at IS NULL
      ORDER BY e.date DESC, e.created_at DESC
    ''');
    return results.map((m) => Expense.fromMap(m)).toList();
  }

  Future<Expense?> getExpenseById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT e.*, s.name as store_name, t.name as tag_name
      FROM expenses e
      LEFT JOIN stores s ON e.store_id = s.id
      LEFT JOIN tags t ON e.tag_id = t.id
      WHERE e.id = ? AND e.deleted_at IS NULL
      LIMIT 1
    ''', [id]);
    if (results.isEmpty) return null;
    return Expense.fromMap(results.first);
  }

  Future<Map<String, dynamic>> getFilteredExpenses({
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? tagIds,
    List<String>? storeIds,
    List<String>? paymentMethods,
    double? minAmount,
    double? maxAmount,
    String sortOrder = 'desc',
    int page = 1,
    int pageSize = 15,
  }) async {
    final db = await _dbHelper.database;
    final conditions = <String>['e.deleted_at IS NULL'];
    final args = <dynamic>[];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim().toLowerCase()}%';
      conditions.add(
        '(LOWER(COALESCE(e.description, "")) LIKE ? OR LOWER(COALESCE(s.name, "")) LIKE ? OR LOWER(COALESCE(t.name, "")) LIKE ? OR LOWER(e.payment_method) LIKE ?)',
      );
      args.addAll([term, term, term, term]);
    }

    if (startDate != null) {
      final sStr = '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      conditions.add('e.date >= ?');
      args.add(sStr);
    }

    if (endDate != null) {
      final eStr = '${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
      conditions.add('e.date <= ?');
      args.add(eStr);
    }

    if (tagIds != null && tagIds.isNotEmpty) {
      final placeholders = List.filled(tagIds.length, '?').join(',');
      conditions.add('e.tag_id IN ($placeholders)');
      args.addAll(tagIds);
    }

    if (storeIds != null && storeIds.isNotEmpty) {
      final placeholders = List.filled(storeIds.length, '?').join(',');
      conditions.add('e.store_id IN ($placeholders)');
      args.addAll(storeIds);
    }

    if (paymentMethods != null && paymentMethods.isNotEmpty) {
      final placeholders = List.filled(paymentMethods.length, '?').join(',');
      conditions.add('e.payment_method IN ($placeholders)');
      args.addAll(paymentMethods);
    }

    if (minAmount != null) {
      conditions.add('e.amount >= ?');
      args.add(minAmount);
    }

    if (maxAmount != null) {
      conditions.add('e.amount <= ?');
      args.add(maxAmount);
    }

    final whereClause = conditions.join(' AND ');

    // Total Count & Total Amount
    final statsRes = await db.rawQuery('''
      SELECT COUNT(e.id) as count, COALESCE(SUM(e.amount), 0.0) as total
      FROM expenses e
      LEFT JOIN stores s ON e.store_id = s.id
      LEFT JOIN tags t ON e.tag_id = t.id
      WHERE $whereClause
    ''', args);

    final totalCount = (statsRes.first['count'] as num?)?.toInt() ?? 0;
    final totalAmount = (statsRes.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalPages = totalCount > 0 ? (totalCount + pageSize - 1) ~/ pageSize : 1;

    // Items
    final orderDir = sortOrder.toLowerCase() == 'asc' ? 'ASC' : 'DESC';
    final offset = (page - 1) * pageSize;
    final itemsRes = await db.rawQuery('''
      SELECT e.*, s.name as store_name, t.name as tag_name
      FROM expenses e
      LEFT JOIN stores s ON e.store_id = s.id
      LEFT JOIN tags t ON e.tag_id = t.id
      WHERE $whereClause
      ORDER BY e.date $orderDir, e.created_at $orderDir
      LIMIT ? OFFSET ?
    ''', [...args, pageSize, offset]);

    final items = itemsRes.map((m) => Expense.fromMap(m)).toList();

    return {
      'items': items,
      'total_count': totalCount,
      'total_amount': totalAmount,
      'page': page,
      'page_size': pageSize,
      'total_pages': totalPages,
    };
  }

  Future<void> updateExpense({
    required String id,
    required double amount,
    required DateTime date,
    String? time,
    String? description,
    String? storeId,
    String? tagId,
    required String paymentMethod,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final dStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    await db.update(
      'expenses',
      {
        'amount': amount,
        'date': dStr,
        'time': time,
        'description': description?.trim().isEmpty == true ? null : description?.trim(),
        'store_id': storeId,
        'tag_id': tagId,
        'payment_method': paymentMethod,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteExpense(String id) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    // Soft delete to support sync tombstones
    await db.update(
      'expenses',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<double> getSumOfExpensesSince(DateTime timestamp) async {
    final db = await _dbHelper.database;
    final iso = timestamp.toUtc().toIso8601String();
    final results = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as sum_amt
      FROM expenses
      WHERE created_at >= ? AND deleted_at IS NULL
    ''', [iso]);
    return (results.first['sum_amt'] as num?)?.toDouble() ?? 0.0;
  }
}
