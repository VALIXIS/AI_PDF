import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/widgets/tool_screen_shell.dart';
import 'package:uuid/uuid.dart';

class TextToPdfScreen extends StatefulWidget {
  final String? initialContent;

  const TextToPdfScreen({Key? key, this.initialContent}) : super(key: key);

  @override
  State<TextToPdfScreen> createState() => _TextToPdfScreenState();
}

class _TextToPdfScreenState extends State<TextToPdfScreen> {
  late final TextEditingController _textController;
  late final TextEditingController _titleController;
  final PdfService _pdfService = PdfService();
  final StorageService _storageService = StorageService();
  final FileService _fileService = FileService();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialContent ?? '');
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  String? _importedFileName;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successPath;

  Future<void> _pickTextFile() async {
    if (_isLoading) return;
    setState(() {
      _errorMessage = null;
      _successPath = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (!mounted || result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) return;

      final ext = _fileService.getExtension(path).toLowerCase();
      final fileName = _fileService.getFileName(path);

      // Check if format is unsupported (e.g. .doc, .docx, .pdf, binary)
      if (ext == '.doc' || ext == '.docx') {
        setState(() {
          _errorMessage =
              'Word documents ($ext) are not supported. Only plain text (.txt) and Markdown (.md) files can be converted to PDF. Please select a text file or paste your text below.';
        });
        return;
      }

      if (ext == '.pdf') {
        setState(() {
          _errorMessage =
              'Selected file is already a PDF document. To extract text from a PDF, please use the "PDF to Text" tool.';
        });
        return;
      }

      final supportedTextExts = [
        '.txt',
        '.text',
        '.md',
        '.markdown',
        '.csv',
        '.log',
        '.json',
        '.xml',
        ''
      ];
      final fileType = await _fileService.detectFileType(path);

      if (!supportedTextExts.contains(ext) &&
          fileType != DetectedFileType.text) {
        setState(() {
          _errorMessage =
              'Unsupported file format: "$ext". Only plain text (.txt, .md, .csv, .log) files are supported. Please select a valid text file.';
        });
        return;
      }

      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        setState(() {
          _errorMessage = 'Selected file is empty or missing: $fileName';
        });
        return;
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Selected text file is empty: $fileName';
        });
        return;
      }

      setState(() {
        _importedFileName = fileName;
        _textController.text = content;
        if (_titleController.text.trim().isEmpty ||
            _titleController.text == 'Document') {
          final dotIdx = fileName.lastIndexOf('.');
          _titleController.text =
              dotIdx != -1 ? fileName.substring(0, dotIdx) : fileName;
        }
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to import file: $e';
      });
    }
  }

  Future<void> _generatePdf() async {
    final title = _titleController.text.trim();
    final content = _textController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      setState(() {
        _errorMessage =
            'Please enter both a title and content to generate a PDF.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successPath = null;
    });

    try {
      final filePath = await _pdfService.generatePdfFromText(
        title: title,
        content: content,
      );

      final entry = HistoryEntry(
        id: const Uuid().v4(),
        title: title,
        date: DateTime.now(),
        filePath: filePath,
        toolType: 'text_to_pdf',
      );
      await _storageService.addHistoryEntry(entry);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successPath = filePath;
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return ToolScreenShell(
      title: 'Text to PDF',
      explanation: 'Create PDF from Text',
      actions: [
        if (!_isLoading)
          TextButton.icon(
            onPressed: _pickTextFile,
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: const Text('Import File'),
          ),
      ],
      onPickFiles: _pickTextFile,
      selectedFiles: const [],
      onExecute: _generatePdf,
      executeButtonLabel: 'Generate PDF',
      executeButtonIcon: Icons.picture_as_pdf_rounded,
      alwaysShowExecuteButton: true,
      showPickButton: false,
      isLoading: _isLoading,
      loadingMessage: 'Generating PDF document from text...',
      errorMessage: _errorMessage,
      onDismissError: () => setState(() => _errorMessage = null),
      onRetry: (_titleController.text.isNotEmpty &&
              _textController.text.isNotEmpty)
          ? _generatePdf
          : null,
      successPath: _successPath,
      successTitle: 'PDF Generated Successfully!',
      successSubtitle: 'Formatted PDF document created.',
      defaultSavePrefix: 'TextToPDF',
      onReset: () {
        setState(() {
          _successPath = null;
          _importedFileName = null;
          _titleController.clear();
          _textController.clear();
          _errorMessage = null;
        });
      },
      scrollable: true,
      customContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imported File Indicator
          if (_importedFileName != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file_rounded,
                      size: 18, color: primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Imported: $_importedFileName',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!_isLoading)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      tooltip: 'Clear imported file',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _importedFileName = null;
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Title Field
          Text(
            'PDF Title',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            enabled: !_isLoading,
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: 'Enter PDF document title...',
              isDense: true,
            ),
            onChanged: (_) {
              if (_errorMessage != null) {
                setState(() => _errorMessage = null);
              }
            },
          ),
          const SizedBox(height: 20),

          // Content Field
          Row(
            children: [
              Text(
                'Content',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (!_isLoading)
                TextButton.icon(
                  onPressed: _pickTextFile,
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: const Text('Load from .txt/.md',
                      style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            enabled: !_isLoading,
            controller: _textController,
            maxLines: 12,
            minLines: 6,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: 'Type, paste, or import content here...',
              alignLabelWithHint: true,
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
