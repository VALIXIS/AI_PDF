import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:pdf_ai_toolkit/services/ai/ai_provider.dart';
import 'package:pdf_ai_toolkit/services/ai/context_helper.dart';

class HuggingFaceProvider implements AiProvider {
  @override
  String get providerName => 'HuggingFace';

  static String get _apiKey {
    if (!dotenv.isInitialized) return '';
    return dotenv.env['HF_API_KEY'] ?? dotenv.env['HUGGINGFACE_API_KEY'] ?? '';
  }

  static const String _baseUrl =
      'https://api-inference.huggingface.co/models/mistralai/Mistral-7B-Instruct-v0.2';

  @override
  bool get isConfigured => _apiKey.isNotEmpty;

  @override
  Future<String> generateText(String input, String mode) async {
    if (input.trim().isEmpty) return input;
    final prompt = _buildPrompt(input, mode);

    if (!isConfigured) {
      throw Exception('Hugging Face API key is not configured in .env');
    }

    return await _callApi(prompt);
  }

  @override
  Future<String> askPdfQuestion({
    required String pdfText,
    required String question,
    String? conversationHistory,
  }) async {
    final historySection = conversationHistory != null &&
            conversationHistory.isNotEmpty
        ? '--- RECENT CONVERSATION HISTORY ---\n$conversationHistory\n--- END HISTORY ---\n\n'
        : '';

    final limitedPdfText = ContextHelper.limitText(pdfText, maxChars: 30000);

    final prompt =
        '''You are an expert AI document assistant. Answer the question accurately based on the provided PDF document context and conversation history.

$historySection--- PDF DOCUMENT CONTEXT ---
$limitedPdfText
--- END CONTEXT ---

Question: $question
Answer:''';

    if (!isConfigured) {
      throw Exception('Hugging Face API key is not configured in .env');
    }

    return await _callApi(prompt);
  }

  @override
  Future<String> compareDocuments({
    required List<String> docTexts,
    required String question,
    String? conversationHistory,
  }) async {
    final historySection = conversationHistory != null &&
            conversationHistory.isNotEmpty
        ? '--- RECENT CONVERSATION HISTORY ---\n$conversationHistory\n--- END HISTORY ---\n\n'
        : '';

    final docsBuffer = StringBuffer();
    for (int i = 0; i < docTexts.length; i++) {
      docsBuffer.writeln('=== DOCUMENT ${i + 1} ===');
      docsBuffer.writeln(ContextHelper.limitText(docTexts[i], maxChars: 15000));
      docsBuffer.writeln();
    }

    final prompt =
        '''You are an expert AI document analysis companion. Compare and analyze the attached PDF documents to answer the user request.

$historySection--- ATTACHED DOCUMENTS ---
${docsBuffer.toString()}--- END ATTACHED DOCUMENTS ---

Request: $question
Detailed Analysis & Comparison:''';

    if (!isConfigured) {
      throw Exception('Hugging Face API key is not configured in .env');
    }

    return await _callApi(prompt);
  }

  Future<String> _callApi(String prompt) async {
    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'inputs': prompt}),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw Exception('Hugging Face API request timeout'),
        );

    if (response.statusCode == 200) {
      return _parseResponse(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Invalid Hugging Face API key');
    } else if (response.statusCode == 503) {
      throw Exception('Hugging Face model loading, please retry');
    } else {
      throw Exception('Hugging Face API Error: ${response.statusCode}');
    }
  }

  String _parseResponse(String body) {
    final data = jsonDecode(body);
    if (data is List && data.isNotEmpty) {
      final item = data[0];
      if (item is Map && item.containsKey('generated_text')) {
        return item['generated_text'] ?? '';
      }
    }
    if (data is Map && data.containsKey('generated_text')) {
      return data['generated_text'] ?? '';
    }
    throw Exception('Unexpected Hugging Face response format');
  }

  String _buildPrompt(String input, String mode) {
    switch (mode) {
      case 'notes':
        return 'Convert the following text into structured study notes:\n\n$input';
      case 'summary':
        return 'Summarize the following content clearly:\n\n$input';
      case 'clean':
        return 'Clean and organize the following text:\n\n$input';
      default:
        return input;
    }
  }
}
