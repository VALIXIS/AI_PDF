import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/widgets/tool_screen_shell.dart';

enum PdfToImageMode {
  all,
  single,
  range,
}

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
  PdfToImageMode _mode = PdfToImageMode.all;
  int _singlePage = 1;
  int _startPage = 1;
  int _endPage = 1;
  bool _isLoading = false;
  bool _isExportingZip = false;
  String? _errorMessage;
  List<String>? _successImagePaths;
  String? _zipPath;

  late final TextEditingController _singlePageController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;

  @override
  void initState() {
    super.initState();
    _singlePageController = TextEditingController(text: '1');
    _startController = TextEditingController(text: '1');
    _endController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _singlePageController.dispose();
    _startController.dispose();
    _endController.dispose();
    FileService().cleanupTempResources();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    if (_isLoading) return;
    setState(() {
      _errorMessage = null;
      _successImagePaths = null;
      _zipPath = null;
    });

    try {
      final selectedPath = await _fileService.pickPdfFile();
      if (!mounted) return;
      if (selectedPath != null) {
        final ext = _fileService.getExtension(selectedPath).toLowerCase();
        if (ext == '.doc' || ext == '.docx') {
          setState(() {
            _selectedFile = null;
            _errorMessage =
                'Word documents ($ext) are not supported for image conversion. Please select a valid PDF (.pdf) file.';
          });
          return;
        }

        if (!await _fileService.isPdfFile(selectedPath)) {
          setState(() {
            _selectedFile = null;
            _errorMessage =
                'Selected file is not a valid PDF document. Please select a valid .pdf file.';
          });
          return;
        }

        final pages = await _pdfService.getPdfPageCount(selectedPath);
        if (!mounted) return;
        setState(() {
          _selectedFile = selectedPath;
          _totalPages = pages;
          _singlePage = 1;
          _startPage = 1;
          _endPage = pages;
          _singlePageController.text = '1';
          _startController.text = '1';
          _endController.text = pages.toString();
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
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

    int start = 1;
    int end = _totalPages ?? 1;

    if (_mode == PdfToImageMode.single) {
      final page = int.tryParse(_singlePageController.text);
      if (page == null) {
        setState(() {
          _errorMessage = 'Please enter a valid page number.';
        });
        return;
      }
      if (_totalPages != null && (page < 1 || page > _totalPages!)) {
        setState(() {
          _errorMessage = 'Page number must be between 1 and $_totalPages.';
        });
        return;
      }
      start = page;
      end = page;
      _singlePage = page;
    } else if (_mode == PdfToImageMode.range) {
      final s = int.tryParse(_startController.text);
      final e = int.tryParse(_endController.text);

      if (s == null || e == null) {
        setState(() {
          _errorMessage = 'Please enter valid start and end page numbers.';
        });
        return;
      }

      if (_totalPages != null) {
        if (s < 1 || s > _totalPages!) {
          setState(() {
            _errorMessage = 'Start page must be between 1 and $_totalPages.';
          });
          return;
        }
        if (e < s || e > _totalPages!) {
          setState(() {
            _errorMessage =
                'End page must be between start page and $_totalPages.';
          });
          return;
        }
      }
      start = s;
      end = e;
      _startPage = s;
      _endPage = e;
    } else {
      start = 1;
      end = _totalPages ?? 1;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successImagePaths = null;
      _zipPath = null;
    });

    try {
      final imagePaths = await _pdfService.convertPdfToImages(
        pdfPath: _selectedFile!,
        startPage: start,
        endPage: end,
      );

      if (imagePaths.isNotEmpty) {
        await _storageService.addHistoryEntry(HistoryEntry(
          id: AiController().generateId(),
          title: imagePaths.length == 1
              ? 'PDF to Image (Page $start)'
              : 'PDF to Image (${imagePaths.length} pages)',
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
        _errorMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('PdfServiceException: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _exportZipArchive() async {
    if (_successImagePaths == null || _successImagePaths!.isEmpty) return;
    setState(() {
      _isExportingZip = true;
    });

    try {
      final baseName = _selectedFile != null
          ? path.basenameWithoutExtension(_selectedFile!)
          : 'pdf_extracted';
      final zip = await _pdfService.createZipFromImages(
        imagePaths: _successImagePaths!,
        baseName: baseName,
      );

      if (!mounted) return;
      setState(() {
        _zipPath = zip;
        _isExportingZip = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ZIP archive created: ${path.basename(zip)}'),
          action: SnackBarAction(
            label: 'Save ZIP',
            onPressed: _saveZipToDownloads,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExportingZip = false;
        _errorMessage = 'Failed to create ZIP: $e';
      });
    }
  }

  void _saveZipToDownloads() {
    if (_zipPath == null || !mounted) return;
    ShareService.promptAndSaveFileDirectToDownloads(
      context,
      sourcePath: _zipPath!,
      defaultPrefix: 'PDF_Images_Archive',
      onOpen: () {
        ShareService.openDownloadedFile(context, _zipPath!);
      },
    );
  }

  void _shareZipArchive() {
    if (_zipPath == null || !mounted) return;
    ShareService.shareFile(
      context,
      filePath: _zipPath!,
      subject: 'Extracted PDF Images Archive',
    );
  }

  void _saveAllImages() {
    if (_successImagePaths == null || _successImagePaths!.isEmpty) return;
    if (mounted) {
      ShareService.saveMultipleFilesDirectToDownloads(
        context,
        sourcePaths: _successImagePaths!,
      );
    }
  }

  void _shareAllImages() {
    if (_successImagePaths == null || _successImagePaths!.isEmpty) return;
    if (mounted) {
      ShareService.shareMultipleFiles(
        context,
        filePaths: _successImagePaths!,
        text: 'Extracted high-quality images from PDF.',
      );
    }
  }

  void _saveSingle(String imagePath) {
    if (mounted) {
      ShareService.promptAndSaveFileDirectToDownloads(
        context,
        sourcePath: imagePath,
        defaultPrefix: 'PageImage',
        onOpen: () => _previewImage(imagePath),
      );
    }
  }

  void _previewImage(String imagePath) {
    if (mounted) {
      ShareService.openDownloadedFile(context, imagePath);
    }
  }

  void _shareSingle(String imagePath) {
    if (mounted) {
      ShareService.showSaveShareDialog(context, imagePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScreenShell(
      title: 'PDF to Image',
      explanation:
          'Convert PDF Pages to Images & ZIP\nSelect a PDF to extract pages as individual PNG images or bundle them into a single ZIP archive.',
      onPickFiles: _pickPdf,
      selectedFiles: _selectedFile != null ? [_selectedFile!] : [],
      onRemoveFile: (_) {
        setState(() {
          _selectedFile = null;
          _successImagePaths = null;
          _zipPath = null;
          _errorMessage = null;
        });
      },
      onExecute: _selectedFile != null ? _convertToImages : null,
      executeButtonLabel: _mode == PdfToImageMode.all
          ? 'Extract All Pages (${_totalPages ?? 1} PNGs)'
          : _mode == PdfToImageMode.single
              ? 'Export Page $_singlePage as PNG'
              : 'Export Pages $_startPage–$_endPage as PNGs',
      executeButtonIcon: Icons.image_rounded,
      pickButtonLabel: 'Select PDF',
      showPickButton: _selectedFile != null,
      isLoading: _isLoading,
      loadingMessage:
          'Rendering PDF pages to PNG images in background...',
      errorMessage: _errorMessage,
      onDismissError: () => setState(() => _errorMessage = null),
      onRetry: _selectedFile != null ? _convertToImages : null,
      successPath: _zipPath ??
          (_successImagePaths != null && _successImagePaths!.isNotEmpty
              ? _successImagePaths!.first
              : null),
      successTitle: 'Extraction Successful!',
      successSubtitle: _successImagePaths != null
          ? 'Generated ${_successImagePaths!.length} PNG image file(s).'
          : null,
      onReset: () {
        setState(() {
          _successImagePaths = null;
          _selectedFile = null;
          _zipPath = null;
          _errorMessage = null;
        });
      },
      emptyStateIcon: Icons.picture_as_pdf_rounded,
      emptyStateTitle: 'No PDF Selected',
      emptyStateSubtitle:
          'Select a PDF to extract pages as individual PNG images or bundle them into a single ZIP archive.',
      emptyStateActionLabel: 'Select PDF',
      extraConfig: _selectedFile == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Option',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SegmentedButton<PdfToImageMode>(
                  segments: const [
                    ButtonSegment(
                      value: PdfToImageMode.all,
                      label: Text('All Pages'),
                      icon: Icon(Icons.auto_awesome_motion_rounded),
                    ),
                    ButtonSegment(
                      value: PdfToImageMode.single,
                      label: Text('Single Page'),
                      icon: Icon(Icons.insert_drive_file_rounded),
                    ),
                    ButtonSegment(
                      value: PdfToImageMode.range,
                      label: Text('Range'),
                      icon: Icon(Icons.view_array_rounded),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: _isLoading
                      ? null
                      : (newSelection) {
                          setState(() {
                            _mode = newSelection.first;
                            _errorMessage = null;
                          });
                        },
                ),
                const SizedBox(height: 16),
                if (_mode == PdfToImageMode.single) ...[
                  Text(
                    'Select Page to Export',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    enabled: !_isLoading,
                    controller: _singlePageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'e.g. 1',
                      labelText: 'Page Number (1–${_totalPages ?? 1})',
                      isDense: true,
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        setState(() {
                          _singlePage = int.tryParse(value) ?? 1;
                          _errorMessage = null;
                        });
                      }
                    },
                  ),
                ] else if (_mode == PdfToImageMode.range) ...[
                  Text(
                    'Page Range to Render',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          enabled: !_isLoading,
                          controller: _startController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Start Page (1–${_totalPages ?? 1})',
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          enabled: !_isLoading,
                          controller: _endController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'End Page (1–${_totalPages ?? 1})',
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
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Extracts all pages (1 to ${_totalPages ?? 1}) into individual PNG files, with 1-click ZIP archive creation.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
      successContent: _successImagePaths == null
          ? null
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saveAllImages,
                        icon: const Icon(Icons.save_alt_rounded, size: 16),
                        label: const Text('Save Images'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _shareAllImages,
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('Share All'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isExportingZip
                            ? null
                            : (_zipPath != null
                                ? _saveZipToDownloads
                                : _exportZipArchive),
                        icon: _isExportingZip
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.folder_zip_rounded, size: 16),
                        label: Text(_zipPath != null
                            ? 'Save ZIP File'
                            : 'Export as ZIP'),
                      ),
                    ),
                    if (_zipPath != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.share_rounded, size: 18),
                        tooltip: 'Share ZIP',
                        onPressed: _shareZipArchive,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: _successImagePaths!.length,
                    itemBuilder: (context, index) {
                      final filePath = _successImagePaths![index];
                      final file = File(filePath);
                      final fileName = path.basename(filePath);
                      final pageIndex = _mode == PdfToImageMode.single
                          ? _singlePage
                          : index + _startPage;

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _previewImage(filePath),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(file, fit: BoxFit.contain),
                                    Positioned(
                                      top: 6,
                                      left: 6,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.65),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2, horizontal: 6),
                                        child: Text(
                                          'Page $pageIndex',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(
                                          Icons.fullscreen_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.download_rounded,
                                        size: 16),
                                    tooltip: 'Save Page $pageIndex',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _saveSingle(filePath),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.share_rounded,
                                        size: 16),
                                    tooltip: 'Share Page $pageIndex',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _shareSingle(filePath),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
