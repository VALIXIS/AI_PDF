import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

class PdfToImageScreen extends StatefulWidget {
  const PdfToImageScreen({Key? key}) : super(key: key);

  @override
  State<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends State<PdfToImageScreen> {
  final FileService _fileService = FileService();
  final PdfService _pdfService = PdfService();
  final StorageService _storageService = StorageService();

  String? _selectedFile;
  int? _totalPages;
  int _startPage = 1;
  int _endPage = 1;
  bool _isLoading = false;
  String? _errorMessage;
  List<String>? _successImagePaths;

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
    setState(() {
      _errorMessage = null;
      _successImagePaths = null;
    });

    try {
      final path = await _fileService.pickPdfFile();
      if (path != null) {
        final pages = await _pdfService.getPdfPageCount(path);
        setState(() {
          _selectedFile = path;
          _totalPages = pages;
          _startPage = 1;
          _endPage = pages;
          _startController.text = '1';
          _endController.text = pages.toString();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to inspect PDF: $e';
      });
    }
  }

  Future<void> _convertToImages() async {
    if (_selectedFile == null) {
      setState(() {
        _errorMessage = 'Please select a PDF file first.';
      });
      return;
    }

    if (_totalPages != null) {
      if (_startPage < 1 || _startPage > _totalPages!) {
        setState(() {
          _errorMessage = 'Start page must be between 1 and $_totalPages.';
        });
        return;
      }
      if (_endPage < _startPage || _endPage > _totalPages!) {
        setState(() {
          _errorMessage = 'End page must be between start page and $_totalPages.';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successImagePaths = null;
    });

    try {
      final imagePaths = await _pdfService.convertPdfToImages(
        pdfPath: _selectedFile!,
        startPage: _startPage,
        endPage: _endPage,
      );

      if (imagePaths.isNotEmpty) {
        // Record the conversion in history using the first page's image path
        await _storageService.addHistoryEntry(HistoryEntry(
          id: AiController().generateId(),
          title: 'PDF to Image (${imagePaths.length} pages)',
          date: DateTime.now(),
          filePath: imagePaths.first,
          toolType: 'pdf_to_image',
        ));
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successImagePaths = imagePaths;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('PdfServiceException: ', '');
        _isLoading = false;
      });
    }
  }

  void _shareAll() {
    if (_successImagePaths == null || _successImagePaths!.isEmpty) return;
    if (mounted) {
      ShareService.showSaveShareDialog(context, _successImagePaths!.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF to Image'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Convert PDF Pages to Images',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a PDF and convert its pages to high-quality PNG images',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            // Loading State Banner
            if (_isLoading)
              const ToolLoadingBanner(
                message: 'Rendering PDF pages to images...',
              ),

            // Error Banner
            if (_errorMessage != null)
              ToolErrorBanner(
                message: _errorMessage!,
                onRetry: _selectedFile != null ? _convertToImages : null,
                onDismiss: () => setState(() => _errorMessage = null),
              ),

            // Success View with Images Grid
            if (_successImagePaths != null) ...[
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Conversion Successful!',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                ),
                                Text(
                                  'Generated ${_successImagePaths!.length} image files.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _shareAll,
                              icon: const Icon(Icons.share),
                              label: const Text('Share Images'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _successImagePaths = null;
                                _selectedFile = null;
                                _errorMessage = null;
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: _successImagePaths!.length,
                  itemBuilder: (context, index) {
                    final file = File(_successImagePaths![index]);
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(file, fit: BoxFit.contain),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                              child: Text(
                                'Page ${index + _startPage}',
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
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
                                'Pages range: $_startPage - $_endPage (Total $_totalPages)',
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
                  'Page Range to Render',
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
                            controller: _startController,
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
                            controller: _endController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'e.g. 5',
                              isDense: true,
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                setState(() {
                                  _endPage = int.tryParse(value) ?? 1;
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

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _convertToImages,
                    icon: const Icon(Icons.image),
                    label: const Text('Convert to Images'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ] else
                Expanded(
                  child: ToolEmptyState(
                    icon: Icons.picture_as_pdf,
                    title: 'No PDF Selected',
                    subtitle: 'Choose a PDF document to render its pages as image files',
                    actionLabel: 'Select PDF',
                    onAction: _isLoading ? null : _pickPdf,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
