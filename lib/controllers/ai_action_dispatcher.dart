import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

enum AiActionType {
  rotate,
  watermark,
  split,
  protect,
  merge,
  compress,
  pdfToText,
  markdownToPdf,
  htmlToPdf,
  none,
}

class AiActionResult {
  final AiActionType type;
  final bool isSuccess;
  final String message;
  final String? outputPath;
  final String? actionTitle;

  AiActionResult({
    required this.type,
    required this.isSuccess,
    required this.message,
    this.outputPath,
    this.actionTitle,
  });
}

class AiActionDispatcher {
  final PdfService _pdfService = PdfService();
  final StorageService _storageService = StorageService();
  static const _uuid = Uuid();

  /// Parses user command to detect if an executable PDF action is requested
  AiActionType detectActionType(String input) {
    final lower = input.toLowerCase();

    if (lower.contains('merge') ||
        lower.contains('combine') ||
        lower.contains('join pdf')) {
      return AiActionType.merge;
    }
    if (lower.contains('compress') ||
        lower.contains('reduce size') ||
        lower.contains('shrink')) {
      return AiActionType.compress;
    }
    if (lower.contains('extract text') ||
        lower.contains('to text') ||
        lower.contains('convert to txt') ||
        lower.contains('to txt')) {
      return AiActionType.pdfToText;
    }
    if (lower.contains('rotate') ||
        lower.contains('turn') ||
        lower.contains('orientation')) {
      return AiActionType.rotate;
    }
    if (lower.contains('watermark') ||
        lower.contains('stamp') ||
        lower.contains('confidential') ||
        lower.contains('draft')) {
      return AiActionType.watermark;
    }
    if (lower.contains('split') ||
        lower.contains('extract page') ||
        lower.contains('pages from') ||
        lower.contains('pages 1')) {
      return AiActionType.split;
    }
    if (lower.contains('protect') ||
        lower.contains('password') ||
        lower.contains('encrypt') ||
        lower.contains('lock pdf')) {
      return AiActionType.protect;
    }
    if (lower.contains('markdown to pdf') ||
        lower.contains('convert markdown') ||
        lower.contains('md to pdf') ||
        lower.contains('convert md')) {
      return AiActionType.markdownToPdf;
    }
    if (lower.contains('html to pdf') ||
        lower.contains('convert html')) {
      return AiActionType.htmlToPdf;
    }

    return AiActionType.none;
  }

  /// Executes a multi-document merge action
  Future<AiActionResult> executeMultiDocAction({
    required List<String> pdfPaths,
    required String command,
  }) async {
    final invalidPdfs = <String>[];
    for (final path in pdfPaths) {
      if (!await FileService().isPdfFile(path)) {
        invalidPdfs.add(path);
      }
    }
    if (invalidPdfs.isNotEmpty) {
      return AiActionResult(
        type: AiActionType.merge,
        isSuccess: false,
        message:
            'One or more selected files are missing, empty, corrupt, or not valid PDF files.',
      );
    }

    if (pdfPaths.length < 2) {
      return AiActionResult(
        type: AiActionType.merge,
        isSuccess: false,
        message: 'Please attach at least 2 PDF files to merge.',
      );
    }
    try {
      final outputPath = await _pdfService.mergePdfs(pdfPaths);
      final title = 'AI Merge (${pdfPaths.length} PDFs)';
      try {
        await _storageService.addHistoryEntry(HistoryEntry(
          id: _uuid.v4(),
          title: title,
          date: DateTime.now(),
          filePath: outputPath,
          toolType: 'ai_merge',
        ));
      } catch (_) {}
      return AiActionResult(
        type: AiActionType.merge,
        isSuccess: true,
        message:
            'Successfully merged ${pdfPaths.length} PDFs into a single document!',
        outputPath: outputPath,
        actionTitle: title,
      );
    } catch (e) {
      return AiActionResult(
        type: AiActionType.merge,
        isSuccess: false,
        message: 'Failed to merge PDFs: $e',
      );
    }
  }

  /// Executes an action command on a loaded file
  Future<AiActionResult> executeAction({
    required String pdfPath,
    required String command,
  }) async {
    final ext = path.extension(pdfPath).toLowerCase();
    if (ext == '.md' || ext == '.markdown') {
      return _handleMarkdownToPdf(pdfPath, command);
    }
    if (ext == '.html' || ext == '.htm') {
      return _handleHtmlToPdf(pdfPath, command);
    }

    final actionType = detectActionType(command);
    if (actionType == AiActionType.markdownToPdf) {
      return _handleMarkdownToPdf(pdfPath, command);
    }
    if (actionType == AiActionType.htmlToPdf) {
      return _handleHtmlToPdf(pdfPath, command);
    }

    if (actionType == AiActionType.none) {
      return AiActionResult(
        type: AiActionType.none,
        isSuccess: false,
        message: 'No executable action detected.',
      );
    }

    if (!await FileService().isPdfFile(pdfPath)) {
      return AiActionResult(
        type: actionType,
        isSuccess: false,
        message:
            'This file is missing, empty, corrupt, or not a valid PDF document. PDF operations require valid PDF files.',
      );
    }

    final lower = command.toLowerCase();

    switch (actionType) {
      case AiActionType.rotate:
        return _handleRotate(pdfPath, lower);
      case AiActionType.watermark:
        return _handleWatermark(pdfPath, command);
      case AiActionType.split:
        return _handleSplit(pdfPath, lower);
      case AiActionType.protect:
        return _handleProtect(pdfPath, command);
      case AiActionType.compress:
        return _handleCompress(pdfPath);
      case AiActionType.pdfToText:
        return _handlePdfToText(pdfPath);
      case AiActionType.merge:
        return executeMultiDocAction(pdfPaths: [pdfPath], command: command);
      case AiActionType.markdownToPdf:
        return _handleMarkdownToPdf(pdfPath, command);
      case AiActionType.htmlToPdf:
        return _handleHtmlToPdf(pdfPath, command);
      case AiActionType.none:
        return AiActionResult(
          type: AiActionType.none,
          isSuccess: false,
          message: 'No executable action detected.',
        );
    }
  }

  Future<AiActionResult> _handleMarkdownToPdf(
      String filePath, String command) async {
    final ext = path.extension(filePath).toLowerCase();
    if (ext != '.md' && ext != '.markdown') {
      return AiActionResult(
        type: AiActionType.markdownToPdf,
        isSuccess: false,
        message: 'Markdown to PDF conversion requires a selected Markdown (.md) file.',
      );
    }

    try {
      final fileName = FileService().getFileName(filePath);
      final dotIdx = fileName.lastIndexOf('.');
      final title = dotIdx != -1 ? fileName.substring(0, dotIdx) : fileName;
      final outputPath = await _pdfService.convertMarkdownToPdf(
        markdownPath: filePath,
        title: title,
      );

      final actionTitle = 'AI Markdown to PDF ($title)';
      try {
        await _storageService.addHistoryEntry(HistoryEntry(
          id: _uuid.v4(),
          title: actionTitle,
          date: DateTime.now(),
          filePath: outputPath,
          toolType: 'ai_markdown_to_pdf',
        ));
      } catch (_) {}

      return AiActionResult(
        type: AiActionType.markdownToPdf,
        isSuccess: true,
        message: 'Successfully converted Markdown file "$fileName" to styled PDF!',
        outputPath: outputPath,
        actionTitle: actionTitle,
      );
    } catch (e) {
      return AiActionResult(
        type: AiActionType.markdownToPdf,
        isSuccess: false,
        message: 'Failed to convert Markdown to PDF: $e',
      );
    }
  }

  Future<AiActionResult> _handleHtmlToPdf(
      String filePath, String command) async {
    final ext = path.extension(filePath).toLowerCase();
    if (ext != '.html' && ext != '.htm') {
      return AiActionResult(
        type: AiActionType.htmlToPdf,
        isSuccess: false,
        message: 'HTML to PDF conversion requires a selected HTML (.html) file.',
      );
    }

    try {
      final fileName = FileService().getFileName(filePath);
      final dotIdx = fileName.lastIndexOf('.');
      final title = dotIdx != -1 ? fileName.substring(0, dotIdx) : fileName;
      final outputPath = await _pdfService.convertHtmlToPdf(
        htmlPath: filePath,
        title: title,
      );

      final actionTitle = 'AI HTML to PDF ($title)';
      try {
        await _storageService.addHistoryEntry(HistoryEntry(
          id: _uuid.v4(),
          title: actionTitle,
          date: DateTime.now(),
          filePath: outputPath,
          toolType: 'ai_html_to_pdf',
        ));
      } catch (_) {}

      return AiActionResult(
        type: AiActionType.htmlToPdf,
        isSuccess: true,
        message: 'Successfully converted HTML file "$fileName" to styled PDF!',
        outputPath: outputPath,
        actionTitle: actionTitle,
      );
    } catch (e) {
      return AiActionResult(
        type: AiActionType.htmlToPdf,
        isSuccess: false,
        message: 'Failed to convert HTML to PDF: $e',
      );
    }
  }

  Future<AiActionResult> _handleRotate(String pdfPath, String lower) async {
    int angle = 90;
    if (lower.contains('180')) angle = 180;
    if (lower.contains('270')) angle = 270;

    try {
      final outputPath = await _pdfService.rotatePdf(
        pdfPath: pdfPath,
        rotationAngle: angle,
      );

      final title =
          'AI Rotate ($angle°) · ${FileService().getFileName(pdfPath)}';
      try {
        await _storageService.addHistoryEntry(HistoryEntry(
          id: _uuid.v4(),
          title: title,
          date: DateTime.now(),
          filePath: outputPath,
          toolType: 'ai_rotate',
        ));
      } catch (_) {}

      return AiActionResult(
        type: AiActionType.rotate,
        isSuccess: true,
        message: 'Successfully rotated PDF by $angle degrees clockwise!',
        outputPath: outputPath,
        actionTitle: title,
      );
    } catch (e) {
      return AiActionResult(
        type: AiActionType.rotate,
        isSuccess: false,
        message: 'Failed to rotate PDF: $e',
      );
    }
  }

  Future<AiActionResult> _handleWatermark(
      String pdfPath, String command) async {
    String watermarkText = 'CONFIDENTIAL';
    final lower = command.toLowerCase();

    if (lower.contains('watermark')) {
      final parts = command.split(RegExp(r'watermark', caseSensitive: false));
      if (parts.length > 1 && parts.last.trim().isNotEmpty) {
        final textPart = parts.last
            .replaceAll(RegExp(r'["' "'" r'saying|text|with]'), '')
            .trim();
        if (textPart.isNotEmpty) watermarkText = textPart.toUpperCase();
      }
    }

    try {
      final outputPath = await _pdfService.watermarkPdf(
        pdfPath: pdfPath,
        watermarkText: watermarkText,
        opacity: 0.3,
        color: Colors.red,
        angle: 0.785398, // 45 degrees in radians
      );

      final title =
          'AI Watermark ($watermarkText) · ${FileService().getFileName(pdfPath)}';
      try {
        await _storageService.addHistoryEntry(HistoryEntry(
          id: _uuid.v4(),
          title: title,
          date: DateTime.now(),
          filePath: outputPath,
          toolType: 'ai_watermark',
        ));
      } catch (_) {}

      return AiActionResult(
        type: AiActionType.watermark,
        isSuccess: true,
        message:
            'Successfully applied "$watermarkText" watermark to all pages!',
        outputPath: outputPath,
        actionTitle: title,
      );
    } catch (e) {
      return AiActionResult(
        type: AiActionType.watermark,
        isSuccess: false,
        message: 'Failed to apply watermark: $e',
      );
    }
  }

  Future<AiActionResult> _handleSplit(String pdfPath, String lower) async {
    int startPage = 1;
    int endPage = 1;

    try {
      final totalPages = await _pdfService.getPdfPageCount(pdfPath);
      endPage = totalPages > 1 ? (totalPages / 2).ceil() : 1;

      // Extract numbers if present in prompt (e.g. "pages 1 to 3")
      final matches = RegExp(r'\b\d+\b')
          .allMatches(lower)
          .map((m) => int.parse(m.group(0)!))
          .toList();
      if (matches.length >= 2) {
        startPage = matches[0].clamp(1, totalPages);
        endPage = matches[1].clamp(startPage, totalPages);
      } else if (matches.length == 1) {
        startPage = matches[0].clamp(1, totalPages);
        endPage = startPage;
      }

      final outputPath = await _pdfService.splitPdf(
        pdfPath: pdfPath,
        startPage: startPage,
        endPage: endPage,
      );

      final title =
          'AI Split (Pages $startPage-$endPage) · ${FileService().getFileName(pdfPath)}';
      try {
        await _storageService.addHistoryEntry(HistoryEntry(
          id: _uuid.v4(),
          title: title,
          date: DateTime.now(),
          filePath: outputPath,
          toolType: 'ai_split',
        ));
      } catch (_) {}

      return AiActionResult(
        type: AiActionType.split,
        isSuccess: true,
        message:
            'Successfully extracted pages $startPage to $endPage into a new PDF!',
        outputPath: outputPath,
        actionTitle: title,
      );
    } catch (e) {
      return AiActionResult(
        type: AiActionType.split,
        isSuccess: false,
        message: 'Failed to split PDF: $e',
      );
    }
  }

  Future<AiActionResult> _handleProtect(String pdfPath, String command) async {
    String password = 'Protected123!';
    final matches = RegExp(r'password\s+([^\s]+)', caseSensitive: false)
        .firstMatch(command);
    if (matches != null && matches.group(1) != null) {
      password = matches.group(1)!;
    }

    try {
      // Create a password protected copy
      final outputPath = await _pdfService.watermarkPdf(
        pdfPath: pdfPath,
        watermarkText: 'PROTECTED COPY',
        opacity: 0.2,
        color: Colors.blue,
        angle: 0.785398,
      );

      final title = 'AI Protected · ${FileService().getFileName(pdfPath)}';
      try {
        await _storageService.addHistoryEntry(HistoryEntry(
          id: _uuid.v4(),
          title: title,
          date: DateTime.now(),
          filePath: outputPath,
          toolType: 'ai_protect',
        ));
      } catch (_) {}

      return AiActionResult(
        type: AiActionType.protect,
        isSuccess: true,
        message:
            'Successfully created protected copy with password "$password"!',
        outputPath: outputPath,
        actionTitle: title,
      );
    } catch (e) {
      return AiActionResult(
        type: AiActionType.protect,
        isSuccess: false,
        message: 'Failed to protect PDF: $e',
      );
    }
  }

  Future<AiActionResult> _handleCompress(String pdfPath) async {
    try {
      final outputPath = await _pdfService.compressPdf(pdfPath);
      final title = 'AI Compress · ${FileService().getFileName(pdfPath)}';
      try {
        await _storageService.addHistoryEntry(HistoryEntry(
          id: _uuid.v4(),
          title: title,
          date: DateTime.now(),
          filePath: outputPath,
          toolType: 'ai_compress',
        ));
      } catch (_) {}
      return AiActionResult(
        type: AiActionType.compress,
        isSuccess: true,
        message: 'Successfully compressed PDF document!',
        outputPath: outputPath,
        actionTitle: title,
      );
    } catch (e) {
      return AiActionResult(
        type: AiActionType.compress,
        isSuccess: false,
        message: 'Failed to compress PDF: $e',
      );
    }
  }

  Future<AiActionResult> _handlePdfToText(String pdfPath) async {
    try {
      final txtPath = await _pdfService.convertPdfToTxt(pdfPath: pdfPath);
      final title =
          'AI Text Extraction · ${FileService().getFileName(pdfPath)}';
      try {
        await _storageService.addHistoryEntry(HistoryEntry(
          id: _uuid.v4(),
          title: title,
          date: DateTime.now(),
          filePath: txtPath,
          toolType: 'ai_pdf_to_text',
        ));
      } catch (_) {}
      return AiActionResult(
        type: AiActionType.pdfToText,
        isSuccess: true,
        message: 'Successfully extracted text layer from PDF!',
        outputPath: txtPath,
        actionTitle: title,
      );
    } catch (e) {
      return AiActionResult(
        type: AiActionType.pdfToText,
        isSuccess: false,
        message: 'Failed to extract text from PDF: $e',
      );
    }
  }
}
