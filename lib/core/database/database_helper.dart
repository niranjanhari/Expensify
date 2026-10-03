import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expensify_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createDB(db, version);
        await _createSmsTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createSmsTables(db);
      },
      onOpen: (db) async {
        await _createSmsTables(db);
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  static Future<void> _createSmsTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_transactions (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        transaction_type TEXT NOT NULL,
        sender TEXT NOT NULL,
        bank_name TEXT,
        account_identifier TEXT,
        payee_identifier TEXT,
        parsed_payee TEXT,
        reference_id TEXT,
        sms_timestamp INTEGER NOT NULL,
        raw_sms TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        fingerprint TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pending_tx_status ON pending_transactions(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pending_tx_fingerprint ON pending_transactions(fingerprint)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pending_tx_ref ON pending_transactions(reference_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payee_mappings (
        id TEXT PRIMARY KEY,
        identifier_type TEXT NOT NULL,
        identifier TEXT NOT NULL,
        payee_name TEXT NOT NULL,
        default_tag_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_payee_mapping_unique ON payee_mappings(identifier_type, identifier)');
  }

  Future<void> _createDB(Database db, int version) async {
    const uuid = Uuid();
    final now = DateTime.now().toUtc().toIso8601String();

    // 1. Tags
    await db.execute('''
      CREATE TABLE tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // 2. Stores
    await db.execute('''
      CREATE TABLE stores (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        normalized_name TEXT NOT NULL UNIQUE,
        default_tag_id TEXT REFERENCES tags(id) ON DELETE SET NULL,
        usage_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // 3. Expenses
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        time TEXT,
        description TEXT,
        store_id TEXT REFERENCES stores(id) ON DELETE SET NULL,
        tag_id TEXT REFERENCES tags(id) ON DELETE SET NULL,
        payment_method TEXT NOT NULL DEFAULT 'Cash',
        is_recurring INTEGER NOT NULL DEFAULT 0,
        recurring_expense_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
    await db.execute('CREATE INDEX idx_expenses_created_at ON expenses(created_at)');

    // 4. Account Balances
    await db.execute('''
      CREATE TABLE account_balances (
        id TEXT PRIMARY KEY,
        baseline_amount REAL NOT NULL,
        set_at TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // 5. Budgets
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        tag_id TEXT REFERENCES tags(id) ON DELETE SET NULL,
        amount REAL NOT NULL,
        period TEXT NOT NULL DEFAULT 'monthly',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // 6. Recurring Expenses
    await db.execute('''
      CREATE TABLE recurring_expenses (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        store_id TEXT REFERENCES stores(id) ON DELETE SET NULL,
        tag_id TEXT REFERENCES tags(id) ON DELETE SET NULL,
        frequency TEXT NOT NULL DEFAULT 'Monthly',
        next_due_date TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        payment_method TEXT NOT NULL DEFAULT 'Cash',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // 7. Quick Add Pins
    await db.execute('''
      CREATE TABLE quick_add_pins (
        id TEXT PRIMARY KEY,
        store_id TEXT REFERENCES stores(id) ON DELETE SET NULL,
        tag_id TEXT REFERENCES tags(id) ON DELETE SET NULL,
        amount REAL NOT NULL,
        description TEXT,
        payment_method TEXT NOT NULL DEFAULT 'Cash',
        is_pinned INTEGER NOT NULL DEFAULT 1,
        is_hidden INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // Seed default editable tags
    final batch = db.batch();
    for (final tag in defaultSeedTags) {
      batch.insert('tags', {
        'id': uuid.v4(),
        'name': tag['name']!,
        'description': tag['description']!,
        'created_at': now,
        'updated_at': now,
        'deleted_at': null,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
