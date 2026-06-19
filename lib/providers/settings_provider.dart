import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/style_references.dart';

class SettingsProvider with ChangeNotifier {
  static const String _bookmarksKey = 'bookmarked_note_ids';
  static const String _geminiApiKeyKey = 'secure_gemini_api_key';
  static const String _legacyGeminiApiKeyKey = 'settings_gemini_api_key';

  static const String _writingStyleInstructionEnKey = 'settings_writing_style_instruction_en';
  static const String _writingStyleInstructionIdKey = 'settings_writing_style_instruction_id';
  static const String _writingStyleSamplesEnKey = 'settings_writing_style_samples_en';
  static const String _writingStyleSamplesIdKey = 'settings_writing_style_samples_id';

  static const _secureStorage = FlutterSecureStorage();

  Set<String> _bookmarkedIds = {};
  String _geminiApiKey = '';
  bool _initialized = false;

  String _writingStyleInstructionEn = '';
  String _writingStyleInstructionId = '';
  List<String> _writingStyleSamplesEn = [];
  List<String> _writingStyleSamplesId = [];

  SettingsProvider() {
    _loadPreferences();
  }

  bool get isInitialized => _initialized;
  Set<String> get bookmarkedIds => _bookmarkedIds;
  String get geminiApiKey => _geminiApiKey;

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load standard bookmarks
      final List<String>? bookmarks = prefs.getStringList(_bookmarksKey);
      if (bookmarks != null) {
        _bookmarkedIds = bookmarks.toSet();
      }
      
      // Read securely
      String? savedApiKey = await _secureStorage.read(key: _geminiApiKeyKey);
      
      // Migration from insecure legacy SharedPreferences if needed
      if (savedApiKey == null || savedApiKey.trim().isEmpty) {
        final legacyKey = prefs.getString(_legacyGeminiApiKeyKey);
        if (legacyKey != null && legacyKey.trim().isNotEmpty) {
          savedApiKey = legacyKey;
          await _secureStorage.write(key: _geminiApiKeyKey, value: legacyKey);
          await prefs.remove(_legacyGeminiApiKeyKey);
        }
      }
      
      _geminiApiKey = savedApiKey ?? '';

      // Load writing style configuration
      _writingStyleInstructionEn = prefs.getString(_writingStyleInstructionEnKey) ?? StyleReferences.defaultInstructionEn;
      _writingStyleInstructionId = prefs.getString(_writingStyleInstructionIdKey) ?? StyleReferences.defaultInstructionId;
      _writingStyleSamplesEn = prefs.getStringList(_writingStyleSamplesEnKey) ?? List.from(StyleReferences.defaultArticlesEn);
      _writingStyleSamplesId = prefs.getStringList(_writingStyleSamplesIdKey) ?? List.from(StyleReferences.defaultArticlesId);
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  bool isBookmarked(String noteId) {
    return _bookmarkedIds.contains(noteId);
  }

  Future<void> toggleBookmark(String noteId) async {
    if (_bookmarkedIds.contains(noteId)) {
      _bookmarkedIds.remove(noteId);
    } else {
      _bookmarkedIds.add(noteId);
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_bookmarksKey, _bookmarkedIds.toList());
    } catch (e) {
      debugPrint('Error saving bookmarks: $e');
    }
  }

  Future<void> setGeminiApiKey(String key) async {
    _geminiApiKey = key;
    notifyListeners();

    try {
      if (key.trim().isEmpty) {
        await _secureStorage.delete(key: _geminiApiKeyKey);
      } else {
        await _secureStorage.write(key: _geminiApiKeyKey, value: key);
      }
    } catch (e) {
      debugPrint('Error saving Gemini API Key securely: $e');
    }
  }

  String getWritingStyleInstruction(String langCode) {
    if (langCode == 'id') {
      return _writingStyleInstructionId.isNotEmpty ? _writingStyleInstructionId : StyleReferences.defaultInstructionId;
    }
    return _writingStyleInstructionEn.isNotEmpty ? _writingStyleInstructionEn : StyleReferences.defaultInstructionEn;
  }

  List<String> getWritingStyleSamples(String langCode) {
    if (langCode == 'id') {
      return _writingStyleSamplesId.isNotEmpty ? _writingStyleSamplesId : StyleReferences.defaultArticlesId;
    }
    return _writingStyleSamplesEn.isNotEmpty ? _writingStyleSamplesEn : StyleReferences.defaultArticlesEn;
  }

  Future<void> setWritingStyleInstruction(String langCode, String instruction) async {
    if (langCode == 'id') {
      _writingStyleInstructionId = instruction;
    } else {
      _writingStyleInstructionEn = instruction;
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (langCode == 'id') {
        await prefs.setString(_writingStyleInstructionIdKey, instruction);
      } else {
        await prefs.setString(_writingStyleInstructionEnKey, instruction);
      }
    } catch (e) {
      debugPrint('Error saving writing style instruction: $e');
    }
  }

  Future<void> setWritingStyleSamples(String langCode, List<String> samples) async {
    if (langCode == 'id') {
      _writingStyleSamplesId = List.from(samples);
    } else {
      _writingStyleSamplesEn = List.from(samples);
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (langCode == 'id') {
        await prefs.setStringList(_writingStyleSamplesIdKey, samples);
      } else {
        await prefs.setStringList(_writingStyleSamplesEnKey, samples);
      }
    } catch (e) {
      debugPrint('Error saving writing style samples: $e');
    }
  }
}
