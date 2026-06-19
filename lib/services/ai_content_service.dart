import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_generative_ai/google_generative_ai.dart';

class AiContentService {
  static const List<String> _modelCandidates = [
    'gemini-3.5-flash',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash-latest',
    'gemini-1.5-flash',
    'gemini-1.0-pro',
  ];

  GenerativeModel _getModel(String modelName, String apiKey, {Content? systemInstruction}) {
    return GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: systemInstruction,
    );
  }

  /// Helper to resolve the API Key, checking user input settings first, then
  /// compile-time --dart-define, and finally platform environment.
  String _resolveApiKey(String userApiKey) {
    if (userApiKey.trim().isNotEmpty) {
      return userApiKey.trim();
    }
    
    // Fallback to compile-time env
    String key = const String.fromEnvironment('GEMINI_API_KEY');
    if (key.isNotEmpty) {
      return key;
    }

    // Fallback to platform env
    try {
      if (!kIsWeb) {
        key = Platform.environment['GEMINI_API_KEY'] ?? '';
      }
    } catch (_) {}
    
    return key.trim();
  }

  /// Checks if any API key is configured either in Settings, compile-time define, or system environment.
  bool hasAnyConfiguredKey(String userApiKey) {
    return _resolveApiKey(userApiKey).isNotEmpty;
  }

  /// Emulates writing style based on few-shot examples and system instruction.
  Future<String> restructureThoughts(
    String rawThoughts,
    String userApiKey, {
    required String systemInstruction,
    required List<String> styleReferences,
  }) async {
    final apiKey = _resolveApiKey(userApiKey);
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key is not configured. Please enter your API key in Account Settings.');
    }

    final buffer = StringBuffer();
    buffer.writeln("Writing Style Reference Articles:");
    for (int i = 0; i < styleReferences.length; i++) {
      buffer.writeln("### REFERENCE ARTICLE ${i + 1} ###");
      buffer.writeln(styleReferences[i]);
      buffer.writeln();
    }
    buffer.writeln("Raw thoughts to restructure:");
    buffer.writeln(rawThoughts);

    return _generateWithFallback(
      buffer.toString(),
      apiKey,
      systemInstruction: Content.system(systemInstruction),
    );
  }

  /// Flow C (Restructure Comprehensive):
  /// Rewrites and restructures raw thoughts into comprehensive, polished writing.
  Future<String> restructureComprehensive(String rawThoughts, String userApiKey) async {
    final apiKey = _resolveApiKey(userApiKey);
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key is not configured. Please enter your API key in Account Settings or run the app with --dart-define=GEMINI_API_KEY=your_key.');
    }

    final prompt = "Rewrite and restructure these chaotic, rumbling thoughts into a comprehensive, well-formulated, and engaging piece of writing. Keep the tone natural and improve the overall flow. Return only the polished writing, do not include any intro or outro explanations.\n\n"
        "Raw thoughts:\n$rawThoughts";

    return _generateWithFallback(prompt, apiKey);
  }

  /// Flow A (Restructure & Summarize):
  /// 1. Rewrite and restructure chaotic raw thoughts.
  /// 2. Append divider '---' followed by a highly concise summary under 300 characters.
  Future<String> restructureAndSummarize(String rawThoughts, String userApiKey) async {
    final apiKey = _resolveApiKey(userApiKey);
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key is not configured. Please enter your API key in Account Settings or run the app with --dart-define=GEMINI_API_KEY=your_key.');
    }

    final prompt = "1. Rewrite and restructure these chaotic, fleeting thoughts into clear, well-formulated prose.\n"
        "2. At the very end of your response, add a divider '---' followed by a highly concise summary of the text that is strictly under 300 characters (including spaces).\n\n"
        "Raw thoughts:\n$rawThoughts";

    return _generateWithFallback(prompt, apiKey);
  }

  /// Flow B / Social Post Generation:
  /// Generates a punchy social media summary with a specific character limit (spaces and hashtags included).
  /// [maxCharacters] determines the limit (300 for Bluesky, 500 for Mastodon, 200 for General Share).
  /// [includeHashtags] specifies if hashtags should be generated.
  Future<String> generateSocialSummary({
    required String textContent,
    required String userApiKey,
    required int maxCharacters,
    required bool includeHashtags,
  }) async {
    final apiKey = _resolveApiKey(userApiKey);
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key is not configured. Please enter your API key in Account Settings or run the app with --dart-define=GEMINI_API_KEY=your_key.');
    }

    String prompt;
    if (includeHashtags) {
      prompt = "Generate a punchy, engaging social media summary of this text. It MUST include 2-3 relevant hashtags at the end. The ENTIRE summary, including spaces and hashtags, MUST be strictly under $maxCharacters characters.\n\n"
          "Text content:\n$textContent";
    } else {
      prompt = "Generate a punchy, engaging summary of this text. The ENTIRE summary, including spaces, MUST be strictly under $maxCharacters characters. Do NOT include hashtags.\n\n"
          "Text content:\n$textContent";
    }

    final result = await _generateWithFallback(prompt, apiKey);
    return result.trim();
  }

  /// Internal helper to attempt generation using model candidates, falling back sequentially if one fails.
  Future<String> _generateWithFallback(String prompt, String apiKey, {Content? systemInstruction}) async {
    final contents = [Content.text(prompt)];
    final List<String> errors = [];
    
    for (final modelName in _modelCandidates) {
      try {
        debugPrint('Attempting content generation with $modelName...');
        final model = _getModel(modelName, apiKey, systemInstruction: systemInstruction);
        final response = await model.generateContent(contents);
        if (response.text != null) {
          debugPrint('Successfully generated content with $modelName!');
          return response.text!;
        }
        errors.add('$modelName returned empty response.');
      } catch (e) {
        debugPrint('Failed to generate with $modelName: $e');
        errors.add('$modelName failed: ${e.toString()}');
      }
    }
    
    throw Exception('AI generation failed for all candidate models:\n${errors.join('\n')}');
  }
}
