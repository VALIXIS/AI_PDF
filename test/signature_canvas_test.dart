import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show PictureRecorder, Canvas;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/models/pdf_annotation.dart';
import 'package:pdf_ai_toolkit/models/saved_signature.dart';
import 'package:pdf_ai_toolkit/services/signature_storage_service.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_signature_overlay_screen.dart';
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

  group('Cubic Bezier Smoothing on Touch Points Tests', () {
    test('computeCubicBezierPath returns empty path for empty list', () {
      final path = SignaturePainter.computeCubicBezierPath([]);
      expect(path.getBounds().isEmpty, isTrue);
    });

    test('computeCubicBezierPath handles single touch point', () {
      final path =
          SignaturePainter.computeCubicBezierPath([const Offset(50, 50)]);
      final bounds = path.getBounds();
      expect(bounds.left, equals(50));
      expect(bounds.top, equals(50));
    });

    test('computeCubicBezierPath connects two touch points with cubic curve', () {
      final path = SignaturePainter.computeCubicBezierPath([
        const Offset(10, 10),
        const Offset(100, 100),
      ]);
      final bounds = path.getBounds();
      expect(bounds.left, closeTo(10, 1));
      expect(bounds.top, closeTo(10, 1));
      expect(bounds.right, closeTo(100, 1));
      expect(bounds.bottom, closeTo(100, 1));
    });

    test('computeCubicBezierPath generates smooth cubic Bezier path through multiple touch points',
        () {
      final points = [
        const Offset(0, 50),
        const Offset(50, 0),
        const Offset(100, 50),
        const Offset(150, 100),
        const Offset(200, 50),
      ];
      final path = SignaturePainter.computeCubicBezierPath(points);
      final bounds = path.getBounds();
      expect(bounds.left, closeTo(0, 5));
      expect(bounds.right, closeTo(200, 5));
      expect(bounds.width, greaterThan(180));
      expect(bounds.height, greaterThan(40));
    });

    test('SignaturePainter paints single dot and multi-point cubic strokes without throwing',
        () {
      final strokes = [
        SignatureStroke(
          points: [const Offset(20, 20)],
          color: Colors.black,
          strokeWidth: 3.0,
        ),
        SignatureStroke(
          points: [
            const Offset(10, 10),
            const Offset(30, 40),
            const Offset(60, 20),
            const Offset(90, 80),
          ],
          color: Colors.blue,
          strokeWidth: 4.0,
        ),
      ];
      final painter = SignaturePainter(strokes: strokes);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => painter.paint(canvas, const Size(200, 200)), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('SignatureCubicSmoother in pdf_signature_overlay_screen creates valid cubic paths',
        () {
      final points = [
        const Offset(10, 20),
        const Offset(40, 60),
        const Offset(80, 30),
      ];
      final path = SignatureCubicSmoother.computeCubicBezierPath(points);
      final bounds = path.getBounds();
      expect(bounds.left, closeTo(10, 5));
      expect(bounds.right, closeTo(80, 5));
    });
  });

  group('PDF Page Signature Overlay Gesture Handles Tests', () {
    testWidgets('InteractiveOverlayItem renders reposition and scale gesture handles when selected',
        (tester) async {
      final overlay = PdfOverlayPlacement(
        id: 'overlay_test_1',
        pageIndex: 0,
        x: 0.25,
        y: 0.35,
        width: 0.4,
        height: 0.2,
        imageBytes: dummyPngBytes,
        label: 'Signature',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 800,
              child: Stack(
                children: [
                  InteractiveOverlayItem(
                    overlay: overlay,
                    canvasW: 600,
                    canvasH: 800,
                    isSelected: true,
                    primary: Colors.blue,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reposition_handle')), findsOneWidget);
      expect(find.byKey(const Key('scale_handle')), findsOneWidget);
      expect(find.byKey(const Key('scale_handle_width')), findsOneWidget);
      expect(find.byKey(const Key('scale_handle_height')), findsOneWidget);
      expect(find.byIcon(Icons.open_with_rounded), findsOneWidget);
      expect(find.byIcon(Icons.aspect_ratio_rounded), findsOneWidget);
    });

    testWidgets('InteractiveOverlayItem hides gesture handles when unselected',
        (tester) async {
      final overlay = PdfOverlayPlacement(
        id: 'overlay_test_2',
        pageIndex: 0,
        x: 0.25,
        y: 0.35,
        width: 0.4,
        height: 0.2,
        imageBytes: dummyPngBytes,
        label: 'Signature',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 800,
              child: Stack(
                children: [
                  InteractiveOverlayItem(
                    overlay: overlay,
                    canvasW: 600,
                    canvasH: 800,
                    isSelected: false,
                    primary: Colors.blue,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reposition_handle')), findsNothing);
      expect(find.byKey(const Key('scale_handle')), findsNothing);
    });

    testWidgets('Dragging reposition gesture handle translates signature x and y coordinates',
        (tester) async {
      double? deltaX;
      double? deltaY;

      final overlay = PdfOverlayPlacement(
        id: 'overlay_test_3',
        pageIndex: 0,
        x: 0.2,
        y: 0.3,
        width: 0.4,
        height: 0.2,
        imageBytes: dummyPngBytes,
        label: 'Signature',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 1000,
              child: Stack(
                children: [
                  InteractiveOverlayItem(
                    overlay: overlay,
                    canvasW: 800,
                    canvasH: 1000,
                    isSelected: true,
                    primary: Colors.blue,
                    onTap: () {},
                    onRepositionDelta: (dx, dy) {
                      deltaX = dx;
                      deltaY = dy;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialX = overlay.x;
      final initialY = overlay.y;

      final handle = find.byKey(const Key('reposition_handle'));
      expect(handle, findsOneWidget);

      await tester.drag(handle, const Offset(80, 100));
      await tester.pumpAndSettle();

      expect(overlay.x, greaterThan(initialX));
      expect(overlay.y, greaterThan(initialY));
      expect(deltaX, isNotNull);
      expect(deltaY, isNotNull);
    });

    testWidgets('Dragging scale gesture handle resizes signature width and height',
        (tester) async {
      double? scaledW;
      double? scaledH;

      final overlay = PdfOverlayPlacement(
        id: 'overlay_test_4',
        pageIndex: 0,
        x: 0.1,
        y: 0.1,
        width: 0.3,
        height: 0.15,
        imageBytes: dummyPngBytes,
        label: 'Signature',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 1000,
              child: Stack(
                children: [
                  InteractiveOverlayItem(
                    overlay: overlay,
                    canvasW: 800,
                    canvasH: 1000,
                    isSelected: true,
                    primary: Colors.blue,
                    onTap: () {},
                    onScaleDelta: (dw, dh) {
                      scaledW = dw;
                      scaledH = dh;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialW = overlay.width;
      final initialH = overlay.height;

      final handle = find.byKey(const Key('scale_handle'));
      expect(handle, findsOneWidget);

      await tester.drag(handle, const Offset(80, 50));
      await tester.pumpAndSettle();

      expect(overlay.width, greaterThan(initialW));
      expect(overlay.height, greaterThan(initialH));
      expect(scaledW, isNotNull);
      expect(scaledH, isNotNull);
    });

    testWidgets('Dragging edge scale handles resizes single axis', (tester) async {
      final overlay = PdfOverlayPlacement(
        id: 'overlay_test_5',
        pageIndex: 0,
        x: 0.1,
        y: 0.1,
        width: 0.3,
        height: 0.15,
        imageBytes: dummyPngBytes,
        label: 'Signature',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 1000,
              child: Stack(
                children: [
                  InteractiveOverlayItem(
                    overlay: overlay,
                    canvasW: 800,
                    canvasH: 1000,
                    isSelected: true,
                    primary: Colors.blue,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialW = overlay.width;
      final initialH = overlay.height;

      // Drag width handle horizontally
      await tester.drag(
          find.byKey(const Key('scale_handle_width')), const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(overlay.width, greaterThan(initialW));
      expect(overlay.height, equals(initialH));

      // Drag height handle vertically
      await tester.drag(
          find.byKey(const Key('scale_handle_height')), const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(overlay.height, greaterThan(initialH));
    });

    testWidgets('Repositioning and scaling respect page bounds and clamping',
        (tester) async {
      final overlay = PdfOverlayPlacement(
        id: 'overlay_test_6',
        pageIndex: 0,
        x: 0.8,
        y: 0.8,
        width: 0.3,
        height: 0.2,
        imageBytes: dummyPngBytes,
        label: 'Signature',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 500,
              child: Stack(
                children: [
                  InteractiveOverlayItem(
                    overlay: overlay,
                    canvasW: 500,
                    canvasH: 500,
                    isSelected: true,
                    primary: Colors.blue,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final handle = find.byKey(const Key('reposition_handle'));

      // Drag far beyond bottom-right
      await tester.drag(handle, const Offset(2000, 2000));
      await tester.pumpAndSettle();
      expect(overlay.x, lessThanOrEqualTo(1.0));
      expect(overlay.y, lessThanOrEqualTo(1.0));

      // Drag far beyond top-left
      await tester.drag(handle, const Offset(-3000, -3000));
      await tester.pumpAndSettle();
      expect(overlay.x, greaterThanOrEqualTo(0.0));
      expect(overlay.y, greaterThanOrEqualTo(0.0));
    });
  });
}
