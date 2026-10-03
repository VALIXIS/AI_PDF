import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';

void main() {
  test('generatePdfFromMarkdownContent handles huge multi-page summary cleanly without height exception', () async {
    final pdfService = PdfService();

    final buffer = StringBuffer();
    buffer.writeln('# Executive Summary');
    buffer.writeln('QUANT LIFE SKILLS - Complete Solutions | VVIT Training & Placement\n');
    buffer.writeln('## Complete Step-by-Step Solutions');

    for (int i = 1; i <= 150; i++) {
      buffer.writeln('### Section $i: Quantitative Analysis & Problem Solving');
      buffer.writeln('This is a detailed analysis for question $i in the dataset. '
          'We compute the arithmetic and geometric progressions, calculate the sum of terms, '
          'and determine the optimal solution pathways with maximum precision. ' * 3);
      buffer.writeln('- Step 1: Initialize formula S_n = n/2 * (2a + (n-1)d)');
      buffer.writeln('- Step 2: Substitute values: a = 5, d = 3, n = 29');
      buffer.writeln('- Step 3: Compute final sum: S_29 = 29/2 * (10 + 84) = 1363');
      buffer.writeln('- Step 4: Verify boundary conditions and validate against test cases.');
      buffer.writeln();
    }

    final tempDir = await Directory.systemTemp.createTemp('md_test_');
    final outputPath = await pdfService.generatePdfFromMarkdownContent(
      title: 'Executive Brief - QUANT_SOLUTIONS',
      markdownContent: buffer.toString(),
      customOutputPath: tempDir.path,
    );

    final file = File(outputPath);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(1000));

    await tempDir.delete(recursive: true);
  });
}
