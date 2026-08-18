import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/main.dart';

void main() {
  testWidgets('App loads and displays HomeScreen', (WidgetTester tester) async {
    // Build the app and verify it loads.
    await tester.pumpWidget(const PdfAiToolkitApp());
    await tester.pumpAndSettle();

    // Verify that the HomeScreen is rendered by looking for its specific text.
    expect(find.text('What would you like\nto do today?'), findsOneWidget);
    expect(find.text('PDF AI Toolkit'), findsWidgets);
    
    // Verify that tool cards are rendered
    expect(find.text('All Tools'), findsOneWidget);
    expect(find.text('Start Scan'), findsOneWidget);
  });
}
