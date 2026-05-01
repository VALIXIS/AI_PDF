import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
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
  bool _isLoading = false;
  String? _errorMessage;

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
            const SizedBox(height: 12),
            Text(
              'Select a PDF to compress and reduce its file size',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 20),

            // Info Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This is a placeholder feature. Implementation requires advanced PDF optimization.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Error Message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
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

            // Selected File
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.picture_as_pdf,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedFile != null
                          ? _fileService.getFileName(_selectedFile!)
                          : 'No file selected',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Compression Options
            Text(
              'Compression Level',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                ListTile(
                  leading: Radio(
                    value: 'low',
                    groupValue: 'medium',
                    onChanged: (_) {},
                  ),
                  title: const Text('Low (Best Quality)'),
                  subtitle: const Text('Slight reduction in size'),
                ),
                ListTile(
                  leading: Radio(
                    value: 'medium',
                    groupValue: 'medium',
                    onChanged: (_) {},
                  ),
                  title: const Text('Medium (Balanced)'),
                  subtitle: const Text('Good quality and size'),
                ),
                ListTile(
                  leading: Radio(
                    value: 'high',
                    groupValue: 'medium',
                    onChanged: (_) {},
                  ),
                  title: const Text('High (Smaller Size)'),
                  subtitle: const Text('Reduced quality'),
                ),
              ],
            ),

            const Spacer(),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _pickPdf,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Select PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                if (_selectedFile != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _compressPdf,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.compress),
                      label: const Text('Compress'),
                    ),
                  ),
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
      setState(() {
        _selectedFile = file;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _compressPdf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final filePath = await _pdfService.compressPdf(_selectedFile!);

      final entry = HistoryEntry(
        id: const Uuid().v4(),
        title: 'Compressed PDF - ${DateTime.now().hour}:${DateTime.now().minute}',
        date: DateTime.now(),
        filePath: filePath,
        toolType: 'compress_pdf',
      );
      await _storageService.addHistoryEntry(entry);

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF compressed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _selectedFile = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
}
