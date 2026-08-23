import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:pdf_ai_toolkit/models/pdf_annotation.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/core/errors/app_exceptions.dart';

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
      final targetPath = path.join(output.path, fileName);
      final pdfBytes = await pdf.save();

      return await FileService().safeWriteBytes(targetPath, pdfBytes);
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

  /// Safely validates a PDF file and loads a Syncfusion PdfDocument.
  /// Throws descriptive [PdfServiceException] for any file or PDF structural errors.
  Future<syncfusion.PdfDocument> _openPdfDocument(String pdfPath) async {
    if (pdfPath.trim().isEmpty) {
      throw PdfServiceException('PDF file path cannot be empty.');
    }
    final file = File(pdfPath);
    if (!await file.exists()) {
      throw PdfServiceException('File not found: $pdfPath');
    }
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      throw PdfServiceException('Failed to read PDF file bytes: $pdfPath', details: e);
    }
    if (bytes.isEmpty) {
      throw PdfServiceException('File is empty: $pdfPath');
    }

    // Check PDF header signature (%PDF-)
    final int headerLength = bytes.length < 1024 ? bytes.length : 1024;
    final String headerText = String.fromCharCodes(bytes.sublist(0, headerLength));
    if (!headerText.contains('%PDF-')) {
      throw PdfServiceException('File is not a valid PDF document or contains invalid header: $pdfPath');
    }

    try {
      final document = syncfusion.PdfDocument(inputBytes: bytes);
      if (document.pages.count == 0) {
        document.dispose();
        throw PdfServiceException('Source PDF contains no pages: $pdfPath');
      }
      return document;
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('password') || errStr.contains('encrypted') || errStr.contains('protection')) {
        throw PdfServiceException(
          'PDF file is encrypted or password-protected and cannot be processed.',
          details: e,
        );
      }
      throw PdfServiceException(
        'PDF document is corrupted or malformed: $pdfPath',
        details: e,
      );
    }
  }

  /// Gets the total page count of a PDF file
  Future<int> getPdfPageCount(String pdfPath) async {
    final document = await _openPdfDocument(pdfPath);
    try {
      return document.pages.count;
    } finally {
      document.dispose();
    }
  }

  /// Merges multiple PDF files
  Future<String> mergePdfs(List<String> pdfPaths, {String? customOutputPath}) async {
    if (pdfPaths.isEmpty) {
      throw PdfServiceException('No PDF files selected to merge.');
    }

    syncfusion.PdfDocument? outputDocument;
    final List<syncfusion.PdfDocument> openedDocuments = [];
    try {
      outputDocument = syncfusion.PdfDocument();

      for (final filePath in pdfPaths) {
        final syncfusion.PdfDocument sourceDocument = await _openPdfDocument(filePath);
        openedDocuments.add(sourceDocument);

        final int pageCount = sourceDocument.pages.count;
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
      final targetPath = path.join(dirPath, fileName);
      return await FileService().safeWriteBytes(targetPath, mergedBytes);
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to merge PDFs: $e', details: e);
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
    syncfusion.PdfDocument? sourceDocument;
    syncfusion.PdfDocument? outputDocument;
    try {
      sourceDocument = await _openPdfDocument(pdfPath);
      final int totalPages = sourceDocument.pages.count;

      if (startPage < 1) {
        throw PdfServiceException('Start page must be at least 1 (got $startPage).');
      }
      if (endPage > totalPages) {
        throw PdfServiceException('End page ($endPage) exceeds total pages in document ($totalPages).');
      }
      if (startPage > endPage) {
        throw PdfServiceException('Start page ($startPage) cannot be greater than end page ($endPage).');
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
      final targetPath = path.join(dirPath, fileName);
      return await FileService().safeWriteBytes(targetPath, outputBytes);
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to split PDF: $e', details: e);
    } finally {
      sourceDocument?.dispose();
      outputDocument?.dispose();
    }
  }

  /// Compresses a PDF file using high-efficiency stream compression and page re-rendering
  Future<String> compressPdf(String pdfPath, {String? customOutputPath}) async {
    syncfusion.PdfDocument? sourceDoc;
    syncfusion.PdfDocument? outputDoc;

    try {
      sourceDoc = await _openPdfDocument(pdfPath);
      outputDoc = syncfusion.PdfDocument();
      outputDoc.compressionLevel = syncfusion.PdfCompressionLevel.best;

      for (int i = 0; i < sourceDoc.pages.count; i++) {
        final syncfusion.PdfPage sourcePage = sourceDoc.pages[i];
        final syncfusion.PdfTemplate template = sourcePage.createTemplate();

        final syncfusion.PdfSection section = outputDoc.sections!.add();
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

      final List<int> outputBytes = outputDoc.saveSync();
      final String dirPath = customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final fileName = 'compressed_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final targetPath = path.join(dirPath, fileName);
      return await FileService().safeWriteBytes(targetPath, outputBytes);
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to compress PDF: $e', details: e);
    } finally {
      sourceDoc?.dispose();
      outputDoc?.dispose();
    }
  }

  /// Rotates the pages of a PDF by a specified angle (90, 180, 270)
  Future<String> rotatePdf({
    required String pdfPath,
    required int rotationAngle,
    String? customOutputPath,
  }) async {
    sf.PdfDocument? document;
    try {
      document = await _openPdfDocument(pdfPath);

      for (int i = 0; i < document.pages.count; i++) {
        final sf.PdfPage page = document.pages[i];
        final currentRotation = page.rotation;
        
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

        final newDegrees = (currentDegrees + rotationAngle) % 360;

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

      final List<int> outputBytes = await document.save();
      final String dirPath = customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final fileName = 'rotated_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final targetPath = path.join(dirPath, fileName);
      
      return await FileService().safeWriteBytes(targetPath, outputBytes);
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to rotate PDF: $e', details: e);
    } finally {
      document?.dispose();
    }
  }

  /// Applies a visible text watermark to all pages of a PDF
  Future<String> watermarkPdf({
    required String pdfPath,
    required String watermarkText,
    required double opacity,
    required double angle, // in radians
    required Color color,
    String? customOutputPath,
  }) async {
    if (watermarkText.trim().isEmpty) {
      throw PdfServiceException('Watermark text cannot be empty.');
    }

    sf.PdfDocument? document;
    try {
      document = await _openPdfDocument(pdfPath);

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

        final sf.PdfGraphicsState state = graphics.save();
        graphics.setTransparency(opacity);
        graphics.translateTransform(page.size.width / 2, page.size.height / 2);
        graphics.rotateTransform(angleInDegrees);

        final Size textSize = font.measureString(watermarkText);

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

        graphics.restore(state);
      }

      final List<int> outputBytes = await document.save();
      final String dirPath = customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final fileName = 'watermarked_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final targetPath = path.join(dirPath, fileName);

      return await FileService().safeWriteBytes(targetPath, outputBytes);
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to apply watermark: $e', details: e);
    } finally {
      document?.dispose();
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
    sf.PdfDocument? document;
    try {
      document = await _openPdfDocument(sourcePdfPath);
      final int pageCount = document.pages.count;

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
          // Normalize and clamp normalized coordinates
          final double nx = ann.x.clamp(0.0, 1.0);
          final double ny = ann.y.clamp(0.0, 1.0);
          final double nw = ann.width.clamp(0.01, 1.0);
          final double nh = ann.height.clamp(0.01, 1.0);

          final double x = nx * pageWidth;
          final double y = ny * pageHeight;
          final double w = nw * pageWidth;
          final double h = nh * pageHeight;

          final double maxAvailW = (pageWidth - x).clamp(1.0, pageWidth);
          final double maxAvailH = (pageHeight - y).clamp(1.0, pageHeight);

          if (ann.kind == AnnotationKind.text) {
            if (ann.text.trim().isEmpty) continue;
            final double fontSize = ann.fontSize.clamp(6.0, 144.0);
            final sf.PdfFont font = sf.PdfStandardFont(
              sf.PdfFontFamily.helvetica,
              fontSize,
              style: ann.bold ? sf.PdfFontStyle.bold : sf.PdfFontStyle.regular,
            );
            final sf.PdfBrush brush = sf.PdfSolidBrush(
              sf.PdfColor(
                (ann.color.r * 255.0).round().clamp(0, 255),
                (ann.color.g * 255.0).round().clamp(0, 255),
                (ann.color.b * 255.0).round().clamp(0, 255),
              ),
            );
            final Size textSize = font.measureString(ann.text);
            final double rawW = w > textSize.width ? w : textSize.width;
            final double rawH = h > textSize.height ? h : textSize.height;
            final double textW = rawW.clamp(textSize.width, maxAvailW);
            final double textH = rawH.clamp(textSize.height, maxAvailH);

            graphics.drawString(
              ann.text,
              font,
              brush: brush,
              bounds: Rect.fromLTWH(x, y, textW, textH),
            );
          } else if (ann.kind == AnnotationKind.image && ann.imageBytes != null && ann.imageBytes!.isNotEmpty) {
            try {
              final sf.PdfBitmap bitmap = sf.PdfBitmap(ann.imageBytes!);
              final double drawW = w.clamp(1.0, maxAvailW);
              final double drawH = h.clamp(1.0, maxAvailH);
              graphics.drawImage(
                bitmap,
                Rect.fromLTWH(x, y, drawW, drawH),
              );
            } catch (_) {
              // Corrupted or unsupported image bytes are skipped safely
            }
          }
        }
      }

      final List<int> outputBytes = await document.save();
      final String dirPath = customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final fileName = 'edited_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final targetPath = path.join(dirPath, fileName);

      return await FileService().safeWriteBytes(targetPath, outputBytes);
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to save edited PDF: $e', details: e);
    } finally {
      document?.dispose();
    }
  }

  /// Extracts text from a PDF document and saves it as a TXT file
  Future<String> convertPdfToTxt({
    required String pdfPath,
    String? customOutputPath,
  }) async {
    sf.PdfDocument? document;
    try {
      document = await _openPdfDocument(pdfPath);
      final sf.PdfTextExtractor extractor = sf.PdfTextExtractor(document);
      final String extractedText = extractor.extractText();
      
      if (extractedText.trim().isEmpty) {
        throw PdfServiceException('No extractable text found in the PDF. Scanned or image-only PDFs are not supported.');
      }

      final String dirPath = customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final fileName = 'extracted_${DateTime.now().millisecondsSinceEpoch}.txt';
      final outputFile = File(path.join(dirPath, fileName));
      await outputFile.writeAsString(extractedText, encoding: utf8);

      return outputFile.path;
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to extract text: $e', details: e);
    } finally {
      document?.dispose();
    }
  }
}

