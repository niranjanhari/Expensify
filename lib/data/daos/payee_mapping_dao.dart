import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../../domain/models/payee_mapping.dart';

class PayeeMappingDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  /// Finds a saved payee mapping by identifier type and identifier string.
  Future<PayeeMapping?> findMapping({
    required String identifierType,
    required String identifier,
  }) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'payee_mappings',
      where: 'identifier_type = ? AND identifier = ?',
      whereArgs: [identifierType.trim().toLowerCase(), identifier.trim().toLowerCase()],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return PayeeMapping.fromMap(results.first);
  }

  /// Finds a saved payee mapping by checking UPI ID, account number, or merchant identifier.
  Future<PayeeMapping?> findBestMatch({
    String? upiId,
    String? accountIdentifier,
    String? merchantIdentifier,
  }) async {
    if (upiId != null && upiId.isNotEmpty) {
      final match = await findMapping(
        identifierType: PayeeIdentifierType.upiId,
        identifier: upiId,
      );
      if (match != null) return match;
    }

    if (accountIdentifier != null && accountIdentifier.isNotEmpty) {
      final match = await findMapping(
        identifierType: PayeeIdentifierType.bankAccount,
        identifier: accountIdentifier,
      );
      if (match != null) return match;
    }

    if (merchantIdentifier != null && merchantIdentifier.isNotEmpty) {
      final match = await findMapping(
        identifierType: PayeeIdentifierType.merchantIdentifier,
        identifier: merchantIdentifier,
      );
      if (match != null) return match;
    }

    return null;
  }

  /// Saves or updates a payee mapping.
  Future<PayeeMapping> saveOrUpdate({
    required String identifierType,
    required String identifier,
    required String payeeName,
    String? defaultTagId,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final cleanType = identifierType.trim().toLowerCase();
    final cleanId = identifier.trim().toLowerCase();
    final cleanName = payeeName.trim();

    final existing = await findMapping(
      identifierType: cleanType,
      identifier: cleanId,
    );

    if (existing != null) {
      final updated = existing.copyWith(
        payeeName: cleanName,
        defaultTagId: defaultTagId ?? existing.defaultTagId,
        updatedAt: now,
      );
      await db.update(
        'payee_mappings',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return updated;
    } else {
      final mapping = PayeeMapping(
        id: _uuid.v4(),
        identifierType: cleanType,
        identifier: cleanId,
        payeeName: cleanName,
        defaultTagId: defaultTagId,
        createdAt: now,
        updatedAt: now,
      );
      await db.insert(
        'payee_mappings',
        mapping.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return mapping;
    }
  }

  /// Lists all stored payee mappings.
  Future<List<PayeeMapping>> getAllMappings() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'payee_mappings',
      orderBy: 'updated_at DESC',
    );
    return results.map((m) => PayeeMapping.fromMap(m)).toList();
  }

  /// Deletes a mapping.
  Future<void> deleteMapping(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'payee_mappings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
