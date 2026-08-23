import 'dart:developer' as developer;
import 'package:pdf_ai_toolkit/services/ai/ai_provider.dart';
import 'package:pdf_ai_toolkit/services/ai/gemini_provider.dart';
import 'package:pdf_ai_toolkit/services/ai/hugging_face_provider.dart';

class AiProviderFactory {
  final GeminiProvider _geminiProvider = GeminiProvider();
  final HuggingFaceProvider _huggingFaceProvider = HuggingFaceProvider();

  /// Gets the primary AI provider (Gemini if configured, else Hugging Face)
  AiProvider get activeProvider {
    if (_geminiProvider.isConfigured) {
      return _geminiProvider;
    }
    return _huggingFaceProvider;
  }

  /// Generates text with intelligent fallback strategy (Primary: Gemini -> Fallback: Hugging Face)
  Future<String> generateText(String input, String mode) async {
    if (_geminiProvider.isConfigured) {
      try {
        developer.log('Executing text generation via primary GeminiProvider',
            name: 'AiProviderFactory');
        return await _geminiProvider.generateText(input, mode);
      } catch (e) {
        developer.log('GeminiProvider failed: $e.', name: 'AiProviderFactory');
        if (!_huggingFaceProvider.isConfigured) {
          rethrow;
        }
        developer.log('Gracefully falling back to HuggingFaceProvider',
            name: 'AiProviderFactory');
        return await _huggingFaceProvider.generateText(input, mode);
      }
    }
    return await _huggingFaceProvider.generateText(input, mode);
  }

  /// Answers PDF questions with intelligent fallback strategy (Primary: Gemini -> Fallback: Hugging Face)
  Future<String> askPdfQuestion({
    required String pdfText,
    required String question,
    String? conversationHistory,
  }) async {
    if (_geminiProvider.isConfigured) {
      try {
        developer.log('Executing askPdfQuestion via primary GeminiProvider',
            name: 'AiProviderFactory');
        return await _geminiProvider.askPdfQuestion(
          pdfText: pdfText,
          question: question,
          conversationHistory: conversationHistory,
        );
      } catch (e) {
        developer.log('GeminiProvider failed: $e.', name: 'AiProviderFactory');
        if (!_huggingFaceProvider.isConfigured) {
          rethrow;
        }
        developer.log('Gracefully falling back to HuggingFaceProvider',
            name: 'AiProviderFactory');
        return await _huggingFaceProvider.askPdfQuestion(
          pdfText: pdfText,
          question: question,
          conversationHistory: conversationHistory,
        );
      }
    }
    return await _huggingFaceProvider.askPdfQuestion(
      pdfText: pdfText,
      question: question,
      conversationHistory: conversationHistory,
    );
  }

  /// Compares documents with intelligent fallback strategy (Primary: Gemini -> Fallback: Hugging Face)
  Future<String> compareDocuments({
    required List<String> docTexts,
    required String question,
    String? conversationHistory,
  }) async {
    if (_geminiProvider.isConfigured) {
      try {
        developer.log('Executing compareDocuments via primary GeminiProvider',
            name: 'AiProviderFactory');
        return await _geminiProvider.compareDocuments(
          docTexts: docTexts,
          question: question,
          conversationHistory: conversationHistory,
        );
      } catch (e) {
        developer.log('GeminiProvider failed: $e.', name: 'AiProviderFactory');
        if (!_huggingFaceProvider.isConfigured) {
          rethrow;
        }
        developer.log('Gracefully falling back to HuggingFaceProvider',
            name: 'AiProviderFactory');
        return await _huggingFaceProvider.compareDocuments(
          docTexts: docTexts,
          question: question,
          conversationHistory: conversationHistory,
        );
      }
    }
    return await _huggingFaceProvider.compareDocuments(
      docTexts: docTexts,
      question: question,
      conversationHistory: conversationHistory,
    );
  }
}
