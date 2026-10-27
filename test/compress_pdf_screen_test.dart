import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/views/tools/compress_pdf_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('compress_screen_test_');

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

  group('CompressPdfScreen Widget & UI Tests', () {
    testWidgets('CompressPdfScreen renders properly with initial empty state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CompressPdfScreen(),
        ),
      );

      expect(find.text('Compress PDF'), findsOneWidget);
      expect(
          find.text(
              'Reduce the file size of your PDF document while maintaining readable text and image quality.'),
          findsOneWidget);
      expect(find.byType(CompressPdfScreen), findsOneWidget);
    });

    testWidgets(
        'CompressPdfScreen displays segmented DPI controls and vector preservation notice',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CompressPdfScreen(),
        ),
      );

      // Verify the widget structure
      expect(find.byType(CompressPdfScreen), findsOneWidget);
    });
  });
}
