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

  /// Generates executive briefs with intelligent fallback strategy (Primary: Gemini -> Fallback: Hugging Face -> Local Fallback)
  Future<String> generateExecutiveBrief({required String pdfText}) async {
    if (_geminiProvider.isConfigured) {
      try {
        developer.log('Executing generateExecutiveBrief via primary GeminiProvider',
            name: 'AiProviderFactory');
        return await _geminiProvider.generateExecutiveBrief(pdfText: pdfText);
      } catch (e) {
        developer.log('GeminiProvider failed: $e.', name: 'AiProviderFactory');
        if (_huggingFaceProvider.isConfigured) {
          try {
            developer.log('Falling back to HuggingFaceProvider',
                name: 'AiProviderFactory');
            return await _huggingFaceProvider.generateExecutiveBrief(
                pdfText: pdfText);
          } catch (hfe) {
            developer.log('HuggingFaceProvider failed: $hfe',
                name: 'AiProviderFactory');
          }
        }
      }
    } else if (_huggingFaceProvider.isConfigured) {
      try {
        developer.log('Executing generateExecutiveBrief via HuggingFaceProvider',
            name: 'AiProviderFactory');
        return await _huggingFaceProvider.generateExecutiveBrief(
            pdfText: pdfText);
      } catch (e) {
        developer.log('HuggingFaceProvider failed: $e',
            name: 'AiProviderFactory');
      }
    }

    // Fallback local executive brief generator when no API keys are configured in .env
    developer.log(
        'No active online AI API key configured in .env. Using structured offline document brief generator.',
        name: 'AiProviderFactory');
    return _generateOfflineExecutiveBrief(pdfText);
  }

  String _generateOfflineExecutiveBrief(String pdfText) {
    final cleanText = pdfText.trim();
    if (cleanText.isEmpty) {
      return '''# Executive Summary
No extractable text found in the document.

## Key Action Items
- Ensure the document contains readable text layers.

## Critical Dates
- No specific critical dates mentioned in document.''';
    }

    final sentences = cleanText
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().length > 10)
        .toList();

    // 1. Executive Summary: First 3-4 significant sentences
    final summarySentences = sentences.take(4).join(' ');
    final execSummary = summarySentences.isNotEmpty
        ? summarySentences
        : cleanText.substring(0, cleanText.length.clamp(0, 300));

    // 2. Key Action Items: Sentences containing action keywords
    final actionKeywords = RegExp(
        r'\b(must|shall|should|will|require|action|complete|submit|review|approve|deliver|manage|ensure|deadline|task|objective)\b',
        caseSensitive: false);
    final actionItems = sentences
        .where((s) => actionKeywords.hasMatch(s))
        .take(6)
        .map((s) => '- ${s.trim()}')
        .toList();

    if (actionItems.isEmpty) {
      actionItems.addAll(
        sentences.skip(4).take(4).map((s) => '- ${s.trim()}'),
      );
    }
    if (actionItems.isEmpty) {
      actionItems.add(
          '- Review document contents and verify operational requirements.');
    }

    // 3. Critical Dates: Extract date patterns
    final datePattern = RegExp(
        r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2}|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{1,2}(?:st|nd|rd|th)?,? \d{4}|\d{1,2} (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{4}|Q[1-4] \d{4})\b',
        caseSensitive: false);

    final dateSentences = <String>[];
    for (final s in sentences) {
      final match = datePattern.firstMatch(s);
      if (match != null) {
        dateSentences.add('- **${match.group(0)}**: ${s.trim()}');
        if (dateSentences.length >= 5) break;
      }
    }

    final datesSection = dateSentences.isNotEmpty
        ? dateSentences.join('\n')
        : '- No specific critical dates mentioned in document.';

    return '''# Executive Summary
$execSummary

## Key Action Items
${actionItems.join('\n')}

## Critical Dates
$datesSection''';
  }
}
