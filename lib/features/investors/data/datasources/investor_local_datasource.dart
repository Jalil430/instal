import 'package:sqflite/sqflite.dart';
import '../../../../shared/database/database_helper.dart';
import '../models/investor_model.dart';

abstract class InvestorLocalDataSource {
  Future<List<InvestorModel>> getAllInvestors(String userId);
  Future<InvestorModel?> getInvestorById(String id);
  Future<String> createInvestor(InvestorModel investor);
  Future<void> updateInvestor(InvestorModel investor);
  Future<void> deleteInvestor(String id);
  Future<List<InvestorModel>> searchInvestors(String userId, String query);
}

class InvestorLocalDataSourceImpl implements InvestorLocalDataSource {
  final DatabaseHelper _databaseHelper;

  InvestorLocalDataSourceImpl(this._databaseHelper);

  @override
  Future<List<InvestorModel>> getAllInvestors(String userId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'investors',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return InvestorModel.fromMap(maps[i]);
    });
  }

  @override
  Future<InvestorModel?> getInvestorById(String id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'investors',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return InvestorModel.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<String> createInvestor(InvestorModel investor) async {
    final db = await _databaseHelper.database;
    await db.insert(
      'investors',
      investor.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return investor.id;
  }

  @override
  Future<void> updateInvestor(InvestorModel investor) async {
    final db = await _databaseHelper.database;
    await db.update(
      'investors',
      investor.toMap(),
      where: 'id = ?',
      whereArgs: [investor.id],
    );
  }

  @override
  Future<void> deleteInvestor(String id) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'investors',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<InvestorModel>> searchInvestors(String userId, String query) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'investors',
      where: 'user_id = ? AND full_name LIKE ?',
      whereArgs: [userId, '%$query%'],
      orderBy: 'full_name ASC',
    );

    return List.generate(maps.length, (i) {
      return InvestorModel.fromMap(maps[i]);
    });
  }
} 