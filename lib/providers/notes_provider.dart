import 'package:flutter/foundation.dart';
import '../models/note.dart';
import '../database/database_service.dart';
import '../database/notes_repository.dart';

class NotesProvider with ChangeNotifier {
  final List<Note> _notes = [];
  bool _isLoading = true;
  late final NotesRepository _notesRepository;

  NotesProvider() {
    _initDatabaseAndLoad();
  }

  List<Note> get notes => List.unmodifiable(_notes);
  bool get isLoading => _isLoading;

  Future<void> _initDatabaseAndLoad() async {
    if (kIsWeb) {
      _seedMockNotes();
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      // 1. Configure DatabaseService
      final dbService = DatabaseService();
      dbService.dbName = 'stream_notes_v2.db';
      dbService.dbVersion = 1;
      // Register creation queries
      dbService.onCreateTablesQueries = [
        NotesRepository.createTableQuery,
      ];

      // 2. Instantiate repository
      _notesRepository = NotesRepository(dbService: dbService);

      // 3. Load notes
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
      final dbNotes = await _notesRepository.getAll();
      
      // Sort notes descending by date (newest first)
      dbNotes.sort((a, b) => b.date.compareTo(a.date));
      _notes.addAll(dbNotes);
    } catch (e) {
      if (kDebugMode) {
        print("Error loading notes: $e");
      }
      _seedMockNotes();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addNote(Note note) async {
    _notes.insert(0, note);
    notifyListeners();
    if (!kIsWeb) {
      await _notesRepository.insert(note);
    }
  }

  Future<void> updateNote(Note updatedNote) async {
    final index = _notes.indexWhere((note) => note.id == updatedNote.id);
    if (index != -1) {
      _notes[index] = updatedNote;
      notifyListeners();
      if (!kIsWeb) {
        await _notesRepository.update(updatedNote);
      }
    }
  }

  Future<void> deleteNote(String id) async {
    _notes.removeWhere((note) => note.id == id);
    notifyListeners();
    if (!kIsWeb) {
      await _notesRepository.delete(id);
    }
  }

  Note? getNoteById(String id) {
    try {
      return _notes.firstWhere((note) => note.id == id);
    } catch (_) {
      return null;
    }
  }
}
