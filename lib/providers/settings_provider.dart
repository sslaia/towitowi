import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/style_references.dart';

class SettingsProvider with ChangeNotifier {
  static const String _bookmarksKey = 'bookmarked_note_ids';
  static const String _geminiApiKeyKey = 'secure_gemini_api_key';
  static const String _legacyGeminiApiKeyKey = 'settings_gemini_api_key';
  static const String _onboardingCompletedKey = 'settings_onboarding_completed';
  static const String _themeModeKey = 'settings_theme_mode';
  static const String _showGeminiSetupAlertKey = 'settings_show_gemini_setup_alert';
  static const String _geminiSetupAlertNextShowTimeKey = 'settings_gemini_setup_alert_next_show_time';

  static const String _writingStyleInstructionEnKey = 'settings_writing_style_instruction_en';
  static const String _writingStyleInstructionIdKey = 'settings_writing_style_instruction_id';
  static const String _writingStyleSamplesEnKey = 'settings_writing_style_samples_en';
  static const String _writingStyleSamplesIdKey = 'settings_writing_style_samples_id';

  static const _secureStorage = FlutterSecureStorage();

  Set<String> _bookmarkedIds = {};
  String _geminiApiKey = '';
  bool _initialized = false;
  bool _onboardingCompleted = false;
  ThemeMode _themeMode = ThemeMode.system;
  bool _showGeminiSetupAlert = true;
  int _geminiSetupAlertNextShowTime = 0;

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
  bool get isOnboardingCompleted => _onboardingCompleted;
  ThemeMode get themeMode => _themeMode;
  bool get showGeminiSetupAlert => _showGeminiSetupAlert;
  int get geminiSetupAlertNextShowTime => _geminiSetupAlertNextShowTime;

  bool get shouldShowGeminiSetupAlert {
    if (!_showGeminiSetupAlert) return false;
    if (_geminiApiKey.trim().isNotEmpty) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now >= _geminiSetupAlertNextShowTime;
  }

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
      
      // Load onboarding status
      _onboardingCompleted = prefs.getBool(_onboardingCompletedKey) ?? false;

      // Load theme mode preference
      final String? themeModeStr = prefs.getString(_themeModeKey);
      if (themeModeStr != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (e) => e.name == themeModeStr,
          orElse: () => ThemeMode.system,
        );
      }
      _showGeminiSetupAlert = prefs.getBool(_showGeminiSetupAlertKey) ?? true;
      _geminiSetupAlertNextShowTime = prefs.getInt(_geminiSetupAlertNextShowTimeKey) ?? 0;
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> completeOnboarding() async {
    _onboardingCompleted = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, true);
    } catch (e) {
      debugPrint('Error saving onboarding preference: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
    } catch (e) {
      debugPrint('Error saving theme mode preference: $e');
    }
  }

  Future<void> resetOnboarding() async {
    _onboardingCompleted = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, false);
    } catch (e) {
      debugPrint('Error resetting onboarding preference: $e');
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

  Future<void> disableGeminiSetupAlertForever() async {
    _showGeminiSetupAlert = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_showGeminiSetupAlertKey, false);
    } catch (e) {
      debugPrint('Error saving disable Gemini alert preference: $e');
    }
  }

  Future<void> snoozeGeminiSetupAlert(int days) async {
    final nextTime = DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;
    _geminiSetupAlertNextShowTime = nextTime;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_geminiSetupAlertNextShowTimeKey, nextTime);
    } catch (e) {
      debugPrint('Error saving snooze Gemini alert preference: $e');
    }
  }
}
