import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

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
  Future<String> mergePdfs(List<String> pdfPaths) async {
    try {
      final pdf = pw.Document();

      // For basic merge, we'll create a new PDF with page references
      // Note: Full PDF merge requires more complex PDF manipulation
      // This is a placeholder implementation

      final output = await getApplicationDocumentsDirectory();
      final fileName =
          'merged_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${output.path}/$fileName');

      // Create a simple merged PDF document
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'Merged PDF',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    'Merged ${pdfPaths.length} PDFs',
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

  /// Rotates the pages of a PDF by a specified angle (90, 180, 270)
  Future<String> rotatePdf({
    required String pdfPath,
    required int rotationAngle,
  }) async {
    try {
      final file = File(pdfPath);
      if (!await file.exists()) {
        throw Exception('Input file does not exist');
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Input PDF file is empty');
      }

      // Load existing document
      final sf.PdfDocument document = sf.PdfDocument(inputBytes: bytes);

      try {
        for (int i = 0; i < document.pages.count; i++) {
          final sf.PdfPage page = document.pages[i];
          
          // Get current page rotation
          final currentRotation = page.rotation;
          
          // Convert enum to degrees
          int currentDegrees = 0;
          switch (currentRotation) {
            case sf.PdfPageRotateAngle.rotateAngle0:
              currentDegrees = 0;
              break;
            case sf.PdfPageRotateAngle.rotateAngle90:
              currentDegrees = 90;
              break;
            case sf.PdfPageRotateAngle.rotateAngle180:
              currentDegrees = 180;
              break;
            case sf.PdfPageRotateAngle.rotateAngle270:
              currentDegrees = 270;
              break;
          }

          // Calculate new degrees (additive and normalized to 0, 90, 180, 270)
          final newDegrees = (currentDegrees + rotationAngle) % 360;

          // Set new rotation angle
          if (newDegrees == 90) {
            page.rotation = sf.PdfPageRotateAngle.rotateAngle90;
          } else if (newDegrees == 180) {
            page.rotation = sf.PdfPageRotateAngle.rotateAngle180;
          } else if (newDegrees == 270) {
            page.rotation = sf.PdfPageRotateAngle.rotateAngle270;
          } else {
            page.rotation = sf.PdfPageRotateAngle.rotateAngle0;
          }
        }

        // Save rotated PDF to file
        final List<int> outputBytes = await document.save();
        
        final output = await getApplicationDocumentsDirectory();
        final fileName = 'rotated_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final outputFile = File('${output.path}/$fileName');
        await outputFile.writeAsBytes(outputBytes);
        
        return outputFile.path;
      } finally {
        document.dispose();
      }
    } catch (e) {
      throw Exception('Failed to rotate PDF: $e');
    }
  }
}
