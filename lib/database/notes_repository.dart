import '../models/note.dart';
import 'base_repository.dart';

/// A concrete repository implementation for the [Note] entity.
///
/// Extends the generic [BaseRepository] to provide SQLite storage
/// operations specifically for [Note] models.
class NotesRepository extends BaseRepository<Note> {
  static const String tableNotes = 'notes';

  NotesRepository({required super.dbService})
      : super(
          tableName: tableNotes,
          primaryKey: 'id',
          toMap: (note) => note.toMap(),
          fromMap: (map) => Note.fromMap(map),
        );

  /// Returns the SQL creation statement for the notes table.
  static String get createTableQuery => '''
    CREATE TABLE $tableNotes (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      label TEXT NOT NULL,
      date TEXT NOT NULL
    )
  ''';
}
