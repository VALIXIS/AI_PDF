import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/services/ai_service.dart';
import 'package:pdf_ai_toolkit/views/tools/chat_with_pdf_screen.dart';

void main() {
  group('AI PDF Document Q&A & Chat Service Tests', () {
    final aiService = AiService();
    final aiController = AiController();

    test('askPdfQuestion throws exception when API key is missing', () async {
      const pdfContext =
          'Project Antigravity is an AI coding assistant designed by Google DeepMind.';
      const question = 'What is Project Antigravity?';

      expect(
        () => aiService.askPdfQuestion(
          pdfText: pdfContext,
          question: question,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('AiController.askDocumentQuestion validates non-empty question',
        () async {
      expect(
        () => aiController.askDocumentQuestion(
            pdfText: 'Sample text', question: '  '),
        throwsException,
      );
    });
  });

  group('ChatWithPdfScreen UI & State Tests', () {
    testWidgets('ChatWithPdfScreen displays AppBar and welcoming state',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ChatWithPdfScreen(),
      ));

      expect(find.text('AI PDF Companion'), findsOneWidget);
      expect(find.text('No active document'), findsOneWidget);
      expect(find.byIcon(Icons.file_upload_outlined), findsOneWidget);
    });

    testWidgets('ChatWithPdfScreen input bar displays send button',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ChatWithPdfScreen(),
      ));

      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });
  });
}
