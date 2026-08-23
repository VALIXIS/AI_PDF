import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pdf_ai_toolkit/services/ai/gemini_provider.dart';
import 'package:pdf_ai_toolkit/services/ai/hugging_face_provider.dart';
import 'package:pdf_ai_toolkit/services/ai/ai_provider_factory.dart';
import 'package:pdf_ai_toolkit/services/ai_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/controllers/ai_action_dispatcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Ensure dotenv is safely initialized for tests without real keys
    dotenv.testLoad(fileInput: 'HF_API_KEY=\nGEMINI_API_KEY=\n');
  });

  group('AI Provider Architecture & Strategy Unit Tests', () {
    test(
        'HuggingFaceProvider identifies providerName and defaults isConfigured correctly',
        () {
      final hf = HuggingFaceProvider();
      expect(hf.providerName, equals('HuggingFace'));
      expect(hf.isConfigured, isFalse);
    });

    test(
        'GeminiProvider identifies providerName and defaults isConfigured correctly',
        () {
      final gemini = GeminiProvider();
      expect(gemini.providerName, equals('Gemini'));
      expect(gemini.isConfigured, isFalse);
    });

    test('AiProviderFactory defaults to HuggingFace when Gemini key is absent',
        () {
      final factory = AiProviderFactory();
      expect(factory.activeProvider.providerName, equals('HuggingFace'));
    });

    test('HuggingFaceProvider throws exception when API key is missing',
        () async {
      final hf = HuggingFaceProvider();
      expect(
        () => hf.askPdfQuestion(
          pdfText: 'Sample text content',
          question: 'What is this document about?',
          conversationHistory: 'User: Hello\nAI Companion: Hi!',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test(
        'HuggingFaceProvider throws exception on multi-document comparison when missing key',
        () async {
      final hf = HuggingFaceProvider();
      expect(
        () => hf.compareDocuments(
          docTexts: ['Doc 1 text content', 'Doc 2 text content'],
          question: 'Compare Document 1 and Document 2',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test(
        'AiService routes requests via AiProviderFactory and throws when keys are absent',
        () async {
      final service = AiService();
      expect(service.activeProviderName, equals('HuggingFace'));

      expect(
        () => service.generateText('Flutter is awesome', AiService.modeNotes),
        throwsA(isA<Exception>()),
      );

      expect(
        () => service.askPdfQuestion(
          pdfText: 'Flutter widgets build UI.',
          question: 'What builds UI?',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('AiController throws exception when no providers are configured',
        () async {
      final controller = AiController();
      expect(
        () => controller.compareDocuments(
          docTexts: ['Version 1 specs', 'Version 2 specs'],
          question: 'What are the main changes between versions?',
          conversationHistory:
              'User: Summarize V1\nAI Companion: V1 is initial draft',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Autonomous Tool Intent Validation Tests', () {
    final dispatcher = AiActionDispatcher();

    test(
        'detectActionType detects multi-doc merge, split, compress, and text conversion',
        () {
      expect(dispatcher.detectActionType('Merge attached PDFs'),
          equals(AiActionType.merge));
      expect(dispatcher.detectActionType('Combine these 2 files'),
          equals(AiActionType.merge));
      expect(dispatcher.detectActionType('Split pages 1 to 3'),
          equals(AiActionType.split));
      expect(dispatcher.detectActionType('Compress this PDF file'),
          equals(AiActionType.compress));
      expect(dispatcher.detectActionType('Extract text from PDF'),
          equals(AiActionType.pdfToText));
      expect(dispatcher.detectActionType('Rotate 90 degrees'),
          equals(AiActionType.rotate));
      expect(dispatcher.detectActionType('Add watermark CONFIDENTIAL'),
          equals(AiActionType.watermark));
      expect(dispatcher.detectActionType('Protect PDF with password 12345'),
          equals(AiActionType.protect));
    });

    test(
        'detectActionType returns none for conversational document Q&A prompts',
        () {
      expect(
          dispatcher
              .detectActionType('Summarize the main points of this document'),
          equals(AiActionType.none));
      expect(dispatcher.detectActionType('What are the key conclusions?'),
          equals(AiActionType.none));
      expect(
          dispatcher
              .detectActionType('Compare this document with previous version'),
          equals(AiActionType.none));
    });
  });
}
