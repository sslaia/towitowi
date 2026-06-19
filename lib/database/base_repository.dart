import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

/// A reusable base repository that implements standard CRUD operations
/// for any data model class `T`.
///
/// By providing conversion callbacks ([toMap] and [fromMap]), it separates
/// SQLite-specific query logic from the domain models.
class BaseRepository<T> {
  final DatabaseService _dbService;
  final String tableName;
  final String primaryKey;
  final Map<String, dynamic> Function(T item) toMap;
  final T Function(Map<String, dynamic> map) fromMap;

  BaseRepository({
    required DatabaseService dbService,
    required this.tableName,
    required this.toMap,
    required this.fromMap,
    this.primaryKey = 'id',
  }) : _dbService = dbService;

  /// Inserts a new record or replaces an existing one if there's a conflict.
  Future<void> insert(T item) async {
    final db = await _dbService.database;
    await db.insert(
      tableName,
      toMap(item),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves all records from the table.
  Future<List<T>> getAll() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  /// Retrieves a single record by its primary key.
  Future<T?> getById(dynamic id) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: '$primaryKey = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return fromMap(maps.first);
  }

  /// Updates an existing record matching the primary key.
  Future<int> update(T item) async {
    final db = await _dbService.database;
    final mapData = toMap(item);
    final idValue = mapData[primaryKey];

    return await db.update(
      tableName,
      mapData,
      where: '$primaryKey = ?',
      whereArgs: [idValue],
    );
  }

  /// Deletes a record matching the primary key.
  Future<int> delete(dynamic id) async {
    final db = await _dbService.database;
    return await db.delete(
      tableName,
      where: '$primaryKey = ?',
      whereArgs: [id],
    );
  }

  /// Deletes all records from the table.
  Future<int> deleteAll() async {
    final db = await _dbService.database;
    return await db.delete(tableName);
  }
}
