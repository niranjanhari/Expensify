import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../domain/models/pending_transaction.dart';

class PendingTransactionDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Checks if a transaction is a duplicate based on reference ID or fingerprint or time/amount proximity.
  Future<bool> isDuplicate({
    String? referenceId,
    required String fingerprint,
    required double amount,
    String? accountIdentifier,
    String? payeeIdentifier,
    required int smsTimestamp,
  }) async {
    final db = await _dbHelper.database;

    // 1. Strong check: Reference ID
    if (referenceId != null && referenceId.trim().isNotEmpty) {
      final refMatches = await db.query(
        'pending_transactions',
        where: 'reference_id = ?',
        whereArgs: [referenceId.trim()],
        limit: 1,
      );
      if (refMatches.isNotEmpty) return true;
    }

    // 2. Strong check: Computed fingerprint
    if (fingerprint.isNotEmpty) {
      final fpMatches = await db.query(
        'pending_transactions',
        where: 'fingerprint = ?',
        whereArgs: [fingerprint],
        limit: 1,
      );
      if (fpMatches.isNotEmpty) return true;
    }

    // 3. Proximity check: same amount, same account or payee, within ±5 minutes (300000ms)
    const timeWindow = 300000;
    final minTime = smsTimestamp - timeWindow;
    final maxTime = smsTimestamp + timeWindow;

    if (accountIdentifier != null && accountIdentifier.trim().isNotEmpty) {
      final proximityMatches = await db.query(
        'pending_transactions',
        where: 'amount = ? AND account_identifier = ? AND sms_timestamp BETWEEN ? AND ?',
        whereArgs: [amount, accountIdentifier.trim(), minTime, maxTime],
        limit: 1,
      );
      if (proximityMatches.isNotEmpty) return true;
    }

    if (payeeIdentifier != null && payeeIdentifier.trim().isNotEmpty) {
      final proximityMatches = await db.query(
        'pending_transactions',
        where: 'amount = ? AND payee_identifier = ? AND sms_timestamp BETWEEN ? AND ?',
        whereArgs: [amount, payeeIdentifier.trim().toLowerCase(), minTime, maxTime],
        limit: 1,
      );
      if (proximityMatches.isNotEmpty) return true;
    }

    return false;
  }

  /// Inserts a newly detected pending transaction if not already duplicated.
  /// Returns the inserted transaction, or null if it was a duplicate.
  Future<PendingTransaction?> insertIfNotDuplicate(PendingTransaction transaction) async {
    final dup = await isDuplicate(
      referenceId: transaction.referenceId,
      fingerprint: transaction.fingerprint,
      amount: transaction.amount,
      accountIdentifier: transaction.accountIdentifier,
      payeeIdentifier: transaction.payeeIdentifier,
      smsTimestamp: transaction.smsTimestamp,
    );

    if (dup) {
      return null;
    }

    final db = await _dbHelper.database;
    await db.insert(
      'pending_transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return transaction;
  }

  /// Retrieves a pending transaction by its unique ID.
  Future<PendingTransaction?> getById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'pending_transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return PendingTransaction.fromMap(results.first);
  }

  /// Gets all transactions with status 'pending', newest first.
  Future<List<PendingTransaction>> getPendingTransactions() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'pending_transactions',
      where: 'status = ?',
      whereArgs: [PendingTransactionStatus.pending],
      orderBy: 'sms_timestamp DESC, created_at DESC',
    );
    return results.map((m) => PendingTransaction.fromMap(m)).toList();
  }

  /// Returns the number of unreviewed pending transactions.
  Future<int> getPendingCount() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pending_transactions WHERE status = ?',
      [PendingTransactionStatus.pending],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Marks a pending transaction as confirmed.
  Future<void> markConfirmed(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'pending_transactions',
      {'status': PendingTransactionStatus.confirmed},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marks a pending transaction as ignored so it won't be shown again or re-notified.
  Future<void> markIgnored(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'pending_transactions',
      {'status': PendingTransactionStatus.ignored},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
