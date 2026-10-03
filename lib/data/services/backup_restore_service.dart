import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database/database_helper.dart';

/// Service responsible for full offline JSON backup and atomic restore of Expensify data.
class BackupRestoreService {
  static const int currentBackupVersion = 1;

  final DatabaseHelper _dbHelper;

  BackupRestoreService({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Generates a complete UTF-8 JSON backup representation of all user data.
  Future<String> generateBackupJson({DatabaseHelper? dbHelper}) async {
    final helper = dbHelper ?? _dbHelper;
    final db = await helper.database;

    final tags = await db.query('tags');
    final stores = await db.query('stores');
    final expenses = await db.query('expenses');
    final accountBalances = await db.query('account_balances');
    final budgets = await db.query('budgets');
    final recurringExpenses = await db.query('recurring_expenses');
    final quickAddPins = await db.query('quick_add_pins');

    final backupPayload = <String, dynamic>{
      'backup_version': currentBackupVersion,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'app': 'Expensify',
      'data': {
        'tags': tags,
        'stores': stores,
        'expenses': expenses,
        'account_balances': accountBalances,
        'budgets': budgets,
        'recurring_expenses': recurringExpenses,
        'quick_add_pins': quickAddPins,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(backupPayload);
  }

  /// Exports backup JSON to a temporary file and triggers the native Android share/save dialog.
  /// Returns a summary map of the counts exported.
  Future<Map<String, dynamic>> createAndShareBackup({DatabaseHelper? dbHelper}) async {
    final jsonContent = await generateBackupJson(dbHelper: dbHelper);
    final summary = validateBackupJson(jsonContent);

    final now = DateTime.now();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final fileName = 'expensify_backup_$yyyy-$mm-${dd}_$hh-$min.json';

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$fileName';
    final file = File(filePath);

    await file.writeAsString(jsonContent, encoding: utf8, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json', name: fileName)],
      subject: 'Expensify Data Backup',
    );

    return {
      'fileName': fileName,
      'expensesCount': summary['expensesCount'],
      'storesCount': summary['storesCount'],
      'tagsCount': summary['tagsCount'],
      'budgetsCount': summary['budgetsCount'],
      'recurringCount': summary['recurringCount'],
      'quickAddCount': summary['quickAddCount'],
      'balancesCount': summary['balancesCount'],
    };
  }

  /// Validates that [jsonString] is a valid Expensify backup with the expected schema and version.
  /// Throws [FormatException] if validation fails.
  /// Returns a parsed summary without logging sensitive financial details.
  Map<String, dynamic> validateBackupJson(String jsonString) {
    if (jsonString.trim().isEmpty) {
      throw const FormatException('Selected file is empty.');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (e) {
      throw FormatException('Invalid JSON format: $e');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup structure: root must be a JSON object.');
    }

    final version = decoded['backup_version'];
    if (version == null) {
      throw const FormatException('Invalid backup: missing "backup_version".');
    }
    if (version is! int || version != currentBackupVersion) {
      throw FormatException('Unsupported backup version: $version (expected $currentBackupVersion).');
    }

    final data = decoded['data'];
    if (data == null || data is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup structure: missing "data" object.');
    }

    // Validate that tables are lists
    final tables = [
      'tags',
      'stores',
      'expenses',
      'account_balances',
      'budgets',
      'recurring_expenses',
      'quick_add_pins',
    ];

    for (final table in tables) {
      if (data.containsKey(table) && data[table] != null && data[table] is! List) {
        throw FormatException('Invalid table data for "$table": expected a list of records.');
      }
    }

    final expenses = (data['expenses'] as List?) ?? [];
    final stores = (data['stores'] as List?) ?? [];
    final tags = (data['tags'] as List?) ?? [];
    final budgets = (data['budgets'] as List?) ?? [];
    final recurring = (data['recurring_expenses'] as List?) ?? [];
    final quickAdd = (data['quick_add_pins'] as List?) ?? [];
    final balances = (data['account_balances'] as List?) ?? [];

    return {
      'backupVersion': version,
      'createdAt': decoded['created_at']?.toString() ?? '',
      'expensesCount': expenses.length,
      'storesCount': stores.length,
      'tagsCount': tags.length,
      'budgetsCount': budgets.length,
      'recurringCount': recurring.length,
      'quickAddCount': quickAdd.length,
      'balancesCount': balances.length,
      'parsedData': data,
    };
  }

  /// Restores all data from [parsedData] atomically inside a single SQLite transaction.
  /// If any error occurs during deletion or insertion, the entire transaction rolls back.
  Future<Map<String, int>> restoreBackupData(
    Map<String, dynamic> parsedData, {
    DatabaseHelper? dbHelper,
  }) async {
    final helper = dbHelper ?? _dbHelper;
    final db = await helper.database;

    final tags = (parsedData['tags'] as List?) ?? [];
    final stores = (parsedData['stores'] as List?) ?? [];
    final balances = (parsedData['account_balances'] as List?) ?? [];
    final budgets = (parsedData['budgets'] as List?) ?? [];
    final recurring = (parsedData['recurring_expenses'] as List?) ?? [];
    final quickAdd = (parsedData['quick_add_pins'] as List?) ?? [];
    final expenses = (parsedData['expenses'] as List?) ?? [];

    await db.transaction((txn) async {
      // 1. Delete existing data in reverse foreign-key dependency order
      await txn.delete('expenses');
      await txn.delete('quick_add_pins');
      await txn.delete('recurring_expenses');
      await txn.delete('budgets');
      await txn.delete('account_balances');
      await txn.delete('stores');
      await txn.delete('tags');

      // 2. Insert new data in strict foreign-key dependency order
      // (a) Tags (no FK)
      for (final item in tags) {
        await txn.insert('tags', Map<String, dynamic>.from(item as Map));
      }

      // (b) Stores (references tags)
      for (final item in stores) {
        await txn.insert('stores', Map<String, dynamic>.from(item as Map));
      }

      // (c) Account Balances (no FK)
      for (final item in balances) {
        await txn.insert('account_balances', Map<String, dynamic>.from(item as Map));
      }

      // (d) Budgets (references tags)
      for (final item in budgets) {
        await txn.insert('budgets', Map<String, dynamic>.from(item as Map));
      }

      // (e) Recurring Expenses (references stores, tags)
      for (final item in recurring) {
        await txn.insert('recurring_expenses', Map<String, dynamic>.from(item as Map));
      }

      // (f) Quick Add Pins (references stores, tags)
      for (final item in quickAdd) {
        await txn.insert('quick_add_pins', Map<String, dynamic>.from(item as Map));
      }

      // (g) Expenses (references stores, tags)
      for (final item in expenses) {
        await txn.insert('expenses', Map<String, dynamic>.from(item as Map));
      }
    });

    return {
      'expenses': expenses.length,
      'stores': stores.length,
      'tags': tags.length,
      'budgets': budgets.length,
      'recurring': recurring.length,
      'quickAdd': quickAdd.length,
      'balances': balances.length,
    };
  }
}
