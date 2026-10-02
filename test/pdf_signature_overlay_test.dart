import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_signature_overlay_screen.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_sig_test_hive_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HistoryEntryAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PdfSignatureOverlayScreen UI Tests', () {
    testWidgets('renders empty picker state initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PdfSignatureOverlayScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign & Stamp PDF'), findsOneWidget);
      expect(find.text('No PDF Document Selected'), findsOneWidget);
      expect(find.text('Select PDF Document'), findsOneWidget);
    });
  });
}
