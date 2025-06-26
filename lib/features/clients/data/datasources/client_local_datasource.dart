import 'package:sqflite/sqflite.dart';
import '../../../../shared/database/database_helper.dart';
import '../models/client_model.dart';

abstract class ClientLocalDataSource {
  Future<List<ClientModel>> getAllClients(String userId);
  Future<ClientModel?> getClientById(String id);
  Future<String> createClient(ClientModel client);
  Future<void> updateClient(ClientModel client);
  Future<void> deleteClient(String id);
  Future<List<ClientModel>> searchClients(String userId, String query);
}

class ClientLocalDataSourceImpl implements ClientLocalDataSource {
  final DatabaseHelper _databaseHelper;

  ClientLocalDataSourceImpl(this._databaseHelper);

  @override
  Future<List<ClientModel>> getAllClients(String userId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clients',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return ClientModel.fromMap(maps[i]);
    });
  }

  @override
  Future<ClientModel?> getClientById(String id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return ClientModel.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<String> createClient(ClientModel client) async {
    final db = await _databaseHelper.database;
    await db.insert(
      'clients',
      client.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return client.id;
  }

  @override
  Future<void> updateClient(ClientModel client) async {
    final db = await _databaseHelper.database;
    await db.update(
      'clients',
      client.toMap(),
      where: 'id = ?',
      whereArgs: [client.id],
    );
  }

  @override
  Future<void> deleteClient(String id) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<ClientModel>> searchClients(String userId, String query) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clients',
      where: 'user_id = ? AND (full_name LIKE ? OR contact_number LIKE ? OR passport_number LIKE ?)',
      whereArgs: [userId, '%$query%', '%$query%', '%$query%'],
      orderBy: 'full_name ASC',
    );

    return List.generate(maps.length, (i) {
      return ClientModel.fromMap(maps[i]);
    });
  }
} 