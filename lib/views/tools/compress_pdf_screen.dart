import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/widgets/tool_screen_shell.dart';
import 'package:uuid/uuid.dart';

class CompressPdfScreen extends StatefulWidget {
  const CompressPdfScreen({Key? key}) : super(key: key);

  @override
  State<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends State<CompressPdfScreen> {
  final FileService _fileService = FileService();
  final PdfService _pdfService = PdfService();
  final StorageService _storageService = StorageService();

  String? _selectedFile;
  String _compressionLevel = 'medium';
  bool _isLoading = false;
  String? _errorMessage;
  String? _successPath;

  Future<void> _pickPdf() async {
    try {
      final file = await _fileService.pickPdfFile();
      if (!mounted) return;
      if (file != null) {
        setState(() {
          _selectedFile = file;
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

  Future<void> _compressPdf() async {
    if (_selectedFile == null) {
      setState(() {
        _errorMessage = 'Please select a PDF file first.';
      });
      return;
    }

    setState(() {
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

      final filePath = await _pdfService.compressPdf(
        _selectedFile!,
        compressionLevel: _compressionLevel,
      );

      final entry = HistoryEntry(
        id: const Uuid().v4(),
        title:
            'Compressed PDF - ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        date: DateTime.now(),
        filePath: filePath,
        toolType: 'compress_pdf',
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
      title: 'Compress PDF',
      explanation:
          'Reduce the file size of your PDF document while maintaining readable text and image quality.',
      onPickFiles: _pickPdf,
      selectedFiles: _selectedFile != null ? [_selectedFile!] : [],
      onRemoveFile: (_) {
        setState(() {
          _selectedFile = null;
          _errorMessage = null;
        });
      },
      onExecute: _selectedFile != null ? _compressPdf : null,
      executeButtonLabel: 'Compress PDF',
      isLoading: _isLoading,
      loadingMessage: 'Compressing and optimizing PDF file size...',
      errorMessage: _errorMessage,
      onDismissError: () => setState(() => _errorMessage = null),
      successPath: _successPath,
      successSubtitle: 'Applied level: ${_compressionLevel.toUpperCase()}',
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
                const Text(
                  'Compression Level',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'low',
                      label: Text('Low'),
                      icon: Icon(Icons.high_quality_rounded),
                    ),
                    ButtonSegment<String>(
                      value: 'medium',
                      label: Text('Medium'),
                      icon: Icon(Icons.balance_rounded),
                    ),
                    ButtonSegment<String>(
                      value: 'high',
                      label: Text('High'),
                      icon: Icon(Icons.compress_rounded),
                    ),
                  ],
                  selected: {_compressionLevel},
                  onSelectionChanged: _isLoading
                      ? null
                      : (selection) {
                          setState(() {
                            _compressionLevel = selection.first;
                            _errorMessage = null;
                          });
                        },
                ),
                const SizedBox(height: 8),
                Text(
                  _compressionLevel == 'low'
                      ? 'Best quality, subtle size reduction.'
                      : _compressionLevel == 'high'
                          ? 'Smallest file size, maximum compression.'
                          : 'Balanced quality and file size.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
    );
  }
}
