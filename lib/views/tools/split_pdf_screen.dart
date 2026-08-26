import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/widgets/tool_screen_shell.dart';
import 'package:uuid/uuid.dart';

class SplitPdfScreen extends StatefulWidget {
  const SplitPdfScreen({Key? key}) : super(key: key);

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen> {
  final FileService _fileService = FileService();
  final PdfService _pdfService = PdfService();
  final StorageService _storageService = StorageService();

  String? _selectedFile;
  int? _totalPages;
  int _startPage = 1;
  int _endPage = 1;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successPath;

  late final TextEditingController _startController;
  late final TextEditingController _endController;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(text: '1');
    _endController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    try {
      final file = await _fileService.pickPdfFile();
      if (!mounted) return;
      if (file != null) {
        int? pageCount;
        try {
          pageCount = await _pdfService.getPdfPageCount(file);
        } catch (_) {
          pageCount = null;
        }

        setState(() {
          _selectedFile = file;
          _totalPages = pageCount;
          _startPage = 1;
          _endPage = pageCount ?? 1;
          _startController.text = '1';
          _endController.text = '$_endPage';
          _errorMessage = null;
          _successPath = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _splitPdf() async {
    if (_selectedFile == null) {
      setState(() {
        _errorMessage = 'Please select a PDF file first.';
      });
      return;
    }

    final start = int.tryParse(_startController.text);
    final end = int.tryParse(_endController.text);

    if (start == null || end == null) {
      setState(() {
        _errorMessage = 'Please enter valid page numbers.';
      });
      return;
    }

    if (start < 1) {
      setState(() {
        _errorMessage = 'Start page must be 1 or greater.';
      });
      return;
    }

    if (_totalPages != null && end > _totalPages!) {
      setState(() {
        _errorMessage = 'End page cannot exceed total pages (${_totalPages!}).';
      });
      return;
    }

    if (start > end) {
      setState(() {
        _errorMessage = 'Start page cannot be greater than end page.';
      });
      return;
    }

    setState(() {
      _startPage = start;
      _endPage = end;
      _isLoading = true;
      _errorMessage = null;
      _successPath = null;
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

      final filePath = await _pdfService.splitPdf(
        pdfPath: _selectedFile!,
        startPage: start,
        endPage: end,
      );

      final entry = HistoryEntry(
        id: const Uuid().v4(),
        title:
            'Split PDF - ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        date: DateTime.now(),
        filePath: filePath,
        toolType: 'split_pdf',
      );
      await _storageService.addHistoryEntry(entry);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successPath = filePath;
      });

      ShareService.showSaveShareDialog(context, filePath);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textCol = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return ToolScreenShell(
      title: 'Split PDF',
      explanation:
          'Extract a specific page range from your PDF document into a new PDF.',
      onPickFiles: _pickPdf,
      selectedFiles: _selectedFile != null ? [_selectedFile!] : [],
      onRemoveFile: (_) {
        setState(() {
          _selectedFile = null;
          _errorMessage = null;
        });
      },
      onExecute: _selectedFile != null ? _splitPdf : null,
      executeButtonLabel: 'Extract Pages',
      isLoading: _isLoading,
      loadingMessage: 'Extracting pages $_startPage to $_endPage...',
      errorMessage: _errorMessage,
      onDismissError: () => setState(() => _errorMessage = null),
      successPath: _successPath,
      successSubtitle: 'Extracted pages $_startPage to $_endPage',
      onReset: () {
        setState(() {
          _successPath = null;
          _selectedFile = null;
          _errorMessage = null;
        });
      },
      extraConfig: _selectedFile == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_totalPages != null) ...[
                  Text(
                    'Total Pages: $_totalPages',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        enabled: !_isLoading,
                        controller: _startController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textCol, fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'Start Page',
                          isDense: true,
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null) {
                            setState(() {
                              _startPage = parsed;
                              _errorMessage = null;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        enabled: !_isLoading,
                        controller: _endController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textCol, fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'End Page',
                          isDense: true,
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null) {
                            setState(() {
                              _endPage = parsed;
                              _errorMessage = null;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
