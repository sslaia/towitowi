import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/note.dart';
import '../database/database.dart';
import '../services/legacy_migration_service.dart';
import '../services/backup_service.dart';

class NotesProvider with ChangeNotifier {
  final List<Note> _notes = [];
  bool _isLoading = true;
  late final AppDatabase _db;
  Timer? _autoBackupTimer;

  NotesProvider() {
    _initDatabaseAndLoad();
    _startAutoBackupTimer();
  }

  List<Note> get notes => List.unmodifiable(_notes);
  bool get isLoading => _isLoading;
  AppDatabase get db => _db;

  Future<void> _initDatabaseAndLoad() async {
    if (kIsWeb) {
      _seedMockNotes();
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      // 1. Initialize Drift Database
      _db = AppDatabase();

      // 2. Perform legacy sqflite database migration if needed
      await LegacyMigrationService.migrateIfNeeded(_db);

      // 3. Load active notes
      await _loadNotesFromDb();
    } catch (e) {
      if (kDebugMode) {
        print("Database initialization failed, fallback to mock notes: $e");
      }
      _seedMockNotes();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _seedMockNotes() {
    _notes.addAll([
      Note(
        id: '1',
        title: 'Towi note 1',
        content: 'This is the first note content.',
        label: 'General',
        date: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      Note(
        id: '2',
        title: 'Towi note 2',
        content: 'This is the second note content.',
        label: 'Poetry',
        date: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Note(
        id: '3',
        title: 'Towi note 3',
        content: 'This is the third note content.',
        label: 'Ideas',
        date: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      Note(
        id: '4',
        title: 'Towi note 4',
        content: 'This is the fourth note content.',
        label: 'General',
        date: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Note(
        id: '5',
        title: 'Towi note 5',
        content: 'This is the fifth note content.',
        label: 'Draft',
        date: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Note(
        id: '6',
        title: 'Towi note 6',
        content: 'This is the sixth note content, which should be hidden initially.',
        label: 'General',
        date: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Note(
        id: '7',
        title: 'Towi note 7',
        content: 'This is the seventh note content, which should also be hidden initially.',
        label: 'Ideas',
        date: DateTime.now().subtract(const Duration(days: 4)),
      ),
    ]);
  }

  Future<void> _loadNotesFromDb() async {
    try {
      final driftNotes = await _db.getActiveNotes();
      final domainNotes = driftNotes.map((n) => n.toDomainNote()).toList();
      
      // Sort notes descending by date (newest first)
      domainNotes.sort((a, b) => b.date.compareTo(a.date));
      _notes.addAll(domainNotes);
    } catch (e) {
      if (kDebugMode) {
        print("Error loading notes: $e");
      }
      _seedMockNotes();
    } finally {
      _isLoading = false;
      notifyListeners();
      if (!kIsWeb) {
        BackupService.checkAndTriggerAutoBackup(_notes);
      }
    }
  }

  /// Reloads notes from the database. Useful after a synchronization cycle.
  Future<void> reloadNotes() async {
    _notes.clear();
    await _loadNotesFromDb();
  }

  Future<void> addNote(Note note) async {
    _notes.add(note);
    _notes.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    if (!kIsWeb) {
      await _db.saveNote(note.toDriftNote(createdAt: DateTime.now(), updatedAt: DateTime.now()));
      BackupService.checkAndTriggerAutoBackup(_notes);
    }
  }

  Future<void> updateNote(Note updatedNote) async {
    final index = _notes.indexWhere((note) => note.id == updatedNote.id);
    if (index != -1) {
      _notes[index] = updatedNote;
      _notes.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
      if (!kIsWeb) {
        await _db.saveNote(updatedNote.toDriftNote(updatedAt: DateTime.now()));
        BackupService.checkAndTriggerAutoBackup(_notes);
      }
    }
  }

  Future<void> deleteNote(String id) async {
    _notes.removeWhere((note) => note.id == id);
    notifyListeners();
    if (!kIsWeb) {
      await _db.softDeleteNote(id);
      BackupService.checkAndTriggerAutoBackup(_notes);
    }
  }

  Note? getNoteById(String id) {
    try {
      return _notes.firstWhere((note) => note.id == id);
    } catch (_) {
      return null;
    }
  }

  void _startAutoBackupTimer() {
    _autoBackupTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      if (!kIsWeb && _notes.isNotEmpty) {
        BackupService.checkAndTriggerAutoBackup(_notes);
      }
    });
  }

  @override
  void dispose() {
    _autoBackupTimer?.cancel();
    super.dispose();
  }
}
