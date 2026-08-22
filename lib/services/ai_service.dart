import 'package:pdf_ai_toolkit/services/ai/ai_provider_factory.dart';

class AiService {
  final AiProviderFactory _factory = AiProviderFactory();

  // AI Mode constants
  static const String modeNotes = 'notes';
  static const String modeSummary = 'summary';
  static const String modeClean = 'clean';

  /// Active AI Provider Name ('Gemini' or 'HuggingFace')
  String get activeProviderName => _factory.activeProvider.providerName;

  /// Generates text using Primary (Gemini) with Fallback (Hugging Face)
  Future<String> generateText(String input, String mode) async {
    return await _factory.generateText(input, mode);
  }

  /// Answers a question based on PDF document text context & optional chat history
  Future<String> askPdfQuestion({
    required String pdfText,
    required String question,
    String? conversationHistory,
  }) async {
    return await _factory.askPdfQuestion(
      pdfText: pdfText,
      question: question,
      conversationHistory: conversationHistory,
    );
  }

  /// Compares multiple document texts and answers user queries
  Future<String> compareDocuments({
    required List<String> docTexts,
    required String question,
    String? conversationHistory,
  }) async {
    return await _factory.compareDocuments(
      docTexts: docTexts,
      question: question,
      conversationHistory: conversationHistory,
    );
  }

  /// Legacy method for backward compatibility
  @Deprecated('Use generateText instead')
  Future<String> callAi(String prompt) async {
    return await _factory.generateText(prompt, modeClean);
  }
}
