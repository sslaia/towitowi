import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// A reusable, modular SQLite database service.
///
/// This class handles the initialization and lifecycle of the SQLite database.
/// It can be customized with a database name, version, and table schemas,
/// making it easily portable to other projects.
class DatabaseService {
  // Singleton instance
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  /// The name of the SQLite database file.
  String dbName = 'app_database.db';

  /// The version of the database schema.
  int dbVersion = 1;

  /// A list of SQL statements executed during table creation.
  List<String> onCreateTablesQueries = [];

  /// A custom callback invoked during database upgrades.
  FutureOr<void> Function(Database db, int oldVersion, int newVersion)? onUpgradeCallback;

  /// A custom callback invoked after table creation (e.g. for initial seeding).
  FutureOr<void> Function(Database db, int version)? onCreateCallback;

  /// Gets the active database instance, initializing it if necessary.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initializes the SQLite database connection.
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final pathString = join(dbPath, dbName);

    return await openDatabase(
      pathString,
      version: dbVersion,
      onCreate: (db, version) async {
        for (final query in onCreateTablesQueries) {
          await db.execute(query);
        }
        if (onCreateCallback != null) {
          await onCreateCallback!(db, version);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (onUpgradeCallback != null) {
          await onUpgradeCallback!(db, oldVersion, newVersion);
        }
      },
    );
  }

  /// Closes the database connection.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
