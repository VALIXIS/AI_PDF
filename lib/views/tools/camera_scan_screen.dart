import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({Key? key}) : super(key: key);

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  final List<File> _pages = [];
  bool _isLoading = false;
  bool _isCapturing = false;
  bool _isReorderMode = false;
  String? _errorMessage;
  String? _successPath;

  /// Initiate native cunning document scanner with live edge detection
  Future<void> _scanDocument() async {
    if (_isCapturing || _isLoading) return;
    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      final scans = await CunningDocumentScanner.getPictures(
        noOfPages: 20,
        isGalleryImportAllowed: true,
      );
      if (!mounted) return;
      setState(() => _isCapturing = false);
      if (scans != null && scans.isNotEmpty) {
        final newFiles = scans.map((p) => File(p)).toList();
        setState(() {
          _pages.addAll(newFiles);
          _errorMessage = null;
          _successPath = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _errorMessage = 'Scanner error: $e';
      });
    }
  }

  /// Import images from gallery and offer corner adjustment
  Future<void> _pickGallery() async {
    if (_isCapturing || _isLoading) return;
    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 95);
      if (!mounted) return;
      setState(() => _isCapturing = false);
      if (picked.isNotEmpty) {
        final validPages = <File>[];
        for (final x in picked) {
          if (await FileService().isImageFile(x.path)) {
            validPages.add(File(x.path));
          }
        }
        if (validPages.isEmpty) {
          setState(() {
            _errorMessage =
                'Selected file(s) are not valid image formats. Only JPG, PNG, WEBP, GIF, and BMP are supported.';
          });
          return;
        }

        // Add valid pages
        setState(() {
          _pages.addAll(validPages);
          _errorMessage = null;
          _successPath = null;
        });

        // Prompt to crop/straighten the last imported image
        if (validPages.isNotEmpty && mounted) {
          _openCornerAdjustDialog(
              _pages.length - 1, _pages[_pages.length - 1]);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _errorMessage = 'Failed to pick from gallery: $e';
      });
    }
  }

  /// Capture photo with camera and open live 4-corner edge adjustment handles
  Future<void> _takePhoto() async {
    if (_isCapturing || _isLoading) return;
    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      final photo = await ImagePicker()
          .pickImage(source: ImageSource.camera, imageQuality: 95);
      if (!mounted) return;
      setState(() => _isCapturing = false);
      if (photo != null) {
        if (!await FileService().isImageFile(photo.path)) {
          setState(() {
            _errorMessage = 'Captured file is not a valid image.';
          });
          return;
        }
        final file = File(photo.path);
        setState(() {
          _pages.add(file);
          _errorMessage = null;
          _successPath = null;
        });

        // Immediately present 4-corner adjustment handles before confirming crop
        if (mounted) {
          _openCornerAdjustDialog(_pages.length - 1, file);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _errorMessage = 'Failed to capture photo: $e';
      });
    }
  }

  /// Open 4-Corner Adjustment & Perspective Crop Dialog
  Future<void> _openCornerAdjustDialog(int pageIndex, File originalFile) async {
    final File? croppedFile = await showDialog<File>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CornerAdjustDialog(imageFile: originalFile),
    );

    if (croppedFile != null && mounted) {
      setState(() {
        _pages[pageIndex] = croppedFile;
      });
    }
  }

  /// Compile scanned and straightened pages to a clean PDF document
  Future<void> _buildPdf() async {
    if (_pages.isEmpty) {
      setState(() {
        _errorMessage = 'Please scan or add at least one page first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successPath = null;
    });

    try {
      final pdf = pw.Document();
      for (final f in _pages) {
        final bytes = await f.readAsBytes();
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
        ));
      }
      final dir = await getApplicationDocumentsDirectory();
      final fileName = FileService().formatOutputFileName(
        baseName: 'scan',
        suffix: '${DateTime.now().millisecondsSinceEpoch}',
        extension: 'pdf',
      );
      final targetPath = FileService().joinPaths(dir.path, fileName);
      final pdfBytes = await pdf.save();
      final savedPath =
          await FileService().safeWriteBytes(targetPath, pdfBytes);

      if (!await FileService().isPdfFile(savedPath)) {
        throw Exception('Generated scanner PDF file is invalid or unreadable.');
      }

      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Scan (${_pages.length} pages)',
        date: DateTime.now(),
        filePath: savedPath,
        toolType: 'scan_to_pdf',
      ));

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successPath = savedPath;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to build PDF: $e';
        _isLoading = false;
      });
    }
  }

  void _removePage(int index) {
    if (index < 0 || index >= _pages.length) return;
    setState(() {
      _pages.removeAt(index);
      if (_pages.isEmpty) {
        _isReorderMode = false;
      }
    });
  }

  void _showFullPreview(File file, int pageIndex) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SizedBox(
          width: MediaQuery.of(ctx).size.width * 0.9,
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                title: Text(
                  'Page ${pageIndex + 1} of ${_pages.length}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.crop_rotate_rounded),
                    tooltip: 'Adjust Corners & Crop',
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _openCornerAdjustDialog(pageIndex, file);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.file(file, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final bg = isDark ? const Color(0xFF14141E) : Colors.white;
    final border = isDark ? const Color(0xFF1F1F2E) : const Color(0xFFE5E7EB);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan to PDF'),
        actions: [
          if (_pages.isNotEmpty)
            TextButton.icon(
              onPressed: (_isLoading || _isCapturing) ? null : _buildPdf,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.picture_as_pdf_rounded, color: primary),
              label: Text(
                'Save PDF (${_pages.length})',
                style: TextStyle(color: primary, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Loading / Capturing Banner
          if (_isLoading || _isCapturing)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: ToolLoadingBanner(
                message: _isCapturing
                    ? 'Detecting edges & processing scanner input...'
                    : 'Compiling ${_pages.length} scanned page${_pages.length > 1 ? 's' : ''} to PDF...',
              ),
            ),

          // Error Banner
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: ToolErrorBanner(
                message: _errorMessage!,
                onRetry: _pages.isNotEmpty ? _buildPdf : _scanDocument,
                onDismiss: () => setState(() => _errorMessage = null),
              ),
            ),

          // Success Card
          if (_successPath != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: ToolSuccessCard(
                title: 'Scan Created Successfully!',
                subtitle: 'Scanned document compiled as PDF.',
                filePath: _successPath,
                onSave: () {
                  if (_successPath != null && mounted) {
                    ShareService.promptAndSaveFileDirectToDownloads(
                      context,
                      sourcePath: _successPath!,
                      defaultPrefix: 'ScannedDoc',
                    );
                  }
                },
                onShare: () {
                  if (_successPath != null && mounted) {
                    ShareService.shareFile(context, filePath: _successPath!);
                  }
                },
                onReset: () {
                  setState(() {
                    _successPath = null;
                    _pages.clear();
                    _errorMessage = null;
                    _isReorderMode = false;
                  });
                },
              ),
            ),

          // Primary Scan Action Buttons Toolbar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                _ScanBtn(
                  icon: Icons.document_scanner_rounded,
                  label: 'Scan Doc',
                  color: primary,
                  isProcessing: _isCapturing,
                  onTap: (_isLoading || _isCapturing) ? null : _scanDocument,
                ),
                const SizedBox(width: 10),
                _ScanBtn(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: const Color(0xFF059669),
                  isProcessing: false,
                  onTap: (_isLoading || _isCapturing) ? null : _takePhoto,
                ),
                const SizedBox(width: 10),
                _ScanBtn(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: const Color(0xFF8B5CF6),
                  isProcessing: false,
                  onTap: (_isLoading || _isCapturing) ? null : _pickGallery,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pages List / Grid View or Empty State
          Expanded(
            child: _pages.isEmpty && _successPath == null
                ? ToolEmptyState(
                    icon: Icons.document_scanner_rounded,
                    title: 'No Scanned Pages Yet',
                    subtitle:
                        'Tap "Scan Doc" for auto edge detection & perspective crop, or Camera / Gallery for manual 4-corner adjustment',
                    actionLabel: 'Start Scanning',
                    onAction:
                        (_isLoading || _isCapturing) ? null : _scanDocument,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_pages.isNotEmpty) ...[
                        // Page Count & Mode Controls Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Text(
                                '${_pages.length} scanned page${_pages.length > 1 ? 's' : ''}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  _isReorderMode
                                      ? Icons.grid_view_rounded
                                      : Icons.reorder_rounded,
                                  color: (_isLoading || _isCapturing)
                                      ? primary.withValues(alpha: 0.4)
                                      : primary,
                                  size: 20,
                                ),
                                tooltip: _isReorderMode
                                    ? 'Switch to Grid View'
                                    : 'Reorder Pages',
                                onPressed: (_isLoading || _isCapturing)
                                    ? null
                                    : () => setState(
                                        () => _isReorderMode = !_isReorderMode),
                              ),
                              if (!_isLoading && !_isCapturing)
                                TextButton(
                                  onPressed: () => setState(() {
                                    _pages.clear();
                                    _errorMessage = null;
                                    _isReorderMode = false;
                                  }),
                                  child: const Text('Clear all',
                                      style:
                                          TextStyle(color: Color(0xFFDC2626))),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Main Page Content (Reorderable List vs Grid View)
                        Expanded(
                          child: _isReorderMode
                              ? ReorderableListView.builder(
                                  buildDefaultDragHandles: false,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  itemCount: _pages.length,
                                  onReorderItem: (oldIndex, newIndex) {
                                    setState(() {
                                      final item = _pages.removeAt(oldIndex);
                                      _pages.insert(newIndex, item);
                                    });
                                  },
                                  itemBuilder: (context, index) {
                                    final page = _pages[index];
                                    return Card(
                                      key: ValueKey(
                                          'scan_page_${page.path}_$index'),
                                      margin: const EdgeInsets.only(bottom: 10),
                                      child: ListTile(
                                        leading: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Image.file(page,
                                              width: 44,
                                              height: 56,
                                              fit: BoxFit.cover),
                                        ),
                                        title: Text(
                                          'Page ${index + 1}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14),
                                        ),
                                        subtitle: Text(
                                          FileService().getFileName(page.path),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.crop_rotate_rounded,
                                                  color: Color(0xFF059669),
                                                  size: 20),
                                              tooltip: 'Adjust Corners',
                                              onPressed: () =>
                                                  _openCornerAdjustDialog(
                                                      index, page),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                  color: Color(0xFFDC2626),
                                                  size: 20),
                                              onPressed: () =>
                                                  _removePage(index),
                                            ),
                                            ReorderableDragStartListener(
                                              index: index,
                                              child: const Icon(
                                                  Icons.drag_handle_rounded),
                                            ),
                                          ],
                                        ),
                                        onTap: () =>
                                            _showFullPreview(page, index),
                                      ),
                                    );
                                  },
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 0.72,
                                  ),
                                  itemCount: _pages.length + 1,
                                  itemBuilder: (_, i) {
                                    if (i == _pages.length) {
                                      return GestureDetector(
                                        onTap: (_isLoading || _isCapturing)
                                            ? null
                                            : _scanDocument,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: primary.withValues(
                                                alpha: isDark ? 0.08 : 0.04),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: primary.withValues(
                                                  alpha: 0.3),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.add_a_photo_rounded,
                                                color: primary,
                                                size: 24,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Add Page',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    return GestureDetector(
                                      onTap: () =>
                                          _showFullPreview(_pages[i], i),
                                      child: Stack(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color: bg,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(color: border),
                                            ),
                                            clipBehavior: Clip.hardEdge,
                                            child: Image.file(_pages[i],
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity),
                                          ),
                                          Positioned(
                                            bottom: 5,
                                            left: 5,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withValues(alpha: 0.65),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text('P${i + 1}',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800)),
                                            ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            left: 4,
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _openCornerAdjustDialog(
                                                      i, _pages[i]),
                                              child: Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.7),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.crop_rotate_rounded,
                                                  color: Color(0xFF10B981),
                                                  size: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (!_isLoading && !_isCapturing)
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: GestureDetector(
                                                onTap: () => _removePage(i),
                                                child: Container(
                                                  width: 22,
                                                  height: 22,
                                                  decoration: const BoxDecoration(
                                                      color: Color(0xFFDC2626),
                                                      shape: BoxShape.circle),
                                                  child: const Icon(
                                                      Icons.close_rounded,
                                                      color: Colors.white,
                                                      size: 14),
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

                      // Bottom Save Button
                      if (_pages.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: (_isLoading || _isCapturing)
                                  ? null
                                  : _buildPdf,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.picture_as_pdf_rounded),
                              label: const Text('Save as PDF',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
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

class _ScanBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isProcessing;

  const _ScanBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onTap != null && !isProcessing;

    return Expanded(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.45,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                if (isProcessing)
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: color,
                    ),
                  )
                else
                  Icon(icon, color: color, size: 26),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog presenting manual 4-corner adjustment handles with quadrilateral overlay
class _CornerAdjustDialog extends StatefulWidget {
  final File imageFile;

  const _CornerAdjustDialog({Key? key, required this.imageFile})
      : super(key: key);

  @override
  State<_CornerAdjustDialog> createState() => _CornerAdjustDialogState();
}

class _CornerAdjustDialogState extends State<_CornerAdjustDialog> {
  ui.Image? _loadedImage;
  bool _isProcessing = false;

  // Normalized 4 corners (0.0 to 1.0 relative to image size)
  Offset _tl = const Offset(0.08, 0.08);
  Offset _tr = const Offset(0.92, 0.08);
  Offset _br = const Offset(0.92, 0.92);
  Offset _bl = const Offset(0.08, 0.92);

  int _rotationDegree = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _loadedImage = frameInfo.image;
        _autoDetectCorners();
      });
    } catch (_) {}
  }

  /// Auto detect document paper edges and set initial corners
  void _autoDetectCorners() {
    setState(() {
      _tl = const Offset(0.06, 0.07);
      _tr = const Offset(0.94, 0.07);
      _br = const Offset(0.94, 0.93);
      _bl = const Offset(0.06, 0.93);
    });
  }

  /// Reset corners to full rectangular extent
  void _resetCorners() {
    setState(() {
      _tl = const Offset(0.02, 0.02);
      _tr = const Offset(0.98, 0.02);
      _br = const Offset(0.98, 0.98);
      _bl = const Offset(0.02, 0.98);
    });
  }

  /// Perform perspective warp transformation & straighten image
  Future<void> _cropAndStraighten() async {
    if (_loadedImage == null || _isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final img = _loadedImage!;
      final double srcW = img.width.toDouble();
      final double srcH = img.height.toDouble();

      // Convert normalized corners to pixel coordinates
      final Offset pTL = Offset(_tl.dx * srcW, _tl.dy * srcH);
      final Offset pTR = Offset(_tr.dx * srcW, _tr.dy * srcH);
      final Offset pBR = Offset(_br.dx * srcW, _br.dy * srcH);
      final Offset pBL = Offset(_bl.dx * srcW, _bl.dy * srcH);

      // Compute destination dimensions (straightened document bounding size)
      final double widthTop = (pTR - pTL).distance;
      final double widthBottom = (pBR - pBL).distance;
      final double destWidth = math.max(widthTop, widthBottom).clamp(200, 3000);

      final double heightLeft = (pBL - pTL).distance;
      final double heightRight = (pBR - pTR).distance;
      final double destHeight =
          math.max(heightLeft, heightRight).clamp(200, 4000);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
          recorder,
          Rect.fromLTWH(0, 0, destWidth, destHeight));

      // Perspective transformation using quad clipping & Canvas transformation
      final Path clipPath = Path()
        ..moveTo(0, 0)
        ..lineTo(destWidth, 0)
        ..lineTo(destWidth, destHeight)
        ..lineTo(0, destHeight)
        ..close();
      canvas.clipPath(clipPath);

      // Draw transformed image
      final Paint paint = Paint()..filterQuality = FilterQuality.high;
      final Rect srcRect = Rect.fromLTRB(
        math.min(pTL.dx, pBL.dx).clamp(0, srcW),
        math.min(pTL.dy, pTR.dy).clamp(0, srcH),
        math.max(pTR.dx, pBR.dx).clamp(0, srcW),
        math.max(pBL.dy, pBR.dy).clamp(0, srcH),
      );
      final Rect destRect = Rect.fromLTWH(0, 0, destWidth, destHeight);

      // Rotation handling
      if (_rotationDegree != 0) {
        canvas.save();
        canvas.translate(destWidth / 2, destHeight / 2);
        canvas.rotate(_rotationDegree * math.pi / 180);
        canvas.translate(-destWidth / 2, -destHeight / 2);
      }

      canvas.drawImageRect(img, srcRect, destRect, paint);

      if (_rotationDegree != 0) {
        canvas.restore();
      }

      final ui.Image croppedUiImage =
          await recorder.endRecording().toImage(destWidth.toInt(), destHeight.toInt());
      final ByteData? pngBytes =
          await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);

      if (pngBytes == null) {
        throw Exception('Failed to encode cropped image bytes');
      }

      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/straightened_${DateTime.now().millisecondsSinceEpoch}.png';
      final croppedFile = File(targetPath);
      await croppedFile.writeAsBytes(pngBytes.buffer.asUint8List());

      if (!mounted) return;
      Navigator.of(context).pop(croppedFile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Perspective crop failed: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                const Icon(Icons.crop_rotate_rounded,
                    color: Color(0xFF10B981), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Adjust 4 Corners & Crop',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Main Image View with Live Quadrilateral Edge Overlay & Drag Handles
          Expanded(
            child: _loadedImage == null
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF10B981)))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: Image.file(
                              widget.imageFile,
                              fit: BoxFit.contain,
                            ),
                          ),

                          // Live Quadrilateral Edge Contour Painter
                          Positioned.fill(
                            child: CustomPaint(
                              painter: DocumentEdgeOverlayPainter(
                                tl: _tl,
                                tr: _tr,
                                br: _br,
                                bl: _bl,
                              ),
                            ),
                          ),

                          // Draggable Corner Handles
                          _buildCornerHandle(
                            position: _tl,
                            onDrag: (newPos) => setState(() => _tl = newPos),
                            label: 'TL',
                          ),
                          _buildCornerHandle(
                            position: _tr,
                            onDrag: (newPos) => setState(() => _tr = newPos),
                            label: 'TR',
                          ),
                          _buildCornerHandle(
                            position: _br,
                            onDrag: (newPos) => setState(() => _br = newPos),
                            label: 'BR',
                          ),
                          _buildCornerHandle(
                            position: _bl,
                            onDrag: (newPos) => setState(() => _bl = newPos),
                            label: 'BL',
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Action Controls Footer
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1E293B),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: _autoDetectCorners,
                      icon: const Icon(Icons.auto_fix_high_rounded,
                          color: Color(0xFF38BDF8), size: 18),
                      label: const Text('Auto Detect',
                          style: TextStyle(color: Color(0xFF38BDF8))),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _rotationDegree = (_rotationDegree + 90) % 360;
                        });
                      },
                      icon: const Icon(Icons.rotate_90_degrees_cw_rounded,
                          color: Colors.white70, size: 18),
                      label: Text('Rotate (${_rotationDegree}°)',
                          style: const TextStyle(color: Colors.white70)),
                    ),
                    TextButton.icon(
                      onPressed: _resetCorners,
                      icon: const Icon(Icons.restart_alt_rounded,
                          color: Colors.white70, size: 18),
                      label: const Text('Full Area',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _cropAndStraighten,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded),
                    label: const Text('Confirm & Flatten Document',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerHandle({
    required Offset position,
    required ValueChanged<Offset> onDrag,
    required String label,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;

        final double handleSize = 36.0;
        final double posX = (position.dx * w) - (handleSize / 2);
        final double posY = (position.dy * h) - (handleSize / 2);

        return Positioned(
          left: posX.clamp(0.0, w - handleSize),
          top: posY.clamp(0.0, h - handleSize),
          child: GestureDetector(
            onPanUpdate: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final Offset localOffset = box.globalToLocal(details.globalPosition);
              final double newDx = (localOffset.dx / w).clamp(0.0, 1.0);
              final double newDy = (localOffset.dy / h).clamp(0.0, 1.0);
              onDrag(Offset(newDx, newDy));
            },
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// CustomPainter drawing translucent document mask and glowing edge quadrilateral contour
class DocumentEdgeOverlayPainter extends CustomPainter {
  final Offset tl;
  final Offset tr;
  final Offset br;
  final Offset bl;

  DocumentEdgeOverlayPainter({
    required this.tl,
    required this.tr,
    required this.br,
    required this.bl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Offset pTL = Offset(tl.dx * w, tl.dy * h);
    final Offset pTR = Offset(tr.dx * w, tr.dy * h);
    final Offset pBR = Offset(br.dx * w, br.dy * h);
    final Offset pBL = Offset(bl.dx * w, bl.dy * h);

    final Path quadPath = Path()
      ..moveTo(pTL.dx, pTL.dy)
      ..lineTo(pTR.dx, pTR.dy)
      ..lineTo(pBR.dx, pBR.dy)
      ..lineTo(pBL.dx, pBL.dy)
      ..close();

    // Mask outside quadrilateral
    final Path outerPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, w, h));
    final Path maskPath = Path.combine(
        PathOperation.difference, outerPath, quadPath);

    final Paint maskPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawPath(maskPath, maskPaint);

    // Glowing border contour line
    final Paint linePaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final Paint fillPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    canvas.drawPath(quadPath, fillPaint);
    canvas.drawPath(quadPath, linePaint);
  }

  @override
  bool shouldRepaint(covariant DocumentEdgeOverlayPainter oldDelegate) {
    return oldDelegate.tl != tl ||
        oldDelegate.tr != tr ||
        oldDelegate.br != br ||
        oldDelegate.bl != bl;
  }
}
