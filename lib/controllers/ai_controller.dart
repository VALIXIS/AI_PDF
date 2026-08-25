import 'package:pdf_ai_toolkit/services/ai_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_action_dispatcher.dart';
import 'package:uuid/uuid.dart';

class AiMode {
  static const String notes = 'notes';
  static const String summary = 'summary';
  static const String clean = 'clean';
}

class AiController {
  final AiService _aiService = AiService();
  final AiActionDispatcher _actionDispatcher = AiActionDispatcher();
  static const uuid = Uuid();

  /// Processes document commands and detects executable tool actions
  Future<AiActionResult?> processDocumentAction({
    required String pdfPath,
    required String command,
  }) async {
    final type = _actionDispatcher.detectActionType(command);
    final ext = pdfPath.split('.').last.toLowerCase();
    final isConvertible =
        ext == 'md' || ext == 'markdown' || ext == 'html' || ext == 'htm';

    if (type == AiActionType.none && !isConvertible) return null;
    return await _actionDispatcher.executeAction(
      pdfPath: pdfPath,
      command: command,
    );
  }

  /// Processes multi-document commands (e.g. merging 2+ PDFs)
  Future<AiActionResult?> processMultiDocumentAction({
    required List<String> pdfPaths,
    required String command,
  }) async {
    final type = _actionDispatcher.detectActionType(command);
    if (type == AiActionType.merge && pdfPaths.length >= 2) {
      return await _actionDispatcher.executeMultiDocAction(
        pdfPaths: pdfPaths,
        command: command,
      );
    }
    if (pdfPaths.isNotEmpty) {
      return await processDocumentAction(
        pdfPath: pdfPaths.last,
        command: command,
      );
    }
    return null;
  }

  /// Processes text with selected AI mode using Hugging Face API
  ///
  /// Sends text to Hugging Face for processing and returns the generated result.
  /// Validates input and falls back gracefully on errors.
  Future<String> processText({
    required String input,
    required String mode,
  }) async {
    try {
      if (input.isEmpty) {
        throw Exception('Input text cannot be empty');
      }

      // Validate mode
      if (!getAvailableModes().contains(mode)) {
        throw Exception('Invalid mode: $mode');
      }

      // Use new generateText method with Hugging Face API
      return await _aiService.generateText(input, mode);
    } catch (e) {
      throw Exception('Failed to process text: $e');
    }
  }

  /// Gets the prompt for a specific mode
  String getPromptDescription(String mode) {
    switch (mode) {
      case AiMode.notes:
        return 'Convert text into organized notes with headers and bullet points';
      case AiMode.summary:
        return 'Create a concise summary of the text';
      case AiMode.clean:
        return 'Polish and refine text for clarity and professionalism';
      default:
        return 'Unknown mode';
    }
  }

  /// Gets all available modes
  List<String> getAvailableModes() {
    return [AiMode.notes, AiMode.summary, AiMode.clean];
  }

  /// Answers a question about a PDF document with optional conversation history context
  Future<String> askDocumentQuestion({
    required String pdfText,
    required String question,
    String? conversationHistory,
  }) async {
    try {
      if (question.trim().isEmpty) {
        throw Exception('Question cannot be empty');
      }
      return await _aiService.askPdfQuestion(
        pdfText: pdfText,
        question: question.trim(),
        conversationHistory: conversationHistory,
      );
    } catch (e) {
      throw Exception('Failed to get answer: $e');
    }
  }

  /// Compares multiple PDF documents and answers user request
  Future<String> compareDocuments({
    required List<String> docTexts,
    required String question,
    String? conversationHistory,
  }) async {
    try {
      if (question.trim().isEmpty) {
        throw Exception('Question cannot be empty');
      }
      if (docTexts.isEmpty) {
        throw Exception('Document list cannot be empty');
      }
      return await _aiService.compareDocuments(
        docTexts: docTexts,
        question: question.trim(),
        conversationHistory: conversationHistory,
      );
    } catch (e) {
      throw Exception('Failed to compare documents: $e');
    }
  }

  /// Active AI provider name
  String get activeProviderName => _aiService.activeProviderName;

  /// Generates a unique ID for history entries
  String generateId() {
    return uuid.v4();
  }
}
