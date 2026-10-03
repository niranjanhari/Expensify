import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../../domain/models/store.dart';

class StoreDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  Future<List<Store>> getAllStores() async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT s.*, t.name as default_tag_name
      FROM stores s
      LEFT JOIN tags t ON s.default_tag_id = t.id
      WHERE s.deleted_at IS NULL
      ORDER BY s.usage_count DESC, s.name ASC
    ''');
    return results.map((m) => Store.fromMap(m)).toList();
  }

  Future<List<Store>> searchStores(String query, {int limit = 10}) async {
    final clean = query.trim().toLowerCase();
    final db = await _dbHelper.database;
    if (clean.isEmpty) {
      return (await getAllStores()).take(limit).toList();
    }
    final results = await db.rawQuery('''
      SELECT s.*, t.name as default_tag_name
      FROM stores s
      LEFT JOIN tags t ON s.default_tag_id = t.id
      WHERE s.deleted_at IS NULL AND s.normalized_name LIKE ?
      ORDER BY s.usage_count DESC, s.name ASC
      LIMIT ?
    ''', ['%$clean%', limit]);
    return results.map((m) => Store.fromMap(m)).toList();
  }

  Future<Store?> getStoreByName(String name) async {
    final normalized = Store.normalizeStoreName(name);
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT s.*, t.name as default_tag_name
      FROM stores s
      LEFT JOIN tags t ON s.default_tag_id = t.id
      WHERE s.normalized_name = ? AND s.deleted_at IS NULL
      LIMIT 1
    ''', [normalized]);
    if (results.isEmpty) return null;
    return Store.fromMap(results.first);
  }

  Future<Store> getOrCreateStore(String name, {String? defaultTagId}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError('Store name cannot be empty.');

    final existing = await getStoreByName(cleanName);
    if (existing != null) {
      if (defaultTagId != null && existing.defaultTagId == null) {
        final db = await _dbHelper.database;
        final now = DateTime.now().toUtc().toIso8601String();
        await db.update(
          'stores',
          {'default_tag_id': defaultTagId, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [existing.id],
        );
        return Store(
          id: existing.id,
          name: existing.name,
          normalizedName: existing.normalizedName,
          defaultTagId: defaultTagId,
          usageCount: existing.usageCount,
          createdAt: existing.createdAt,
          updatedAt: DateTime.parse(now),
        );
      }
      return existing;
    }

    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc();
    final newStore = Store(
      id: _uuid.v4(),
      name: cleanName,
      normalizedName: Store.normalizeStoreName(cleanName),
      defaultTagId: defaultTagId,
      usageCount: 0,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('stores', newStore.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return newStore;
  }

  Future<void> incrementUsage(String storeId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.rawUpdate('''
      UPDATE stores
      SET usage_count = usage_count + 1, updated_at = ?
      WHERE id = ?
    ''', [now, storeId]);
  }

  Future<Map<String, dynamic>> getStoreMetrics(String storeId) async {
    final db = await _dbHelper.database;
    final countRes = await db.rawQuery('''
      SELECT COUNT(id) as count, COALESCE(SUM(amount), 0.0) as total, MAX(date) as last_date
      FROM expenses
      WHERE store_id = ? AND deleted_at IS NULL
    ''', [storeId]);

    final count = (countRes.first['count'] as num?)?.toInt() ?? 0;
    final total = (countRes.first['total'] as num?)?.toDouble() ?? 0.0;
    final avg = count > 0 ? total / count : 0.0;
    final lastDate = countRes.first['last_date'] as String?;

    // Frequent tag
    final tagRes = await db.rawQuery('''
      SELECT e.tag_id, t.name as tag_name, COUNT(e.id) as tag_count
      FROM expenses e
      JOIN tags t ON e.tag_id = t.id
      WHERE e.store_id = ? AND e.deleted_at IS NULL
      GROUP BY e.tag_id, t.name
      ORDER BY tag_count DESC
      LIMIT 1
    ''', [storeId]);

    String? frequentTagId;
    String? frequentTagName;
    if (tagRes.isNotEmpty) {
      frequentTagId = tagRes.first['tag_id'] as String?;
      frequentTagName = tagRes.first['tag_name'] as String?;
    }

    return {
      'purchase_count': count,
      'total_spent': total,
      'avg_spent': avg,
      'last_date': lastDate,
      'frequent_tag_id': frequentTagId,
      'frequent_tag_name': frequentTagName,
    };
  }

  Future<List<Map<String, dynamic>>> getAllStoresWithExpenseCount() async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT s.*, t.name as default_tag_name, COUNT(e.id) as expense_count
      FROM stores s
      LEFT JOIN tags t ON s.default_tag_id = t.id
      LEFT JOIN expenses e ON e.store_id = s.id AND e.deleted_at IS NULL
      WHERE s.deleted_at IS NULL
      GROUP BY s.id
      ORDER BY s.usage_count DESC, s.name ASC
    ''');
    return results;
  }

  Future<void> renameStore(String storeId, String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty) throw ArgumentError('Store name cannot be empty.');
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'stores',
      {
        'name': clean,
        'normalized_name': Store.normalizeStoreName(clean),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [storeId],
    );
  }

  Future<void> deleteStore(String storeId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE expenses SET store_id = NULL, updated_at = ? WHERE store_id = ?',
        [now, storeId],
      );
      await txn.rawUpdate(
        'UPDATE recurring_expenses SET store_id = NULL, updated_at = ? WHERE store_id = ?',
        [now, storeId],
      );
      await txn.rawUpdate(
        'UPDATE quick_add_pins SET store_id = NULL, updated_at = ? WHERE store_id = ?',
        [now, storeId],
      );
      await txn.delete('stores', where: 'id = ?', whereArgs: [storeId]);
    });
  }
}
