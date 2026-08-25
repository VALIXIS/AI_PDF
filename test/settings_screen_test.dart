import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/views/settings/settings_screen.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('settings_test_hive_');
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

  testWidgets('SettingsScreen loads and displays all sections cleanly',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('AI ASSISTANT'), findsOneWidget);
    expect(find.text('AI Provider Engine'), findsOneWidget);
    expect(find.text('DATA & STORAGE'), findsOneWidget);
    expect(find.text('History Records'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('PDF AI Toolkit'), findsOneWidget);
    expect(find.text('Privacy & Security'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
  });
}
