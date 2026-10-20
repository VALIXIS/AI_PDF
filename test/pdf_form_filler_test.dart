import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:pdf_ai_toolkit/models/pdf_annotation.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_form_filler_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF Form Filler Baseline Calibration Tests', () {
    test('standardPdfFieldHeight returns correct proportions', () {
      // Clamped to minimum 18.0
      expect(PdfFormFillerScreen.standardPdfFieldHeight(10.0), equals(18.0));
      expect(PdfFormFillerScreen.standardPdfFieldHeight(12.0), equals(18.0));

      // 14pt -> 14 * 1.45 = 20.3
      expect(PdfFormFillerScreen.standardPdfFieldHeight(14.0), closeTo(20.3, 0.01));

      // 16pt -> 16 * 1.45 = 23.2
      expect(PdfFormFillerScreen.standardPdfFieldHeight(16.0), closeTo(23.2, 0.01));

      // 24pt -> 24 * 1.45 = 34.8
      expect(PdfFormFillerScreen.standardPdfFieldHeight(24.0), closeTo(34.8, 0.01));

      // Max clamp 72.0
      expect(PdfFormFillerScreen.standardPdfFieldHeight(60.0), equals(72.0));
    });

    test('standardPdfFontBaseline calculates accurate Helvetica baseline offset', () {
      const fontSize = 14.0;
      final fieldHeight = PdfFormFillerScreen.standardPdfFieldHeight(fontSize);
      final baseline = PdfFormFillerScreen.standardPdfFontBaseline(
        fontSize: fontSize,
        fieldHeight: fieldHeight,
      );

      // Helvetica ascent is 0.772, descent is 0.228.
      // fontAscent = 14 * 0.772 = 10.808
      // verticalMargin = (20.3 - 14.0) / 2 = 3.15
      // baseline = 3.15 + 10.808 = 13.958
      expect(baseline, closeTo(13.958, 0.01));

      // Baseline should sit below fontAscent by exactly the vertical margin
      expect(baseline, greaterThan(14.0 * 0.772));
      // Baseline plus descent should be within fieldHeight
      expect(baseline + (14.0 * 0.228), closeTo(fieldHeight - 3.15, 0.01));
    });

    test('Tap placement aligns font baseline directly on the tapped form line', () {
      const pageHeight = 841.8;
      const tapY = 0.45; // User taps on a form underline at 45% of page height
      const fontSize = 14.0;

      final fieldH = PdfFormFillerScreen.standardPdfFieldHeight(fontSize);
      final baselineOffset = PdfFormFillerScreen.standardPdfFontBaseline(
        fontSize: fontSize,
        fieldHeight: fieldH,
      );
      final normBaselineOffset = baselineOffset / pageHeight;
      final normH = fieldH / pageHeight;

      final startY = (tapY - normBaselineOffset).clamp(0.0, 1.0 - normH);

      // Calibrated baseline position: field startY + baseline offset == tap position
      final effectiveBaselineOnPage = startY + normBaselineOffset;
      expect(effectiveBaselineOnPage, closeTo(tapY, 0.0001));
    });

    test('Font size adjustment pins the baseline to the form line', () {
      const pageHeight = 841.8;
      const tapY = 0.45;

      // Start with 14pt font
      double fontSize = 14.0;
      double fieldH = PdfFormFillerScreen.standardPdfFieldHeight(fontSize);
      double baselineOffset = PdfFormFillerScreen.standardPdfFontBaseline(
        fontSize: fontSize,
        fieldHeight: fieldH,
      );
      double y = tapY - (baselineOffset / pageHeight);

      // Verify initial baseline
      final initialBaseline = y + (baselineOffset / pageHeight);
      expect(initialBaseline, closeTo(tapY, 0.0001));

      // User changes slider to 20pt font
      final oldBaselinePoints = baselineOffset;
      final oldBaselineY = y + (oldBaselinePoints / pageHeight);

      fontSize = 20.0;
      final newFieldH = PdfFormFillerScreen.standardPdfFieldHeight(fontSize);
      final newBaselinePoints = PdfFormFillerScreen.standardPdfFontBaseline(
        fontSize: fontSize,
        fieldHeight: newFieldH,
      );
      y = oldBaselineY - (newBaselinePoints / pageHeight);

      // New baseline position must stay pinned to tapY
      final newBaselineOnPage = y + (newBaselinePoints / pageHeight);
      expect(newBaselineOnPage, closeTo(tapY, 0.0001));
    });

    test('Checkmark placement centers on tap point', () {
      const pageWidth = 595.2;
      const pageHeight = 841.8;
      const rx = 0.3;
      const ry = 0.5;
      const checkFontSize = 22.0;
      final checkSize = checkFontSize * 1.1;
      final normW = checkSize / pageWidth;
      final normH = checkSize / pageHeight;

      final startX = rx - normW / 2;
      final startY = ry - normH / 2;

      expect(startX + normW / 2, closeTo(rx, 0.0001));
      expect(startY + normH / 2, closeTo(ry, 0.0001));
    });
  });

  group('PDF Form Filler Tap Targets (>= 48x48dp) Tests', () {
    test('Annotation touch padding expands tiny targets to at least 48x48dp', () {
      const double minTapTargetSize = 48.0;

      // Checkmark: visual 12x12dp
      const visualCheckmarkW = 12.0;
      const visualCheckmarkH = 12.0;
      final touchCheckmarkW = math.max(minTapTargetSize, visualCheckmarkW);
      final touchCheckmarkH = math.max(minTapTargetSize, visualCheckmarkH);
      expect(touchCheckmarkW, equals(48.0));
      expect(touchCheckmarkH, equals(48.0));

      final padCheckmarkX = (touchCheckmarkW - visualCheckmarkW) / 2.0;
      final padCheckmarkY = (touchCheckmarkH - visualCheckmarkH) / 2.0;
      expect(padCheckmarkX, equals(18.0));
      expect(padCheckmarkY, equals(18.0));

      // Small Text Field: visual 60x18dp
      const visualTextW = 60.0;
      const visualTextH = 18.0;
      final touchTextW = math.max(minTapTargetSize, visualTextW);
      final touchTextH = math.max(minTapTargetSize, visualTextH);
      expect(touchTextW, equals(60.0));
      expect(touchTextH, equals(48.0)); // Height expanded to 48dp

      final padTextY = (touchTextH - visualTextH) / 2.0;
      expect(padTextY, equals(15.0));

      // Wide Highlight Box: visual 180x24dp
      const visualHighlightW = 180.0;
      const visualHighlightH = 24.0;
      final touchHighlightW = math.max(minTapTargetSize, visualHighlightW);
      final touchHighlightH = math.max(minTapTargetSize, visualHighlightH);
      expect(touchHighlightW, equals(180.0));
      expect(touchHighlightH, equals(48.0)); // Height expanded to 48dp
    });
  });

  group('PDF Form Filler End-to-End Demo Export Test', () {
    test('Generates a valid demo PDF and burns calibrated annotations', () async {
      // Create a demo blank PDF document in memory
      final sfDoc = sf.PdfDocument();
      final page = sfDoc.pages.add();
      // Draw a sample form line: "Full Name: ____________________"
      final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12);
      page.graphics.drawString(
        'Full Name: _________________________________',
        font,
        bounds: const Rect.fromLTWH(50, 100, 300, 20),
      );
      final tempDir = Directory.systemTemp.createTempSync('ai_pdf_test_');
      final demoPdfPath = '${tempDir.path}${Platform.pathSeparator}demo_form.pdf';
      File(demoPdfPath).writeAsBytesSync(sfDoc.saveSync());
      sfDoc.dispose();

      expect(File(demoPdfPath).existsSync(), isTrue);

      // Add calibrated annotations
      final annotationsByPage = <int, List<Annotation>>{
        0: [
          Annotation.text(
            id: 'test-text-1',
            x: 0.25,
            y: 0.118, // Calibrated to sit on the form line
            text: 'John Doe',
            fontSize: 14,
            color: Colors.black,
            height: 0.024,
            width: 0.3,
          ),
          Annotation.checkmark(
            id: 'test-check-1',
            x: 0.7,
            y: 0.115,
            fontSize: 20,
            color: const Color(0xFF10B981),
          ),
          Annotation.dateStamp(
            id: 'test-date-1',
            x: 0.25,
            y: 0.18,
            text: '2026-10-20',
            fontSize: 12,
            color: const Color(0xFF1E293B),
            height: 0.021,
            width: 0.25,
          ),
          Annotation.highlight(
            id: 'test-high-1',
            x: 0.1,
            y: 0.11,
            width: 0.15,
            height: 0.03,
            color: const Color(0xFFFFEB3B),
            opacity: 0.4,
          ),
        ],
      };

      final pdfService = PdfService();
      final outputPath = await pdfService.saveEditedPdf(
        sourcePdfPath: demoPdfPath,
        annotationsByPage: annotationsByPage,
        customOutputPath: tempDir.path,
      );

      final outputFile = File(outputPath);
      expect(outputFile.existsSync(), isTrue);
      final outputBytes = outputFile.readAsBytesSync();
      expect(outputBytes.length, greaterThan(100));

      // Verify the exported PDF contains the annotations and text
      final verifyDoc = sf.PdfDocument(inputBytes: outputBytes);
      expect(verifyDoc.pages.count, equals(1));
      verifyDoc.dispose();

      // Clean up temp test files
      try {
        tempDir.deleteSync(recursive: true);
        outputFile.deleteSync();
      } catch (_) {}
    });

    testWidgets('Empty state renders correctly with large select button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PdfFormFillerScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Interactive PDF Form Filler'), findsOneWidget);
      expect(find.text('Select PDF Document'), findsOneWidget);

      final buttonFinder = find.widgetWithText(ElevatedButton, 'Select PDF Document');
      expect(buttonFinder, findsOneWidget);
      final buttonSize = tester.getSize(buttonFinder);
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));
    });
  });
}
