import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/views/tools/watermark_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/redaction_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Watermark & Redaction Screen UI Tests', () {
    testWidgets('WatermarkScreen renders Text and Image Watermark toggle cards',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WatermarkScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify both tabs exist
      expect(find.text('Image Watermark'), findsOneWidget);
      expect(find.text('Text Watermark'), findsOneWidget);

      // Verify auto-aligns info badge
      expect(find.textContaining('Auto-aligns to page rotation'), findsOneWidget);

      // Initially Text Watermark is selected
      expect(find.text('Watermark Text'), findsOneWidget);

      // Tap on Image Watermark toggle
      await tester.tap(find.text('Image Watermark'));
      await tester.pumpAndSettle();

      // Verify Image mode controls appear
      expect(find.text('Watermark Image'), findsOneWidget);
      expect(find.textContaining('Select PNG / JPG Logo'), findsOneWidget);
      expect(find.text('Scale'), findsOneWidget);

      // Tap back to Text Watermark
      await tester.tap(find.text('Text Watermark'));
      await tester.pumpAndSettle();
      expect(find.text('Watermark Text'), findsOneWidget);
    });

    testWidgets('RedactionScreen renders status banner and orientation badge',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RedactionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify status badge is always present
      expect(
        find.text('Visual redaction auto-aligns to page rotation & crop offsets'),
        findsOneWidget,
      );

      // Verify orientation tag chip
      expect(find.text('0° Upright'), findsOneWidget);

      // Verify empty state placeholder
      expect(find.text('Select PDF Document to Redact'), findsOneWidget);
      expect(find.text('No PDF Selected'), findsOneWidget);
    });
  });
}
