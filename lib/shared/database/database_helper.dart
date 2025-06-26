import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'instal_app.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create clients table
    await db.execute('''
      CREATE TABLE clients (
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
      CREATE TABLE investors (
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
      CREATE TABLE installments (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        client_id TEXT NOT NULL,
        investor_id TEXT NOT NULL,
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
      CREATE TABLE installment_payments (
        id TEXT PRIMARY KEY,
        installment_id TEXT NOT NULL,
        payment_number INTEGER NOT NULL,
        due_date INTEGER NOT NULL,
        expected_amount REAL NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'предстоящий',
        paid_date INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (installment_id) REFERENCES installments (id)
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_clients_user_id ON clients (user_id)');
    await db.execute('CREATE INDEX idx_investors_user_id ON investors (user_id)');
    await db.execute('CREATE INDEX idx_installments_user_id ON installments (user_id)');
    await db.execute('CREATE INDEX idx_installments_client_id ON installments (client_id)');
    await db.execute('CREATE INDEX idx_installments_investor_id ON installments (investor_id)');
    await db.execute('CREATE INDEX idx_installment_payments_installment_id ON installment_payments (installment_id)');
    await db.execute('CREATE INDEX idx_installment_payments_status ON installment_payments (status)');
    await db.execute('CREATE INDEX idx_installment_payments_due_date ON installment_payments (due_date)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < newVersion) {
      // Add migration logic here when needed
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<void> deleteDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'instal_app.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
} 