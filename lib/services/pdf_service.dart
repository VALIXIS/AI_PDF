import 'dart:io';
import 'dart:ui';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:pdf_ai_toolkit/models/pdf_annotation.dart';

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
      final file = File(path.join(output.path, fileName));
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

  /// Gets the total page count of a PDF file
  Future<int> getPdfPageCount(String pdfPath) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      throw Exception('File not found: $pdfPath');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('File is empty: $pdfPath');
    }
    syncfusion.PdfDocument? document;
    try {
      document = syncfusion.PdfDocument(inputBytes: bytes);
      return document.pages.count;
    } catch (e) {
      throw Exception('Failed to read PDF page count: $e');
    } finally {
      document?.dispose();
    }
  }

  /// Merges multiple PDF files
  Future<String> mergePdfs(List<String> pdfPaths, {String? customOutputPath}) async {
    if (pdfPaths.isEmpty) {
      throw Exception('No PDF files selected to merge.');
    }

    syncfusion.PdfDocument? outputDocument;
    final List<syncfusion.PdfDocument> openedDocuments = [];
    try {
      outputDocument = syncfusion.PdfDocument();

      for (final filePath in pdfPaths) {
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception('File not found: $filePath');
        }
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          throw Exception('File is empty: $filePath');
        }

        final syncfusion.PdfDocument sourceDocument =
            syncfusion.PdfDocument(inputBytes: bytes);
        openedDocuments.add(sourceDocument);

        final int pageCount = sourceDocument.pages.count;
        if (pageCount == 0) {
          throw Exception('Source PDF contains no pages: $filePath');
        }

        for (int i = 0; i < pageCount; i++) {
          final syncfusion.PdfPage sourcePage = sourceDocument.pages[i];
          final syncfusion.PdfTemplate template = sourcePage.createTemplate();

          final syncfusion.PdfSection section = outputDocument.sections!.add();
          section.pageSettings.size = sourcePage.size;
          section.pageSettings.margins.all = 0;
          section.pageSettings.rotate = sourcePage.rotation;

          final syncfusion.PdfPage newPage = section.pages.add();
          newPage.graphics.drawPdfTemplate(
            template,
            Offset.zero,
            sourcePage.size,
          );
        }
      }

      final List<int> mergedBytes = outputDocument.saveSync();

      final String dirPath = customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final fileName =
          'merged_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path.join(dirPath, fileName));
      await file.writeAsBytes(mergedBytes);

      return file.path;
    } catch (e) {
      throw Exception('Failed to merge PDFs: $e');
    } finally {
      for (final doc in openedDocuments) {
        doc.dispose();
      }
      outputDocument?.dispose();
    }
  }

  /// Splits a PDF by extracting pages in the specified range [startPage] to [endPage] (1-indexed inclusive)
  Future<String> splitPdf({
    required String pdfPath,
    required int startPage,
    required int endPage,
    String? customOutputPath,
  }) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      throw Exception('File not found: $pdfPath');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('File is empty: $pdfPath');
    }

    syncfusion.PdfDocument? sourceDocument;
    syncfusion.PdfDocument? outputDocument;
    try {
      sourceDocument = syncfusion.PdfDocument(inputBytes: bytes);
      final int totalPages = sourceDocument.pages.count;

      if (totalPages == 0) {
        throw Exception('Source PDF contains no pages.');
      }
      if (startPage < 1) {
        throw Exception('Start page must be at least 1 (got $startPage).');
      }
      if (endPage > totalPages) {
        throw Exception('End page ($endPage) exceeds total pages in document ($totalPages).');
      }
      if (startPage > endPage) {
        throw Exception('Start page ($startPage) cannot be greater than end page ($endPage).');
      }

      outputDocument = syncfusion.PdfDocument();

      for (int pageNum = startPage; pageNum <= endPage; pageNum++) {
        final int pageIndex = pageNum - 1;
        final syncfusion.PdfPage sourcePage = sourceDocument.pages[pageIndex];
        final syncfusion.PdfTemplate template = sourcePage.createTemplate();

        final syncfusion.PdfSection section = outputDocument.sections!.add();
        section.pageSettings.size = sourcePage.size;
        section.pageSettings.margins.all = 0;
        section.pageSettings.rotate = sourcePage.rotation;

        final syncfusion.PdfPage newPage = section.pages.add();
        newPage.graphics.drawPdfTemplate(
          template,
          Offset.zero,
          sourcePage.size,
        );
      }

      final List<int> outputBytes = outputDocument.saveSync();

      final String dirPath = customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final fileName =
          'split_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outputFile = File(path.join(dirPath, fileName));
      await outputFile.writeAsBytes(outputBytes);

      return outputFile.path;
    } catch (e) {
      throw Exception('Failed to split PDF: $e');
    } finally {
      sourceDocument?.dispose();
      outputDocument?.dispose();
    }
  }

  /// Compresses a PDF (placeholder)
  Future<String> compressPdf(String pdfPath) async {
    try {
      // Placeholder implementation
      final output = await getApplicationDocumentsDirectory();
      final fileName =
          'compressed_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path.join(output.path, fileName));

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
    String? customOutputPath,
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
        
        final String dirPath = customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
        final fileName = 'rotated_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final outputFile = File(path.join(dirPath, fileName));
        await outputFile.writeAsBytes(outputBytes);
        
        return outputFile.path;
      } finally {
        document.dispose();
      }
    } catch (e) {
      throw Exception('Failed to rotate PDF: $e');
    }
  }

  /// Applies a visible text watermark to all pages of a PDF
  Future<String> watermarkPdf({
    required String pdfPath,
    required String watermarkText,
    required double opacity,
    required double angle, // in radians
    required Color color,
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

      if (watermarkText.isEmpty) {
        throw Exception('Watermark text cannot be empty');
      }

      // Load existing document
      final sf.PdfDocument document = sf.PdfDocument(inputBytes: bytes);

      try {
        final double angleInDegrees = angle * 180 / 3.141592653589793;
        final sf.PdfFont font = sf.PdfStandardFont(
          sf.PdfFontFamily.helvetica,
          50,
          style: sf.PdfFontStyle.bold,
        );

        final sf.PdfBrush brush = sf.PdfSolidBrush(
          sf.PdfColor(
            (color.r * 255).round(),
            (color.g * 255).round(),
            (color.b * 255).round(),
          ),
        );

        for (int i = 0; i < document.pages.count; i++) {
          final sf.PdfPage page = document.pages[i];
          final sf.PdfGraphics graphics = page.graphics;

          // Save current graphics state
          final sf.PdfGraphicsState state = graphics.save();

          // Set transparency/opacity
          graphics.setTransparency(opacity);

          // Translate origin to the center of the page
          graphics.translateTransform(page.size.width / 2, page.size.height / 2);

          // Apply rotation in degrees
          graphics.rotateTransform(angleInDegrees);

          // Measure text size to center it
          final Size textSize = font.measureString(watermarkText);

          // Draw the text centered around the new origin (0, 0)
          graphics.drawString(
            watermarkText,
            font,
            brush: brush,
            bounds: Rect.fromLTWH(
              -textSize.width / 2,
              -textSize.height / 2,
              textSize.width,
              textSize.height,
            ),
          );

          // Restore graphics state
          graphics.restore(state);
        }

        // Save watermarked PDF
        final List<int> outputBytes = await document.save();

        final output = await getApplicationDocumentsDirectory();
        final fileName = 'watermarked_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final outputFile = File(path.join(output.path, fileName));
        await outputFile.writeAsBytes(outputBytes);

        return outputFile.path;
      } finally {
        document.dispose();
      }
    } catch (e) {
      throw Exception('Failed to apply watermark: $e');
    }
  }

  /// Non-destructively saves an edited PDF by overlaying text and image annotations
  /// directly onto the original PDF's vector/graphics layer using Syncfusion.
  /// Original extractable text, vector graphics, embedded images, page sizes, and rotations
  /// are preserved without rasterizing unchanged pages into images.
  Future<String> saveEditedPdf({
    required String sourcePdfPath,
    required Map<int, List<Annotation>> annotationsByPage,
    String? customOutputPath,
  }) async {
    final file = File(sourcePdfPath);
    if (!await file.exists()) {
      throw Exception('Source PDF file not found: $sourcePdfPath');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Source PDF file is empty: $sourcePdfPath');
    }

    sf.PdfDocument? document;
    try {
      document = sf.PdfDocument(inputBytes: bytes);
      final int pageCount = document.pages.count;
      if (pageCount == 0) {
        throw Exception('Source PDF contains no pages: $sourcePdfPath');
      }

      for (final entry in annotationsByPage.entries) {
        final int pageIndex = entry.key;
        final List<Annotation> annotations = entry.value;

        if (pageIndex < 0 || pageIndex >= pageCount || annotations.isEmpty) {
          continue;
        }

        final sf.PdfPage page = document.pages[pageIndex];
        final sf.PdfGraphics graphics = page.graphics;
        final double pageWidth = page.size.width;
        final double pageHeight = page.size.height;

        for (final ann in annotations) {
          final double x = ann.x * pageWidth;
          final double y = ann.y * pageHeight;
          final double w = ann.width * pageWidth;
          final double h = ann.height * pageHeight;

          if (ann.kind == AnnotationKind.text) {
            if (ann.text.isEmpty) continue;
            final sf.PdfFont font = sf.PdfStandardFont(
              sf.PdfFontFamily.helvetica,
              ann.fontSize,
              style: ann.bold ? sf.PdfFontStyle.bold : sf.PdfFontStyle.regular,
            );
            final sf.PdfBrush brush = sf.PdfSolidBrush(
              sf.PdfColor(
                (ann.color.r * 255.0).round().clamp(0, 255),
                (ann.color.g * 255.0).round().clamp(0, 255),
                (ann.color.b * 255.0).round().clamp(0, 255),
              ),
            );
            final double availableWidth = (pageWidth - x).clamp(0.0, pageWidth);
            final double availableHeight = (pageHeight - y).clamp(0.0, pageHeight);
            graphics.drawString(
              ann.text,
              font,
              brush: brush,
              bounds: Rect.fromLTWH(x, y, availableWidth, availableHeight),
            );
          } else if (ann.kind == AnnotationKind.image && ann.imageBytes != null && ann.imageBytes!.isNotEmpty) {
            final sf.PdfBitmap bitmap = sf.PdfBitmap(ann.imageBytes!);
            graphics.drawImage(
              bitmap,
              Rect.fromLTWH(x, y, w, h),
            );
          }
        }
      }

      final List<int> outputBytes = await document.save();
      final String dirPath = customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final fileName = 'edited_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outputFile = File(path.join(dirPath, fileName));
      await outputFile.writeAsBytes(outputBytes);

      return outputFile.path;
    } catch (e) {
      throw Exception('Failed to save edited PDF: $e');
    } finally {
      document?.dispose();
    }
  }
}
