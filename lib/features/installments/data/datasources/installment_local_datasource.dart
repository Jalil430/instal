import 'package:sqflite/sqflite.dart';
import '../../../../shared/database/database_helper.dart';
import '../models/installment_model.dart';
import '../models/installment_payment_model.dart';

abstract class InstallmentLocalDataSource {
  Future<List<InstallmentModel>> getAllInstallments(String userId);
  Future<InstallmentModel?> getInstallmentById(String id);
  Future<String> createInstallment(InstallmentModel installment);
  Future<void> updateInstallment(InstallmentModel installment);
  Future<void> deleteInstallment(String id);
  Future<List<InstallmentModel>> searchInstallments(String userId, String query);
  Future<List<InstallmentModel>> getInstallmentsByClientId(String clientId);
  Future<List<InstallmentModel>> getInstallmentsByInvestorId(String investorId);
  
  // Payment operations
  Future<List<InstallmentPaymentModel>> getPaymentsByInstallmentId(String installmentId);
  Future<InstallmentPaymentModel?> getPaymentById(String id);
  Future<String> createPayment(InstallmentPaymentModel payment);
  Future<void> updatePayment(InstallmentPaymentModel payment);
  Future<void> deletePayment(String id);
  Future<List<InstallmentPaymentModel>> getOverduePayments(String userId);
  Future<List<InstallmentPaymentModel>> getDuePayments(String userId);
}

class InstallmentLocalDataSourceImpl implements InstallmentLocalDataSource {
  final DatabaseHelper _databaseHelper;

  InstallmentLocalDataSourceImpl(this._databaseHelper);

  @override
  Future<List<InstallmentModel>> getAllInstallments(String userId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'installments',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return InstallmentModel.fromMap(maps[i]);
    });
  }

  @override
  Future<InstallmentModel?> getInstallmentById(String id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'installments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return InstallmentModel.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<String> createInstallment(InstallmentModel installment) async {
    final db = await _databaseHelper.database;
    await db.insert(
      'installments',
      installment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return installment.id;
  }

  @override
  Future<void> updateInstallment(InstallmentModel installment) async {
    final db = await _databaseHelper.database;
    await db.update(
      'installments',
      installment.toMap(),
      where: 'id = ?',
      whereArgs: [installment.id],
    );
  }

  @override
  Future<void> deleteInstallment(String id) async {
    final db = await _databaseHelper.database;
    
    // Delete associated payments first
    await db.delete(
      'installment_payments',
      where: 'installment_id = ?',
      whereArgs: [id],
    );
    
    // Then delete the installment
    await db.delete(
      'installments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<InstallmentModel>> searchInstallments(String userId, String query) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'installments',
      where: 'user_id = ? AND product_name LIKE ?',
      whereArgs: [userId, '%$query%'],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return InstallmentModel.fromMap(maps[i]);
    });
  }

  @override
  Future<List<InstallmentModel>> getInstallmentsByClientId(String clientId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'installments',
      where: 'client_id = ?',
      whereArgs: [clientId],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return InstallmentModel.fromMap(maps[i]);
    });
  }

  @override
  Future<List<InstallmentModel>> getInstallmentsByInvestorId(String investorId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'installments',
      where: 'investor_id = ?',
      whereArgs: [investorId],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return InstallmentModel.fromMap(maps[i]);
    });
  }

  // Payment operations
  @override
  Future<List<InstallmentPaymentModel>> getPaymentsByInstallmentId(String installmentId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'installment_payments',
      where: 'installment_id = ?',
      whereArgs: [installmentId],
      orderBy: 'payment_number ASC',
    );

    return List.generate(maps.length, (i) {
      return InstallmentPaymentModel.fromMap(maps[i]);
    });
  }

  @override
  Future<InstallmentPaymentModel?> getPaymentById(String id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'installment_payments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return InstallmentPaymentModel.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<String> createPayment(InstallmentPaymentModel payment) async {
    final db = await _databaseHelper.database;
    await db.insert(
      'installment_payments',
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return payment.id;
  }

  @override
  Future<void> updatePayment(InstallmentPaymentModel payment) async {
    final db = await _databaseHelper.database;
    await db.update(
      'installment_payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  @override
  Future<void> deletePayment(String id) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'installment_payments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<InstallmentPaymentModel>> getOverduePayments(String userId) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now();
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT ip.* FROM installment_payments ip
      INNER JOIN installments i ON ip.installment_id = i.id
      WHERE i.user_id = ? AND ip.is_paid = 0 AND ip.due_date < ?
      ORDER BY ip.due_date ASC
    ''', [userId, now.millisecondsSinceEpoch]);

    return List.generate(maps.length, (i) {
      return InstallmentPaymentModel.fromMap(maps[i]);
    });
  }

  @override
  Future<List<InstallmentPaymentModel>> getDuePayments(String userId) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now();
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT ip.* FROM installment_payments ip
      INNER JOIN installments i ON ip.installment_id = i.id
      WHERE i.user_id = ? AND ip.is_paid = 0 AND ip.due_date <= ?
      ORDER BY ip.due_date ASC
    ''', [userId, now.millisecondsSinceEpoch]);

    return List.generate(maps.length, (i) {
      return InstallmentPaymentModel.fromMap(maps[i]);
    });
  }
} 