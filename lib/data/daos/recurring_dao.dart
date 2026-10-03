import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../../domain/models/recurring_expense.dart';
import 'expense_dao.dart';

class RecurringDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ExpenseDao _expenseDao = ExpenseDao();
  final Uuid _uuid = const Uuid();

  DateTime _advanceDueDate(DateTime current, String frequency) {
    final freq = frequency.trim().toLowerCase();
    if (freq == 'daily') {
      return current.add(const Duration(days: 1));
    } else if (freq == 'weekly') {
      return current.add(const Duration(days: 7));
    } else if (freq == 'monthly') {
      final nextMonth = (current.month % 12) + 1;
      final nextYear = current.year + (current.month ~/ 12);
      final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
      final targetDay = current.day > daysInNextMonth ? daysInNextMonth : current.day;
      return DateTime(nextYear, nextMonth, targetDay);
    } else {
      return current.add(const Duration(days: 30));
    }
  }

  Future<RecurringExpense> createRecurringExpense({
    required String description,
    required double amount,
    String? storeId,
    String? tagId,
    String frequency = 'Monthly',
    DateTime? nextDueDate,
    String paymentMethod = 'Cash',
  }) async {
    final cleanDesc = description.trim();
    if (cleanDesc.isEmpty) throw ArgumentError('Description cannot be empty.');
    if (amount <= 0.0) throw ArgumentError('Amount must be positive.');

    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc();
    final due = nextDueDate ?? DateTime.now();

    final rec = RecurringExpense(
      id: _uuid.v4(),
      description: cleanDesc,
      amount: amount,
      storeId: storeId,
      tagId: tagId,
      frequency: frequency,
      nextDueDate: due,
      active: true,
      paymentMethod: paymentMethod,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('recurring_expenses', rec.toMap());
    return rec;
  }

  Future<List<RecurringExpense>> getAllRecurringExpenses({bool activeOnly = true}) async {
    final db = await _dbHelper.database;
    final whereClause = activeOnly
        ? 'r.active = 1 AND r.deleted_at IS NULL'
        : 'r.deleted_at IS NULL';

    final results = await db.rawQuery('''
      SELECT r.*, s.name as store_name, t.name as tag_name
      FROM recurring_expenses r
      LEFT JOIN stores s ON r.store_id = s.id
      LEFT JOIN tags t ON r.tag_id = t.id
      WHERE $whereClause
      ORDER BY r.next_due_date ASC
    ''');
    return results.map((m) => RecurringExpense.fromMap(m)).toList();
  }

  Future<List<RecurringExpense>> getDueRecurringExpenses() async {
    final db = await _dbHelper.database;
    final today = DateTime.now();
    final todayStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final results = await db.rawQuery('''
      SELECT r.*, s.name as store_name, t.name as tag_name
      FROM recurring_expenses r
      LEFT JOIN stores s ON r.store_id = s.id
      LEFT JOIN tags t ON r.tag_id = t.id
      WHERE r.active = 1 AND r.next_due_date <= ? AND r.deleted_at IS NULL
      ORDER BY r.next_due_date ASC
    ''', [todayStr]);
    return results.map((m) => RecurringExpense.fromMap(m)).toList();
  }

  Future<void> confirmAndLogRecurring(String recurringId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'recurring_expenses',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [recurringId],
      limit: 1,
    );
    if (maps.isEmpty) return;

    final rec = RecurringExpense.fromMap(maps.first);
    final today = DateTime.now();
    final timeStr = '${today.hour.toString().padLeft(2, '0')}:${today.minute.toString().padLeft(2, '0')}';

    // 1. Log the expense
    await _expenseDao.createExpense(
      amount: rec.amount,
      date: today,
      time: timeStr,
      description: '[Recurring] ${rec.description}',
      storeId: rec.storeId,
      tagId: rec.tagId,
      paymentMethod: rec.paymentMethod,
      isRecurring: true,
      recurringExpenseId: rec.id,
    );

    // 2. Advance next due date
    final nextDue = _advanceDueDate(rec.nextDueDate, rec.frequency);
    final now = DateTime.now().toUtc().toIso8601String();
    final nextDueStr = '${nextDue.year.toString().padLeft(4, '0')}-${nextDue.month.toString().padLeft(2, '0')}-${nextDue.day.toString().padLeft(2, '0')}';

    await db.update(
      'recurring_expenses',
      {'next_due_date': nextDueStr, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [recurringId],
    );
  }

  Future<void> skipRecurring(String recurringId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'recurring_expenses',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [recurringId],
      limit: 1,
    );
    if (maps.isEmpty) return;

    final rec = RecurringExpense.fromMap(maps.first);
    final nextDue = _advanceDueDate(rec.nextDueDate, rec.frequency);
    final now = DateTime.now().toUtc().toIso8601String();
    final nextDueStr = '${nextDue.year.toString().padLeft(4, '0')}-${nextDue.month.toString().padLeft(2, '0')}-${nextDue.day.toString().padLeft(2, '0')}';

    await db.update(
      'recurring_expenses',
      {'next_due_date': nextDueStr, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [recurringId],
    );
  }

  Future<void> deleteRecurringExpense(String id) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'recurring_expenses',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
