import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';
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
  int _startPage = 1;
  int _endPage = 5;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split PDF'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Extract Pages from PDF',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a PDF and specify the page range to extract',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            // Loading State Banner
            if (_isLoading)
              const ToolLoadingBanner(
                message: 'Splitting PDF pages...',
              ),

            // Error Banner
            if (_errorMessage != null)
              ToolErrorBanner(
                message: _errorMessage!,
                onRetry: _selectedFile != null ? _splitPdf : null,
                onDismiss: () => setState(() => _errorMessage = null),
              ),

            // Success Card
            if (_successPath != null)
              ToolSuccessCard(
                title: 'PDF Split Successfully!',
                subtitle: 'Extracted pages $_startPage to $_endPage.',
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

            // File selection and Range controls or Empty State
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
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Target range: Pages $_startPage - $_endPage',
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

              // Page Range Controls
              Text(
                'Page Range',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start Page', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        TextField(
                          enabled: !_isLoading,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 1',
                            isDense: true,
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              setState(() {
                                _startPage = int.tryParse(value) ?? 1;
                                _errorMessage = null;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('End Page', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        TextField(
                          enabled: !_isLoading,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 5',
                            isDense: true,
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              setState(() {
                                _endPage = int.tryParse(value) ?? 5;
                                _errorMessage = null;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ] else if (_successPath == null) ...[
              Expanded(
                child: ToolEmptyState(
                  icon: Icons.call_split_rounded,
                  title: 'No PDF Selected',
                  subtitle: 'Select a PDF document to extract a specific page range',
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
                    label: Text(_selectedFile == null ? 'Select PDF' : 'Change PDF'),
                  ),
                ),
                if (_selectedFile != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _splitPdf,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.call_split),
                      label: const Text('Split PDF'),
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

  Future<void> _splitPdf() async {
    if (_selectedFile == null) {
      setState(() {
        _errorMessage = 'Please select a PDF file first.';
      });
      return;
    }

    if (_startPage < 1 || _endPage < _startPage) {
      setState(() {
        _errorMessage = 'Please enter a valid page range (End page must be >= Start page).';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successPath = null;
    });

    try {
      final filePath = await _pdfService.splitPdf(
        pdfPath: _selectedFile!,
        startPage: _startPage,
        endPage: _endPage,
      );

      final entry = HistoryEntry(
        id: const Uuid().v4(),
        title: 'Split PDF (p$_startPage-$_endPage)',
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
