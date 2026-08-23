import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:pdf_ai_toolkit/services/ai/ai_provider.dart';
import 'package:pdf_ai_toolkit/services/ai/context_helper.dart';

class GeminiProvider implements AiProvider {
  @override
  String get providerName => 'Gemini';

  static String get _apiKey {
    if (!dotenv.isInitialized) return '';
    return dotenv.env['GEMINI_API_KEY'] ??
        dotenv.env['GOOGLE_GEMINI_API_KEY'] ??
        dotenv.env['GEMINI_KEY'] ??
        '';
  }

  // Model endpoints list for maximum API compatibility
  static const List<String> _modelEndpoints = [
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent',
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent',
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent',
  ];

  @override
  bool get isConfigured => _apiKey.isNotEmpty;

  @override
  Future<String> generateText(String input, String mode) async {
    if (input.trim().isEmpty) return input;
    final prompt = _buildPrompt(input, mode);

    if (!isConfigured) {
      throw Exception('Gemini API key is not configured in .env');
    }

    return await _callGeminiApi(prompt);
  }

  @override
  Future<String> askPdfQuestion({
    required String pdfText,
    required String question,
    String? conversationHistory,
  }) async {
    if (!isConfigured) {
      throw Exception('Gemini API key is not configured in .env');
    }

    final historySection = conversationHistory != null &&
            conversationHistory.isNotEmpty
        ? '--- RECENT CONVERSATION HISTORY ---\n$conversationHistory\n--- END HISTORY ---\n\n'
        : '';

    final limitedPdfText = ContextHelper.limitText(pdfText, maxChars: 600000);

    final prompt =
        '''You are an expert AI PDF Companion. Answer the user question accurately based on the PDF document text context and conversation history.

$historySection--- PDF DOCUMENT CONTEXT ---
$limitedPdfText
--- END CONTEXT ---

Question: $question
Answer:''';

    return await _callGeminiApi(prompt);
  }

  @override
  Future<String> compareDocuments({
    required List<String> docTexts,
    required String question,
    String? conversationHistory,
  }) async {
    if (!isConfigured) {
      throw Exception('Gemini API key is not configured in .env');
    }

    final historySection = conversationHistory != null &&
            conversationHistory.isNotEmpty
        ? '--- RECENT CONVERSATION HISTORY ---\n$conversationHistory\n--- END HISTORY ---\n\n'
        : '';

    final docsBuffer = StringBuffer();
    for (int i = 0; i < docTexts.length; i++) {
      docsBuffer.writeln('=== DOCUMENT ${i + 1} ===');
      docsBuffer
          .writeln(ContextHelper.limitText(docTexts[i], maxChars: 300000));
      docsBuffer.writeln();
    }

    final prompt =
        '''You are an expert AI PDF Companion specializing in multi-document analysis and comparison. Compare and analyze the attached PDF documents to fulfill the user request.

$historySection--- ATTACHED DOCUMENTS ---
${docsBuffer.toString()}--- END ATTACHED DOCUMENTS ---

Request: $question
Detailed Analysis & Comparison:''';

    return await _callGeminiApi(prompt);
  }

  Future<String> _callGeminiApi(String prompt) async {
    developer.log('AI Provider: Gemini', name: 'GeminiProvider');
    Object? lastError;
    for (final baseEndpoint in _modelEndpoints) {
      try {
        final url = Uri.parse('$baseEndpoint?key=$_apiKey');
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt}
                    ]
                  }
                ],
                'generationConfig': {
                  'temperature': 0.2,
                  'maxOutputTokens': 2048,
                }
              }),
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw Exception('Gemini API timeout'),
            );

        if (response.statusCode == 200) {
          return _parseGeminiResponse(response.body);
        } else {
          lastError = Exception(
              'Gemini API HTTP Error (${baseEndpoint.split('/').last.split(':').first}): ${response.statusCode} - ${response.body}');
          developer.log('Endpoint $baseEndpoint failed: $lastError',
              name: 'GeminiProvider');
          continue;
        }
      } catch (e) {
        lastError = e;
        developer.log('Endpoint $baseEndpoint failed with exception: $e',
            name: 'GeminiProvider');
        continue;
      }
    }
    throw Exception('All Gemini model endpoints failed: $lastError');
  }

  String _parseGeminiResponse(String body) {
    final data = jsonDecode(body);
    if (data is Map && data.containsKey('candidates')) {
      final candidates = data['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        if (content is Map && content.containsKey('parts')) {
          final parts = content['parts'];
          if (parts is List && parts.isNotEmpty) {
            return parts[0]['text'] ?? '';
          }
        }
      }
    }
    throw Exception('Failed to parse Gemini response payload');
  }

  String _buildPrompt(String input, String mode) {
    switch (mode) {
      case 'notes':
        return 'Convert the following text into structured, clear study notes with headers and bullet points:\n\n$input';
      case 'summary':
        return 'Summarize the following text concisely while retaining all critical facts:\n\n$input';
      case 'clean':
        return 'Clean and organize the following text for readability and structure:\n\n$input';
      default:
        return input;
    }
  }
}
