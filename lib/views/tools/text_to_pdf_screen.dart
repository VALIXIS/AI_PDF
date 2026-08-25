import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';
import 'package:uuid/uuid.dart';

class TextToPdfScreen extends StatefulWidget {
  const TextToPdfScreen({Key? key}) : super(key: key);

  @override
  State<TextToPdfScreen> createState() => _TextToPdfScreenState();
}

class _TextToPdfScreenState extends State<TextToPdfScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final PdfService _pdfService = PdfService();
  final StorageService _storageService = StorageService();
  final FileService _fileService = FileService();

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

      final supportedTextExts = ['.txt', '.text', '.md', '.markdown', '.csv', '.log', '.json', '.xml', ''];
      final fileType = await _fileService.detectFileType(path);

      if (!supportedTextExts.contains(ext) && fileType != DetectedFileType.text) {
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
        if (_titleController.text.trim().isEmpty || _titleController.text == 'Document') {
          final dotIdx = fileName.lastIndexOf('.');
          _titleController.text = dotIdx != -1 ? fileName.substring(0, dotIdx) : fileName;
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
        _errorMessage = 'Please enter both a title and content to generate a PDF.';
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

      if (mounted) {
        ShareService.showSaveShareDialog(context, filePath);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('PdfServiceException: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Text to PDF'),
        actions: [
          if (!_isLoading)
            TextButton.icon(
              onPressed: _pickTextFile,
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Import File'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create PDF from Text',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter text or import a plain text file (.txt, .md) to generate a formatted PDF',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),

              // Loading Banner
              if (_isLoading)
                const ToolLoadingBanner(
                  message: 'Generating PDF document from text...',
                ),

              // Error Banner
              if (_errorMessage != null)
                ToolErrorBanner(
                  message: _errorMessage!,
                  onRetry: (_titleController.text.isNotEmpty && _textController.text.isNotEmpty)
                      ? _generatePdf
                      : null,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),

              // Success Card
              if (_successPath != null)
                ToolSuccessCard(
                  title: 'PDF Generated Successfully!',
                  subtitle: 'Formatted PDF document created.',
                  filePath: _successPath,
                  onShare: () {
                    if (_successPath != null && mounted) {
                      ShareService.showSaveShareDialog(context, _successPath!);
                    }
                  },
                  onReset: () {
                    setState(() {
                      _successPath = null;
                      _importedFileName = null;
                      _titleController.clear();
                      _textController.clear();
                      _errorMessage = null;
                    });
                  },
                ),

              // Imported File Indicator
              if (_importedFileName != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file_rounded, size: 18, color: primary),
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
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (!_isLoading)
                    TextButton.icon(
                      onPressed: _pickTextFile,
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: const Text('Load from .txt/.md', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                enabled: !_isLoading,
                controller: _textController,
                maxLines: 10,
                minLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Enter text to convert to PDF or import a text file...',
                ),
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
              ),
              const SizedBox(height: 8),

              Text(
                'Tip: Use # for headers, • for bullet points',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 24),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _generatePdf,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: const Text('Generate PDF'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
