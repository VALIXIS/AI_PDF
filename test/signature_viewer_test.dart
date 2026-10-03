import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/models/saved_signature.dart';
import 'package:pdf_ai_toolkit/views/tools/signature_viewer_screen.dart';

void main() {
  late Directory tempDir;

  final dummyPngBytes = Uint8List.fromList([
    137, 80, 78, 71, 13, 10, 26, 10,
    0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
    0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180,
    0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
  ]);

  final sampleSignature = SavedSignature(
    id: 'test_viewer_sig_1',
    title: 'Executive Signature',
    createdAt: DateTime(2026, 10, 1, 14, 30),
    pngBytes: dummyPngBytes,
    colorValue: 0xFF2563EB, // Royal Blue
    strokeWidth: 4.5,
  );

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_sig_viewer_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SignatureViewerScreen Widget Tests', () {
    testWidgets('Renders full-screen viewer with zoom, backgrounds, and metadata',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignatureViewerScreen(signature: sampleSignature),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Title and Subtitle
      expect(find.text('Executive Signature'), findsOneWidget);
      expect(find.text('1/10/2026  14:30'), findsOneWidget);

      // Verify Action Buttons
      expect(find.byIcon(Icons.zoom_out_map_rounded), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsWidgets);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      // Verify Background Switcher
      expect(find.text('Canvas Background:'), findsOneWidget);
      expect(find.text('White'), findsOneWidget);
      expect(find.text('Grid'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      // Verify InteractiveViewer and Image
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      // Verify Metadata Chips
      expect(find.text('Ink Color'), findsOneWidget);
      expect(find.text('4.5 pt'), findsOneWidget);
      expect(find.text('Transparent PNG'), findsOneWidget);
      expect(find.text('Export / Share PNG'), findsOneWidget);
    });

    testWidgets('Tapping background options switches canvas background mode',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignatureViewerScreen(signature: sampleSignature),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Grid mode
      await tester.tap(find.text('Grid'));
      await tester.pumpAndSettle();

      // Tap Dark mode
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      // Tap White mode
      await tester.tap(find.text('White'));
      await tester.pumpAndSettle();

      expect(find.text('Executive Signature'), findsOneWidget);
    });

    testWidgets('Shows "Use Signature" button when allowUse is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignatureViewerScreen(
            signature: sampleSignature,
            allowUse: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Use Signature'), findsOneWidget);
    });
  });
}
