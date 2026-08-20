import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
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
            const SizedBox(height: 12),
            Text(
              'Select a PDF and specify the page range',
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
                          ? '${_fileService.getFileName(_selectedFile!)}${_totalPages != null ? ' ($_totalPages pages)' : ''}'
                          : 'No file selected',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Page Range
            Text(
              'Page Range',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _startController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Start page',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(8),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _startPage = int.tryParse(value) ?? 1;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'To',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _endController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'End page',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(8),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _endPage = int.tryParse(value) ?? (_totalPages ?? 1);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text(
              _totalPages != null
                  ? 'Selected range: Pages $_startPage - $_endPage of $_totalPages'
                  : 'Selected range: Pages $_startPage - $_endPage',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
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
                      onPressed: _isLoading ? null : _splitPdf,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.call_split),
                      label: const Text('Split'),
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
      if (file == null) return;

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
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _splitPdf() async {
    if (_selectedFile == null) {
      setState(() {
        _errorMessage = 'Please select a PDF file.';
      });
      return;
    }

    if (_startPage < 1) {
      setState(() {
        _errorMessage = 'Start page must be at least 1.';
      });
      return;
    }

    if (_totalPages != null && _endPage > _totalPages!) {
      setState(() {
        _errorMessage = 'End page ($_endPage) cannot exceed total pages ($_totalPages).';
      });
      return;
    }

    if (_startPage > _endPage) {
      setState(() {
        _errorMessage = 'Start page ($_startPage) cannot be greater than end page ($_endPage).';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_selectedFile == null || !await _fileService.isFileAccessible(_selectedFile!)) {
        setState(() {
          _errorMessage = 'Selected file no longer exists or is inaccessible.';
          _isLoading = false;
        });
        return;
      }

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

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;
      if (mounted) { ShareService.showSaveShareDialog(context, filePath); }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF split successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

}
