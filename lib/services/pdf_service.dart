import 'dart:io';
import 'dart:ui';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:path_provider/path_provider.dart';

class PdfService {
  /// Generates a PDF from formatted text
  Future<String> generatePdfFromText({
    required String title,
    required String content,
  }) async {
    try {
      final pdf = pw.Document();

      // Split content into sections (split by newlines and bullets)
      final lines = content.split('\n');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                  // Title
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),

                  // Metadata
                  pw.Text(
                    'Generated: ${DateTime.now().toString().split('.')[0]}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey,
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Content
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: _buildContentWidgets(lines),
                  ),
                ],
            );
          },
        ),
      );

      // Save PDF to file
      final output = await getApplicationDocumentsDirectory();
      final fileName =
          'pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      return file.path;
    } catch (e) {
      throw Exception('Failed to generate PDF: $e');
    }
  }

  /// Builds content widgets from lines
  List<pw.Widget> _buildContentWidgets(List<String> lines) {
    List<pw.Widget> widgets = [];

    for (String line in lines) {
      if (line.isEmpty) {
        widgets.add(pw.SizedBox(height: 8));
      } else if (line.startsWith('# ')) {
        // Header 1
        widgets.add(
          pw.Text(
            line.substring(2),
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 6));
      } else if (line.startsWith('## ')) {
        // Header 2
        widgets.add(
          pw.Text(
            line.substring(3),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 4));
      } else if (line.startsWith('• ') || line.startsWith('- ')) {
        // Bullet point
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
            child: pw.Text(
              line.substring(2),
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        );
      } else {
        // Regular text
        widgets.add(
          pw.Text(
            line,
            style: const pw.TextStyle(fontSize: 11),
          ),
        );
        widgets.add(pw.SizedBox(height: 4));
      }
    }

    return widgets;
  }

  /// Merges multiple PDF files
  Future<String> mergePdfs(List<String> pdfPaths, {String? customOutputPath}) async {
    if (pdfPaths.isEmpty) {
      throw Exception('No PDF files selected to merge.');
    }

    syncfusion.PdfDocument? outputDocument;
    try {
      outputDocument = syncfusion.PdfDocument();

      for (final path in pdfPaths) {
        final file = File(path);
        if (!await file.exists()) {
          throw Exception('File not found: $path');
        }
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          throw Exception('File is empty: $path');
        }

        final syncfusion.PdfDocument sourceDocument =
            syncfusion.PdfDocument(inputBytes: bytes);

        for (int i = 0; i < sourceDocument.pages.count; i++) {
          final syncfusion.PdfPage sourcePage = sourceDocument.pages[i];
          final syncfusion.PdfTemplate template = sourcePage.createTemplate();

          final syncfusion.PdfSection section = outputDocument.sections!.add();
          section.pageSettings.size = sourcePage.size;
          section.pageSettings.margins.all = 0;

          final syncfusion.PdfPage newPage = section.pages.add();
          newPage.graphics.drawPdfTemplate(
            template,
            Offset.zero,
            sourcePage.size,
          );
        }

        sourceDocument.dispose();
      }

      final List<int> mergedBytes = outputDocument.saveSync();
      outputDocument.dispose();
      outputDocument = null;

      final String dirPath = customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final fileName =
          'merged_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('$dirPath/$fileName');
      await file.writeAsBytes(mergedBytes);

      return file.path;
    } catch (e) {
      outputDocument?.dispose();
      throw Exception('Failed to merge PDFs: $e');
    }
  }

  /// Splits a PDF by extracting pages
  Future<String> splitPdf({
    required String pdfPath,
    required int startPage,
    required int endPage,
  }) async {
    try {
      // This is a placeholder implementation
      // Full PDF splitting requires pdf manipulation library

      final output = await getApplicationDocumentsDirectory();
      final fileName =
          'split_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${output.path}/$fileName');

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'Split PDF',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    'Pages $startPage - $endPage',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ],
              ),
            );
          },
        ),
      );

      await file.writeAsBytes(await pdf.save());
      return file.path;
    } catch (e) {
      throw Exception('Failed to split PDF: $e');
    }
  }

  /// Compresses a PDF (placeholder)
  Future<String> compressPdf(String pdfPath) async {
    try {
      // Placeholder implementation
      final output = await getApplicationDocumentsDirectory();
      final fileName =
          'compressed_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${output.path}/$fileName');

      // For now, copy the file
      await File(pdfPath).copy(file.path);
      return file.path;
    } catch (e) {
      throw Exception('Failed to compress PDF: $e');
    }
  }
}
