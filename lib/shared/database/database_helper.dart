import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('instal.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, // Increment version to trigger schema update
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Drop and recreate tables with updated schema
      await db.execute('DROP TABLE IF EXISTS installment_payments');
      await db.execute('DROP TABLE IF EXISTS installments');
      await db.execute('DROP TABLE IF EXISTS investors');
      await db.execute('DROP TABLE IF EXISTS clients');
      await _createDB(db, newVersion);
    }
  }

  Future _createDB(Database db, int version) async {
    // Create clients table
    await db.execute('''
      CREATE TABLE clients(
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        full_name TEXT NOT NULL,
        contact_number TEXT NOT NULL,
        passport_number TEXT NOT NULL,
        address TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create investors table
    await db.execute('''
      CREATE TABLE investors(
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        full_name TEXT NOT NULL,
        investment_amount REAL NOT NULL,
        investor_percentage REAL NOT NULL,
        user_percentage REAL NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create installments table
    await db.execute('''
      CREATE TABLE installments(
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        client_id TEXT NOT NULL,
        investor_id TEXT,
        product_name TEXT NOT NULL,
        cash_price REAL NOT NULL,
        installment_price REAL NOT NULL,
        term_months INTEGER NOT NULL,
        down_payment REAL NOT NULL,
        monthly_payment REAL NOT NULL,
        down_payment_date INTEGER NOT NULL,
        installment_start_date INTEGER NOT NULL,
        installment_end_date INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (client_id) REFERENCES clients (id),
        FOREIGN KEY (investor_id) REFERENCES investors (id)
      )
    ''');

    // Create installment_payments table
    await db.execute('''
      CREATE TABLE installment_payments(
        id TEXT PRIMARY KEY,
        installment_id TEXT NOT NULL,
        payment_number INTEGER NOT NULL,
        due_date INTEGER NOT NULL,
        expected_amount REAL NOT NULL,
        is_paid INTEGER DEFAULT 0,
        paid_date INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (installment_id) REFERENCES installments (id)
      )
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
} 