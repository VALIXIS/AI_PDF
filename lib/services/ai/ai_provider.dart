abstract class AiProvider {
  /// Name of the AI provider (e.g., 'Gemini', 'HuggingFace')
  String get providerName;

  /// Returns true if the provider has a valid API key configured
  bool get isConfigured;

  /// Generates text for general modes ('notes', 'summary', 'clean')
  Future<String> generateText(String input, String mode);

  /// Answers a question based on PDF text context and optional chat history
  Future<String> askPdfQuestion({
    required String pdfText,
    required String question,
    String? conversationHistory,
  });

  /// Compares multiple document texts and answers user query
  Future<String> compareDocuments({
    required List<String> docTexts,
    required String question,
    String? conversationHistory,
  });
}
