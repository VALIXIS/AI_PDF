import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compress PDF'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reduce PDF File Size',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a PDF to compress and optimize its file size',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            // Loading Banner
            if (_isLoading)
              const ToolLoadingBanner(
                message: 'Compressing PDF document...',
              ),

            // Error Banner
            if (_errorMessage != null)
              ToolErrorBanner(
                message: _errorMessage!,
                onRetry: _selectedFile != null ? _compressPdf : null,
                onDismiss: () => setState(() => _errorMessage = null),
              ),

            // Success Card
            if (_successPath != null)
              ToolSuccessCard(
                title: 'PDF Compressed Successfully!',
                subtitle:
                    'Level: ${_compressionLevel.toUpperCase()} compression applied.',
                filePath: _successPath,
                onShare: () {
                  if (_successPath != null && mounted) {
                    ShareService.showSaveShareDialog(context, _successPath!);
                  }
                },
                onReset: () {
                  setState(() {
                    _successPath = null;
                    _selectedFile = null;
                    _errorMessage = null;
                  });
                },
              ),

            // Selected file or empty state
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
                              'Selected for compression',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (!_isLoading)
                        IconButton(
                          icon: const Icon(Icons.swap_horiz_rounded),
                          tooltip: 'Change File',
                          onPressed: _pickPdf,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Compression Level Options
              Text(
                'Compression Level',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'low',
                    label: Text('Low'),
                    icon: Icon(Icons.high_quality),
                  ),
                  ButtonSegment<String>(
                    value: 'medium',
                    label: Text('Medium'),
                    icon: Icon(Icons.balance),
                  ),
                  ButtonSegment<String>(
                    value: 'high',
                    label: Text('High'),
                    icon: Icon(Icons.compress),
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
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
            ] else if (_successPath == null) ...[
              Expanded(
                child: ToolEmptyState(
                  icon: Icons.compress_rounded,
                  title: 'No PDF Selected',
                  subtitle: 'Select a PDF file to reduce its file size',
                  actionLabel: 'Select PDF',
                  onAction: _isLoading ? null : _pickPdf,
                ),
              ),
            ] else
              const Spacer(),

            const SizedBox(height: 16),

            // Action Buttons
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
                      onPressed: _isLoading ? null : _compressPdf,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.compress),
                      label: const Text('Compress'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

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

      final filePath = await _pdfService.compressPdf(_selectedFile!);

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

      if (mounted) {
        ShareService.showSaveShareDialog(context, filePath);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
}
