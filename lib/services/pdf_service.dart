import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:markdown/markdown.dart' as md;
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
    String? customOutputPath,
  }) async {
    try {
      final pdf = pw.Document();

      // Split content into sections (split by newlines and bullets)
      final lines = content.split('\n');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
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
              ..._buildContentWidgets(lines),
            ];
          },
        ),
      );

      // Save PDF to file
      final String dirPath =
          customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final fileName = FileService().formatOutputFileName(
        baseName: title,
        extension: 'pdf',
      );
      final targetPath = path.join(dirPath, fileName);
      final pdfBytes = await pdf.save();

      final resultPath =
          await FileService().safeWriteBytes(targetPath, pdfBytes);

      // Verification: ensure output is valid
      final outputFile = File(resultPath);
      if (!await outputFile.exists()) {
        throw PdfServiceException('Failed to create PDF output file',
            code: 'TXT_TO_PDF_OUTPUT_NOT_FOUND');
      }
      if (await outputFile.length() == 0) {
        throw PdfServiceException('Generated PDF file is empty',
            code: 'TXT_TO_PDF_OUTPUT_EMPTY');
      }

      // Verify the generated PDF can be reopened/read
      syncfusion.PdfDocument? testDoc;
      try {
        testDoc = syncfusion.PdfDocument(inputBytes: pdfBytes);
        if (testDoc.pages.count == 0) {
          throw Exception('Generated PDF contains no pages');
        }
      } catch (e) {
        throw PdfServiceException('Generated PDF is corrupt or invalid: $e',
            code: 'TXT_TO_PDF_INVALID_OUTPUT', details: e);
      } finally {
        testDoc?.dispose();
      }

      return resultPath;
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to generate PDF: $e',
          code: 'TXT_TO_PDF_FAILURE', details: e);
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
    final fs = FileService();
    if (!await fs.isFileAccessible(pdfPath)) {
      throw PdfServiceException('File not found: $pdfPath',
          code: 'PDF_INPUT_NOT_FOUND');
    }
    if (!await fs.isPdfFile(pdfPath)) {
      throw PdfServiceException(
          'File is empty, corrupt, or not a valid PDF: $pdfPath',
          code: 'PDF_CORRUPT_OR_INVALID');
    }
    final bytes = await File(pdfPath).readAsBytes();
    syncfusion.PdfDocument? document;
    try {
      document = syncfusion.PdfDocument(inputBytes: bytes);
      return document.pages.count;
    } catch (e) {
      throw PdfServiceException('Failed to read PDF page count: $e',
          code: 'PDF_CORRUPT_OR_INVALID', details: e);
    } finally {
      document?.dispose();
    }
  }

  /// Merges multiple PDF files
  Future<String> mergePdfs(List<String> pdfPaths,
      {String? customOutputPath}) async {
    if (pdfPaths.isEmpty) {
      throw PdfServiceException('No PDF files selected to merge.',
          code: 'PDF_MERGE_EMPTY_SELECTION');
    }

    final fs = FileService();
    for (final filePath in pdfPaths) {
      if (!await fs.isFileAccessible(filePath)) {
        throw PdfServiceException('File not found: $filePath',
            code: 'PDF_INPUT_NOT_FOUND');
      }
      if (!await fs.isPdfFile(filePath)) {
        throw PdfServiceException(
            'File is empty, corrupt, or not a valid PDF: $filePath',
            code: 'PDF_CORRUPT_OR_INVALID');
      }
    }

    syncfusion.PdfDocument? outputDocument;
    try {
      outputDocument = syncfusion.PdfDocument();

      for (final filePath in pdfPaths) {
        final bytes = await File(filePath).readAsBytes();

        final syncfusion.PdfDocument sourceDocument =
            syncfusion.PdfDocument(inputBytes: bytes);
        try {
          final int pageCount = sourceDocument.pages.count;
          if (pageCount == 0) {
            throw PdfServiceException('Source PDF contains no pages: $filePath',
                code: 'PDF_EMPTY_PAGES');
          }

          for (int i = 0; i < pageCount; i++) {
            final syncfusion.PdfPage sourcePage = sourceDocument.pages[i];
            final syncfusion.PdfTemplate template = sourcePage.createTemplate();

            final syncfusion.PdfSection section =
                outputDocument.sections!.add();
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
        } finally {
          sourceDocument.dispose();
        }
      }

      final List<int> mergedBytes = outputDocument.saveSync();

      final String dirPath =
          customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final String firstBase =
          (pdfPaths.isNotEmpty && pdfPaths.first.isNotEmpty)
              ? path.basenameWithoutExtension(pdfPaths.first)
              : 'merged';
      final fileName = FileService().formatOutputFileName(
        baseName: firstBase,
        suffix: 'merged',
        extension: 'pdf',
      );
      final targetPath = path.join(dirPath, fileName);
      final resultPath =
          await FileService().safeWriteBytes(targetPath, mergedBytes);

      if (!await fs.isFileValidAndAccessible(resultPath)) {
        throw PdfServiceException('Failed to generate valid merged PDF output.',
            code: 'PDF_MERGE_OUTPUT_INVALID');
      }
      return resultPath;
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to merge PDFs: $e', details: e);
    } finally {
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
    final fs = FileService();
    if (!await fs.isFileAccessible(pdfPath)) {
      throw PdfServiceException('File not found: $pdfPath',
          code: 'PDF_INPUT_NOT_FOUND');
    }
    if (!await fs.isPdfFile(pdfPath)) {
      throw PdfServiceException(
          'File is empty, corrupt, or not a valid PDF: $pdfPath',
          code: 'PDF_CORRUPT_OR_INVALID');
    }
    final bytes = await File(pdfPath).readAsBytes();

    syncfusion.PdfDocument? sourceDocument;
    syncfusion.PdfDocument? outputDocument;
    try {
      sourceDocument = syncfusion.PdfDocument(inputBytes: bytes);
      final int totalPages = sourceDocument.pages.count;

      if (totalPages == 0) {
        throw PdfServiceException('Source PDF contains no pages.',
            code: 'PDF_EMPTY_PAGES');
      }
      if (startPage < 1) {
        throw PdfServiceException(
            'Start page must be at least 1 (got $startPage).',
            code: 'PDF_INVALID_PAGE_RANGE');
      }
      if (endPage > totalPages) {
        throw PdfServiceException(
            'End page ($endPage) exceeds total pages in document ($totalPages).',
            code: 'PDF_INVALID_PAGE_RANGE');
      }
      if (startPage > endPage) {
        throw PdfServiceException(
            'Start page ($startPage) cannot be greater than end page ($endPage).',
            code: 'PDF_INVALID_PAGE_RANGE');
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

      final String dirPath =
          customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final String baseName = path.basenameWithoutExtension(pdfPath);
      final fileName = FileService().formatOutputFileName(
        baseName: baseName,
        suffix: 'split_p${startPage}-p${endPage}',
        extension: 'pdf',
      );
      final targetPath = path.join(dirPath, fileName);
      final resultPath =
          await FileService().safeWriteBytes(targetPath, outputBytes);

      if (!await fs.isFileValidAndAccessible(resultPath)) {
        throw PdfServiceException('Failed to generate valid split PDF output.',
            code: 'PDF_SPLIT_OUTPUT_INVALID');
      }
      return resultPath;
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to split PDF: $e', details: e);
    } finally {
      sourceDocument?.dispose();
      outputDocument?.dispose();
    }
  }

  /// Compresses a PDF file using high-efficiency stream compression and page re-rendering
  Future<String> compressPdf(
    String pdfPath, {
    String? customOutputPath,
    String compressionLevel = 'medium',
  }) async {
    final fs = FileService();
    if (!await fs.isFileAccessible(pdfPath)) {
      throw PdfServiceException(
          'Input file not found for compression: $pdfPath',
          code: 'PDF_INPUT_NOT_FOUND');
    }

    final file = File(pdfPath);
    final size = await file.length();
    if (size > 50 * 1024 * 1024) {
      throw PdfServiceException(
          'PDF file exceeds maximum supported size of 50MB.',
          code: 'PDF_COMPRESS_FILE_TOO_LARGE');
    }

    if (!await fs.isPdfFile(pdfPath)) {
      throw PdfServiceException(
          'Input PDF file is empty, corrupt, or not a valid PDF: $pdfPath',
          code: 'PDF_CORRUPT_OR_INVALID');
    }

    final bytes = await file.readAsBytes();

    syncfusion.PdfDocument? sourceDoc;
    syncfusion.PdfDocument? outputDoc;

    try {
      sourceDoc = syncfusion.PdfDocument(inputBytes: bytes);
      outputDoc = syncfusion.PdfDocument();

      final pageCount = sourceDoc.pages.count;
      if (pageCount == 0) {
        throw PdfServiceException('PDF document contains no pages to compress.',
            code: 'PDF_COMPRESS_EMPTY_PDF');
      }

      syncfusion.PdfCompressionLevel level;
      switch (compressionLevel.toLowerCase()) {
        case 'low':
          level = syncfusion.PdfCompressionLevel.belowNormal;
          break;
        case 'high':
          level = syncfusion.PdfCompressionLevel.best;
          break;
        case 'medium':
        default:
          level = syncfusion.PdfCompressionLevel.normal;
          break;
      }
      outputDoc.compressionLevel = level;

      for (int i = 0; i < pageCount; i++) {
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
      final String dirPath =
          customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final String baseName = path.basenameWithoutExtension(pdfPath);
      final fileName = FileService().formatOutputFileName(
        baseName: baseName,
        suffix: 'compressed',
        extension: 'pdf',
      );
      final targetPath = path.join(dirPath, fileName);
      final resultPath =
          await FileService().safeWriteBytes(targetPath, outputBytes);

      if (!await fs.isFileValidAndAccessible(resultPath)) {
        throw PdfServiceException(
            'Failed to generate valid compressed PDF output.',
            code: 'PDF_COMPRESS_OUTPUT_INVALID');
      }

      // Verify output by reopening
      syncfusion.PdfDocument? testDoc;
      try {
        testDoc = syncfusion.PdfDocument(inputBytes: outputBytes);
        if (testDoc.pages.count != pageCount) {
          throw Exception('Compressed PDF page count mismatch.');
        }
      } catch (e) {
        throw PdfServiceException(
            'Generated compressed PDF is corrupt or invalid: $e',
            code: 'PDF_COMPRESS_INVALID_OUTPUT',
            details: e);
      } finally {
        testDoc?.dispose();
      }

      return resultPath;
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
    final fs = FileService();
    try {
      if (!await fs.isFileAccessible(pdfPath)) {
        throw PdfServiceException('Input file does not exist: $pdfPath',
            code: 'PDF_INPUT_NOT_FOUND');
      }
      final file = File(pdfPath);
      final size = await file.length();
      if (size > 50 * 1024 * 1024) {
        throw PdfServiceException(
            'PDF file exceeds maximum supported size of 50MB.',
            code: 'PDF_ROTATE_FILE_TOO_LARGE');
      }

      if (!await fs.isPdfFile(pdfPath)) {
        throw PdfServiceException(
            'Input PDF file is empty, corrupt, or not a valid PDF: $pdfPath',
            code: 'PDF_CORRUPT_OR_INVALID');
      }

      final bytes = await file.readAsBytes();

      // Load existing document
      final sf.PdfDocument document = sf.PdfDocument(inputBytes: bytes);

      try {
        final pageCount = document.pages.count;
        if (pageCount == 0) {
          throw PdfServiceException('PDF document contains no pages to rotate.',
              code: 'PDF_ROTATE_EMPTY_PDF');
        }

        for (int i = 0; i < pageCount; i++) {
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
        final String dirPath =
            customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
        final String baseName = path.basenameWithoutExtension(pdfPath);
        final fileName = FileService().formatOutputFileName(
          baseName: baseName,
          suffix: 'rotated_${rotationAngle}',
          extension: 'pdf',
        );
        final targetPath = path.join(dirPath, fileName);

        final resultPath =
            await FileService().safeWriteBytes(targetPath, outputBytes);
        if (!await fs.isFileValidAndAccessible(resultPath)) {
          throw PdfServiceException(
              'Failed to generate valid rotated PDF output.',
              code: 'PDF_ROTATE_OUTPUT_INVALID');
        }

        // Verify output by reopening
        syncfusion.PdfDocument? testDoc;
        try {
          testDoc = syncfusion.PdfDocument(inputBytes: outputBytes);
          if (testDoc.pages.count != pageCount) {
            throw Exception('Rotated PDF page count mismatch.');
          }
        } catch (e) {
          throw PdfServiceException(
              'Generated rotated PDF is corrupt or invalid: $e',
              code: 'PDF_ROTATE_INVALID_OUTPUT',
              details: e);
        } finally {
          testDoc?.dispose();
        }

        return resultPath;
      } finally {
        document.dispose();
      }
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to rotate PDF: $e', details: e);
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
    final fs = FileService();
    try {
      if (!await fs.isFileAccessible(pdfPath)) {
        throw PdfServiceException('Input file does not exist: $pdfPath',
            code: 'PDF_INPUT_NOT_FOUND');
      }

      final file = File(pdfPath);
      final size = await file.length();
      if (size > 50 * 1024 * 1024) {
        throw PdfServiceException(
            'PDF file exceeds maximum supported size of 50MB.',
            code: 'PDF_WATERMARK_FILE_TOO_LARGE');
      }

      if (!await fs.isPdfFile(pdfPath)) {
        throw PdfServiceException(
            'Input PDF file is empty, corrupt, or not a valid PDF: $pdfPath',
            code: 'PDF_CORRUPT_OR_INVALID');
      }

      if (watermarkText.trim().isEmpty) {
        throw PdfServiceException('Watermark text cannot be empty',
            code: 'PDF_WATERMARK_EMPTY_TEXT');
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw PdfServiceException('Input PDF file is empty',
            code: 'PDF_CORRUPT_OR_INVALID');
      }

      // Load existing document
      final sf.PdfDocument document = sf.PdfDocument(inputBytes: bytes);

      try {
        final pageCount = document.pages.count;
        if (pageCount == 0) {
          throw PdfServiceException(
              'PDF document contains no pages to watermark.',
              code: 'PDF_WATERMARK_EMPTY_PDF');
        }

        final double angleInDegrees = angle * 180 / 3.141592653589793;
        final sf.PdfFont font = sf.PdfStandardFont(
          sf.PdfFontFamily.helvetica,
          50,
          style: sf.PdfFontStyle.bold,
        );

        final sf.PdfBrush brush = sf.PdfSolidBrush(
          sf.PdfColor(
            (color.r * 255).round().clamp(0, 255),
            (color.g * 255).round().clamp(0, 255),
            (color.b * 255).round().clamp(0, 255),
          ),
        );

        final clampedOpacity = opacity.clamp(0.0, 1.0);

        for (int i = 0; i < pageCount; i++) {
          final sf.PdfPage page = document.pages[i];
          final sf.PdfGraphics graphics = page.graphics;

          // Save current graphics state
          final sf.PdfGraphicsState state = graphics.save();

          // Set transparency/opacity
          graphics.setTransparency(clampedOpacity);

          // Translate origin to the center of the page
          graphics.translateTransform(
              page.size.width / 2, page.size.height / 2);

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

        final String dirPath =
            customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
        final String baseName = path.basenameWithoutExtension(pdfPath);
        final fileName = FileService().formatOutputFileName(
          baseName: baseName,
          suffix: 'watermarked',
          extension: 'pdf',
        );
        final targetPath = path.join(dirPath, fileName);

        final resultPath =
            await FileService().safeWriteBytes(targetPath, outputBytes);

        if (!await fs.isFileValidAndAccessible(resultPath)) {
          throw PdfServiceException(
              'Failed to generate valid watermarked PDF output.',
              code: 'PDF_WATERMARK_OUTPUT_INVALID');
        }

        // Verify output by reopening
        syncfusion.PdfDocument? testDoc;
        try {
          testDoc = syncfusion.PdfDocument(inputBytes: outputBytes);
          if (testDoc.pages.count != pageCount) {
            throw Exception('Watermarked PDF page count mismatch.');
          }
        } catch (e) {
          throw PdfServiceException(
              'Generated watermarked PDF is corrupt or invalid: $e',
              code: 'PDF_WATERMARK_INVALID_OUTPUT',
              details: e);
        } finally {
          testDoc?.dispose();
        }

        return resultPath;
      } finally {
        document.dispose();
      }
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to apply watermark: $e',
          code: 'PDF_WATERMARK_FAILURE', details: e);
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
    final fs = FileService();
    if (!await fs.isFileAccessible(sourcePdfPath)) {
      throw PdfServiceException('Source PDF file not found: $sourcePdfPath',
          code: 'PDF_EDITOR_INPUT_NOT_FOUND');
    }
    if (!await fs.isPdfFile(sourcePdfPath)) {
      throw PdfServiceException(
          'Source PDF file is empty or invalid: $sourcePdfPath',
          code: 'PDF_EDITOR_INPUT_INVALID');
    }

    final bytes = await File(sourcePdfPath).readAsBytes();
    if (bytes.isEmpty) {
      throw PdfServiceException('Source PDF file is empty: $sourcePdfPath',
          code: 'PDF_EDITOR_INPUT_EMPTY');
    }

    sf.PdfDocument? document;
    try {
      document = sf.PdfDocument(inputBytes: bytes);
      final int pageCount = document.pages.count;
      if (pageCount == 0) {
        throw PdfServiceException(
            'Source PDF contains no pages: $sourcePdfPath',
            code: 'PDF_EDITOR_EMPTY_PAGES');
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
          // Normalize and clamp normalized coordinates
          final double nx = ann.x.clamp(0.0, 1.0);
          final double ny = ann.y.clamp(0.0, 1.0);
          final double nw = ann.width.clamp(0.01, 1.0);
          final double nh = ann.height.clamp(0.01, 1.0);

          final double x = nx * pageWidth;
          final double y = ny * pageHeight;
          final double w = nw * pageWidth;
          final double h = nh * pageHeight;

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
            final double textW = (w > textSize.width ? w : textSize.width)
                .clamp(textSize.width, pageWidth);
            final double textH = (h > textSize.height ? h : textSize.height)
                .clamp(textSize.height, pageHeight);
            graphics.drawString(
              ann.text,
              font,
              brush: brush,
              bounds: Rect.fromLTWH(x, y, textW, textH),
            );
          } else if (ann.kind == AnnotationKind.image &&
              ann.imageBytes != null &&
              ann.imageBytes!.isNotEmpty) {
            try {
              final sf.PdfBitmap bitmap = sf.PdfBitmap(ann.imageBytes!);
              final double drawW =
                  w.clamp(1.0, (pageWidth - x).clamp(1.0, pageWidth));
              final double drawH =
                  h.clamp(1.0, (pageHeight - y).clamp(1.0, pageHeight));
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
      final String dirPath =
          customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final String baseName = path.basenameWithoutExtension(sourcePdfPath);
      final fileName = FileService().formatOutputFileName(
        baseName: baseName,
        suffix: 'edited',
        extension: 'pdf',
      );
      final targetPath = path.join(dirPath, fileName);

      final resultPath =
          await FileService().safeWriteBytes(targetPath, outputBytes);

      // Verify the generated output is readable and non-corrupt
      sf.PdfDocument? testDoc;
      try {
        final savedBytes = await File(resultPath).readAsBytes();
        testDoc = sf.PdfDocument(inputBytes: savedBytes);
        if (testDoc.pages.count != pageCount) {
          throw PdfServiceException(
              'Saved PDF page count (${testDoc.pages.count}) mismatched source ($pageCount)',
              code: 'PDF_EDITOR_OUTPUT_INVALID');
        }
      } catch (e) {
        if (e is PdfServiceException) rethrow;
        throw PdfServiceException('Saved PDF output is invalid or corrupt: $e',
            code: 'PDF_EDITOR_OUTPUT_INVALID', details: e);
      } finally {
        testDoc?.dispose();
      }

      return resultPath;
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to save edited PDF: $e',
          code: 'PDF_EDITOR_SAVE_FAILURE', details: e);
    } finally {
      document?.dispose();
    }
  }

  /// Extracts text from a PDF document and saves it as a TXT file
  Future<String> convertPdfToTxt({
    required String pdfPath,
    String? customOutputPath,
  }) async {
    final fs = FileService();
    if (!await fs.isFileAccessible(pdfPath)) {
      throw PdfServiceException('Input PDF file not found: $pdfPath',
          code: 'PDF_TO_TXT_INPUT_NOT_FOUND');
    }

    final file = File(pdfPath);
    final size = await file.length();
    if (size > 50 * 1024 * 1024) {
      throw PdfServiceException(
          'PDF file exceeds maximum supported size of 50MB.',
          code: 'PDF_TO_TXT_FILE_TOO_LARGE');
    }

    if (!await fs.isPdfFile(pdfPath)) {
      throw PdfServiceException(
          'Input file is empty, corrupt, or not a valid PDF: $pdfPath',
          code: 'PDF_TO_TXT_INVALID_PDF');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw PdfServiceException('Input PDF file is empty: $pdfPath',
          code: 'PDF_TO_TXT_INPUT_EMPTY');
    }

    // Load existing document
    sf.PdfDocument? document;
    try {
      document = sf.PdfDocument(inputBytes: bytes);
    } catch (e) {
      throw PdfServiceException('Invalid or corrupt PDF file: $e',
          code: 'PDF_TO_TXT_INVALID_PDF', details: e);
    }

    try {
      if (document.pages.count == 0) {
        throw PdfServiceException('PDF contains no pages.',
            code: 'PDF_TO_TXT_EMPTY_PDF');
      }

      final sf.PdfTextExtractor extractor = sf.PdfTextExtractor(document);
      final String extractedText = extractor.extractText();

      if (extractedText.trim().isEmpty) {
        throw PdfServiceException(
            'No extractable text found in the PDF. Scanned or image-only PDFs are not supported.',
            code: 'PDF_TO_TXT_NO_TEXT');
      }

      // Save extracted text to a .txt file safely using safeWriteBytes
      final String dirPath =
          customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final String baseName = path.basenameWithoutExtension(pdfPath);
      final fileName = FileService().formatOutputFileName(
        baseName: baseName,
        suffix: 'extracted',
        extension: 'txt',
      );
      final targetPath = path.join(dirPath, fileName);
      final resultPath = await FileService()
          .safeWriteBytes(targetPath, utf8.encode(extractedText));

      // Output validation
      final outputFile = File(resultPath);
      if (!await outputFile.exists()) {
        throw PdfServiceException('Failed to create TXT output file',
            code: 'PDF_TO_TXT_OUTPUT_NOT_FOUND');
      }
      if (await outputFile.length() == 0) {
        throw PdfServiceException('Generated TXT file is empty',
            code: 'PDF_TO_TXT_OUTPUT_EMPTY');
      }
      final ext = path.extension(resultPath).toLowerCase();
      if (ext != '.txt') {
        throw PdfServiceException('Generated output is not a valid text file.',
            code: 'PDF_TO_TXT_OUTPUT_INVALID_FORMAT');
      }

      return resultPath;
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to extract text: $e',
          code: 'PDF_TO_TXT_FAILURE', details: e);
    } finally {
      document.dispose();
    }
  }

  /// Extracts text from a PDF document and returns the raw string
  Future<String> extractPdfText(String pdfPath) async {
    try {
      final file = File(pdfPath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $pdfPath');
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return '';
      }
      final document = sf.PdfDocument(inputBytes: bytes);
      try {
        final extractor = sf.PdfTextExtractor(document);
        return extractor.extractText();
      } finally {
        document.dispose();
      }
    } catch (e) {
      throw Exception('Failed to extract text: $e');
    }
  }

  /// Converts a TXT file to a PDF file
  Future<String> convertTxtToPdf({
    required String txtPath,
    required String title,
    String? customOutputPath,
  }) async {
    final fs = FileService();
    if (!await fs.isFileAccessible(txtPath)) {
      throw PdfServiceException('Input TXT file not found: $txtPath',
          code: 'TXT_TO_PDF_INPUT_NOT_FOUND');
    }
    if (!await fs.isTextFile(txtPath)) {
      throw PdfServiceException(
          'Input file is not a valid plain text file: $txtPath',
          code: 'TXT_TO_PDF_INVALID_TEXT');
    }

    if (title.trim().isEmpty) {
      throw PdfServiceException('PDF title cannot be empty',
          code: 'TXT_TO_PDF_EMPTY_TITLE');
    }

    final file = File(txtPath);
    final size = await file.length();
    if (size > 5 * 1024 * 1024) {
      throw PdfServiceException(
          'TXT file exceeds maximum supported size of 5MB.',
          code: 'TXT_TO_PDF_FILE_TOO_LARGE');
    }

    String content;
    try {
      content = await file.readAsString(encoding: utf8);
    } catch (e) {
      throw PdfServiceException('Failed to read TXT file content as UTF-8: $e',
          code: 'TXT_TO_PDF_INVALID_TEXT', details: e);
    }

    if (content.trim().isEmpty) {
      throw PdfServiceException('Input TXT file is empty',
          code: 'TXT_TO_PDF_INPUT_EMPTY');
    }

    try {
      return await generatePdfFromText(
          title: title, content: content, customOutputPath: customOutputPath);
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to convert TXT to PDF: $e',
          code: 'TXT_TO_PDF_FAILURE', details: e);
    }
  }

  /// Converts a list of image files to a single PDF document
  Future<String> convertImagesToPdf({
    required List<String> imagePaths,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    bool fitPage = true,
    String? customOutputPath,
  }) async {
    if (imagePaths.isEmpty) {
      throw PdfServiceException('No images selected for conversion.',
          code: 'IMAGE_TO_PDF_NO_IMAGES');
    }
    if (imagePaths.length > 100) {
      throw PdfServiceException('Exceeded maximum limit of 100 images.',
          code: 'IMAGE_TO_PDF_TOO_MANY_IMAGES');
    }

    final fs = FileService();
    try {
      final pdf = pw.Document();

      for (final imagePath in imagePaths) {
        if (!await fs.isFileAccessible(imagePath)) {
          throw PdfServiceException('Image file not found: $imagePath',
              code: 'IMAGE_TO_PDF_INPUT_NOT_FOUND');
        }
        if (!await fs.isImageFile(imagePath)) {
          throw PdfServiceException(
              'File is empty, corrupt, or not a supported image format: $imagePath',
              code: 'IMAGE_TO_PDF_INVALID_IMAGE');
        }

        final imgFile = File(imagePath);
        final size = await imgFile.length();
        if (size > 10 * 1024 * 1024) {
          throw PdfServiceException(
              'Image file exceeds maximum supported size of 10MB: $imagePath',
              code: 'IMAGE_TO_PDF_FILE_TOO_LARGE');
        }

        final bytes = await imgFile.readAsBytes();
        if (bytes.isEmpty) {
          throw PdfServiceException('Image file is empty: $imagePath',
              code: 'IMAGE_TO_PDF_INPUT_EMPTY');
        }

        pw.MemoryImage img;
        try {
          img = pw.MemoryImage(bytes);
        } catch (e) {
          throw PdfServiceException(
              'Invalid or corrupt image format: $imagePath',
              code: 'IMAGE_TO_PDF_INVALID_IMAGE',
              details: e);
        }

        pdf.addPage(pw.Page(
          pageFormat: pageFormat,
          margin: fitPage ? pw.EdgeInsets.zero : const pw.EdgeInsets.all(20),
          build: (_) => fitPage
              ? pw.Image(img, fit: pw.BoxFit.contain)
              : pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
        ));
      }

      final String dirPath =
          customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final fileName =
          'images_converted_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final targetPath = path.join(dirPath, fileName);

      Uint8List pdfBytes;
      try {
        pdfBytes = await pdf.save();
      } catch (e) {
        throw PdfServiceException(
            'Invalid or corrupt image content detected during PDF compilation: $e',
            code: 'IMAGE_TO_PDF_INVALID_IMAGE',
            details: e);
      }

      final resultPath =
          await FileService().safeWriteBytes(targetPath, pdfBytes);

      // Validate output
      final outputFile = File(resultPath);
      if (!await outputFile.exists()) {
        throw PdfServiceException('Failed to create PDF output file',
            code: 'IMAGE_TO_PDF_OUTPUT_NOT_FOUND');
      }
      if (await outputFile.length() == 0) {
        throw PdfServiceException('Generated PDF file is empty',
            code: 'IMAGE_TO_PDF_OUTPUT_EMPTY');
      }

      // Verify the generated PDF can be reopened/read
      syncfusion.PdfDocument? testDoc;
      try {
        testDoc = syncfusion.PdfDocument(inputBytes: pdfBytes);
        if (testDoc.pages.count != imagePaths.length) {
          throw Exception(
              'Generated PDF page count (${testDoc.pages.count}) does not match input images count (${imagePaths.length})');
        }
      } catch (e) {
        throw PdfServiceException('Generated PDF is corrupt or invalid: $e',
            code: 'IMAGE_TO_PDF_INVALID_OUTPUT', details: e);
      } finally {
        testDoc?.dispose();
      }

      return resultPath;
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to convert images to PDF: $e',
          code: 'IMAGE_TO_PDF_FAILURE', details: e);
    }
  }

  /// Converts a PDF file into a list of image file paths (one per page)
  Future<List<String>> convertPdfToImages({
    required String pdfPath,
    String? customOutputPath,
    int? startPage, // 1-indexed
    int? endPage, // 1-indexed
    double scale = 2.0,
  }) async {
    final fs = FileService();
    if (!await fs.isFileAccessible(pdfPath)) {
      throw PdfServiceException('Input PDF file not found: $pdfPath',
          code: 'PDF_TO_IMAGE_INPUT_NOT_FOUND');
    }
    if (!await fs.isPdfFile(pdfPath)) {
      throw PdfServiceException(
          'Input file is empty, corrupt, or not a valid PDF: $pdfPath',
          code: 'PDF_TO_IMAGE_INVALID_PDF');
    }

    final file = File(pdfPath);
    final size = await file.length();
    if (size > 50 * 1024 * 1024) {
      throw PdfServiceException(
          'PDF file exceeds maximum supported size of 50MB.',
          code: 'PDF_TO_IMAGE_FILE_TOO_LARGE');
    }

    final int fileLength = await file.length();
    if (fileLength == 0) {
      throw PdfServiceException('Input PDF file is empty: $pdfPath',
          code: 'PDF_TO_IMAGE_INPUT_EMPTY');
    }

    final List<String> outputPaths = [];
    pdfx.PdfDocument? doc;
    try {
      try {
        doc = await pdfx.PdfDocument.openFile(pdfPath);
      } catch (e) {
        throw PdfServiceException(
            'Failed to open PDF document for rendering: $e',
            code: 'PDF_TO_IMAGE_INVALID_PDF',
            details: e);
      }

      final int pageCount = doc.pagesCount;
      if (pageCount == 0) {
        throw PdfServiceException('PDF document contains no pages',
            code: 'PDF_TO_IMAGE_EMPTY_PDF');
      }

      final int start = startPage ?? 1;
      final int end = endPage ?? pageCount;

      if (start < 1 || start > pageCount) {
        throw PdfServiceException(
            'Invalid start page: $start (total pages: $pageCount)',
            code: 'PDF_TO_IMAGE_INVALID_PAGE_RANGE');
      }
      if (end < start || end > pageCount) {
        throw PdfServiceException(
            'Invalid end page: $end (total pages: $pageCount)',
            code: 'PDF_TO_IMAGE_INVALID_PAGE_RANGE');
      }

      final String dirPath =
          customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final String baseName = path.basenameWithoutExtension(pdfPath);

      for (int pageNum = start; pageNum <= end; pageNum++) {
        final page = await doc.getPage(pageNum);
        try {
          final pageImage = await page.render(
            width: page.width * scale,
            height: page.height * scale,
            format: pdfx.PdfPageImageFormat.png,
          );

          if (pageImage == null || pageImage.bytes.isEmpty) {
            throw Exception('Failed to render page $pageNum');
          }

          final fileName = FileService().formatOutputFileName(
            baseName: baseName,
            suffix: 'page_$pageNum',
            extension: 'png',
          );
          final targetPath = path.join(dirPath, fileName);
          final imagePath =
              await FileService().safeWriteBytes(targetPath, pageImage.bytes);

          // Validate generated image
          final imgFile = File(imagePath);
          if (!await imgFile.exists() || await imgFile.length() == 0) {
            throw Exception(
                'Rendered image file is empty or missing: $imagePath');
          }

          // Validate PNG magic bytes: 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
          final header =
              await FileService().readFileHeader(imagePath, maxBytes: 8);
          if (header.length < 8 ||
              header[0] != 0x89 ||
              header[1] != 0x50 ||
              header[2] != 0x4E ||
              header[3] != 0x47) {
            throw Exception(
                'Generated file for page $pageNum is not a valid PNG.');
          }

          outputPaths.add(imagePath);
        } finally {
          await page.close();
        }
      }

      return outputPaths;
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to render PDF to images: $e',
          code: 'PDF_TO_IMAGE_FAILURE', details: e);
    } finally {
      await doc?.close();
    }
  }

  /// Converts a Markdown file to a styled PDF file
  Future<String> convertMarkdownToPdf({
    required String markdownPath,
    required String title,
    String? customOutputPath,
  }) async {
    final fs = FileService();
    if (!await fs.isFileAccessible(markdownPath)) {
      throw PdfServiceException('Input Markdown file not found: $markdownPath',
          code: 'MARKDOWN_TO_PDF_INPUT_NOT_FOUND');
    }

    final file = File(markdownPath);
    final size = await file.length();
    if (size == 0) {
      throw PdfServiceException('Input Markdown file is empty',
          code: 'MARKDOWN_TO_PDF_INPUT_EMPTY');
    }
    if (size > 5 * 1024 * 1024) {
      throw PdfServiceException(
          'Markdown file exceeds maximum supported size of 5MB.',
          code: 'MARKDOWN_TO_PDF_FILE_TOO_LARGE');
    }

    if (!await fs.isMarkdownFile(markdownPath)) {
      throw PdfServiceException(
          'Input file is not a valid plain-text Markdown file: $markdownPath',
          code: 'MARKDOWN_TO_PDF_INVALID_INPUT');
    }

    if (title.trim().isEmpty) {
      throw PdfServiceException('PDF title cannot be empty',
          code: 'MARKDOWN_TO_PDF_EMPTY_TITLE');
    }

    String content;
    try {
      content = await file.readAsString(encoding: utf8);
    } catch (e) {
      throw PdfServiceException(
          'Failed to read Markdown file content as UTF-8: $e',
          code: 'MARKDOWN_TO_PDF_INVALID_INPUT',
          details: e);
    }

    if (content.trim().isEmpty) {
      throw PdfServiceException('Input Markdown file is empty',
          code: 'MARKDOWN_TO_PDF_INPUT_EMPTY');
    }

    try {
      final pdf = pw.Document();

      // Parse markdown to AST
      final md.Document document = md.Document(
        extensionSet: md.ExtensionSet.gitHubFlavored,
      );
      final List<md.Node> nodes = document.parseLines(content.split('\n'));

      // Render AST nodes to PDF widgets
      final renderer = MarkdownPdfRenderer();
      final widgets = renderer.render(nodes);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Document Title Header
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 12),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom:
                          pw.BorderSide(color: PdfColors.grey300, width: 1)),
                ),
                margin: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      'Generated: ${DateTime.now().toString().split(' ')[0]}',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              ...widgets,
            ];
          },
        ),
      );

      final String dirPath =
          customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final fileName =
          'markdown_converted_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final targetPath = path.join(dirPath, fileName);
      final pdfBytes = await pdf.save();

      final resultPath =
          await FileService().safeWriteBytes(targetPath, pdfBytes);

      // Validate output
      final outputFile = File(resultPath);
      if (!await outputFile.exists()) {
        throw PdfServiceException('Failed to create PDF output file',
            code: 'MARKDOWN_TO_PDF_OUTPUT_NOT_FOUND');
      }
      if (await outputFile.length() == 0) {
        throw PdfServiceException('Generated PDF file is empty',
            code: 'MARKDOWN_TO_PDF_OUTPUT_EMPTY');
      }

      // Verify the generated PDF can be reopened/read
      syncfusion.PdfDocument? testDoc;
      try {
        testDoc = syncfusion.PdfDocument(inputBytes: pdfBytes);
        if (testDoc.pages.count == 0) {
          throw Exception('Generated PDF contains no pages');
        }
      } catch (e) {
        throw PdfServiceException('Generated PDF is corrupt or invalid: $e',
            code: 'MARKDOWN_TO_PDF_INVALID_OUTPUT', details: e);
      } finally {
        testDoc?.dispose();
      }

      return resultPath;
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to convert Markdown to PDF: $e',
          code: 'MARKDOWN_TO_PDF_FAILURE', details: e);
    }
  }

  /// Converts an HTML file to a styled PDF file
  Future<String> convertHtmlToPdf({
    required String htmlPath,
    required String title,
    String? customOutputPath,
  }) async {
    final fs = FileService();
    if (!await fs.isFileAccessible(htmlPath)) {
      throw PdfServiceException('Input HTML file not found: $htmlPath',
          code: 'HTML_TO_PDF_INPUT_NOT_FOUND');
    }

    final file = File(htmlPath);
    final size = await file.length();
    if (size == 0) {
      throw PdfServiceException('Input HTML file is empty',
          code: 'HTML_TO_PDF_INPUT_EMPTY');
    }
    if (size > 5 * 1024 * 1024) {
      throw PdfServiceException(
          'HTML file exceeds maximum supported size of 5MB.',
          code: 'HTML_TO_PDF_FILE_TOO_LARGE');
    }

    if (!await fs.isHtmlFile(htmlPath)) {
      throw PdfServiceException(
          'Input file is not a valid plain-text HTML file: $htmlPath',
          code: 'HTML_TO_PDF_INVALID_INPUT');
    }

    if (title.trim().isEmpty) {
      throw PdfServiceException('PDF title cannot be empty',
          code: 'HTML_TO_PDF_EMPTY_TITLE');
    }

    String content;
    try {
      content = await file.readAsString(encoding: utf8);
    } catch (e) {
      throw PdfServiceException('Failed to read HTML file content as UTF-8: $e',
          code: 'HTML_TO_PDF_INVALID_INPUT', details: e);
    }

    if (content.trim().isEmpty) {
      throw PdfServiceException('Input HTML file is empty',
          code: 'HTML_TO_PDF_INPUT_EMPTY');
    }

    try {
      final pdf = pw.Document();

      // Render HTML elements to PDF widgets
      final renderer = HtmlPdfRenderer();
      final widgets = renderer.render(content);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Document Title Header
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 12),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom:
                          pw.BorderSide(color: PdfColors.grey300, width: 1)),
                ),
                margin: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      'Generated: ${DateTime.now().toString().split(' ')[0]}',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              ...widgets,
            ];
          },
        ),
      );

      final String dirPath =
          customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final fileName =
          'html_converted_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final targetPath = path.join(dirPath, fileName);
      final pdfBytes = await pdf.save();

      final resultPath =
          await FileService().safeWriteBytes(targetPath, pdfBytes);

      // Validate output
      final outputFile = File(resultPath);
      if (!await outputFile.exists()) {
        throw PdfServiceException('Failed to create PDF output file',
            code: 'HTML_TO_PDF_OUTPUT_NOT_FOUND');
      }
      if (await outputFile.length() == 0) {
        throw PdfServiceException('Generated PDF file is empty',
            code: 'HTML_TO_PDF_OUTPUT_EMPTY');
      }

      // Verify the generated PDF can be reopened/read
      syncfusion.PdfDocument? testDoc;
      try {
        testDoc = syncfusion.PdfDocument(inputBytes: pdfBytes);
        if (testDoc.pages.count == 0) {
          throw Exception('Generated PDF contains no pages');
        }
      } catch (e) {
        throw PdfServiceException('Generated PDF is corrupt or invalid: $e',
            code: 'HTML_TO_PDF_INVALID_OUTPUT', details: e);
      } finally {
        testDoc?.dispose();
      }

      return resultPath;
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to convert HTML to PDF: $e',
          code: 'HTML_TO_PDF_FAILURE', details: e);
    }
  }

  /// Password protects a PDF document using User & Owner Passwords
  Future<String> protectPdf({
    required String pdfPath,
    required String password,
    String? customOutputPath,
  }) async {
    try {
      final file = File(pdfPath);
      if (!await file.exists()) {
        throw PdfServiceException('Input file does not exist',
            code: 'PROTECT_PDF_INPUT_NOT_FOUND');
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw PdfServiceException('Input PDF file is empty',
            code: 'PROTECT_PDF_INPUT_EMPTY');
      }

      final syncfusion.PdfDocument document =
          syncfusion.PdfDocument(inputBytes: bytes);
      try {
        // Set encryption algorithm
        document.security.algorithm =
            syncfusion.PdfEncryptionAlgorithm.aesx256Bit;

        // Set passwords
        document.security.userPassword = password;
        document.security.ownerPassword = password;

        final List<int> outputBytes = document.saveSync();

        final String dirPath =
            customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
        final String baseName = path.basenameWithoutExtension(pdfPath);
        final fileName = FileService().formatOutputFileName(
          baseName: baseName,
          suffix: 'protected',
          extension: 'pdf',
        );
        final targetPath = path.join(dirPath, fileName);

        return await FileService().safeWriteBytes(targetPath, outputBytes);
      } finally {
        document.dispose();
      }
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to protect PDF: $e',
          code: 'PROTECT_PDF_FAILURE', details: e);
    }
  }
}

class MarkdownPdfRenderer {
  List<pw.Widget> render(List<md.Node> nodes) {
    final List<pw.Widget> widgets = [];
    for (final node in nodes) {
      final widget = _renderNode(node);
      if (widget != null) {
        widgets.add(widget);
      }
    }
    return widgets;
  }

  pw.Widget? _renderNode(md.Node node) {
    if (node is md.Text) {
      return pw.Paragraph(
        text: node.text,
        style: const pw.TextStyle(fontSize: 11),
      );
    } else if (node is md.Element) {
      switch (node.tag) {
        case 'h1':
          return _renderHeader(node, 24, pw.FontWeight.bold, 16);
        case 'h2':
          return _renderHeader(node, 18, pw.FontWeight.bold, 12);
        case 'h3':
          return _renderHeader(node, 14, pw.FontWeight.bold, 10);
        case 'h4':
        case 'h5':
        case 'h6':
          return _renderHeader(node, 12, pw.FontWeight.bold, 8);
        case 'p':
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.RichText(
              text: pw.TextSpan(
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
                children: _renderInlineSpans(node.children ?? []),
              ),
            ),
          );
        case 'ul':
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: (node.children ?? [])
                .map((li) => _renderListItem(li, isOrdered: false))
                .toList(),
          );
        case 'ol':
          int index = 1;
          final listItems = <pw.Widget>[];
          for (final li in (node.children ?? [])) {
            listItems.add(_renderListItem(li, isOrdered: true, index: index++));
          }
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: listItems,
          );
        case 'blockquote':
          return pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.grey400, width: 3)),
            ),
            padding: const pw.EdgeInsets.only(left: 12, top: 4, bottom: 4),
            margin: const pw.EdgeInsets.only(bottom: 12, top: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: (node.children ?? [])
                  .map((child) => _renderNode(child))
                  .whereType<pw.Widget>()
                  .toList(),
            ),
          );
        case 'pre':
          final codeText = node.textContent.trim();
          return pw.Container(
            width: double.infinity,
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            padding: const pw.EdgeInsets.all(8),
            margin: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Text(
              codeText,
              style: pw.TextStyle(
                font: pw.Font.courier(),
                fontSize: 9,
                color: PdfColors.grey800,
              ),
            ),
          );
        case 'hr':
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 16),
            child: pw.Divider(color: PdfColors.grey300, thickness: 1),
          );
        default:
          if (node.children != null && node.children!.isNotEmpty) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: node.children!
                  .map((child) => _renderNode(child))
                  .whereType<pw.Widget>()
                  .toList(),
            );
          }
      }
    }
    return null;
  }

  pw.Widget _renderHeader(md.Element node, double fontSize,
      pw.FontWeight fontWeight, double bottomMargin) {
    return pw.Container(
      margin: pw.EdgeInsets.only(top: 16, bottom: bottomMargin),
      child: pw.RichText(
        text: pw.TextSpan(
          style: pw.TextStyle(fontSize: fontSize, fontWeight: fontWeight),
          children: _renderInlineSpans(node.children ?? []),
        ),
      ),
    );
  }

  pw.Widget _renderListItem(md.Node node,
      {required bool isOrdered, int? index}) {
    if (node is! md.Element || node.tag != 'li') {
      final childWidget = _renderNode(node);
      return childWidget ?? pw.SizedBox();
    }

    final childrenSpans = _renderInlineSpans(node.children ?? []);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 16,
            padding: const pw.EdgeInsets.only(top: 4),
            child: isOrdered
                ? pw.Text('$index.', style: const pw.TextStyle(fontSize: 11))
                : pw.Bullet(),
          ),
          pw.Expanded(
            child: pw.RichText(
              text: pw.TextSpan(
                style: const pw.TextStyle(fontSize: 11),
                children: childrenSpans,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<pw.InlineSpan> _renderInlineSpans(List<md.Node> nodes) {
    final List<pw.InlineSpan> spans = [];
    for (final node in nodes) {
      _renderInlineNode(node, spans, const pw.TextStyle());
    }
    return spans;
  }

  void _renderInlineNode(
      md.Node node, List<pw.InlineSpan> spans, pw.TextStyle style) {
    if (node is md.Text) {
      spans.add(pw.TextSpan(text: node.text, style: style));
    } else if (node is md.Element) {
      switch (node.tag) {
        case 'strong':
          final newStyle = style.copyWith(fontWeight: pw.FontWeight.bold);
          for (final child in (node.children ?? [])) {
            _renderInlineNode(child, spans, newStyle);
          }
          break;
        case 'em':
          final newStyle = style.copyWith(fontStyle: pw.FontStyle.italic);
          for (final child in (node.children ?? [])) {
            _renderInlineNode(child, spans, newStyle);
          }
          break;
        case 'code':
          final newStyle = style.copyWith(
            font: pw.Font.courier(),
            color: PdfColors.red700,
          );
          spans.add(pw.TextSpan(text: node.textContent, style: newStyle));
          break;
        case 'a':
          final newStyle = style.copyWith(
            color: PdfColors.blue,
            decoration: pw.TextDecoration.underline,
          );
          for (final child in (node.children ?? [])) {
            _renderInlineNode(child, spans, newStyle);
          }
          break;
        default:
          for (final child in (node.children ?? [])) {
            _renderInlineNode(child, spans, style);
          }
      }
    }
  }
}

class HtmlPdfRenderer {
  List<pw.Widget> render(String htmlContent) {
    final List<pw.Widget> widgets = [];

    // Preprocess: strip comments and document structural wrappers
    var sanitized =
        htmlContent.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    sanitized = sanitized.replaceAll(
        RegExp(r'<style[^>]*>.*?<\/style>', caseSensitive: false, dotAll: true),
        '');
    sanitized = sanitized.replaceAll(
        RegExp(r'<script[^>]*>.*?<\/script>',
            caseSensitive: false, dotAll: true),
        '');
    sanitized = sanitized.replaceAll(
        RegExp(r'<head[^>]*>.*?<\/head>', caseSensitive: false, dotAll: true),
        '');
    sanitized = sanitized.replaceAll(
        RegExp(r'<\/?(html|body|doctype)[^>]*>', caseSensitive: false), '');

    final regExp = RegExp(
      r'<(h1|h2|h3|h4|h5|h6|p|ul|ol|blockquote|pre|hr)([^>]*)>(.*?)<\/\1>',
      caseSensitive: false,
      dotAll: true,
    );

    final matches = regExp.allMatches(sanitized);
    if (matches.isEmpty) {
      final lines = sanitized.split('\n');
      for (final line in lines) {
        if (line.trim().isNotEmpty) {
          widgets.add(pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.RichText(
              text: pw.TextSpan(
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
                text: line.trim(),
              ),
            ),
          ));
        }
      }
      return widgets;
    }

    for (final match in matches) {
      final tag = match.group(1)!.toLowerCase();
      final content = match.group(3)!;

      switch (tag) {
        case 'h1':
          widgets.add(_renderHeader(content, 24, pw.FontWeight.bold, 16));
          break;
        case 'h2':
          widgets.add(_renderHeader(content, 18, pw.FontWeight.bold, 12));
          break;
        case 'h3':
          widgets.add(_renderHeader(content, 14, pw.FontWeight.bold, 10));
          break;
        case 'h4':
        case 'h5':
        case 'h6':
          widgets.add(_renderHeader(content, 12, pw.FontWeight.bold, 8));
          break;
        case 'p':
          widgets.add(pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.RichText(
              text: pw.TextSpan(
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
                children: _renderInlineSpans(content),
              ),
            ),
          ));
          break;
        case 'ul':
          widgets.add(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: _parseListItems(content, isOrdered: false),
          ));
          break;
        case 'ol':
          widgets.add(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: _parseListItems(content, isOrdered: true),
          ));
          break;
        case 'blockquote':
          widgets.add(pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.grey400, width: 3)),
            ),
            padding: const pw.EdgeInsets.only(left: 12, top: 4, bottom: 4),
            margin: const pw.EdgeInsets.only(bottom: 12, top: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: HtmlPdfRenderer().render(content),
            ),
          ));
          break;
        case 'pre':
          var codeText = content;
          if (codeText.toLowerCase().contains('<code')) {
            final codeMatch = RegExp(r'<code[^>]*>(.*?)<\/code>',
                    caseSensitive: false, dotAll: true)
                .firstMatch(codeText);
            if (codeMatch != null) {
              codeText = codeMatch.group(1)!;
            }
          }
          widgets.add(pw.Container(
            width: double.infinity,
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            padding: const pw.EdgeInsets.all(8),
            margin: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Text(
              codeText.trim(),
              style: pw.TextStyle(
                font: pw.Font.courier(),
                fontSize: 9,
                color: PdfColors.grey800,
              ),
            ),
          ));
          break;
        case 'hr':
          widgets.add(pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 16),
            child: pw.Divider(color: PdfColors.grey300, thickness: 1),
          ));
          break;
      }
    }

    return widgets;
  }

  pw.Widget _renderHeader(String innerHtml, double fontSize,
      pw.FontWeight fontWeight, double bottomMargin) {
    return pw.Container(
      margin: pw.EdgeInsets.only(top: 16, bottom: bottomMargin),
      child: pw.RichText(
        text: pw.TextSpan(
          style: pw.TextStyle(fontSize: fontSize, fontWeight: fontWeight),
          children: _renderInlineSpans(innerHtml),
        ),
      ),
    );
  }

  List<pw.Widget> _parseListItems(String innerHtml, {required bool isOrdered}) {
    final listItems = <pw.Widget>[];
    final liReg =
        RegExp(r'<li[^>]*>(.*?)<\/li>', caseSensitive: false, dotAll: true);
    final liMatches = liReg.allMatches(innerHtml);
    int index = 1;

    for (final match in liMatches) {
      final content = match.group(1)!;
      listItems.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 16,
                padding: const pw.EdgeInsets.only(top: 4),
                child: isOrdered
                    ? pw.Text('$index.',
                        style: const pw.TextStyle(fontSize: 11))
                    : pw.Bullet(),
              ),
              pw.Expanded(
                child: pw.RichText(
                  text: pw.TextSpan(
                    style: const pw.TextStyle(fontSize: 11),
                    children: _renderInlineSpans(content),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      index++;
    }

    return listItems;
  }

  List<pw.InlineSpan> _renderInlineSpans(String text) {
    final List<pw.InlineSpan> spans = [];

    final inlineReg = RegExp(
      r'<(strong|b|em|i|code|a)([^>]*)>(.*?)<\/1>|([^<]+)',
      caseSensitive: false,
      dotAll: true,
    );

    final matches = inlineReg.allMatches(text);
    if (matches.isEmpty && text.isNotEmpty) {
      spans.add(pw.TextSpan(text: text));
      return spans;
    }

    for (final match in matches) {
      final tag = match.group(1)?.toLowerCase();
      final content = match.group(3);
      final plainText = match.group(4);

      if (plainText != null && plainText.isNotEmpty) {
        spans.add(pw.TextSpan(text: plainText));
      } else if (tag != null && content != null) {
        switch (tag) {
          case 'strong':
          case 'b':
            spans.add(pw.TextSpan(
              text: content,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ));
            break;
          case 'em':
          case 'i':
            spans.add(pw.TextSpan(
              text: content,
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
            ));
            break;
          case 'code':
            spans.add(pw.TextSpan(
              text: content,
              style: pw.TextStyle(
                font: pw.Font.courier(),
                color: PdfColors.red700,
              ),
            ));
            break;
          case 'a':
            spans.add(pw.TextSpan(
              text: content,
              style: const pw.TextStyle(
                color: PdfColors.blue,
                decoration: pw.TextDecoration.underline,
              ),
            ));
            break;
        }
      }
    }

    if (spans.isEmpty && text.isNotEmpty) {
      spans.add(pw.TextSpan(text: text));
    }

    return spans;
  }
}
