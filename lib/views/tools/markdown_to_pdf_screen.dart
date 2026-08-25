import 'dart:io';
import 'package:flutter/material.dart';
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

        setState(() {
          _selectedFile = path;
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
              ],
            ),
    );
  }
}
