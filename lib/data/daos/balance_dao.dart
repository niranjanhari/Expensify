import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../../domain/models/account_balance.dart';
import 'expense_dao.dart';

class BalanceDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ExpenseDao _expenseDao = ExpenseDao();
  final Uuid _uuid = const Uuid();

  Future<BalanceCalculation> getBalanceDetails() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'account_balances',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (maps.isEmpty) {
      return BalanceCalculation(
        isConfigured: false,
        baselineAmount: 0.0,
        currentBalance: 0.0,
        expensesSinceBaseline: 0.0,
        setAt: null,
        notes: null,
      );
    }

    final balanceRecord = AccountBalance.fromMap(maps.first);
    final spentSince = await _expenseDao.getSumOfExpensesSince(balanceRecord.setAt);
    final currentBal = balanceRecord.baselineAmount - spentSince;

    return BalanceCalculation(
      isConfigured: true,
      baselineAmount: balanceRecord.baselineAmount,
      currentBalance: currentBal,
      expensesSinceBaseline: spentSince,
      setAt: balanceRecord.setAt,
      notes: balanceRecord.notes,
    );
  }

  Future<BalanceCalculation> setAccountBalance({
    required double newBalance,
    String? notes,
  }) async {
    if (newBalance < 0.0) throw ArgumentError('Balance cannot be negative.');

    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc();
    final newRecord = AccountBalance(
      id: _uuid.v4(),
      baselineAmount: newBalance,
      setAt: now,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('account_balances', newRecord.toMap());

    return BalanceCalculation(
      isConfigured: true,
      baselineAmount: newBalance,
      currentBalance: newBalance,
      expensesSinceBaseline: 0.0,
      setAt: now,
      notes: newRecord.notes,
    );
  }
}
