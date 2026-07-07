import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/note.dart';

part 'database.g.dart';

@DataClassName('DriftNote')
class DriftNotes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get label => text()();
  DateTimeColumn get date => dateTime()();
  
  // Sync-related columns
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [DriftNotes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Fetch all active (non-deleted) notes
  Future<List<DriftNote>> getActiveNotes() {
    return (select(driftNotes)..where((t) => t.deleted.equals(false))).get();
  }

  // Fetch all notes (including tombstones for sync logic)
  Future<List<DriftNote>> getAllNotesIncludingDeleted() {
    return select(driftNotes).get();
  }

  // Insert or update a note
  Future<void> saveNote(DriftNote note) async {
    await into(driftNotes).insertOnConflictUpdate(note);
  }

  // Soft delete a note (sets deleted to true, updates updatedAt)
  Future<void> softDeleteNote(String id) async {
    await (update(driftNotes)..where((t) => t.id.equals(id))).write(
      DriftNotesCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // Hard delete a note (e.g. for database cleanup/wipe)
  Future<void> hardDeleteNote(String id) async {
    await (delete(driftNotes)..where((t) => t.id.equals(id))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(p.join(dbFolder.path, 'towitowi_v3.db'));
    return NativeDatabase.createInBackground(file);
  });
}

// Extensions for domain mapping
extension DriftNoteMapper on DriftNote {
  Note toDomainNote() {
    return Note(
      id: id,
      title: title,
      content: content,
      label: label,
      date: date,
    );
  }
}

extension DomainNoteMapper on Note {
  DriftNote toDriftNote({DateTime? createdAt, DateTime? updatedAt, bool deleted = false}) {
    return DriftNote(
      id: id,
      title: title,
      content: content,
      label: label,
      date: date,
      createdAt: createdAt ?? date,
      updatedAt: updatedAt ?? date,
      deleted: deleted,
    );
  }
}
