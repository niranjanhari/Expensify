import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../../domain/models/tag.dart';

class TagDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  Future<List<Tag>> getAllTags() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'tags',
      where: 'deleted_at IS NULL',
      orderBy: 'name ASC',
    );
    return maps.map((m) => Tag.fromMap(m)).toList();
  }

  Future<Tag?> getTagById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'tags',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Tag.fromMap(maps.first);
  }

  Future<Tag?> getTagByName(String name) async {
    final db = await _dbHelper.database;
    final clean = name.trim().toLowerCase();
    final maps = await db.rawQuery(
      'SELECT * FROM tags WHERE LOWER(name) = ? AND deleted_at IS NULL LIMIT 1',
      [clean],
    );
    if (maps.isEmpty) return null;
    return Tag.fromMap(maps.first);
  }

  Future<Tag> getOrCreateTag(String name, {String? description}) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Tag name cannot be empty.');

    final existing = await getTagByName(clean);
    if (existing != null) return existing;

    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc();
    final newTag = Tag(
      id: _uuid.v4(),
      name: clean,
      description: description,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('tags', newTag.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return newTag;
  }

  Future<Tag> createTag(String name, {String? description}) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Category name cannot be empty.');

    final existing = await getTagByName(clean);
    if (existing != null) {
      throw ArgumentError('Category "$clean" already exists.');
    }

    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc();
    final newTag = Tag(
      id: _uuid.v4(),
      name: clean,
      description: description,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('tags', newTag.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
    return newTag;
  }

  Future<List<Map<String, dynamic>>> getAllTagsWithExpenseCount() async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT t.*, COUNT(e.id) as expense_count
      FROM tags t
      LEFT JOIN expenses e ON e.tag_id = t.id AND e.deleted_at IS NULL
      WHERE t.deleted_at IS NULL
      GROUP BY t.id
      ORDER BY t.name ASC
    ''');
    return results;
  }

  Future<void> renameTag(String tagId, String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty) throw ArgumentError('Tag name cannot be empty.');
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'tags',
      {
        'name': clean,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [tagId],
    );
  }

  Future<void> deleteTag(String tagId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE stores SET default_tag_id = NULL, updated_at = ? WHERE default_tag_id = ?',
        [now, tagId],
      );
      await txn.rawUpdate(
        'UPDATE expenses SET tag_id = NULL, updated_at = ? WHERE tag_id = ?',
        [now, tagId],
      );
      await txn.rawUpdate(
        'UPDATE budgets SET tag_id = NULL, updated_at = ? WHERE tag_id = ?',
        [now, tagId],
      );
      await txn.rawUpdate(
        'UPDATE recurring_expenses SET tag_id = NULL, updated_at = ? WHERE tag_id = ?',
        [now, tagId],
      );
      await txn.rawUpdate(
        'UPDATE quick_add_pins SET tag_id = NULL, updated_at = ? WHERE tag_id = ?',
        [now, tagId],
      );
      await txn.delete('tags', where: 'id = ?', whereArgs: [tagId]);
    });
  }
}
