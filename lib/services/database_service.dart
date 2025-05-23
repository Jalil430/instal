import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../models/client.dart';
import '../models/investor.dart';
import '../models/installment.dart';
import '../models/installment_payment.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'instal.db';
  static const _uuid = Uuid();
  
  // TODO: Replace with actual user ID from auth
  static const String currentUserId = 'default_user';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _dbName);
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  static Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clients(
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        fullName TEXT NOT NULL,
        contactNumber TEXT NOT NULL,
        passportNumber TEXT NOT NULL,
        address TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE investors(
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        fullName TEXT NOT NULL,
        investmentAmount REAL NOT NULL,
        investorPercentage REAL NOT NULL,
        userPercentage REAL NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE installments(
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        clientId TEXT NOT NULL,
        investorId TEXT,
        productName TEXT NOT NULL,
        cashPrice REAL NOT NULL,
        installmentPrice REAL NOT NULL,
        term INTEGER NOT NULL,
        downPayment REAL NOT NULL,
        monthlyPayment REAL NOT NULL,
        downPaymentDate TEXT NOT NULL,
        installmentStartDate TEXT NOT NULL,
        installmentEndDate TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (clientId) REFERENCES clients (id),
        FOREIGN KEY (investorId) REFERENCES investors (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE installment_payments(
        id TEXT PRIMARY KEY,
        installmentId TEXT NOT NULL,
        paymentNumber INTEGER NOT NULL,
        dueDate TEXT NOT NULL,
        expectedAmount REAL NOT NULL,
        paidAmount REAL NOT NULL,
        status TEXT NOT NULL,
        paidDate TEXT,
        FOREIGN KEY (installmentId) REFERENCES installments (id)
      )
    ''');
  }

  // Client CRUD operations
  static Future<String> insertClient(Client client) async {
    final db = await database;
    final clientWithId = client.copyWith(
      id: _uuid.v4(),
      userId: currentUserId,
      createdAt: DateTime.now(),
    );
    await db.insert('clients', clientWithId.toMap());
    return clientWithId.id;
  }

  static Future<List<Client>> getClients() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clients',
      where: 'userId = ?',
      whereArgs: [currentUserId],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Client.fromMap(maps[i]));
  }

  static Future<Client?> getClient(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clients',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, currentUserId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Client.fromMap(maps.first);
  }

  static Future<void> updateClient(Client client) async {
    final db = await database;
    await db.update(
      'clients',
      client.toMap(),
      where: 'id = ? AND userId = ?',
      whereArgs: [client.id, currentUserId],
    );
  }

  static Future<void> deleteClient(String id) async {
    final db = await database;
    await db.delete(
      'clients',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, currentUserId],
    );
  }

  // Investor CRUD operations
  static Future<String> insertInvestor(Investor investor) async {
    final db = await database;
    final investorWithId = investor.copyWith(
      id: _uuid.v4(),
      userId: currentUserId,
      createdAt: DateTime.now(),
    );
    await db.insert('investors', investorWithId.toMap());
    return investorWithId.id;
  }

  static Future<List<Investor>> getInvestors() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'investors',
      where: 'userId = ?',
      whereArgs: [currentUserId],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Investor.fromMap(maps[i]));
  }

  static Future<Investor?> getInvestor(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'investors',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, currentUserId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Investor.fromMap(maps.first);
  }

  static Future<void> updateInvestor(Investor investor) async {
    final db = await database;
    await db.update(
      'investors',
      investor.toMap(),
      where: 'id = ? AND userId = ?',
      whereArgs: [investor.id, currentUserId],
    );
  }

  static Future<void> deleteInvestor(String id) async {
    final db = await database;
    await db.delete(
      'investors',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, currentUserId],
    );
  }

  // Installment CRUD operations
  static Future<String> insertInstallment(Installment installment) async {
    final db = await database;
    final installmentWithId = installment.copyWith(
      id: _uuid.v4(),
      userId: currentUserId,
      createdAt: DateTime.now(),
    );
    
    await db.insert('installments', installmentWithId.toMap());
    
    // Create installment payments
    await _createInstallmentPayments(installmentWithId);
    
    return installmentWithId.id;
  }

  static Future<void> _createInstallmentPayments(Installment installment) async {
    final db = await database;
    
    // Create down payment if exists
    if (installment.downPayment > 0) {
      final downPayment = InstallmentPayment(
        id: _uuid.v4(),
        installmentId: installment.id,
        paymentNumber: 0,
        dueDate: installment.downPaymentDate,
        expectedAmount: installment.downPayment,
        paidAmount: 0,
        status: PaymentStatus.upcoming,
      );
      await db.insert('installment_payments', downPayment.toMap());
    }
    
    // Create monthly payments
    for (int i = 1; i <= installment.term; i++) {
      final dueDate = DateTime(
        installment.installmentStartDate.year,
        installment.installmentStartDate.month + i - 1,
        installment.installmentStartDate.day,
      );
      
      final payment = InstallmentPayment(
        id: _uuid.v4(),
        installmentId: installment.id,
        paymentNumber: i,
        dueDate: dueDate,
        expectedAmount: installment.monthlyPayment,
        paidAmount: 0,
        status: PaymentStatus.upcoming,
      );
      await db.insert('installment_payments', payment.toMap());
    }
  }

  static Future<List<Installment>> getInstallments() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'installments',
      where: 'userId = ?',
      whereArgs: [currentUserId],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Installment.fromMap(maps[i]));
  }

  static Future<List<Installment>> getClientInstallments(String clientId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'installments',
      where: 'userId = ? AND clientId = ?',
      whereArgs: [currentUserId, clientId],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Installment.fromMap(maps[i]));
  }

  static Future<List<Installment>> getInvestorInstallments(String investorId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'installments',
      where: 'userId = ? AND investorId = ?',
      whereArgs: [currentUserId, investorId],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Installment.fromMap(maps[i]));
  }

  static Future<Installment?> getInstallment(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'installments',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, currentUserId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Installment.fromMap(maps.first);
  }

  static Future<void> deleteInstallment(String id) async {
    final db = await database;
    // Delete payments first
    await db.delete(
      'installment_payments',
      where: 'installmentId = ?',
      whereArgs: [id],
    );
    // Then delete installment
    await db.delete(
      'installments',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, currentUserId],
    );
  }

  // Installment Payment operations
  static Future<List<InstallmentPayment>> getInstallmentPayments(String installmentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'installment_payments',
      where: 'installmentId = ?',
      whereArgs: [installmentId],
      orderBy: 'paymentNumber ASC',
    );
    return List.generate(maps.length, (i) => InstallmentPayment.fromMap(maps[i]));
  }

  static Future<void> updatePaymentStatus(String paymentId, double paidAmount, DateTime paidDate) async {
    final db = await database;
    await db.update(
      'installment_payments',
      {
        'paidAmount': paidAmount,
        'paidDate': paidDate.toIso8601String(),
        'status': PaymentStatus.paid.label,
      },
      where: 'id = ?',
      whereArgs: [paymentId],
    );
  }

  static Future<void> updatePaymentStatuses() async {
    final db = await database;
    final now = DateTime.now();
    
    // Update overdue payments
    await db.rawUpdate('''
      UPDATE installment_payments 
      SET status = ? 
      WHERE status != ? 
        AND julianday(?) - julianday(dueDate) > 2
    ''', [PaymentStatus.overdue.label, PaymentStatus.paid.label, now.toIso8601String()]);
    
    // Update due payments
    await db.rawUpdate('''
      UPDATE installment_payments 
      SET status = ? 
      WHERE status != ? 
        AND julianday(?) - julianday(dueDate) >= 0 
        AND julianday(?) - julianday(dueDate) <= 2
    ''', [PaymentStatus.due.label, PaymentStatus.paid.label, now.toIso8601String(), now.toIso8601String()]);
  }
} 