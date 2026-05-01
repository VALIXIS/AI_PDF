import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AiService {
  // Hugging Face API Configuration
  static String get _apiKey => dotenv.env['HF_API_KEY'] ?? '';
  static const String _baseUrl =
      'https://api-inference.huggingface.co/models/mistralai/Mistral-7B-Instruct-v0.2';

  // AI Mode constants
  static const String modeNotes = 'notes';
  static const String modeSummary = 'summary';
  static const String modeClean = 'clean';

  /// Generates text using Hugging Face API
  /// 
  /// [input] - The user input text
  /// [mode] - The processing mode: 'notes', 'summary', or 'clean'
  /// 
  /// Returns the generated text, or falls back to the original input if API fails
  Future<String> generateText(String input, String mode) async {
    try {
      // Validate input
      if (input.isEmpty) {
        return input;
      }

      // Select appropriate prompt builder based on mode
      final prompt = _buildPrompt(input, mode);

      if (_apiKey.isEmpty) {
        return _getMockResponse(prompt);
      }

      // Call Hugging Face API
      final result = await _callHuggingFaceAPI(prompt);

      return result;
    } catch (e) {
      // Graceful fallback: return original input on error
      return input;
    }
  }

  /// Calls the Hugging Face Inference API
  /// 
  /// Sends a POST request to Hugging Face and parses the response
  Future<String> _callHuggingFaceAPI(String prompt) async {
    try {
      if (_apiKey.isEmpty) {
        return _getMockResponse(prompt);
      }

      // Make POST request
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'inputs': prompt,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('API request timeout'),
      );

      // Handle response status codes
      if (response.statusCode == 200) {
        return _parseHuggingFaceResponse(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      } else if (response.statusCode == 503) {
        throw Exception('Hugging Face model is loading, please try again');
      } else {
        throw Exception(
            'API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to call Hugging Face API: $e');
    }
  }

  /// Parses the Hugging Face API response
  /// 
  /// Hugging Face returns: [{ "generated_text": "..." }]
  String _parseHuggingFaceResponse(String responseBody) {
    try {
      final data = jsonDecode(responseBody);

      // Handle list response format
      if (data is List && data.isNotEmpty) {
        final firstItem = data[0];
        if (firstItem is Map && firstItem.containsKey('generated_text')) {
          return firstItem['generated_text'] ?? '';
        }
      }

      // Handle direct object response
      if (data is Map && data.containsKey('generated_text')) {
        return data['generated_text'] ?? '';
      }

      throw Exception('Unexpected response format');
    } catch (e) {
      throw Exception('Failed to parse API response: $e');
    }
  }

  /// Builds the prompt based on the selected mode
  String _buildPrompt(String input, String mode) {
    switch (mode) {
      case modeNotes:
        return buildNotesPrompt(input);
      case modeSummary:
        return buildSummaryPrompt(input);
      case modeClean:
        return buildCleanPrompt(input);
      default:
        return input;
    }
  }

  /// Builds a structured notes prompt
  /// 
  /// Converts text into study notes with headings and bullet points
  String buildNotesPrompt(String input) {
    return 'Convert the following text into structured study notes. Use headings, bullet points, and keep it concise.\n\n$input';
  }

  /// Builds a summary prompt
  /// 
  /// Summarizes content into clear exam notes
  String buildSummaryPrompt(String input) {
    return 'Summarize the following content into clear exam notes.\n\n$input';
  }

  /// Builds a text cleanup prompt
  /// 
  /// Cleans and organizes text without changing meaning
  String buildCleanPrompt(String input) {
    return 'Clean and organize the following text without changing meaning.\n\n$input';
  }

  /// Legacy method for backward compatibility with existing code
  /// 
  /// This method is deprecated. Use [generateText] instead.
  @Deprecated('Use generateText instead')
  Future<String> callAi(String prompt) async {
    try {
      if (_apiKey.isEmpty) {
        return _getMockResponse(prompt);
      }

      final result = await _callHuggingFaceAPI(prompt);
      return result;
    } catch (e) {
      return _getMockResponse(prompt);
    }
  }

  /// Returns a mock response for testing without a valid API key
  /// 
  /// This is used as a fallback when API calls fail
  String _getMockResponse(String prompt) {
    if (prompt.contains('notes')) {
      return '''# Study Notes

## Main Concepts
• Core ideas from the material
• Key terminology explained
• Important relationships

## Summary
• Essential takeaways
• Key facts to remember

## Practice Questions
• Think about what was learned
• Consider real-world applications

Note: This is a demonstration response. Configure YOUR_HF_API_KEY in ai_service.dart for live AI processing.''';
    } else if (prompt.contains('summary')) {
      return '''This is a condensed summary of the provided content.

The key points have been extracted and organized logically. This demonstrates how the app processes and simplifies text for better comprehension.

To enable real API responses: Set up a Hugging Face API key (https://huggingface.co/settings/tokens) and add it to YOUR_HF_API_KEY in ai_service.dart.''';
    } else {
      return '''This is the cleaned and organized version of your text.

The content has been structured for clarity and readability while preserving the original meaning. Formatting and flow have been improved.

For production use: Replace YOUR_HF_API_KEY with your actual Hugging Face API token.''';
    }
  }
}
