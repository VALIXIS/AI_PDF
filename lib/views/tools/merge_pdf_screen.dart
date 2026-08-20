import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
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
            const SizedBox(height: 12),
            Text(
              'Select multiple PDF files to combine into one',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 20),

            // Error Message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 0, 0, 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color.fromRGBO(255, 0, 0, 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Selected Files List
            if (_selectedFiles.isNotEmpty) ...[
              Text(
                'Selected Files (${_selectedFiles.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _selectedFiles.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: Icon(
                        Icons.picture_as_pdf,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        _fileService.getFileName(_selectedFiles[index]),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _selectedFiles.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No PDFs selected',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the button below to select files',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

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
                const SizedBox(width: 12),
                if (_selectedFiles.isNotEmpty)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _mergePdfs,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.merge_type),
                      label: const Text('Merge'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
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
      setState(() {
        _selectedFiles.addAll(files);
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _mergePdfs() async {
    if (_selectedFiles.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one PDF file to merge.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
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
        title: 'Merged PDF - ${DateTime.now().hour}:${DateTime.now().minute}',
        date: DateTime.now(),
        filePath: filePath,
        toolType: 'merge_pdf',
      );
      await _storageService.addHistoryEntry(entry);

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;
      if (mounted) { ShareService.showSaveShareDialog(context, filePath); }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDFs merged successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _selectedFiles.clear();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

}
