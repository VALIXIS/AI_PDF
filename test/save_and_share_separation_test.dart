import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';
import 'package:pdf_ai_toolkit/widgets/tool_screen_shell.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_to_image_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_to_text_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('save_share_test_hive_');
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

  group('UI Action Flow Separation: ToolSuccessCard and ToolScreenShell', () {
    testWidgets('ToolSuccessCard displays separate Save and Share action buttons',
        (WidgetTester tester) async {
      bool saveInvoked = false;
      bool shareInvoked = false;
      bool resetInvoked = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ToolSuccessCard(
            title: 'File Created Successfully!',
            subtitle: 'Ready for export',
            filePath: '${tempDir.path}/document.pdf',
            onSave: () => saveInvoked = true,
            onShare: () => shareInvoked = true,
            onReset: () => resetInvoked = true,
          ),
        ),
      ));

      expect(find.text('File Created Successfully!'), findsOneWidget);
      expect(find.text('document.pdf'), findsOneWidget);

      // Verify separate Save button exists and functions
      final saveBtn = find.text('Save');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      expect(saveInvoked, isTrue);
      expect(shareInvoked, isFalse);

      // Verify separate Share button exists and functions
      final shareBtn = find.text('Share');
      expect(shareBtn, findsOneWidget);
      await tester.tap(shareBtn);
      expect(shareInvoked, isTrue);

      // Verify New Task button exists and functions
      final resetBtn = find.text('New Task');
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      expect(resetInvoked, isTrue);
    });

    testWidgets('ToolScreenShell properly wires onSave and onShare actions',
        (WidgetTester tester) async {
      bool saveTriggered = false;
      bool shareTriggered = false;

      await tester.pumpWidget(MaterialApp(
        home: ToolScreenShell(
          title: 'Merge PDF',
          explanation: 'Combine files',
          onPickFiles: () {},
          selectedFiles: const [],
          onRemoveFile: (_) {},
          onExecute: () {},
          executeButtonLabel: 'Merge',
          isLoading: false,
          loadingMessage: '',
          errorMessage: null,
          onDismissError: () {},
          successPath: '${tempDir.path}/merged.pdf',
          successSubtitle: 'Merged output',
          onReset: () {},
          onSave: () => saveTriggered = true,
          onShare: () => shareTriggered = true,
        ),
      ));

      expect(find.text('Success!'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);

      await tester.tap(find.text('Save'));
      expect(saveTriggered, isTrue);
      expect(shareTriggered, isFalse);

      await tester.tap(find.text('Share'));
      expect(shareTriggered, isTrue);
    });
  });

  group('Tool Screens Verification', () {
    testWidgets('PdfToTextScreen renders with action elements',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: PdfToTextScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ToolEmptyState), findsOneWidget);
      expect(find.text('No PDF Selected'), findsOneWidget);
    });

    testWidgets('PdfToImageScreen renders with action elements',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: PdfToImageScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ToolEmptyState), findsOneWidget);
      expect(find.text('No PDF Selected'), findsOneWidget);
    });
  });

  group('File and Path Safety for Save & Share Separation', () {
    test('FileService correctly checks accessibility of existing vs non-existing files',
        () async {
      final fileService = FileService();
      final nonExisting = '${tempDir.path}/nonexistent.pdf';
      expect(await fileService.isFileAccessible(nonExisting), isFalse);

      final existingFile = File('${tempDir.path}/existing.pdf');
      await existingFile.writeAsString('Dummy PDF content');
      expect(await fileService.isFileAccessible(existingFile.path), isTrue);
    });

    test('FileService correctly formats and sanitizes file names for saving', () {
      final fileService = FileService();
      expect(fileService.sanitizeFileName('my/invalid:file*name?.pdf'), 'my_invalid_file_name_.pdf');
      expect(fileService.getExtension('test.PDF').toLowerCase(), '.pdf');
      expect(fileService.getExtension('image.png'), '.png');
    });
  });
}
