import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/core/errors/app_exceptions.dart';

class PdfToTextScreen extends StatefulWidget {
  const PdfToTextScreen({Key? key}) : super(key: key);

  @override
  State<PdfToTextScreen> createState() => _PdfToTextScreenState();
}

class _PdfToTextScreenState extends State<PdfToTextScreen> {
  final FileService _fileService = FileService();
  final PdfService _pdfService = PdfService();
  final StorageService _storageService = StorageService();

  String? _selectedFile;
  String? _extractedText;
  bool _isLoading = false;
  String? _errorMessage;
  String? _txtPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF to Text'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Extract Text from PDF',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a PDF document (.pdf) to extract its text content',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            // Loading Banner
            if (_isLoading)
              const ToolLoadingBanner(
                message: 'Extracting text content from PDF...',
              ),

            // Error Banner
            if (_errorMessage != null)
              ToolErrorBanner(
                message: _errorMessage!,
                onRetry: _selectedFile != null ? _extractText : null,
                onDismiss: () => setState(() => _errorMessage = null),
              ),

            // Selected file card or Empty State
            if (_selectedFile != null) ...[
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.picture_as_pdf,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fileService.getFileName(_selectedFile!),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ready for extraction',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (!_isLoading)
                        IconButton(
                          icon: const Icon(Icons.swap_horiz_rounded),
                          tooltip: 'Change PDF',
                          onPressed: _pickPdf,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else if (_extractedText == null) ...[
              Expanded(
                child: ToolEmptyState(
                  icon: Icons.text_snippet_rounded,
                  title: 'No PDF Selected',
                  subtitle:
                      'Select a PDF document (.pdf) from your device to extract text content',
                  actionLabel: 'Select PDF',
                  onAction: _isLoading ? null : _pickPdf,
                ),
              ),
            ],

            // Extracted Text Result Card
            if (_extractedText != null) ...[
              if (_txtPath != null) ...[
                ToolSuccessCard(
                  title: 'Text Extracted Successfully!',
                  subtitle: 'Extracted text saved to file.',
                  filePath: _txtPath,
                  onShare: _shareTxtFile,
                  onReset: () {
                    setState(() {
                      _extractedText = null;
                      _selectedFile = null;
                      _txtPath = null;
                      _errorMessage = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Text(
                    'Extracted Text Content',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: 'Copy text',
                    onPressed: _copyToClipboard,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1F1F2E)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _extractedText!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveTxtFile,
                      icon: const Icon(Icons.save_alt_rounded, size: 16),
                      label: const Text('Save TXT'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shareTxtFile,
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ] else if (_selectedFile != null)
              const Spacer(),

            const SizedBox(height: 16),

            // Action Buttons
            if (_extractedText == null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _pickPdf,
                      icon: const Icon(Icons.folder_open),
                      label: Text(
                          _selectedFile == null ? 'Select PDF' : 'Change PDF'),
                    ),
                  ),
                  if (_selectedFile != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _extractText,
                        icon: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.text_fields),
                        label: const Text('Extract Text'),
                      ),
                    ),
                  ],
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _extractedText = null;
                  _selectedFile = null;
                  _errorMessage = null;
                  _txtPath = null;
                }),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Start New Extraction'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPdf() async {
    if (_isLoading) return;
    try {
      final file = await _fileService.pickPdfFile();
      if (!mounted) return;
      if (file != null) {
        final ext = _fileService.getExtension(file).toLowerCase();

        // Check for unsupported formats
        if (ext == '.doc' || ext == '.docx') {
          setState(() {
            _selectedFile = null;
            _errorMessage =
                'Word documents ($ext) are not supported for text extraction. Please select a valid PDF (.pdf) file.';
          });
          return;
        }

        if (!await _fileService.isPdfFile(file)) {
          setState(() {
            _selectedFile = null;
            _errorMessage =
                'Selected file is not a valid PDF document. Please select a valid .pdf file.';
          });
          return;
        }

        setState(() {
          _selectedFile = file;
          _extractedText = null;
          _txtPath = null;
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

  Future<void> _extractText() async {
    if (_selectedFile == null) {
      setState(() {
        _errorMessage = 'Please select a PDF file first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_selectedFile == null ||
          !await _fileService.isFileAccessible(_selectedFile!)) {
        setState(() {
          _errorMessage = 'Selected file no longer exists or is inaccessible.';
          _isLoading = false;
        });
        return;
      }

      if (!await _fileService.isPdfFile(_selectedFile!)) {
        setState(() {
          _errorMessage =
              'Selected file is not a valid PDF document. Please select a valid .pdf file.';
          _isLoading = false;
        });
        return;
      }

      // Perform real PDF -> TXT conversion
      final txtPath = await _pdfService.convertPdfToTxt(
        pdfPath: _selectedFile!,
      );

      // Validate output TXT exists and is readable
      final txtFile = File(txtPath);
      if (!await txtFile.exists()) {
        throw PdfServiceException('Generated TXT file does not exist',
            code: 'PDF_TO_TXT_OUTPUT_NOT_FOUND');
      }

      final text = await txtFile.readAsString(encoding: utf8);
      if (text.trim().isEmpty) {
        throw PdfServiceException(
            'No extractable text found in this PDF. Scanned or image-only PDFs do not have a raw text layer.',
            code: 'PDF_TO_TXT_NO_TEXT');
      }

      // Add to History
      await _storageService.addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Extracted Text: ${_fileService.getFileName(_selectedFile!)}',
        date: DateTime.now(),
        filePath: txtPath,
        toolType: 'pdf_to_text',
      ));

      if (!mounted) return;

      setState(() {
        _extractedText = text;
        _txtPath = txtPath;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      String friendlyError = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('PdfServiceException: ', '');
      if (e is PdfServiceException && e.code == 'PDF_TO_TXT_NO_TEXT') {
        friendlyError =
            'No extractable text found in this PDF. Scanned or image-only PDFs do not contain selectable text.';
      }
      setState(() {
        _errorMessage = friendlyError;
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard() {
    if (_extractedText != null && _extractedText!.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _extractedText!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _saveTxtFile() async {
    if (_txtPath != null && mounted) {
      ShareService.saveFileToUserDestination(context, sourcePath: _txtPath!);
    }
  }

  void _shareTxtFile() async {
    if (_txtPath != null && mounted) {
      ShareService.shareFile(context, filePath: _txtPath!, text: 'Here is the extracted text file.');
    }
  }
}
