import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/views/tools/merge_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/split_pdf_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('merge_split_screen_test_');

    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HistoryEntryAdapter());
    }

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MergePdfScreen & SplitPdfScreen Widget Tests', () {
    testWidgets('MergePdfScreen renders correctly with initial state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MergePdfScreen(),
        ),
      );

      expect(find.text('Merge PDF'), findsOneWidget);
      expect(
          find.text(
              'Combine multiple PDF documents into a single organized PDF file.'),
          findsOneWidget);
      expect(find.byType(MergePdfScreen), findsOneWidget);
    });

    testWidgets('SplitPdfScreen renders correctly with initial state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplitPdfScreen(),
        ),
      );

      expect(find.text('Split PDF'), findsOneWidget);
      expect(
          find.text(
              'Extract a specific page range from your PDF document into a new PDF.'),
          findsOneWidget);
      expect(find.byType(SplitPdfScreen), findsOneWidget);
    });
  });
}
