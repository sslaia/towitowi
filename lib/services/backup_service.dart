import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
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
      dialogTitle: 'Save Backup Archive',
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
  /// Returns the count of successfully imported/updated notes.
  static Future<int> importNotes(NotesProvider notesProvider) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['md', 'zip'],
    );

    if (result == null || result.files.isEmpty) {
      return 0;
    }

    int importCount = 0;

    for (final file in result.files) {
      if (file.path == null) continue;

      final extension = file.extension?.toLowerCase();

      if (extension == 'zip') {
        final zipFile = File(file.path!);
        final bytes = await zipFile.readAsBytes();
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
      } else if (extension == 'md') {
        try {
          final mdFile = File(file.path!);
          final content = await mdFile.readAsString();
          final note = _parseMarkdownNote(file.name, content);
          await _saveImportedNote(notesProvider, note);
          importCount++;
        } catch (e) {
          debugPrint('Error importing markdown file: ${file.name}, error: $e');
        }
      }
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
}
