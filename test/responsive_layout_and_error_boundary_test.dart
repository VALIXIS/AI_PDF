import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/widgets/global_error_boundary.dart';
import 'package:pdf_ai_toolkit/widgets/tool_card.dart';

void main() {
  group('GlobalErrorBoundary & Crash Recovery Tests (APP-HRD-02)', () {
    testWidgets('Renders child normally when no error occurs',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalErrorBoundary(
            child: Scaffold(
              body: Text('Operational Content'),
            ),
          ),
        ),
      );

      expect(find.text('Operational Content'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('Displays interactive recovery UI when error reported',
        (WidgetTester tester) async {
      final boundaryKey = GlobalKey<GlobalErrorBoundaryState>();

      await tester.pumpWidget(
        MaterialApp(
          home: GlobalErrorBoundary(
            key: boundaryKey,
            child: const Scaffold(body: Text('Healthy')),
          ),
        ),
      );

      expect(find.text('Healthy'), findsOneWidget);

      boundaryKey.currentState?.reportError(
        FlutterErrorDetails(
          exception: Exception('Simulated test exception'),
          stack: StackTrace.current,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Copy Error'), findsOneWidget);
      expect(find.text('Restart Session'), findsOneWidget);
    });
  });

  group('ToolCard Responsive & Contrast Sweep (PDF-VIEW-06 & PDF-VIEW-07)', () {
    testWidgets('Renders cleanly on compact mobile width (320px) without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(useMaterial3: true),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: ToolCard(
                  icon: Icons.picture_as_pdf,
                  title: 'Merge PDF Documents',
                  subtitle: 'Combine multiple PDF files into a single unified output.',
                  highlighted: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Merge PDF Documents'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders high contrast Material 3 dark mode styling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: ToolCard(
              icon: Icons.edit_note,
              title: 'AI PDF Refine',
              subtitle: 'Enhance formatting with AI precision.',
              highlighted: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('AI PDF Refine'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
