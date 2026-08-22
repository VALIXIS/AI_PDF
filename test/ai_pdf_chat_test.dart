import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/services/ai_service.dart';
import 'package:pdf_ai_toolkit/views/tools/chat_with_pdf_screen.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

void main() {
  group('AI PDF Document Q&A & Chat Service Tests', () {
    final aiService = AiService();
    final aiController = AiController();

    test('askPdfQuestion generates structured answer from PDF context',
        () async {
      const pdfContext =
          'Project Antigravity is an AI coding assistant designed by Google DeepMind.';
      const question = 'What is Project Antigravity?';

      final answer = await aiService.askPdfQuestion(
        pdfText: pdfContext,
        question: question,
      );

      expect(answer, isNotEmpty);
      expect(answer, contains('Project Antigravity'));
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
    testWidgets('ChatWithPdfScreen displays empty state when no PDF selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ChatWithPdfScreen(),
      ));

      expect(find.text('AI PDF Agent'), findsOneWidget);
      expect(find.byType(ToolEmptyState), findsOneWidget);
      expect(find.text('No PDF Document Selected'), findsOneWidget);
      expect(find.text('Select PDF Document'), findsOneWidget);
    });

    testWidgets('ChatWithPdfScreen header displays title and change button',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ChatWithPdfScreen(),
      ));

      expect(find.byIcon(Icons.folder_open_rounded), findsWidgets);
    });
  });
}
