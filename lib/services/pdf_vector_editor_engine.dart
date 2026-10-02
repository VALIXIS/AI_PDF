import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:pdf_ai_toolkit/services/ai_service.dart';

/// Represents a detected text line / block on a PDF page.
class PdfTextBlock {
  final int pageIndex;
  final Rect bounds;
  final String text;
  final double fontSize;
  final String fontName;
  final bool isBold;
  final bool isItalic;

  PdfTextBlock({
    required this.pageIndex,
    required this.bounds,
    required this.text,
    this.fontSize = 12.0,
    this.fontName = 'Helvetica',
    this.isBold = false,
    this.isItalic = false,
  });

  PdfTextBlock copyWith({
    int? pageIndex,
    Rect? bounds,
    String? text,
    double? fontSize,
    String? fontName,
    bool? isBold,
    bool? isItalic,
  }) {
    return PdfTextBlock(
      pageIndex: pageIndex ?? this.pageIndex,
      bounds: bounds ?? this.bounds,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      fontName: fontName ?? this.fontName,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
    );
  }
}

/// Flagship Native & AI Vector PDF Engine.
/// Provides direct in-place vector text detection & editing, page manipulation,
/// and AI-powered section transformations on PDF documents.
class PdfVectorEditorEngine {
  /// Extracts all selectable text blocks with exact bounding box coordinates from a PDF page.
  static Future<List<PdfTextBlock>> extractTextBlocks(
    Uint8List pdfBytes,
    int pageIndex,
  ) async {
    sf.PdfDocument? document;
    try {
      document = sf.PdfDocument(inputBytes: pdfBytes);
      if (pageIndex < 0 || pageIndex >= document.pages.count) {
        return [];
      }

      final extractor = sf.PdfTextExtractor(document);
      final textLines = extractor.extractTextLines(
        startPageIndex: pageIndex,
        endPageIndex: pageIndex,
      );

      final blocks = <PdfTextBlock>[];
      for (final line in textLines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;

        final bounds = line.bounds;
        final fontSize = line.fontSize > 0 ? line.fontSize : 12.0;

        blocks.add(
          PdfTextBlock(
            pageIndex: pageIndex,
            bounds: bounds,
            text: line.text,
            fontSize: fontSize,
            fontName: line.fontName.isNotEmpty ? line.fontName : 'Helvetica',
            isBold: line.fontName.toLowerCase().contains('bold'),
            isItalic: line.fontName.toLowerCase().contains('italic') ||
                line.fontName.toLowerCase().contains('oblique'),
          ),
        );
      }

      return blocks;
    } catch (_) {
      return [];
    } finally {
      document?.dispose();
    }
  }

  /// Replaces a target text block in-place on a PDF page.
  /// Erases the original vector text bounds with the page background color and
  /// renders the new text with matching or specified font styling.
  static Future<Uint8List> replaceTextBlock({
    required Uint8List pdfBytes,
    required int pageIndex,
    required Rect targetBounds,
    required String replacementText,
    double? newFontSize,
    Color fontColor = Colors.black,
    Color backgroundColor = Colors.white,
    bool isBold = false,
    bool isItalic = false,
  }) async {
    sf.PdfDocument? document;
    sf.PdfDocument? newDoc;
    try {
      document = sf.PdfDocument(inputBytes: pdfBytes);
      if (pageIndex < 0 || pageIndex >= document.pages.count) {
        return pdfBytes;
      }

      newDoc = sf.PdfDocument();

      // Copy all pages
      for (int i = 0; i < document.pages.count; i++) {
        final originalPage = document.pages[i];
        final newPage = newDoc.pages.add();
        
        // Draw original page as a template to preserve all fonts/graphics perfectly
        final template = originalPage.createTemplate();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));

        // If this is the page we are editing, apply our overlay modifications
        if (i == pageIndex) {
          final graphics = newPage.graphics;
          graphics.save();

          // 1. Erase original text bounds with clean background
          final bgBrush = sf.PdfSolidBrush(
            sf.PdfColor(
              backgroundColor.red,
              backgroundColor.green,
              backgroundColor.blue,
            ),
          );

          // Add a 1.5px padding to cleanly cover any antialiased glyph edges
          final eraseRect = Rect.fromLTRB(
            targetBounds.left - 1.5,
            targetBounds.top - 1.5,
            targetBounds.right + 1.5,
            targetBounds.bottom + 1.5,
          );

          graphics.drawRectangle(
            brush: bgBrush,
            bounds: eraseRect,
          );

          // 2. Render new replacement text in-place
          sf.PdfFontStyle style = sf.PdfFontStyle.regular;
          if (isBold && isItalic) {
            style = sf.PdfFontStyle.bold;
          } else if (isBold) {
            style = sf.PdfFontStyle.bold;
          } else if (isItalic) {
            style = sf.PdfFontStyle.italic;
          }

          final calculatedFontSize = (newFontSize != null && newFontSize > 0)
              ? newFontSize
              : (targetBounds.height * 0.75 > 6 ? targetBounds.height * 0.75 : 12.0);

          final font = sf.PdfStandardFont(
            sf.PdfFontFamily.helvetica,
            calculatedFontSize,
            style: style,
          );

          final textBrush = sf.PdfSolidBrush(
            sf.PdfColor(
              fontColor.red,
              fontColor.green,
              fontColor.blue,
            ),
          );

          final format = sf.PdfStringFormat(
            alignment: sf.PdfTextAlignment.left,
            lineAlignment: sf.PdfVerticalAlignment.top,
            wordWrap: sf.PdfWordWrapType.word,
          );

          final textBoundsWidth = targetBounds.width > 30 ? targetBounds.width * 3.0 : 450.0;
          final textBoundsHeight = targetBounds.height > 10 ? targetBounds.height * 3.0 : 60.0;

          graphics.drawString(
            replacementText,
            font,
            brush: textBrush,
            bounds: Rect.fromLTWH(
              targetBounds.left,
              targetBounds.top - 1.0,
              textBoundsWidth,
              textBoundsHeight,
            ),
            format: format,
          );
          graphics.restore();
        }
      }

      final outputBytes = newDoc.saveSync();
      return Uint8List.fromList(outputBytes);
    } finally {
      document?.dispose();
      newDoc?.dispose();
    }
  }

  /// Inserts a blank page into the PDF at the specified index.
  static Future<Uint8List> insertBlankPage({
    required Uint8List pdfBytes,
    required int atIndex,
    double width = 595.0,
    double height = 842.0,
  }) async {
    sf.PdfDocument? document;
    try {
      document = sf.PdfDocument(inputBytes: pdfBytes);

      // If inserting at specific position, recreate document with reordered pages
      if (atIndex >= 0 && atIndex < document.pages.count) {
        final newDoc = sf.PdfDocument();
        final targetIndex = atIndex.clamp(0, document.pages.count);

        for (int i = 0; i < document.pages.count; i++) {
          if (i == targetIndex) {
            newDoc.pages.add();
          }
          final page = document.pages[i];
          final template = page.createTemplate();
          final newPage = newDoc.pages.add();
          newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
        }

        if (targetIndex >= document.pages.count) {
          newDoc.pages.add();
        }

        final out = newDoc.saveSync();
        newDoc.dispose();
        return Uint8List.fromList(out);
      } else {
        document.pages.add();
        final output = document.saveSync();
        return Uint8List.fromList(output);
      }
    } finally {
      document?.dispose();
    }
  }

  /// Deletes the page at [pageIndex] from the PDF.
  static Future<Uint8List> deletePage({
    required Uint8List pdfBytes,
    required int pageIndex,
  }) async {
    sf.PdfDocument? document;
    try {
      document = sf.PdfDocument(inputBytes: pdfBytes);
      if (document.pages.count <= 1) {
        return pdfBytes; // Do not delete the only remaining page
      }

      if (pageIndex >= 0 && pageIndex < document.pages.count) {
        document.pages.removeAt(pageIndex);
      }

      final output = document.saveSync();
      return Uint8List.fromList(output);
    } finally {
      document?.dispose();
    }
  }

  /// Reorders pages within the PDF document.
  static Future<Uint8List> reorderPages({
    required Uint8List pdfBytes,
    required int oldIndex,
    required int newIndex,
  }) async {
    sf.PdfDocument? document;
    sf.PdfDocument? newDocument;
    try {
      document = sf.PdfDocument(inputBytes: pdfBytes);
      final total = document.pages.count;
      if (total <= 1 || oldIndex < 0 || oldIndex >= total || newIndex < 0 || newIndex >= total) {
        return pdfBytes;
      }

      final pageIndices = List<int>.generate(total, (i) => i);
      final moved = pageIndices.removeAt(oldIndex);
      pageIndices.insert(newIndex, moved);

      newDocument = sf.PdfDocument();
      for (final idx in pageIndices) {
        final page = document.pages[idx];
        final template = page.createTemplate();
        final newPage = newDocument.pages.add();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }

      final output = newDocument.saveSync();
      return Uint8List.fromList(output);
    } finally {
      document?.dispose();
      newDocument?.dispose();
    }
  }

  /// Restyles an existing section using AI (e.g. rewrite, fix grammar, restyle title).
  static Future<Uint8List> restyleSectionWithAi({
    required Uint8List pdfBytes,
    required int pageIndex,
    required Rect targetBounds,
    required String originalText,
    required String aiInstruction,
    required AiService aiService,
    double? newFontSize,
    Color fontColor = Colors.black,
  }) async {
    final prompt =
        'Instruction: $aiInstruction\nOriginal text to modify: "$originalText"\nReturn ONLY the modified replacement text without any markdown, quotes, or conversational explanations:';

    final transformedText = await aiService.generateText(prompt, AiService.modeClean);
    final cleaned = transformedText.replaceAll(RegExp(r'^["`\*\s]+|["`\*\s]+$'), '').trim();

    return await replaceTextBlock(
      pdfBytes: pdfBytes,
      pageIndex: pageIndex,
      targetBounds: targetBounds,
      replacementText: cleaned.isNotEmpty ? cleaned : originalText,
      newFontSize: newFontSize,
      fontColor: fontColor,
    );
  }

  /// Adds custom vector text at a given position on the page.
  static Future<Uint8List> addCustomText({
    required Uint8List pdfBytes,
    required int pageIndex,
    required Offset position,
    required String text,
    double fontSize = 14.0,
    Color color = Colors.black,
    bool isBold = false,
    bool isItalic = false,
  }) async {
    sf.PdfDocument? document;
    try {
      document = sf.PdfDocument(inputBytes: pdfBytes);
      if (pageIndex < 0 || pageIndex >= document.pages.count) {
        return pdfBytes;
      }

      final page = document.pages[pageIndex];
      sf.PdfFontStyle style = sf.PdfFontStyle.regular;
      if (isBold && isItalic) {
        style = sf.PdfFontStyle.bold;
      } else if (isBold) {
        style = sf.PdfFontStyle.bold;
      } else if (isItalic) {
        style = sf.PdfFontStyle.italic;
      }

      final font = sf.PdfStandardFont(
        sf.PdfFontFamily.helvetica,
        fontSize,
        style: style,
      );

      final brush = sf.PdfSolidBrush(
        sf.PdfColor(color.red, color.green, color.blue),
      );

      page.graphics.drawString(
        text,
        font,
        brush: brush,
        bounds: Rect.fromLTWH(position.dx, position.dy, 400, 50),
      );

      final out = document.saveSync();
      return Uint8List.fromList(out);
    } finally {
      document?.dispose();
    }
  }

  /// Adds an image annotation onto a PDF page.
  static Future<Uint8List> addCustomImage({
    required Uint8List pdfBytes,
    required int pageIndex,
    required Rect bounds,
    required Uint8List imageBytes,
  }) async {
    sf.PdfDocument? document;
    try {
      document = sf.PdfDocument(inputBytes: pdfBytes);
      if (pageIndex < 0 || pageIndex >= document.pages.count) {
        return pdfBytes;
      }

      final page = document.pages[pageIndex];
      final bitmap = sf.PdfBitmap(imageBytes);
      page.graphics.drawImage(bitmap, bounds);

      final out = document.saveSync();
      return Uint8List.fromList(out);
    } finally {
      document?.dispose();
    }
  }
}
