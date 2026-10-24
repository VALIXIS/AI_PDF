import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/widgets/tool_screen_shell.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';

class HtmlToPdfScreen extends StatefulWidget {
  const HtmlToPdfScreen({Key? key}) : super(key: key);

  @override
  State<HtmlToPdfScreen> createState() => _HtmlToPdfScreenState();
}

class _HtmlToPdfScreenState extends State<HtmlToPdfScreen> {
  final FileService _fileService = FileService();
  final PdfService _pdfService = PdfService();
  final StorageService _storageService = StorageService();

  String? _selectedFile;
  String? _filePreviewContent;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successPath;
  final TextEditingController _titleController =
      TextEditingController(text: 'Converted Document');

  Future<void> _pickHtml() async {
    if (_isLoading) return;
    setState(() {
      _errorMessage = null;
      _successPath = null;
    });

    try {
      final path = await _fileService.pickHtmlFile();
      if (!mounted) return;
      if (path != null) {
        final ext = _fileService.getExtension(path).toLowerCase();
        if (ext == '.doc' || ext == '.docx') {
          setState(() {
            _selectedFile = null;
            _errorMessage =
                'Word documents ($ext) are not supported. Only HTML (.html, .htm) files can be converted to PDF. Please select a valid HTML file.';
          });
          return;
        }

        final file = File(path);
        if (!await file.exists() || await file.length() == 0) {
          setState(() {
            _selectedFile = null;
            _errorMessage =
                'Selected HTML file is empty or missing: ${_fileService.getFileName(path)}';
          });
          return;
        }

        final fileType = await _fileService.detectFileType(path);
        if (ext != '.html' &&
            ext != '.htm' &&
            ext != '.txt' &&
            fileType != DetectedFileType.text) {
          setState(() {
            _selectedFile = null;
            _errorMessage =
                'Unsupported file format: "$ext". HTML to PDF only supports HTML (.html, .htm) files. Please select a valid HTML file.';
          });
          return;
        }

        String? preview;
        try {
          final str = await file.readAsString();
          preview = str.length > 4000 ? str.substring(0, 4000) : str;
        } catch (_) {}

        setState(() {
          _selectedFile = path;
          _filePreviewContent = preview;
          final filename = _fileService.getFileName(path);
          final dotIdx = filename.lastIndexOf('.');
          if (dotIdx != -1) {
            _titleController.text = filename.substring(0, dotIdx);
          } else {
            _titleController.text = filename;
          }
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to pick file: $e';
      });
    }
  }

  Future<void> _convert() async {
    if (_selectedFile == null) {
      setState(() {
        _errorMessage = 'Please select an HTML file first.';
      });
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a document title.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successPath = null;
    });

    try {
      final outPath = await _pdfService.convertHtmlToPdf(
        htmlPath: _selectedFile!,
        title: title,
      );

      await _storageService.addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'HTML to PDF ($title)',
        date: DateTime.now(),
        filePath: outPath,
        toolType: 'html_to_pdf',
      ));

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successPath = outPath;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('PdfServiceException: ', '');
        _isLoading = false;
      });
    }
  }

  Widget _buildHtmlPreview(String html) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final codeBg =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    var cleaned = html.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    cleaned = cleaned.replaceAll(
        RegExp(r'<style[^>]*>.*?<\/style>', caseSensitive: false, dotAll: true),
        '');
    cleaned = cleaned.replaceAll(
        RegExp(r'<script[^>]*>.*?<\/script>',
            caseSensitive: false, dotAll: true),
        '');
    cleaned = cleaned.replaceAll(
        RegExp(r'<head[^>]*>.*?<\/head>', caseSensitive: false, dotAll: true),
        '');
    cleaned = cleaned.replaceAll(
        RegExp(r'<\/?(html|body|doctype)[^>]*>', caseSensitive: false), '');

    final blockReg = RegExp(
      r'<(h1|h2|h3|h4|h5|h6|p|pre|table|ul|ol|hr)([^>]*)>(.*?)<\/\1>',
      caseSensitive: false,
      dotAll: true,
    );
    final matches = blockReg.allMatches(cleaned);
    if (matches.isEmpty) {
      return Text(
        cleaned.replaceAll(RegExp(r'<[^>]+>'), '').trim(),
        style: const TextStyle(fontSize: 12),
      );
    }

    final widgets = <Widget>[];
    for (final match in matches.take(25)) {
      final tag = match.group(1)!.toLowerCase();
      final content = match.group(3)!;

      if (tag == 'pre') {
        var code = content;
        final codeMatch = RegExp(r'<code[^>]*>(.*?)<\/code>',
                caseSensitive: false, dotAll: true)
            .firstMatch(code);
        if (codeMatch != null) code = codeMatch.group(1)!;

        widgets.add(Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: codeBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          padding: const EdgeInsets.all(10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              code.trim(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
              ),
            ),
          ),
        ));
      } else if (tag == 'table') {
        final trReg =
            RegExp(r'<tr[^>]*>(.*?)<\/tr>', caseSensitive: false, dotAll: true);
        final trMatches = trReg.allMatches(content);
        final rows = <TableRow>[];

        for (final trMatch in trMatches) {
          final cellReg = RegExp(r'<(th|td)[^>]*>(.*?)<\/\1>',
              caseSensitive: false, dotAll: true);
          final cellMatches = cellReg.allMatches(trMatch.group(1)!);
          final cells = <Widget>[];
          bool isHeader = false;

          for (final cm in cellMatches) {
            final isTh = cm.group(1)!.toLowerCase() == 'th';
            if (isTh) isHeader = true;
            final cellText =
                cm.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
            cells.add(Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                cellText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isTh ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ));
          }

          if (cells.isNotEmpty) {
            rows.add(TableRow(
              decoration: isHeader
                  ? BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0))
                  : null,
              children: cells,
            ));
          }
        }

        if (rows.isNotEmpty) {
          widgets.add(Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Table(
              border: TableBorder.all(color: borderColor, width: 0.8),
              children: rows,
            ),
          ));
        }
      } else if (tag.startsWith('h')) {
        final double fontSize = tag == 'h1' ? 16 : (tag == 'h2' ? 14 : 12);
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            content.replaceAll(RegExp(r'<[^>]+>'), '').trim(),
            style:
                TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
          ),
        ));
      } else if (tag == 'p') {
        final text = content.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        if (text.isNotEmpty) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(text, style: const TextStyle(fontSize: 12)),
          ));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ToolScreenShell(
      title: 'HTML to PDF',
      explanation:
          'Convert standard HTML files (.html or .htm) to styled PDF documents with proper layout and formatting.',
      onPickFiles: _pickHtml,
      selectedFiles: _selectedFile != null ? [_selectedFile!] : [],
      onRemoveFile: (_) {
        setState(() {
          _selectedFile = null;
          _filePreviewContent = null;
          _errorMessage = null;
        });
      },
      onExecute: _selectedFile != null ? _convert : null,
      executeButtonLabel: 'Convert to PDF',
      isLoading: _isLoading,
      loadingMessage: 'Converting HTML document to styled PDF...',
      errorMessage: _errorMessage,
      onDismissError: () => setState(() => _errorMessage = null),
      successPath: _successPath,
      successSubtitle: 'Styled PDF successfully created.',
      onReset: () {
        setState(() {
          _successPath = null;
          _selectedFile = null;
          _filePreviewContent = null;
          _errorMessage = null;
          _titleController.text = 'Converted Document';
        });
      },
      extraConfig: _selectedFile == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Document Title',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 10),
                TextField(
                  enabled: !_isLoading,
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'Enter PDF header title...',
                    isDense: true,
                  ),
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                ),
                if (_filePreviewContent != null &&
                    _filePreviewContent!.trim().isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(Icons.visibility_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      const Text(
                        'Document Content Preview',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                        width: 0.8,
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: _buildHtmlPreview(_filePreviewContent!),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
