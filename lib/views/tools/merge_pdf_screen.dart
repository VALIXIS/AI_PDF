import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge PDF'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select PDFs to Merge',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select multiple PDF files to combine into one',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            // Loading state
            if (_isLoading)
              ToolLoadingBanner(
                message: 'Merging ${_selectedFiles.length} PDF files...',
              ),

            // Error Banner
            if (_errorMessage != null)
              ToolErrorBanner(
                message: _errorMessage!,
                onRetry: _selectedFiles.length >= 2 ? _mergePdfs : null,
                onDismiss: () => setState(() => _errorMessage = null),
              ),

            // Success Card
            if (_successPath != null)
              ToolSuccessCard(
                title: 'PDFs Merged Successfully!',
                subtitle: 'Your combined PDF is ready to view or share.',
                filePath: _successPath,
                onShare: () {
                  if (_successPath != null && mounted) {
                    ShareService.showSaveShareDialog(context, _successPath!);
                  }
                },
                onReset: () {
                  setState(() {
                    _successPath = null;
                    _selectedFiles.clear();
                    _errorMessage = null;
                  });
                },
              ),

            // Selected Files List or Empty State
            if (_selectedFiles.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    'Selected Files (${_selectedFiles.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  if (!_isLoading)
                    TextButton(
                      onPressed: () => setState(() {
                        _selectedFiles.clear();
                        _errorMessage = null;
                      }),
                      child: const Text(
                        'Clear all',
                        style: TextStyle(color: Color(0xFFDC2626)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _selectedFiles.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          Icons.picture_as_pdf,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          _fileService.getFileName(_selectedFiles[index]),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _selectedFiles.removeAt(index);
                                    _errorMessage = null;
                                  });
                                },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else if (_successPath == null) ...[
              Expanded(
                child: ToolEmptyState(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'No PDFs Selected',
                  subtitle: 'Select two or more PDF files to combine into a single document',
                  actionLabel: 'Add PDFs',
                  onAction: _isLoading ? null : _pickPdfs,
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
                    onPressed: _isLoading ? null : _pickPdfs,
                    icon: const Icon(Icons.add),
                    label: const Text('Add PDFs'),
                  ),
                ),
                if (_selectedFiles.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_isLoading || _selectedFiles.length < 2)
                          ? null
                          : _mergePdfs,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.merge_type),
                      label: Text(_selectedFiles.length < 2 ? 'Select 2+ PDFs' : 'Merge'),
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
        title: 'Merged PDF - ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
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
