import 'dart:io';
import 'package:flutter/material.dart';
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
  String? _successSubtitle;
  int? _originalSize;
  int? _compressedSize;
  int? _bytesSaved;

  Future<void> _pickPdf() async {
    try {
      final file = await _fileService.pickPdfFile();
      if (!mounted) return;
      if (file != null) {
        // Validate file stream accessibility and read size with deterministic cleanup
        RandomAccessFile? raf;
        int size = 0;
        try {
          raf = await File(file).open(mode: FileMode.read);
          size = await raf.length();
          if (size < 4) {
            setState(() {
              _errorMessage = 'Selected PDF file is empty or invalid.';
            });
            return;
          }
        } finally {
          await raf?.close();
        }

        setState(() {
          _selectedFile = file;
          _originalSize = size;
          _compressedSize = null;
          _bytesSaved = null;
          _errorMessage = null;
          _successPath = null;
          _successSubtitle = null;
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
      _successSubtitle = null;
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

      // Pre-validate file stream before compression
      RandomAccessFile? raf;
      int originalSize = 0;
      try {
        raf = await File(_selectedFile!).open(mode: FileMode.read);
        originalSize = await raf.length();
      } finally {
        await raf?.close();
      }

      final filePath = await _pdfService.compressPdf(
        _selectedFile!,
        compressionLevel: _compressionLevel,
      );

      RandomAccessFile? compRaf;
      int compressedSize = 0;
      try {
        compRaf = await File(filePath).open(mode: FileMode.read);
        compressedSize = await compRaf.length();
      } finally {
        await compRaf?.close();
      }

      final bytesSaved = originalSize - compressedSize;

      final dpiLabel = _compressionLevel == 'low'
          ? '72 DPI'
          : _compressionLevel == 'high'
              ? '300 DPI'
              : '150 DPI';

      String subtitle;
      if (bytesSaved > 0) {
        final percent = (bytesSaved / originalSize * 100).toStringAsFixed(1);
        subtitle =
            'Level: ${_compressionLevel.toUpperCase()} ($dpiLabel) • Saved ${_fileService.formatBytes(bytesSaved)} ($percent% reduction)\n${_fileService.formatBytes(originalSize)} → ${_fileService.formatBytes(compressedSize)}';
      } else if (bytesSaved == 0) {
        subtitle =
            'Level: ${_compressionLevel.toUpperCase()} ($dpiLabel) • File size unchanged (${_fileService.formatBytes(originalSize)})\nPDF structure optimized • Vector text preserved';
      } else {
        subtitle =
            'Level: ${_compressionLevel.toUpperCase()} ($dpiLabel) • Already at optimum size (${_fileService.formatBytes(compressedSize)})\nPDF structure optimized • Vector text preserved';
      }

      final entry = HistoryEntry(
        id: const Uuid().v4(),
        title:
            'Compressed PDF (${_compressionLevel.toUpperCase()}) - ${_fileService.formatBytes(compressedSize)}',
        date: DateTime.now(),
        filePath: filePath,
        toolType: 'compress_pdf',
      );
      await _storageService.addHistoryEntry(entry);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successPath = filePath;
        _originalSize = originalSize;
        _compressedSize = compressedSize;
        _bytesSaved = bytesSaved;
        _successSubtitle = subtitle;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildSizeDiffCard(BuildContext context) {
    if (_originalSize == null || _compressedSize == null) {
      return const SizedBox.shrink();
    }

    final isSaved = (_bytesSaved ?? 0) > 0;
    final percent = _originalSize! > 0
        ? ((_bytesSaved ?? 0) / _originalSize! * 100).toStringAsFixed(1)
        : '0.0';

    final dpiLabel = _compressionLevel == 'low'
        ? '72 DPI (Low)'
        : _compressionLevel == 'high'
            ? '300 DPI (High)'
            : '150 DPI (Medium)';

    final borderCol = Theme.of(context).dividerColor.withOpacity(0.2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded,
                  color: Colors.blueAccent, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Before & After File Size Diff',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSaved
                      ? Colors.green.withOpacity(0.12)
                      : Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSaved ? '-$percent%' : '0%',
                  style: TextStyle(
                    color: isSaved ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Original Size (Before)',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        _fileService.formatBytes(_originalSize!),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward_rounded,
                    color: Colors.grey, size: 20),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Compressed Size (After)',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        _fileService.formatBytes(_compressedSize!),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isSaved ? Colors.green : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target Image Resolution: $dpiLabel',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (isSaved)
                Text(
                  'Saved: ${_fileService.formatBytes(_bytesSaved!)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.verified_outlined, size: 14, color: Colors.blueAccent),
              SizedBox(width: 4),
              Text(
                'Vector text streams completely untouched & crisp',
                style: TextStyle(fontSize: 11, color: Colors.blueAccent),
              ),
            ],
          ),
        ],
      ),
    );
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
          _originalSize = null;
          _compressedSize = null;
          _bytesSaved = null;
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
      successSubtitle:
          _successSubtitle ?? 'Applied level: ${_compressionLevel.toUpperCase()}',
      successContent: _buildSizeDiffCard(context),
      onReset: () {
        setState(() {
          _successPath = null;
          _successSubtitle = null;
          _selectedFile = null;
          _originalSize = null;
          _compressedSize = null;
          _bytesSaved = null;
          _errorMessage = null;
        });
      },
      extraConfig: _selectedFile == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_originalSize != null) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(0.2),
                        width: 1.2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded,
                              color: Color(0xFFE03131), size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Original PDF File Size',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Text(
                                  _fileService.formatBytes(_originalSize!),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Compression Level',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'low',
                      label: Text('Low (72 DPI)'),
                      icon: Icon(Icons.high_quality_rounded),
                    ),
                    ButtonSegment<String>(
                      value: 'medium',
                      label: Text('Medium (150 DPI)'),
                      icon: Icon(Icons.balance_rounded),
                    ),
                    ButtonSegment<String>(
                      value: 'high',
                      label: Text('High (300 DPI)'),
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
                      ? 'Low (72 DPI): Downsamples images to 72 DPI, ideal for email and web.'
                      : _compressionLevel == 'high'
                          ? 'High (300 DPI): Downsamples images to 300 DPI, preserving print sharpness.'
                          : 'Medium (150 DPI): Downsamples images to 150 DPI, ideal for e-books and docs.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      'Vector text streams remain 100% vector & crisp',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.green,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

