import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:pdf_ai_toolkit/widgets/pdf_security_dialogs.dart';
import 'package:pdf_ai_toolkit/views/viewer/pdf_document_viewer_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/tools_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_security_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('io.scer.pdf_renderer'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'open.document.file':
          case 'open.document.data':
            return {
              'id': 'mock-doc-id',
              'pagesCount': 1,
            };
          case 'close.document':
            return null;
          case 'open.page':
            return {
              'id': 'mock-page-id',
              'width': 595.0,
              'height': 842.0,
            };
          case 'close.page':
            return null;
          case 'render':
            return {
              'width': 595,
              'height': 842,
              'bytes': Uint8List.fromList([0, 0, 0, 0]),
            };
          default:
            return null;
        }
      },
    );
  });

  tearDownAll(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  /// Helper to create a valid unencrypted PDF file.
  File createValidPdf(String filename) {
    final doc = sf.PdfDocument();
    final page = doc.pages.add();
    page.graphics.drawString(
      'Hello World',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
      bounds: const Rect.fromLTWH(0, 0, 200, 50),
    );
    final bytes = doc.saveSync();
    doc.dispose();

    final file = File('${tempDir.path}/$filename');
    file.writeAsBytesSync(bytes);
    return file;
  }

  /// Helper to create a password-encrypted PDF file.
  File createEncryptedPdf(String filename, String password) {
    final doc = sf.PdfDocument();
    final page = doc.pages.add();
    page.graphics.drawString(
      'Confidential Encrypted Document',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
      bounds: const Rect.fromLTWH(0, 0, 200, 50),
    );
    final security = doc.security;
    security.userPassword = password;
    security.ownerPassword = 'owner_${password}_master';
    security.encryptionOptions = sf.PdfEncryptionOptions.encryptAllContents;

    final bytes = doc.saveSync();
    doc.dispose();

    final file = File('${tempDir.path}/$filename');
    file.writeAsBytesSync(bytes);
    return file;
  }

  /// Helper to create a header-corrupted file (garbage bytes, missing %PDF-).
  File createHeaderCorruptFile(String filename) {
    final file = File('${tempDir.path}/$filename');
    // Write random binary bytes with no %PDF- signature
    file.writeAsBytesSync([0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0]);
    return file;
  }

  /// Helper to create a format-corrupted file (starts with %PDF- but corrupt stream/xref).
  File createFormatCorruptFile(String filename) {
    final file = File('${tempDir.path}/$filename');
    // Starts with %PDF- header, but followed by completely malformed syntax
    const content = '%PDF-1.5\nMalformed stream objects and broken xref table << >>';
    file.writeAsStringSync(content);
    return file;
  }

  group('PDF Security & Integrity Inspection Tests', () {
    test('1. Valid PDF inspection returns issueType: none', () async {
      final file = createValidPdf('valid_sample.pdf');
      final result = await inspectPdfFile(file.path);

      expect(result.isValid, isTrue);
      expect(result.issueType, equals(PdfIssueType.none));
      expect(result.isEncrypted, isFalse);
      expect(result.fileSizeBytes, greaterThan(0));
    });

    test('2. Empty file is caught as header corruption', () async {
      final file = File('${tempDir.path}/empty.pdf');
      file.writeAsBytesSync([]);

      final result = await inspectPdfFile(file.path);
      expect(result.isValid, isFalse);
      expect(result.issueType, equals(PdfIssueType.headerCorrupted));
      expect(result.hasHeaderCorruption, isTrue);
      expect(result.errorMessage, contains('empty'));
    });

    test('3. Missing %PDF- signature is caught as header corruption', () async {
      final file = createHeaderCorruptFile('corrupt_header.pdf');
      final result = await inspectPdfFile(file.path);

      expect(result.isValid, isFalse);
      expect(result.issueType, equals(PdfIssueType.headerCorrupted));
      expect(result.hasHeaderCorruption, isTrue);
      expect(result.errorMessage, contains('%PDF-'));
    });

    test('4. Corrupted syntax/xref is caught as format exception', () async {
      final file = createFormatCorruptFile('corrupt_format.pdf');
      final result = await inspectPdfFile(file.path);

      expect(result.isValid, isFalse);
      expect(result.issueType, equals(PdfIssueType.formatException));
      expect(result.hasFormatException, isTrue);
    });

    test('5. Password-protected PDF triggers passwordRequired signal', () async {
      final file = createEncryptedPdf('protected.pdf', 'Secret123');
      final result = await inspectPdfFile(file.path);

      expect(result.isValid, isFalse);
      expect(result.issueType, equals(PdfIssueType.passwordRequired));
      expect(result.isPasswordProtected, isTrue);
      expect(result.isEncrypted, isTrue);

      // Verifying with correct password resolves to valid
      final unlockedResult = await inspectPdfFile(file.path, password: 'Secret123');
      expect(unlockedResult.isValid, isTrue);
      expect(unlockedResult.issueType, equals(PdfIssueType.none));
    });
  });

 group('PDF Corruption & Decryption Modals Widget Tests', () {
    testWidgets('Header corruption modal displays warning badge and details',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showPdfCorruptionModal(
                    context: context,
                    issueType: PdfIssueType.headerCorrupted,
                    fileName: 'corrupt_doc.pdf',
                    fileSizeBytes: 1024,
                    technicalDetails: "Missing '%PDF-' header signature.",
                  );
                },
                child: const Text('Show Corruption Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Corruption Modal'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pdf_corruption_modal_dialog')), findsOneWidget);
      expect(find.text('Corrupted PDF Header'), findsOneWidget);
      expect(find.text('HEADER CORRUPTION'), findsOneWidget);
      expect(find.text('corrupt_doc.pdf'), findsOneWidget);
      expect(find.byKey(const Key('pdf_corruption_dismiss_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('pdf_corruption_dismiss_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pdf_corruption_modal_dialog')), findsNothing);
    });

    testWidgets('Format exception modal displays format error badge and explanation',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showPdfCorruptionModal(
                    context: context,
                    issueType: PdfIssueType.formatException,
                    fileName: 'broken_stream.pdf',
                    fileSizeBytes: 2048,
                    technicalDetails: 'FormatException: Malformed xref table dictionary.',
                  );
                },
                child: const Text('Show Format Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Format Modal'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pdf_corruption_modal_dialog')), findsOneWidget);
      expect(find.text('PDF Format Exception'), findsOneWidget);
      expect(find.text('FORMAT EXCEPTION'), findsOneWidget);
      expect(find.text('broken_stream.pdf'), findsOneWidget);
      expect(find.text('FormatException: Malformed xref table dictionary.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pdf_corruption_dismiss_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pdf_corruption_modal_dialog')), findsNothing);
    });

    testWidgets('Password modal prompts for password, validates, and unlocks',
        (tester) async {
      String? unlockedPass;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  unlockedPass = await showPdfPasswordModal(
                    context: context,
                    fileName: 'secret_file.pdf',
                    onValidatePassword: (input) async {
                      return input == 'MyCorrectPassword';
                    },
                  );
                },
                child: const Text('Show Password Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Password Modal'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pdf_password_modal_dialog')), findsOneWidget);
      expect(find.text('Password Protected'), findsOneWidget);
      expect(find.text('secret_file.pdf'), findsOneWidget);
      expect(find.byKey(const Key('pdf_password_input_field')), findsOneWidget);

      // Enter incorrect password first
      await tester.enterText(find.byKey(const Key('pdf_password_input_field')), 'WrongPassword');
      await tester.tap(find.byKey(const Key('pdf_unlock_submit_button')));
      await tester.pumpAndSettle();

      // Modal stays open and displays inline error
      expect(find.byKey(const Key('pdf_password_modal_dialog')), findsOneWidget);
      expect(find.textContaining('Incorrect password'), findsOneWidget);

      // Enter correct password
      await tester.enterText(find.byKey(const Key('pdf_password_input_field')), 'MyCorrectPassword');
      await tester.tap(find.byKey(const Key('pdf_unlock_submit_button')));
      await tester.pumpAndSettle();

      // Modal closes and passes back correct password
      expect(find.byKey(const Key('pdf_password_modal_dialog')), findsNothing);
      expect(unlockedPass, equals('MyCorrectPassword'));
    });
  });

  group('PdfDocumentViewerScreen Integrity Tests', () {
    testWidgets('Catches header corruption and displays corruption modal & error state',
        (tester) async {
      final corruptFile = createHeaderCorruptFile('viewer_corrupt.pdf');

      await tester.pumpWidget(
        MaterialApp(
          home: PdfDocumentViewerScreen(filePath: corruptFile.path),
        ),
      );
      await tester.pump();

      final state = tester.state(find.byType(PdfDocumentViewerScreen)) as dynamic;
      await tester.runAsync(() async {
        await state.initPdf();
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The elegant corruption modal is automatically shown
      expect(find.byKey(const Key('pdf_corruption_modal_dialog')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('pdf_corruption_modal_dialog')),
          matching: find.text('Corrupted PDF Header'),
        ),
        findsOneWidget,
      );

      // Dismiss modal
      await tester.tap(find.byKey(const Key('pdf_corruption_dismiss_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Screen displays graceful header corruption state with details button
      expect(find.byKey(const Key('viewer_explain_issue_button')), findsOneWidget);
      expect(find.text('Corrupted PDF Header'), findsOneWidget);
    });

    testWidgets('Catches password protected PDF and prompts decryption modal',
        (tester) async {
      final protectedFile = createEncryptedPdf('viewer_protected.pdf', 'VaultPass');

      await tester.pumpWidget(
        MaterialApp(
          home: PdfDocumentViewerScreen(filePath: protectedFile.path),
        ),
      );
      await tester.pump();

      final state = tester.state(find.byType(PdfDocumentViewerScreen)) as dynamic;
      await tester.runAsync(() async {
        await state.initPdf();
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The elegant password decryption modal is automatically presented
      expect(find.byKey(const Key('pdf_password_modal_dialog')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('pdf_password_modal_dialog')),
          matching: find.text('Password Protected'),
        ),
        findsOneWidget,
      );

      // User cancels password dialog
      await tester.tap(find.byKey(const Key('pdf_password_cancel_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Screen stays on locked state with "Enter Password" action button
      expect(find.byKey(const Key('viewer_enter_password_button')), findsOneWidget);
      expect(find.text('Password Protected PDF'), findsOneWidget);
    });
  });

  group('ToolsScreen Integration Tests', () {
    testWidgets('ToolsScreen displays PDF Viewer in tool grid and open button in AppBar',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the AppBar action button is present
      expect(find.byKey(const Key('tools_open_pdf_action_button')), findsOneWidget);

      // Verify PDF Viewer tool item is present in appTools
      expect(appTools.any((t) => t.title == 'PDF Viewer'), isTrue);

      // Filter by 'Organize' category to bring PDF Viewer into view
      await tester.tap(find.widgetWithText(FilterChip, 'Organize'));
      await tester.pumpAndSettle();

      // Scroll grid to reveal the PDF Viewer card in the Organize category
      await tester.drag(find.byType(GridView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('PDF Viewer'), findsOneWidget);
    });

    testWidgets('PdfViewerLauncherScreen renders select button and triggers picker',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PdfViewerLauncherScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open & Inspect PDF'), findsOneWidget);
      expect(find.byKey(const Key('tools_launcher_pick_pdf_button')), findsOneWidget);
    });
  });
}
