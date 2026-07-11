import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/database.dart';
import '../models/note.dart';

class LegacyMigrationService {
  /// Checks for the presence of the old sqflite database and migrates its data
  /// to the new Drift database if present.
  static Future<void> migrateIfNeeded(AppDatabase targetDb) async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux) return;

    if (Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    try {
      final dbPath = await getDatabasesPath();
      final oldDbPath = join(dbPath, 'stream_notes_v2.db');
      final oldDbFile = File(oldDbPath);

      if (await oldDbFile.exists()) {
        debugPrint('Legacy database found at $oldDbPath. Initiating migration...');
        
        // Open the legacy database using sqflite
        final legacyDb = await openDatabase(oldDbPath);
        
        // Query all notes from the 'notes' table
        final List<Map<String, dynamic>> noteMaps = await legacyDb.query('notes');
        
        debugPrint('Found ${noteMaps.length} legacy notes to migrate.');
        
        for (final map in noteMaps) {
          try {
            final note = Note.fromMap(map);
            // Convert to DriftNote and save
            await targetDb.saveNote(
              note.toDriftNote(
                createdAt: note.date,
                updatedAt: note.date,
                deleted: false,
              ),
            );
          } catch (e) {
            debugPrint('Failed to migrate note row $map: $e');
          }
        }
        
        // Close legacy database
        await legacyDb.close();
        
        // Rename the legacy file to mark migration as completed
        final migratedPath = '$oldDbPath.migrated';
        await oldDbFile.rename(migratedPath);
        debugPrint('Migration completed. Legacy database renamed to $migratedPath.');
      } else {
        debugPrint('No legacy database found at $oldDbPath. Skipping migration.');
      }
    } catch (e) {
      debugPrint('Error during legacy database migration: $e');
    }
  }
}
