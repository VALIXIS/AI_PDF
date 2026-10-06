import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/models/saved_signature.dart';
import 'package:pdf_ai_toolkit/services/signature_storage_service.dart';
import 'package:pdf_ai_toolkit/views/tools/signature_canvas_screen.dart';

void main() {
  late Directory tempDir;

  final dummyPngBytes = Uint8List.fromList([
    137, 80, 78, 71, 13, 10, 26, 10,
    0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
    0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180,
    0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
  ]);

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_sig_ui_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SignatureCanvasScreen Widget Tests', () {
    testWidgets('Renders canvas, tools, sliders, and color palette cleanly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignatureCanvasScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Digital E-Signature Pad'), findsOneWidget);
      expect(find.text('Sign Here'), findsOneWidget);
      expect(find.text('Thickness:'), findsOneWidget);
      expect(find.text('Ink Color:'), findsOneWidget);
      expect(find.text('Saved Signatures'), findsOneWidget);
      expect(find.text('Save Signature'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Drawing on canvas adds stroke and removes "Sign Here" watermark',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignatureCanvasScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign Here'), findsOneWidget);

      final canvasFinder = find.byType(CustomPaint).first;
      final center = tester.getCenter(canvasFinder);

      // Draw stroke
      await tester.dragFrom(center, const Offset(50, 30));
      await tester.pumpAndSettle();

      // "Sign Here" text should be gone once strokes exist
      expect(find.text('Sign Here'), findsNothing);

      // Tap Undo to remove stroke
      final undoButton = find.byTooltip('Undo');
      expect(undoButton, findsOneWidget);
      await tester.tap(undoButton);
      await tester.pumpAndSettle();

      // "Sign Here" should reappear after undo
      expect(find.text('Sign Here'), findsOneWidget);
    });

    testWidgets('Clear button clears all drawn strokes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignatureCanvasScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final canvasFinder = find.byType(CustomPaint).first;
      final center = tester.getCenter(canvasFinder);

      // Draw stroke
      await tester.dragFrom(center, const Offset(40, 40));
      await tester.pumpAndSettle();

      expect(find.text('Sign Here'), findsNothing);

      // Tap Clear
      final clearButton = find.byTooltip('Clear Canvas');
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(find.text('Sign Here'), findsOneWidget);
    });

    testWidgets('SavedSignaturesSheet displays saved signatures and handles selection',
        (tester) async {
      SavedSignature? selectedSig;

      await tester.runAsync(() async {
        final storage = SignatureStorageService();
        await storage.clearAllSignatures();
        await storage.saveSignature(SavedSignature(
          id: 'sheet_test_sig',
          title: 'Contract Signature',
          createdAt: DateTime.now(),
          pngBytes: dummyPngBytes,
        ));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SavedSignaturesSheet(
                onSignatureSelected: (sig) {
                  selectedSig = sig;
                },
              ),
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 200));
      });

      await tester.pump();

      expect(find.text('Saved Signatures'), findsOneWidget);
      expect(find.text('Contract Signature'), findsOneWidget);

      await tester.tap(find.text('Contract Signature'));
      await tester.pump();

      expect(selectedSig, isNotNull);
      expect(selectedSig!.title, equals('Contract Signature'));
    });
  });
}
