import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:pdf_ai_toolkit/models/pdf_annotation.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/core/errors/app_exceptions.dart';

class PdfService {
  /// Safely validates a PDF file and loads a Syncfusion PdfDocument.
  /// Throws descriptive [PdfServiceException] for any file or PDF structural errors.
  Future<syncfusion.PdfDocument> _openPdfDocument(String pdfPath) async {
    if (pdfPath.trim().isEmpty) {
      throw PdfServiceException('PDF file path cannot be empty.', code: 'PDF_PATH_EMPTY');
    }
    final file = File(pdfPath);
    if (!await file.exists()) {
      throw PdfServiceException('File not found: $pdfPath', code: 'PDF_FILE_NOT_FOUND');
    }
    final List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      throw PdfServiceException('Failed to read PDF file bytes: $pdfPath', code: 'PDF_READ_FAILED', details: e);
    }
    if (bytes.isEmpty) {
      throw PdfServiceException('File is empty: $pdfPath', code: 'PDF_FILE_EMPTY');
    }

    // Check PDF header signature (%PDF-)
    final int headerLength = bytes.length < 1024 ? bytes.length : 1024;
    final String headerText = String.fromCharCodes(bytes.sublist(0, headerLength));
    if (!headerText.contains('%PDF-')) {
      throw PdfServiceException('File is not a valid PDF document or contains invalid header: $pdfPath', code: 'PDF_INVALID_SIGNATURE');
    }

    try {
      final document = syncfusion.PdfDocument(inputBytes: bytes);
      if (document.pages.count == 0) {
        document.dispose();
        throw PdfServiceException('Source PDF contains no pages: $pdfPath', code: 'PDF_EMPTY_PAGES');
      }
      return document;
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('password') || errStr.contains('encrypted') || errStr.contains('protection')) {
        throw PdfServiceException(
          'PDF file is encrypted or password-protected and cannot be processed.',
          code: 'PDF_ENCRYPTED',
          details: e,
        );
      }
      throw PdfServiceException(
        'PDF document is corrupted or malformed: $pdfPath',
        code: 'PDF_CORRUPT',
        details: e,
      );
    }
  }

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
      final output = await getApplicationDocumentsDirectory();
      final fileName = FileService().formatOutputFileName(
        baseName: title,
        extension: 'pdf',
      );
      final targetPath = path.join(output.path, fileName);
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
    syncfusion.PdfDocument? document;
    try {
      document = await _openPdfDocument(pdfPath);
      return document.pages.count;
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to read PDF page count: $e',
          code: 'PAGE_COUNT_FAILURE', details: e);
    } finally {
      document?.dispose();
    }
  }

  /// Merges multiple PDF files
  Future<String> mergePdfs(List<String> pdfPaths,
      {String? customOutputPath}) async {
    if (pdfPaths.isEmpty) {
      throw PdfServiceException('No PDF files selected to merge.',
          code: 'MERGE_NO_FILES');
    }

    syncfusion.PdfDocument? outputDocument;
    final List<syncfusion.PdfDocument> openedDocuments = [];
    try {
      outputDocument = syncfusion.PdfDocument();

      for (final filePath in pdfPaths) {
        final syncfusion.PdfDocument sourceDocument =
            await _openPdfDocument(filePath);
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
      return await FileService().safeWriteBytes(targetPath, mergedBytes);
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to merge PDFs: $e',
          code: 'MERGE_FAILURE', details: e);
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
        throw PdfServiceException('Start page must be at least 1 (got $startPage).',
            code: 'SPLIT_INVALID_START');
      }
      if (endPage > totalPages) {
        throw PdfServiceException(
            'End page ($endPage) exceeds total pages in document ($totalPages).',
            code: 'SPLIT_INVALID_END');
      }
      if (startPage > endPage) {
        throw PdfServiceException(
            'Start page ($startPage) cannot be greater than end page ($endPage).',
            code: 'SPLIT_INVALID_RANGE');
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
      return await FileService().safeWriteBytes(targetPath, outputBytes);
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to split PDF: $e',
          code: 'SPLIT_FAILURE', details: e);
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
    syncfusion.PdfDocument? sourceDoc;
    syncfusion.PdfDocument? outputDoc;

    try {
      sourceDoc = await _openPdfDocument(pdfPath);
      outputDoc = syncfusion.PdfDocument();

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
          level = syncfusion.PdfCompressionLevel.aboveNormal;
          break;
      }
      outputDoc.compressionLevel = level;

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
      final String dirPath =
          customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final String baseName = path.basenameWithoutExtension(pdfPath);
      final fileName = FileService().formatOutputFileName(
        baseName: baseName,
        suffix: 'compressed',
        extension: 'pdf',
      );
      final targetPath = path.join(dirPath, fileName);
      return await FileService().safeWriteBytes(targetPath, outputBytes);
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to compress PDF: $e',
          code: 'COMPRESS_FAILURE', details: e);
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
      // Load existing document
      document = await _openPdfDocument(pdfPath);

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
      final String dirPath =
          customOutputPath ?? (await getApplicationDocumentsDirectory()).path;
      final String baseName = path.basenameWithoutExtension(pdfPath);
      final fileName = FileService().formatOutputFileName(
        baseName: baseName,
        suffix: 'rotated_${rotationAngle}',
        extension: 'pdf',
      );
      final targetPath = path.join(dirPath, fileName);

      return await FileService().safeWriteBytes(targetPath, outputBytes);
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to rotate PDF: $e',
          code: 'ROTATE_FAILURE', details: e);
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
    if (watermarkText.isEmpty) {
      throw PdfServiceException('Watermark text cannot be empty',
          code: 'WATERMARK_TEXT_EMPTY');
    }

    sf.PdfDocument? document;
    try {
      // Load existing document
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

        // Save current graphics state
        final sf.PdfGraphicsState state = graphics.save();

        // Set transparency/opacity
        graphics.setTransparency(opacity);

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

      return await FileService().safeWriteBytes(targetPath, outputBytes);
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to apply watermark: $e',
          code: 'WATERMARK_FAILURE', details: e);
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

      return await FileService().safeWriteBytes(targetPath, outputBytes);
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to save edited PDF: $e',
          code: 'SAVE_EDITED_FAILURE', details: e);
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
      return await FileService()
          .safeWriteBytes(targetPath, utf8.encode(extractedText));
    } catch (e) {
      if (e is PdfServiceException) {
        String newCode = e.code ?? 'PDF_TO_TXT_FAILURE';
        if (e.code == 'PDF_FILE_NOT_FOUND') {
          newCode = 'PDF_TO_TXT_INPUT_NOT_FOUND';
        } else if (e.code == 'PDF_FILE_EMPTY') {
          newCode = 'PDF_TO_TXT_INPUT_EMPTY';
        } else if (e.code == 'PDF_CORRUPT' || e.code == 'PDF_INVALID_SIGNATURE' || e.code == 'PDF_ENCRYPTED') {
          newCode = 'PDF_TO_TXT_INVALID_PDF';
        }
        throw PdfServiceException(e.message, code: newCode, details: e.details);
      }
      throw PdfServiceException('Failed to extract text: $e',
          code: 'PDF_TO_TXT_FAILURE', details: e);
    } finally {
      document?.dispose();
    }
  }

  /// Extracts text from a PDF document and returns the raw string
  Future<String> extractPdfText(String pdfPath) async {
    sf.PdfDocument? document;
    try {
      document = await _openPdfDocument(pdfPath);
      final extractor = sf.PdfTextExtractor(document);
      return extractor.extractText();
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to extract text: $e',
          code: 'EXTRACT_TEXT_FAILURE', details: e);
    } finally {
      document?.dispose();
    }
  }

  /// Converts a TXT file to a PDF file
  Future<String> convertTxtToPdf({
    required String txtPath,
    required String title,
    String? customOutputPath,
  }) async {
    final file = File(txtPath);
    if (!await file.exists()) {
      throw PdfServiceException('Input TXT file not found: $txtPath',
          code: 'TXT_TO_PDF_INPUT_NOT_FOUND');
    }

    final content = await file.readAsString(encoding: utf8);
    if (content.trim().isEmpty) {
      throw PdfServiceException('Input TXT file is empty',
          code: 'TXT_TO_PDF_INPUT_EMPTY');
    }

    return await generatePdfFromText(title: title, content: content);
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

    try {
      final pdf = pw.Document();

      for (final imagePath in imagePaths) {
        final imgFile = File(imagePath);
        if (!await imgFile.exists()) {
          throw PdfServiceException('Image file not found: $imagePath',
              code: 'IMAGE_TO_PDF_INPUT_NOT_FOUND');
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
      final pdfBytes = await pdf.save();

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
    syncfusion.PdfDocument? testDoc;
    int pageCount = 0;
    try {
      // Validate PDF structure and details
      testDoc = await _openPdfDocument(pdfPath);
      pageCount = testDoc.pages.count;
    } catch (e) {
      if (e is PdfServiceException) {
        String newCode = e.code ?? 'PDF_TO_IMAGE_FAILURE';
        if (e.code == 'PDF_FILE_NOT_FOUND') {
          newCode = 'PDF_TO_IMAGE_INPUT_NOT_FOUND';
        } else if (e.code == 'PDF_FILE_EMPTY') {
          newCode = 'PDF_TO_IMAGE_INPUT_EMPTY';
        } else if (e.code == 'PDF_CORRUPT' || e.code == 'PDF_INVALID_SIGNATURE' || e.code == 'PDF_ENCRYPTED') {
          newCode = 'PDF_TO_IMAGE_INVALID_PDF';
        }
        throw PdfServiceException(e.message, code: newCode, details: e.details);
      }
      throw PdfServiceException('Failed to render PDF to images: $e',
          code: 'PDF_TO_IMAGE_FAILURE', details: e);
    } finally {
      testDoc?.dispose();
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

    final List<String> outputPaths = [];
    pdfx.PdfDocument? doc;
    try {
      doc = await pdfx.PdfDocument.openFile(pdfPath);
      final String dirPath =
          customOutputPath ?? (await getApplicationDocumentsDirectory()).path;

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

          final fileName =
              'page_${pageNum}_${DateTime.now().millisecondsSinceEpoch}.png';
          final targetPath = path.join(dirPath, fileName);
          final imagePath =
              await FileService().safeWriteBytes(targetPath, pageImage.bytes);

          // Validate generated image
          final imgFile = File(imagePath);
          if (!await imgFile.exists() || await imgFile.length() == 0) {
            throw Exception(
                'Rendered image file is empty or missing: $imagePath');
          }

          outputPaths.add(imagePath);
        } finally {
          await page.close();
        }
      }

      return outputPaths;
    } catch (e) {
      throw PdfServiceException('Failed to render PDF to images: $e',
          code: 'PDF_TO_IMAGE_FAILURE', details: e);
    } finally {
      await doc?.close();
    }
  }
}
