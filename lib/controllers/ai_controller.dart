import 'package:pdf_ai_toolkit/services/ai_service.dart';
import 'package:uuid/uuid.dart';

class AiMode {
  static const String notes = 'notes';
  static const String summary = 'summary';
  static const String clean = 'clean';
}

class AiController {
  final AiService _aiService = AiService();
  static const uuid = Uuid();

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

  /// Answers a question about a PDF document
  Future<String> askDocumentQuestion({
    required String pdfText,
    required String question,
  }) async {
    try {
      if (question.trim().isEmpty) {
        throw Exception('Question cannot be empty');
      }
      return await _aiService.askPdfQuestion(
        pdfText: pdfText,
        question: question.trim(),
      );
    } catch (e) {
      throw Exception('Failed to get answer: $e');
    }
  }

  /// Generates a unique ID for history entries
  String generateId() {
    return uuid.v4();
  }
}
