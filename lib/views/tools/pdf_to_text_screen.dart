import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/core/errors/app_exceptions.dart';
import 'package:pdf_ai_toolkit/widgets/tool_screen_shell.dart';

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
      if (!await _fileService.isFileAccessible(_selectedFile!)) {
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

      final bytes = await txtFile.readAsBytes();
      final text = utf8.decode(bytes, allowMalformed: true);
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
      ShareService.promptAndSaveFileDirectToDownloads(
        context,
        sourcePath: _txtPath!,
        defaultPrefix: 'ExtractedText',
        dialogTitle: 'Save Extracted Text',
      );
    }
  }

  void _shareTxtFile() async {
    if (_txtPath != null && mounted) {
      ShareService.shareFile(context,
          filePath: _txtPath!, text: 'Here is the extracted text file.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScreenShell(
      title: 'PDF to Text',
      explanation:
          'Select a PDF document (.pdf) to extract its text content',
      onPickFiles: _pickPdf,
      selectedFiles: _selectedFile != null ? [_selectedFile!] : [],
      onRemoveFile: (_) {
        setState(() {
          _selectedFile = null;
          _extractedText = null;
          _txtPath = null;
          _errorMessage = null;
        });
      },
      onExecute: _selectedFile != null ? _extractText : null,
      executeButtonLabel: 'Extract Text',
      executeButtonIcon: Icons.text_fields,
      pickButtonLabel: 'Select PDF',
      isLoading: _isLoading,
      loadingMessage: 'Extracting text content from PDF...',
      errorMessage: _errorMessage,
      onDismissError: () => setState(() => _errorMessage = null),
      onRetry: _selectedFile != null ? _extractText : null,
      successPath: _txtPath,
      successTitle: 'Text Extracted Successfully!',
      successSubtitle: 'Extracted text saved to file.',
      onSave: _saveTxtFile,
      onShare: _shareTxtFile,
      defaultSavePrefix: 'ExtractedText',
      onReset: () {
        setState(() {
          _extractedText = null;
          _selectedFile = null;
          _txtPath = null;
          _errorMessage = null;
        });
      },
      emptyStateIcon: Icons.text_snippet_rounded,
      emptyStateTitle: 'No PDF Selected',
      emptyStateSubtitle:
          'Select a PDF document (.pdf) from your device to extract text content',
      emptyStateActionLabel: 'Select PDF',
      successContent: _extractedText == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        icon: const Icon(Icons.download_rounded, size: 16),
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
              ],
            ),
    );
  }
}
