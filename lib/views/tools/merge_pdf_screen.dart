import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/widgets/tool_screen_shell.dart';
import 'package:uuid/uuid.dart';

class MergePdfScreen extends StatefulWidget {
  const MergePdfScreen({Key? key}) : super(key: key);

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  final FileService _fileService = FileService();
  final PdfService _pdfService = PdfService();
  final StorageService _storageService = StorageService();

  final List<String> _selectedFiles = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successPath;

  Future<void> _pickPdfs() async {
    try {
      final files = await _fileService.pickMultiplePdfFiles();
      if (!mounted) return;
      if (files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(files);
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

  Future<void> _mergePdfs() async {
    if (_selectedFiles.length < 2) {
      setState(() {
        _errorMessage = 'Please select at least 2 PDF files to merge.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successPath = null;
    });

    try {
      for (final file in _selectedFiles) {
        if (!await _fileService.isFileAccessible(file)) {
          setState(() {
            _errorMessage =
                'One or more selected files no longer exist or are inaccessible: ${_fileService.getFileName(file)}';
            _isLoading = false;
          });
          return;
        }
      }

      final filePath = await _pdfService.mergePdfs(_selectedFiles);

      final entry = HistoryEntry(
        id: const Uuid().v4(),
        title:
            'Merged PDF - ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        date: DateTime.now(),
        filePath: filePath,
        toolType: 'merge_pdf',
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
    return ToolScreenShell(
      title: 'Merge PDF',
      explanation:
          'Combine multiple PDF documents into a single organized PDF file.',
      onPickFiles: _pickPdfs,
      selectedFiles: _selectedFiles,
      onRemoveFile: (idx) {
        setState(() {
          _selectedFiles.removeAt(idx);
          _errorMessage = null;
        });
      },
      onExecute: _selectedFiles.length >= 2 ? _mergePdfs : null,
      executeButtonLabel:
          _selectedFiles.length < 2 ? 'Select 2+ PDFs' : 'Merge PDFs',
      isLoading: _isLoading,
      loadingMessage: 'Combining ${_selectedFiles.length} PDF documents...',
      errorMessage: _errorMessage,
      onDismissError: () => setState(() => _errorMessage = null),
      successPath: _successPath,
      successSubtitle: 'Your combined PDF document is ready.',
      onReset: () {
        setState(() {
          _successPath = null;
          _selectedFiles.clear();
          _errorMessage = null;
        });
      },
    );
  }
}
