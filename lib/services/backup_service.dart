import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';

class BackupService {
  /// Sanitizes a string to make it safe for a filename.
  static String _sanitizeFilename(String title) {
    final clean = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return clean.isEmpty ? 'untitled' : clean;
  }

  /// Serializes a note to Markdown string with Front Matter headers.
  static String _serializeNoteToMarkdown(Note note) {
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('id: ${note.id}');
    buffer.writeln('title: ${note.title}');
    buffer.writeln('label: ${note.label}');
    buffer.writeln('date: ${note.date.toIso8601String()}');
    buffer.writeln('---');
    buffer.writeln(note.content);
    return buffer.toString();
  }

  /// Parses Markdown content with Front Matter headers back into a Note object.
  static Note _parseMarkdownNote(String filename, String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    if (lines.isNotEmpty && lines.first.trim() == '---') {
      int endFrontMatterIndex = -1;
      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim() == '---') {
          endFrontMatterIndex = i;
          break;
        }
      }

      if (endFrontMatterIndex != -1) {
        final frontMatterLines = lines.sublist(1, endFrontMatterIndex);
        final bodyLines = lines.sublist(endFrontMatterIndex + 1);

        String? id;
        String? title;
        String? label;
        DateTime? date;

        for (final line in frontMatterLines) {
          final colonIndex = line.indexOf(':');
          if (colonIndex != -1) {
            final key = line.substring(0, colonIndex).trim().toLowerCase();
            final value = line.substring(colonIndex + 1).trim();
            String cleanValue = value;
            if ((value.startsWith('"') && value.endsWith('"')) ||
                (value.startsWith("'") && value.endsWith("'"))) {
              cleanValue = value.substring(1, value.length - 1);
            }

            if (key == 'id') {
              id = cleanValue;
            } else if (key == 'title') {
              title = cleanValue;
            } else if (key == 'label') {
              label = cleanValue;
            } else if (key == 'date') {
              date = DateTime.tryParse(cleanValue);
            }
          }
        }

        final body = bodyLines.join('\n').trim();
        final cleanTitle = title ?? filename.replaceAll(RegExp(r'\.md$'), '');
        return Note(
          id: id ?? DateTime.now().millisecondsSinceEpoch.toString() + UniqueKey().toString(),
          title: cleanTitle.isEmpty ? 'Untitled' : cleanTitle,
          label: label ?? 'General',
          content: body,
          date: date ?? DateTime.now(),
        );
      }
    }

    // Fallback if no front matter headers exist
    final cleanTitle = filename.replaceAll(RegExp(r'\.md$'), '');
    return Note(
      id: DateTime.now().millisecondsSinceEpoch.toString() + UniqueKey().toString(),
      title: cleanTitle.isEmpty ? 'Untitled' : cleanTitle,
      label: 'General',
      content: content.trim(),
      date: DateTime.now(),
    );
  }

  /// Exports the given list of notes to a single ZIP file containing Markdown files,
  /// then triggers the system share sheet.
  static Future<void> exportNotes(List<Note> notes) async {
    if (notes.isEmpty) {
      throw Exception('no_notes');
    }

    final archive = Archive();

    // Add each note as a .md file inside the archive
    final Map<String, int> filenameCounts = {};
    for (final note in notes) {
      String baseFilename = _sanitizeFilename(note.title);
      String filename = '$baseFilename.md';

      // Avoid filename collision inside the ZIP
      if (filenameCounts.containsKey(baseFilename)) {
        final count = filenameCounts[baseFilename]! + 1;
        filenameCounts[baseFilename] = count;
        filename = '${baseFilename}_$count.md';
      } else {
        filenameCounts[baseFilename] = 1;
      }

      final content = _serializeNoteToMarkdown(note);
      final contentBytes = utf8.encode(content);
      final archiveFile = ArchiveFile(
        filename,
        contentBytes.length,
        contentBytes,
      );
      archive.addFile(archiveFile);
    }

    // Encode to ZIP
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final defaultFileName = 'towitowi_notes_backup_$timestamp.zip';

    // Show native save file dialog to let user select save path (e.g. Documents folder)
    final selectedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'backup_restore.save_backup_dialog_title'.tr(),
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: ['zip'],
      bytes: zipBytes is Uint8List ? zipBytes : Uint8List.fromList(zipBytes),
    );

    if (selectedPath == null) {
      // User cancelled the save operation
      throw Exception('cancelled');
    }

    // Write bytes to the selected destination path (needed on desktop platforms)
    final file = File(selectedPath);
    if (!await file.exists()) {
      await file.writeAsBytes(zipBytes);
    }
  }

  /// Picks one or multiple .md or .zip files and imports notes into NotesProvider.
  /// Returns the count of successfully imported/updated notes, or -1 if cancelled.
  static Future<int> importNotes(NotesProvider notesProvider) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['md', 'zip'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return -1;
    }

    int importCount = 0;
    int attemptedCount = 0;

    for (final file in result.files) {
      attemptedCount++;
      final extension = file.extension?.toLowerCase();

      // Retrieve bytes from the picked file
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        try {
          bytes = await File(file.path!).readAsBytes();
        } catch (e) {
          debugPrint('Error reading file bytes from path: ${file.path}, error: $e');
        }
      }

      if (bytes == null) {
        debugPrint('File bytes are null for file: ${file.name}');
        continue;
      }

      if (extension == 'zip') {
        try {
          final archive = ZipDecoder().decodeBytes(bytes);

          for (final archiveFile in archive) {
            if (archiveFile.isFile && archiveFile.name.endsWith('.md')) {
              try {
                final contentBytes = archiveFile.content as List<int>;
                final content = utf8.decode(contentBytes);
                final note = _parseMarkdownNote(archiveFile.name, content);
                await _saveImportedNote(notesProvider, note);
                importCount++;
              } catch (e) {
                debugPrint('Error importing file from zip: ${archiveFile.name}, error: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('Error decoding zip: ${file.name}, error: $e');
        }
      } else if (extension == 'md') {
        try {
          final content = utf8.decode(bytes);
          final note = _parseMarkdownNote(file.name, content);
          await _saveImportedNote(notesProvider, note);
          importCount++;
        } catch (e) {
          debugPrint('Error importing markdown file: ${file.name}, error: $e');
        }
      }
    }

    if (attemptedCount > 0 && importCount == 0) {
      throw Exception('no_valid_notes');
    }

    return importCount;
  }

  /// Saves the imported note, updating it if it already exists, or creating a new one.
  static Future<void> _saveImportedNote(NotesProvider notesProvider, Note note) async {
    final existingNote = notesProvider.getNoteById(note.id);
    if (existingNote != null) {
      await notesProvider.updateNote(note);
    } else {
      await notesProvider.addNote(note);
    }
  }

  static const String _lastBackupTimeKey = 'backup_service_last_auto_backup_time';

  /// Returns true if an auto-backup file already exists in application documents.
  static Future<bool> hasAutoBackup() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupFile = File('${directory.path}/towitowi_auto_backup.zip');
      return await backupFile.exists();
    } catch (_) {
      return false;
    }
  }

  /// Restores notes from the existing auto-backup file, returning the count of notes imported.
  static Future<int> restoreFromAutoBackup(NotesProvider notesProvider) async {
    final directory = await getApplicationDocumentsDirectory();
    final backupFile = File('${directory.path}/towitowi_auto_backup.zip');
    if (!await backupFile.exists()) {
      throw Exception('backup_file_not_found');
    }

    final bytes = await backupFile.readAsBytes();
    int importCount = 0;

    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final archiveFile in archive) {
        if (archiveFile.isFile && archiveFile.name.endsWith('.md')) {
          try {
            final contentBytes = archiveFile.content as List<int>;
            final content = utf8.decode(contentBytes);
            final note = _parseMarkdownNote(archiveFile.name, content);
            await _saveImportedNote(notesProvider, note);
            importCount++;
          } catch (e) {
            debugPrint('Error restoring file from zip: ${archiveFile.name}, error: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error decoding auto-backup zip: $e');
      throw Exception('invalid_backup_archive');
    }

    if (importCount == 0) {
      throw Exception('no_valid_notes');
    }

    return importCount;
  }

  /// Safely performs an auto-backup of the given notes list.
  /// It encodes notes to a ZIP, writes it to a temporary file,
  /// and renames/moves it to ensure atomic write.
  static Future<void> performAutoBackup(List<Note> notes) async {
    if (notes.isEmpty) return;

    try {
      final archive = Archive();
      final Map<String, int> filenameCounts = {};

      for (final note in notes) {
        String baseFilename = _sanitizeFilename(note.title);
        String filename = '$baseFilename.md';

        if (filenameCounts.containsKey(baseFilename)) {
          final count = filenameCounts[baseFilename]! + 1;
          filenameCounts[baseFilename] = count;
          filename = '${baseFilename}_$count.md';
        } else {
          filenameCounts[baseFilename] = 1;
        }

        final content = _serializeNoteToMarkdown(note);
        final contentBytes = utf8.encode(content);
        final archiveFile = ArchiveFile(
          filename,
          contentBytes.length,
          contentBytes,
        );
        archive.addFile(archiveFile);
      }

      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);

      final directory = await getApplicationDocumentsDirectory();
      final backupFile = File('${directory.path}/towitowi_auto_backup.zip');
      final tempFile = File('${directory.path}/towitowi_auto_backup.zip.tmp');

      // Write to temp file first
      final bytesToWrite = zipBytes is Uint8List ? zipBytes : Uint8List.fromList(zipBytes);
      await tempFile.writeAsBytes(bytesToWrite, flush: true);

      // Rename temp file to target backup file to overwrite atomically
      if (await tempFile.exists()) {
        await tempFile.rename(backupFile.path);
        debugPrint('Auto-backup completed successfully at: ${backupFile.path}');
      }
    } catch (e) {
      debugPrint('Auto-backup failed: $e');
    }
  }

  /// Triggers auto-backup if more than 12 hours have passed since the last one.
  static Future<void> checkAndTriggerAutoBackup(List<Note> notes) async {
    if (notes.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastBackupMillis = prefs.getInt(_lastBackupTimeKey) ?? 0;
      final nowMillis = DateTime.now().millisecondsSinceEpoch;

      // 12 hours = 12 * 60 * 60 * 1000 = 43,200,000 milliseconds
      const twelveHoursMillis = 12 * 60 * 60 * 1000;

      if (nowMillis - lastBackupMillis >= twelveHoursMillis) {
        await performAutoBackup(notes);
        await prefs.setInt(_lastBackupTimeKey, nowMillis);
      }
    } catch (e) {
      debugPrint('Error checking/triggering auto-backup: $e');
    }
  }
}
