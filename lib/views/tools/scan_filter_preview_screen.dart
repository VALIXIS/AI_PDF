import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

/// Available document image filter presets
enum ScanFilterPreset {
  original,
  magicColor,
  cleanBW,
  grayscale,
}

extension ScanFilterPresetExtension on ScanFilterPreset {
  String get label {
    switch (this) {
      case ScanFilterPreset.original:
        return 'Original';
      case ScanFilterPreset.magicColor:
        return 'Magic Color';
      case ScanFilterPreset.cleanBW:
        return 'Clean B&W';
      case ScanFilterPreset.grayscale:
        return 'Grayscale';
    }
  }

  String get description {
    switch (this) {
      case ScanFilterPreset.original:
        return 'Raw unedited capture';
      case ScanFilterPreset.magicColor:
        return 'Enhanced contrast, sharpness & saturation';
      case ScanFilterPreset.cleanBW:
        return 'Crisp black text on clean white paper';
      case ScanFilterPreset.grayscale:
        return 'Smooth monochrome document gradient';
    }
  }

  IconData get icon {
    switch (this) {
      case ScanFilterPreset.original:
        return Icons.image_rounded;
      case ScanFilterPreset.magicColor:
        return Icons.auto_awesome_rounded;
      case ScanFilterPreset.cleanBW:
        return Icons.contrast_rounded;
      case ScanFilterPreset.grayscale:
        return Icons.gradient_rounded;
    }
  }

  /// 5x4 ColorMatrix for zero-latency Flutter UI preview rendering
  List<double> get colorMatrix {
    switch (this) {
      case ScanFilterPreset.original:
        return <double>[
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1, 0,
        ];
      case ScanFilterPreset.magicColor:
        // Boost contrast, saturation, and white levels for document text clarity
        return <double>[
          1.38, -0.12, -0.12, 0, 15,
          -0.12, 1.38, -0.12, 0, 15,
          -0.12, -0.12, 1.38, 0, 15,
          0, 0, 0, 1, 0,
        ];
      case ScanFilterPreset.cleanBW:
        // Document binarization matrix (high-contrast black text on crisp white)
        return <double>[
          1.8, 1.8, 1.8, 0, -320,
          1.8, 1.8, 1.8, 0, -320,
          1.8, 1.8, 1.8, 0, -320,
          0, 0, 0, 1, 0,
        ];
      case ScanFilterPreset.grayscale:
        // Standard luminance weights for smooth grayscale
        return <double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ];
    }
  }
}

/// Represents a single page in a continuous multi-page scanning session
class ScanPageItem {
  final String id;
  final File rawFile;
  ScanFilterPreset filterPreset;
  File? cachedFilteredFile;

  ScanPageItem({
    required this.id,
    required this.rawFile,
    this.filterPreset = ScanFilterPreset.magicColor,
    this.cachedFilteredFile,
  });
}

class ScanFilterPreviewScreen extends StatefulWidget {
  final List<File>? initialImageFiles;

  const ScanFilterPreviewScreen({
    Key? key,
    this.initialImageFiles,
  }) : super(key: key);

  @override
  State<ScanFilterPreviewScreen> createState() =>
      _ScanFilterPreviewScreenState();
}

class _ScanFilterPreviewScreenState extends State<ScanFilterPreviewScreen> {
  final List<ScanPageItem> _sessionPages = [];
  int _selectedIndex = 0;
  bool _isLoading = false;
  bool _isProcessingBatch = false;
  String? _errorMessage;
  String? _successPdfPath;

  @override
  void initState() {
    super.initState();
    if (widget.initialImageFiles != null && widget.initialImageFiles!.isNotEmpty) {
      for (final f in widget.initialImageFiles!) {
        _sessionPages.add(ScanPageItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          rawFile: f,
          filterPreset: ScanFilterPreset.magicColor,
        ));
      }
    }
  }

  /// Add new pages continuously via native document scanner
  Future<void> _scanMorePages() async {
    if (_isProcessingBatch || _isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final scans = await CunningDocumentScanner.getPictures(
        noOfPages: 20,
        isGalleryImportAllowed: true,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (scans != null && scans.isNotEmpty) {
        final newItems = scans.map((path) {
          return ScanPageItem(
            id: 'scan_${DateTime.now().microsecondsSinceEpoch}_${path.hashCode}',
            rawFile: File(path),
            filterPreset: ScanFilterPreset.magicColor,
          );
        }).toList();

        setState(() {
          _sessionPages.addAll(newItems);
          _selectedIndex = _sessionPages.length - newItems.length;
          _successPdfPath = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Scanner capture failed: $e';
      });
    }
  }

  /// Add pages continuously from Gallery
  Future<void> _pickGalleryPages() async {
    if (_isProcessingBatch || _isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 95);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (picked.isNotEmpty) {
        final validItems = <ScanPageItem>[];
        for (final x in picked) {
          if (await FileService().isImageFile(x.path)) {
            validItems.add(ScanPageItem(
              id: 'gallery_${DateTime.now().microsecondsSinceEpoch}_${x.path.hashCode}',
              rawFile: File(x.path),
              filterPreset: ScanFilterPreset.magicColor,
            ));
          }
        }

        if (validItems.isEmpty) {
          setState(() {
            _errorMessage = 'Selected files are not valid image formats.';
          });
          return;
        }

        setState(() {
          _sessionPages.addAll(validItems);
          _selectedIndex = _sessionPages.length - validItems.length;
          _successPdfPath = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to pick from gallery: $e';
      });
    }
  }

  /// Add single page from Camera
  Future<void> _captureCameraPage() async {
    if (_isProcessingBatch || _isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final photo = await ImagePicker()
          .pickImage(source: ImageSource.camera, imageQuality: 95);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (photo != null) {
        if (!await FileService().isImageFile(photo.path)) {
          setState(() {
            _errorMessage = 'Captured file is not a valid image.';
          });
          return;
        }

        final item = ScanPageItem(
          id: 'camera_${DateTime.now().microsecondsSinceEpoch}',
          rawFile: File(photo.path),
          filterPreset: ScanFilterPreset.magicColor,
        );

        setState(() {
          _sessionPages.add(item);
          _selectedIndex = _sessionPages.length - 1;
          _successPdfPath = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Camera capture error: $e';
      });
    }
  }

  /// Apply current filter preset to all pages in session
  void _applyFilterToAllPages(ScanFilterPreset preset) {
    if (_sessionPages.isEmpty) return;
    setState(() {
      for (final p in _sessionPages) {
        p.filterPreset = preset;
        p.cachedFilteredFile = null; // reset cached output
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied "${preset.label}" filter to all ${_sessionPages.length} pages.'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  /// Batch process all page filters and compile into a single multi-page PDF
  Future<void> _batchProcessAndSavePdf() async {
    if (_sessionPages.isEmpty) {
      setState(() => _errorMessage = 'Please add at least one scanned page.');
      return;
    }

    setState(() {
      _isProcessingBatch = true;
      _errorMessage = null;
      _successPdfPath = null;
    });

    try {
      final pdf = pw.Document();
      final tempDir = await getTemporaryDirectory();

      for (int i = 0; i < _sessionPages.length; i++) {
        final item = _sessionPages[i];
        File fileToEmbed;

        if (item.filterPreset == ScanFilterPreset.original) {
          fileToEmbed = item.rawFile;
        } else {
          // Process image using Dart `image` library
          final bytes = await item.rawFile.readAsBytes();
          final img.Image? decoded = img.decodeImage(bytes);

          if (decoded != null) {
            img.Image processed;
            switch (item.filterPreset) {
              case ScanFilterPreset.magicColor:
                processed = img.adjustColor(
                  decoded,
                  contrast: 1.35,
                  saturation: 1.25,
                  brightness: 1.05,
                );
                break;
              case ScanFilterPreset.cleanBW:
                final gray = img.grayscale(decoded);
                processed = img.contrast(gray, contrast: 185.0);
                break;
              case ScanFilterPreset.grayscale:
                processed = img.grayscale(decoded);
                break;
              case ScanFilterPreset.original:
                processed = decoded;
                break;
            }

            final encodedJpg = img.encodeJpg(processed, quality: 90);
            final targetPath =
                '${tempDir.path}/batch_page_${i}_${DateTime.now().microsecondsSinceEpoch}.jpg';
            final processedFile = File(targetPath);
            await processedFile.writeAsBytes(encodedJpg);
            fileToEmbed = processedFile;
          } else {
            fileToEmbed = item.rawFile;
          }
        }

        final pageBytes = await fileToEmbed.readAsBytes();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Image(
              pw.MemoryImage(pageBytes),
              fit: pw.BoxFit.contain,
            ),
          ),
        );
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final fileName = FileService().formatOutputFileName(
        baseName: 'filtered_scan',
        suffix: '${DateTime.now().millisecondsSinceEpoch}',
        extension: 'pdf',
      );
      final targetPdfPath = FileService().joinPaths(docsDir.path, fileName);
      final pdfBytes = await pdf.save();
      final savedPdfPath =
          await FileService().safeWriteBytes(targetPdfPath, pdfBytes);

      if (!await FileService().isPdfFile(savedPdfPath)) {
        throw Exception('Generated scanner PDF is invalid or corrupted.');
      }

      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Filtered Scan (${_sessionPages.length} pages)',
        date: DateTime.now(),
        filePath: savedPdfPath,
        toolType: 'scan_filter_pdf',
      ));

      if (!mounted) return;
      setState(() {
        _isProcessingBatch = false;
        _successPdfPath = savedPdfPath;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingBatch = false;
        _errorMessage = 'Batch processing failed: $e';
      });
    }
  }

  void _removePage(int index) {
    if (index < 0 || index >= _sessionPages.length) return;
    setState(() {
      _sessionPages.removeAt(index);
      if (_selectedIndex >= _sessionPages.length) {
        _selectedIndex = math.max(0, _sessionPages.length - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final ScanPageItem? currentPage =
        _sessionPages.isNotEmpty && _selectedIndex < _sessionPages.length
            ? _sessionPages[_selectedIndex]
            : null;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Scan & Document Filters'),
        actions: [
          if (_sessionPages.isNotEmpty)
            TextButton.icon(
              onPressed: (_isProcessingBatch || _isLoading)
                  ? null
                  : _batchProcessAndSavePdf,
              icon: _isProcessingBatch
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.picture_as_pdf_rounded, color: primary),
              label: Text(
                'Save PDF (${_sessionPages.length})',
                style: TextStyle(color: primary, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Banner Status (Processing / Loading / Errors / Success)
          if (_isProcessingBatch || _isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: ToolLoadingBanner(
                message: _isProcessingBatch
                    ? 'Applying document filters & compiling multi-page PDF...'
                    : 'Capturing new scan page...',
              ),
            ),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: ToolErrorBanner(
                message: _errorMessage!,
                onRetry: _sessionPages.isNotEmpty
                    ? _batchProcessAndSavePdf
                    : _scanMorePages,
                onDismiss: () => setState(() => _errorMessage = null),
              ),
            ),

          if (_successPdfPath != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: ToolSuccessCard(
                title: 'Filtered Scan PDF Ready!',
                subtitle:
                    'Compiled ${_sessionPages.length} filtered page${_sessionPages.length > 1 ? 's' : ''} into PDF.',
                filePath: _successPdfPath,
                onSave: () {
                  if (_successPdfPath != null && mounted) {
                    ShareService.promptAndSaveFileDirectToDownloads(
                      context,
                      sourcePath: _successPdfPath!,
                      defaultPrefix: 'FilteredScanDoc',
                    );
                  }
                },
                onShare: () {
                  if (_successPdfPath != null && mounted) {
                    ShareService.shareFile(context, filePath: _successPdfPath!);
                  }
                },
                onReset: () {
                  setState(() {
                    _successPdfPath = null;
                    _sessionPages.clear();
                    _selectedIndex = 0;
                    _errorMessage = null;
                  });
                },
              ),
            ),

          // Main View: Empty State OR Active Preview + Filter Chips + Thumbnail Tray
          Expanded(
            child: _sessionPages.isEmpty && _successPdfPath == null
                ? ToolEmptyState(
                    icon: Icons.document_scanner_rounded,
                    title: 'No Scanned Pages in Session',
                    subtitle:
                        'Tap below to continuously capture physical documents with Magic Color, Clean B&W, and Grayscale document filters.',
                    actionLabel: 'Start Document Scan',
                    onAction:
                        (_isLoading || _isProcessingBatch) ? null : _scanMorePages,
                  )
                : Column(
                    children: [
                      // Active Page Stage with Live Filter Preview
                      Expanded(
                        child: currentPage == null
                            ? const SizedBox.shrink()
                            : Container(
                                margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: Stack(
                                  children: [
                                    // Interactive Viewer with Live Matrix ColorFilter Preview
                                    Center(
                                      child: InteractiveViewer(
                                        minScale: 0.8,
                                        maxScale: 4.0,
                                        child: ColorFiltered(
                                          colorFilter: ColorFilter.matrix(
                                            currentPage.filterPreset.colorMatrix,
                                          ),
                                          child: Image.file(
                                            currentPage.rawFile,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Active Filter Badge & Page Counter Overlay
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.75),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white24,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              currentPage.filterPreset.icon,
                                              color: const Color(0xFF10B981),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Page ${_selectedIndex + 1}/${_sessionPages.length} • ${currentPage.filterPreset.label}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),

                      // Filter Presets Selector Bar
                      if (currentPage != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: cardBg,
                            border: Border(top: BorderSide(color: border)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'DOCUMENT FILTERS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const Spacer(),
                                  InkWell(
                                    onTap: () => _applyFilterToAllPages(
                                        currentPage.filterPreset),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      child: Row(
                                        children: [
                                          Icon(Icons.copy_all_rounded,
                                              size: 14, color: primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Apply to all pages',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 42,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: ScanFilterPreset.values.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final preset = ScanFilterPreset.values[index];
                                    final bool isSelected =
                                        currentPage.filterPreset == preset;

                                    return FilterChip(
                                      selected: isSelected,
                                      avatar: Icon(
                                        preset.icon,
                                        size: 16,
                                        color: isSelected
                                            ? Colors.white
                                            : primary,
                                      ),
                                      label: Text(preset.label),
                                      labelStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark
                                                ? Colors.white70
                                                : Colors.black87),
                                      ),
                                      selectedColor: primary,
                                      backgroundColor: isDark
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFFF1F5F9),
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            currentPage.filterPreset = preset;
                                            currentPage.cachedFilteredFile =
                                                null;
                                          });
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Multi-Page Session Thumbnail Tray & Action Controls
                      Container(
                        height: 110,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        color: cardBg,
                        child: Row(
                          children: [
                            // Continuous Add Page Buttons (+ Camera / Scanner / Gallery)
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _TrayAddBtn(
                                  icon: Icons.document_scanner_rounded,
                                  tooltip: 'Scan Doc',
                                  color: primary,
                                  onTap: (_isLoading || _isProcessingBatch)
                                      ? null
                                      : _scanMorePages,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _MiniAddBtn(
                                      icon: Icons.camera_alt_rounded,
                                      color: const Color(0xFF059669),
                                      onTap: (_isLoading || _isProcessingBatch)
                                          ? null
                                          : _captureCameraPage,
                                    ),
                                    const SizedBox(width: 4),
                                    _MiniAddBtn(
                                      icon: Icons.photo_library_rounded,
                                      color: const Color(0xFF8B5CF6),
                                      onTap: (_isLoading || _isProcessingBatch)
                                          ? null
                                          : _pickGalleryPages,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const VerticalDivider(width: 20, indent: 8, endIndent: 8),

                            // Scrollable Page Thumbnail Tray
                            Expanded(
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _sessionPages.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final page = _sessionPages[index];
                                  final bool isSelected = index == _selectedIndex;

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() => _selectedIndex = index);
                                    },
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: 65,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isSelected
                                                  ? primary
                                                  : border,
                                              width: isSelected ? 2.5 : 1,
                                            ),
                                          ),
                                          clipBehavior: Clip.hardEdge,
                                          child: ColorFiltered(
                                            colorFilter: ColorFilter.matrix(
                                              page.filterPreset.colorMatrix,
                                            ),
                                            child: Image.file(
                                              page.rawFile,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),

                                        // Page Number Tag
                                        Positioned(
                                          bottom: 3,
                                          left: 3,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.7),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'P${index + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Delete Page Button
                                        if (!_isLoading && !_isProcessingBatch)
                                          Positioned(
                                            top: 3,
                                            right: 3,
                                            child: GestureDetector(
                                              onTap: () => _removePage(index),
                                              child: Container(
                                                width: 18,
                                                height: 18,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFDC2626),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close_rounded,
                                                  color: Colors.white,
                                                  size: 12,
                                                ),
                                              ),
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
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrayAddBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  const _TrayAddBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 60,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _MiniAddBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _MiniAddBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 14),
      ),
    );
  }
}
