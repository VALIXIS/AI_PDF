import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pdf_ai_toolkit/widgets/tool_screen_shell.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';

class MarkdownToPdfScreen extends StatefulWidget {
  const MarkdownToPdfScreen({Key? key}) : super(key: key);

  @override
  State<MarkdownToPdfScreen> createState() => _MarkdownToPdfScreenState();
}

class _MarkdownToPdfScreenState extends State<MarkdownToPdfScreen> {
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

  Future<void> _pickMarkdown() async {
    if (_isLoading) return;
    setState(() {
      _errorMessage = null;
      _successPath = null;
    });

    try {
      final path = await _fileService.pickMarkdownFile();
      if (!mounted) return;
      if (path != null) {
        final ext = _fileService.getExtension(path).toLowerCase();
        if (ext == '.doc' || ext == '.docx') {
          setState(() {
            _selectedFile = null;
            _errorMessage =
                'Word documents ($ext) are not supported. Only Markdown (.md, .markdown) files can be converted to PDF. Please select a valid Markdown file.';
          });
          return;
        }

        final file = File(path);
        if (!await file.exists() || await file.length() == 0) {
          setState(() {
            _selectedFile = null;
            _errorMessage =
                'Selected Markdown file is empty or missing: ${_fileService.getFileName(path)}';
          });
          return;
        }

        final fileType = await _fileService.detectFileType(path);
        if (ext != '.md' &&
            ext != '.markdown' &&
            ext != '.txt' &&
            fileType != DetectedFileType.text) {
          setState(() {
            _selectedFile = null;
            _errorMessage =
                'Unsupported file format: "$ext". Markdown to PDF only supports Markdown (.md, .markdown) files. Please select a valid Markdown file.';
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
        _errorMessage = 'Please select a Markdown file first.';
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
      final outPath = await _pdfService.convertMarkdownToPdf(
        markdownPath: _selectedFile!,
        title: title,
      );

      await _storageService.addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Markdown to PDF ($title)',
        date: DateTime.now(),
        filePath: outPath,
        toolType: 'markdown_to_pdf',
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

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ToolScreenShell(
      title: 'Markdown to PDF',
      explanation:
          'Convert standard Markdown files (.md or .markdown) to styled PDF documents with proper layout and formatting.',
      onPickFiles: _pickMarkdown,
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
      loadingMessage: 'Converting Markdown document to styled PDF...',
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
                      child: MarkdownBody(
                        data: _filePreviewContent!,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet.fromTheme(
                                Theme.of(context))
                            .copyWith(
                          codeblockDecoration: BoxDecoration(
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1),
                              width: 0.8,
                            ),
                          ),
                          codeblockPadding: const EdgeInsets.all(10),
                          code: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF1E293B),
                          ),
                          tableBorder: TableBorder.all(
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? const Color(0xFF475569)
                                : const Color(0xFFCBD5E1),
                            width: 0.8,
                          ),
                          tableCellsPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          tableHead: const TextStyle(
                              fontWeight: FontWeight.bold),
                          tableHeadAlign: TextAlign.left,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
