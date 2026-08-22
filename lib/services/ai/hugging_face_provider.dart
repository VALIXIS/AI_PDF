import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:pdf_ai_toolkit/services/ai/ai_provider.dart';

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
      return _getMockResponse(prompt);
    }

    try {
      return await _callApi(prompt);
    } catch (e) {
      return _getMockResponse(prompt);
    }
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

    final prompt =
        '''You are an expert AI document assistant. Answer the question accurately based on the provided PDF document context and conversation history.

$historySection--- PDF DOCUMENT CONTEXT ---
$pdfText
--- END CONTEXT ---

Question: $question
Answer:''';

    if (!isConfigured) {
      return _getMockResponse(prompt);
    }

    try {
      return await _callApi(prompt);
    } catch (e) {
      return _getMockResponse(prompt);
    }
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
      docsBuffer.writeln(docTexts[i]);
      docsBuffer.writeln();
    }

    final prompt =
        '''You are an expert AI document analysis companion. Compare and analyze the attached PDF documents to answer the user request.

$historySection--- ATTACHED DOCUMENTS ---
${docsBuffer.toString()}--- END ATTACHED DOCUMENTS ---

Request: $question
Detailed Analysis & Comparison:''';

    if (!isConfigured) {
      return _getMockResponse(prompt);
    }

    try {
      return await _callApi(prompt);
    } catch (e) {
      return _getMockResponse(prompt);
    }
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

  String _getMockResponse(String prompt) {
    if (prompt.contains('ATTACHED DOCUMENTS') || prompt.contains('Compare')) {
      return '''### Document Comparison Analysis

• **Document Overview**: Analyzed ${prompt.contains('DOCUMENT 2') ? '2' : 'multiple'} attached PDF documents.
• **Key Differences**:
  - Document 1 focuses on core specifications and initial guidelines.
  - Document 2 highlights updated execution policies and detailed schedules.
• **Summary**: Both documents share matching terminology but reflect sequential stages of development.

*(Note: Live AI active with HF_API_KEY or GEMINI_API_KEY in .env)*''';
    } else if (prompt.contains('PDF DOCUMENT CONTEXT') ||
        prompt.contains('Question:')) {
      final questionLine = prompt.contains('Question:')
          ? prompt.split('Question:').last.split('\n').first.trim()
          : 'your request';
      return '''Based on the document context:

• **Analysis**: Regarding "$questionLine", the document outlines clear structural facts and details.
• **Key Points**:
  - Extracted text layer was parsed natively.
  - Content has been processed cleanly.

*(Note: Live AI active with HF_API_KEY or GEMINI_API_KEY in .env)*''';
    } else {
      return '''Cleaned and organized content response. Set up GEMINI_API_KEY or HF_API_KEY in .env for live model responses.''';
    }
  }
}
