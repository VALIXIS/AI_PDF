import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:intl/intl.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/models/pdf_annotation.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_editor_screen.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

class PdfSignatureOverlayScreen extends StatefulWidget {
  final String? initialFilePath;

  const PdfSignatureOverlayScreen({Key? key, this.initialFilePath})
      : super(key: key);

  @override
  State<PdfSignatureOverlayScreen> createState() =>
      _PdfSignatureOverlayScreenState();
}

class _PdfSignatureOverlayScreenState extends State<PdfSignatureOverlayScreen> {
  final FileService _fileService = FileService();
  final PdfService _pdfService = PdfService();
  final StorageService _storageService = StorageService();

  String? _selectedFilePath;
  pdfx.PdfDocument? _pdfDocument;
  int _pageCount = 0;
  int _currentPageIndex = 0; // 0-indexed
  bool _isLoadingPdf = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successPath;

  // Rendered page image for current page
  pdfx.PdfPageImage? _currentRenderedPage;
  double _pageAspectRatio = 1.0 / 1.414; // Default A4 ratio

  // Overlays stored per page (key = 0-indexed page number)
  final Map<int, List<PdfOverlayPlacement>> _overlaysByPage = {};
  String? _selectedOverlayId;

  // In-memory library of saved signatures for quick reuse
  final List<Uint8List> _savedSignatures = [];

  // Canvas GlobalKey for exact local touch conversions
  final GlobalKey _canvasKey = GlobalKey();

  // Gesture baseline tracking for smooth manipulation
  double _gestureStartRot = 0.0;
  double _gestureStartW = 0.0;
  double _gestureStartH = 0.0;
  double _gestureStartX = 0.0;
  double _gestureStartY = 0.0;
  Offset _gestureStartFocalPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilePath != null) {
      _loadPdf(widget.initialFilePath!);
    }
  }

  @override
  void dispose() {
    _pdfDocument?.close();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    if (_isLoadingPdf || _isSaving) return;
    setState(() {
      _errorMessage = null;
      _successPath = null;
    });

    try {
      final path = await _fileService.pickPdfFile();
      if (!mounted) return;
      if (path != null) {
        await _loadPdf(path);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to select PDF document: $e';
      });
    }
  }

  Future<void> _loadPdf(String path) async {
    setState(() {
      _isLoadingPdf = true;
      _errorMessage = null;
      _successPath = null;
      _overlaysByPage.clear();
      _selectedOverlayId = null;
    });

    try {
      final doc = await pdfx.PdfDocument.openFile(path);
      final count = doc.pagesCount;
      if (count == 0) {
        throw Exception('Selected PDF document contains no pages.');
      }

      _pdfDocument?.close();
      _pdfDocument = doc;
      _selectedFilePath = path;
      _pageCount = count;
      _currentPageIndex = 0;

      await _renderCurrentPage();

      if (!mounted) return;
      setState(() {
        _isLoadingPdf = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingPdf = false;
        _errorMessage = 'Could not load PDF: $e';
      });
    }
  }

  Future<void> _renderCurrentPage() async {
    if (_pdfDocument == null) return;
    try {
      final page = await _pdfDocument!.getPage(_currentPageIndex + 1);
      final double width = page.width;
      final double height = page.height;
      if (width > 0 && height > 0) {
        _pageAspectRatio = width / height;
      }

      final pageImage = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: pdfx.PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      await page.close();

      if (!mounted) return;
      setState(() {
        _currentRenderedPage = pageImage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to render page ${_currentPageIndex + 1}: $e';
      });
    }
  }

  Future<void> _goToPage(int targetIndex) async {
    if (targetIndex < 0 ||
        targetIndex >= _pageCount ||
        targetIndex == _currentPageIndex) {
      return;
    }
    setState(() {
      _currentPageIndex = targetIndex;
      _selectedOverlayId = null;
      _currentRenderedPage = null;
    });
    await _renderCurrentPage();
  }

  List<PdfOverlayPlacement> get _currentPageOverlays {
    return _overlaysByPage.putIfAbsent(_currentPageIndex, () => []);
  }

  PdfOverlayPlacement? get _selectedOverlay {
    if (_selectedOverlayId == null) return null;
    final list = _currentPageOverlays;
    final index = list.indexWhere((o) => o.id == _selectedOverlayId);
    return index != -1 ? list[index] : null;
  }

  void _addOverlay(Uint8List imageBytes, String label, {double width = 0.35, double height = 0.15}) {
    final id = AiController().generateId();
    final newOverlay = PdfOverlayPlacement(
      id: id,
      pageIndex: _currentPageIndex,
      x: 0.32,
      y: 0.42,
      width: width,
      height: height,
      rotation: 0.0,
      opacity: 1.0,
      imageBytes: imageBytes,
      label: label,
    );

    setState(() {
      _currentPageOverlays.add(newOverlay);
      _selectedOverlayId = id;
    });
  }

  void _deleteSelectedOverlay() {
    if (_selectedOverlayId == null) return;
    setState(() {
      _currentPageOverlays.removeWhere((o) => o.id == _selectedOverlayId);
      _selectedOverlayId = null;
    });
  }

  void _duplicateSelectedOverlay() {
    final sel = _selectedOverlay;
    if (sel == null) return;
    final id = AiController().generateId();
    final copy = sel.copyWith(
      id: id,
      x: (sel.x + 0.04).clamp(0.0, 0.9),
      y: (sel.y + 0.04).clamp(0.0, 0.9),
    );
    setState(() {
      _currentPageOverlays.add(copy);
      _selectedOverlayId = id;
    });
  }

  void _rotateSelectedOverlay(double deltaRadians) {
    final sel = _selectedOverlay;
    if (sel == null) return;
    setState(() {
      double newRot = sel.rotation + deltaRadians;
      while (newRot > math.pi) {
        newRot -= 2 * math.pi;
      }
      while (newRot < -math.pi) {
        newRot += 2 * math.pi;
      }
      sel.rotation = newRot;
    });
  }

  void _setOverlayRotation(double targetRadians) {
    final sel = _selectedOverlay;
    if (sel == null) return;
    setState(() {
      double newRot = targetRadians;
      while (newRot > math.pi) {
        newRot -= 2 * math.pi;
      }
      while (newRot < -math.pi) {
        newRot += 2 * math.pi;
      }
      sel.rotation = newRot;
    });
  }

  // --- Signature & Stamp Creators ---

  Future<void> _openSignaturePad() async {
    final signatureBytes = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _SignaturePadDialog(),
    );

    if (signatureBytes != null && signatureBytes.isNotEmpty) {
      if (!_savedSignatures.any((s) => s.length == signatureBytes.length)) {
        _savedSignatures.add(signatureBytes);
      }
      _addOverlay(signatureBytes, 'Signature', width: 0.38, height: 0.16);
    }
  }

  Future<void> _pickSignatureImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (bytes.isNotEmpty) {
          if (!_savedSignatures.any((s) => s.length == bytes.length)) {
            _savedSignatures.add(bytes);
          }
          _addOverlay(bytes, 'Image Signature', width: 0.35, height: 0.18);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to pick signature image: $e';
      });
    }
  }

  Future<void> _openStampLibrary() async {
    final stampBytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _StampLibraryBottomSheet(
        savedSignatures: _savedSignatures,
        onCustomStamp: (text, color) async {
          final customBytes = await _createStampImage(text: text, color: color);
          if (ctx.mounted) Navigator.pop(ctx, customBytes);
        },
      ),
    );

    if (stampBytes != null && stampBytes.isNotEmpty) {
      _addOverlay(stampBytes, 'Stamp', width: 0.36, height: 0.14);
    }
  }

  static Future<Uint8List> _createStampImage({
    required String text,
    required Color color,
    bool isDate = false,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double width = 360.0;
    const double height = 140.0;

    const rect = Rect.fromLTWH(6, 6, width - 12, height - 12);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // Background semi-transparent fill
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    // Double border for authentic rubber stamp feel
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawRRect(rrect, borderPaint);

    const innerRect = Rect.fromLTWH(13, 13, width - 26, height - 26);
    final innerRRect =
        RRect.fromRectAndRadius(innerRect, const Radius.circular(8));
    final innerBorderPaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(innerRRect, innerBorderPaint);

    // Text Painter
    final textPainter = TextPainter(
      text: TextSpan(
        text: text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: isDate ? 22 : 28,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: width - 36);
    final textOffset = Offset(
      (width - textPainter.width) / 2,
      (height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, textOffset);

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // --- Burn & Export ---

  Future<void> _burnAndExportPdf() async {
    if (_selectedFilePath == null) {
      setState(() {
        _errorMessage = 'Please select a PDF file first.';
      });
      return;
    }

    int totalPlacements = 0;
    for (var list in _overlaysByPage.values) {
      totalPlacements += list.length;
    }

    if (totalPlacements == 0) {
      setState(() {
        _errorMessage =
            'Please place at least one signature or stamp before exporting.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successPath = null;
      _selectedOverlayId = null;
    });

    try {
      final outputPath = await _pdfService.applySignaturesAndStampsToPdf(
        sourcePdfPath: _selectedFilePath!,
        placementsByPage: _overlaysByPage,
      );

      final originalName = _fileService.getFileName(_selectedFilePath!);
      await _storageService.addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Signed PDF: $originalName',
        date: DateTime.now(),
        filePath: outputPath,
        toolType: 'pdf_signature',
      ));

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _successPath = outputPath;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('PdfServiceException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final bg = isDark ? const Color(0xFF14141E) : Colors.white;
    final border = isDark ? const Color(0xFF1F1F2E) : const Color(0xFFE5E7EB);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign & Stamp PDF'),
        actions: [
          if (_selectedFilePath != null && !_isSaving)
            IconButton(
              icon: const Icon(Icons.file_open_outlined),
              tooltip: 'Change PDF',
              onPressed: _pickPdf,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status & Alerts Section
            if (_isLoadingPdf)
              const ToolLoadingBanner(message: 'Loading PDF document...')
            else if (_isSaving)
              const ToolLoadingBanner(
                  message:
                      'Burning signatures & stamps into vector PDF export...')
            else if (_errorMessage != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ToolErrorBanner(
                  message: _errorMessage!,
                  onRetry: _selectedFilePath != null ? _burnAndExportPdf : null,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),
              )
            else if (_successPath != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ToolSuccessCard(
                  title: 'Signed PDF Exported Successfully!',
                  subtitle:
                      'All signatures and stamps were non-destructively burned into the vector PDF.',
                  filePath: _successPath,
                  onSave: () {
                    if (_successPath != null && mounted) {
                      ShareService.promptAndSaveFileDirectToDownloads(
                        context,
                        sourcePath: _successPath!,
                        defaultPrefix: 'Signed_PDF',
                        onOpen: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PdfEditorScreen(
                                initialFilePath: _successPath!,
                              ),
                            ),
                          );
                        },
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
                      _overlaysByPage.clear();
                      _selectedOverlayId = null;
                    });
                  },
                ),
              ),

            // Main Content Area
            Expanded(
              child: _selectedFilePath == null
                  ? _buildEmptyState(context, primary)
                  : _buildPdfViewerWithOverlay(context, isDark, primary),
            ),

            // Bottom Actions & Toolbar
            if (_selectedFilePath != null)
              _buildBottomControls(context, isDark, primary, bg, border),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color primary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ToolEmptyState(
          icon: Icons.draw_rounded,
          title: 'No PDF Document Selected',
          subtitle:
              'Select a PDF to place transparent signatures, rubber stamps, and date stamps with interactive drag, zoom, and rotation.',
          actionLabel: 'Select PDF Document',
          onAction: _pickPdf,
        ),
      ),
    );
  }

  Widget _buildPdfViewerWithOverlay(
      BuildContext context, bool isDark, Color primary) {
    return Column(
      children: [
        // Page Navigation Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8FAFC),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous Page',
                onPressed: _currentPageIndex > 0
                    ? () => _goToPage(_currentPageIndex - 1)
                    : null,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Page ${_currentPageIndex + 1} of $_pageCount',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: primary,
                      ),
                    ),
                  ),
                  if (_currentPageOverlays.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_currentPageOverlays.length} stamp(s)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next Page',
                onPressed: _currentPageIndex < _pageCount - 1
                    ? () => _goToPage(_currentPageIndex + 1)
                    : null,
              ),
            ],
          ),
        ),

        // PDF Page & Interactive Canvas
        Expanded(
          child: GestureDetector(
            onTap: () {
              // Tap outside to deselect active overlay
              if (_selectedOverlayId != null) {
                setState(() => _selectedOverlayId = null);
              }
            },
            child: Container(
              color: isDark ? const Color(0xFF0F0F17) : const Color(0xFFE2E8F0),
              padding: const EdgeInsets.all(12),
              child: Center(
                child: AspectRatio(
                  aspectRatio: _pageAspectRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double canvasW = constraints.maxWidth;
                          final double canvasH = constraints.maxHeight;

                          return Stack(
                            key: _canvasKey,
                            fit: StackFit.expand,
                            children: [
                              // 1. Rendered PDF Background Page
                              if (_currentRenderedPage != null)
                                Image.memory(
                                  _currentRenderedPage!.bytes,
                                  fit: BoxFit.fill,
                                )
                              else
                                const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),

                              // 2. Interactive Signature & Stamp Overlays
                              ..._currentPageOverlays.map((overlay) {
                                return _buildInteractiveOverlayItem(
                                  overlay,
                                  canvasW,
                                  canvasH,
                                  primary,
                                );
                              }).toList(),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveOverlayItem(
    PdfOverlayPlacement overlay,
    double canvasW,
    double canvasH,
    Color primary,
  ) {
    final isSelected = overlay.id == _selectedOverlayId;
    final double itemW = (overlay.width * canvasW).clamp(40.0, canvasW);
    final double itemH = (overlay.height * canvasH).clamp(24.0, canvasH);
    final double left = (overlay.x * canvasW).clamp(0.0, canvasW - itemW);
    final double top = (overlay.y * canvasH).clamp(0.0, canvasH - itemH);

    return Positioned(
      left: left,
      top: top,
      width: itemW,
      height: itemH,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedOverlayId = overlay.id;
          });
        },
        // Single-finger drag & multi-touch gestures (smooth baseline tracking)
        onScaleStart: (details) {
          setState(() {
            _selectedOverlayId = overlay.id;
            _gestureStartRot = overlay.rotation;
            _gestureStartW = overlay.width;
            _gestureStartH = overlay.height;
            _gestureStartX = overlay.x;
            _gestureStartY = overlay.y;
            _gestureStartFocalPoint = details.focalPoint;
          });
        },
        onScaleUpdate: (details) {
          setState(() {
            if (details.pointerCount == 1) {
              // Single finger drag translation
              final delta = details.focalPoint - _gestureStartFocalPoint;
              final newX = (_gestureStartX + (delta.dx / canvasW))
                  .clamp(0.0, 1.0 - overlay.width);
              final newY = (_gestureStartY + (delta.dy / canvasH))
                  .clamp(0.0, 1.0 - overlay.height);
              overlay.x = newX;
              overlay.y = newY;
            } else if (details.pointerCount > 1) {
              // Two-finger pinch to scale
              if (details.scale > 0.0) {
                final double newW =
                    (_gestureStartW * details.scale).clamp(0.06, 0.95);
                final double newH =
                    (_gestureStartH * details.scale).clamp(0.03, 0.95);
                overlay.width = newW;
                overlay.height = newH;
              }

              // Two-finger smooth, controlled rotation
              if (details.rotation != 0.0) {
                double targetRot = _gestureStartRot + details.rotation;
                while (targetRot > math.pi) {
                  targetRot -= 2 * math.pi;
                }
                while (targetRot < -math.pi) {
                  targetRot += 2 * math.pi;
                }
                // Magnetic horizontal snap
                if (targetRot.abs() < 0.04) {
                  targetRot = 0.0;
                }
                overlay.rotation = targetRot;
              }
            }
          });
        },
        child: Transform.rotate(
          angle: overlay.rotation,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Image / Stamp Layer with Opacity
              Opacity(
                opacity: overlay.opacity.clamp(0.1, 1.0),
                child: Container(
                  decoration: isSelected
                      ? BoxDecoration(
                          border: Border.all(
                            color: primary,
                            width: 1.8,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        )
                      : null,
                  padding:
                      isSelected ? const EdgeInsets.all(2) : EdgeInsets.zero,
                  child: Image.memory(
                    overlay.imageBytes,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),

              // Active Selection Controls & Handles
              if (isSelected) ...[
                // Top-Center: Direct Rotation Drag Handle with Stem
                Positioned(
                  top: -34,
                  left: (itemW / 2) - 13,
                  child: GestureDetector(
                    onPanUpdate: (panDetails) {
                      final renderBox = _canvasKey.currentContext
                          ?.findRenderObject() as RenderBox?;
                      if (renderBox == null) return;
                      final localTouch =
                          renderBox.globalToLocal(panDetails.globalPosition);
                      final itemCenterX =
                          (overlay.x + overlay.width / 2.0) * canvasW;
                      final itemCenterY =
                          (overlay.y + overlay.height / 2.0) * canvasH;
                      final dx = localTouch.dx - itemCenterX;
                      final dy = localTouch.dy - itemCenterY;
                      double rawAngle = math.atan2(dy, dx) + (math.pi / 2);

                      // Magnetic snap to cardinal angles (-180, -90, -45, 0, 45, 90, 180)
                      const snapDistance = 0.07; // ~4 degrees
                      for (final snap in [
                        -math.pi,
                        -3 * math.pi / 4,
                        -math.pi / 2,
                        -math.pi / 4,
                        0.0,
                        math.pi / 4,
                        math.pi / 2,
                        3 * math.pi / 4,
                        math.pi,
                      ]) {
                        if ((rawAngle - snap).abs() < snapDistance) {
                          rawAngle = snap;
                          break;
                        }
                      }

                      while (rawAngle > math.pi) {
                        rawAngle -= 2 * math.pi;
                      }
                      while (rawAngle < -math.pi) {
                        rawAngle += 2 * math.pi;
                      }

                      setState(() {
                        overlay.rotation = rawAngle;
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.rotate_right_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 8,
                          color: const Color(0xFF4F46E5),
                        ),
                      ],
                    ),
                  ),
                ),

                // Top-Left: Delete Handle
                Positioned(
                  top: -12,
                  left: -12,
                  child: GestureDetector(
                    onTap: _deleteSelectedOverlay,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ),

                // Top-Right: Duplicate Handle
                Positioned(
                  top: -12,
                  right: -12,
                  child: GestureDetector(
                    onTap: _duplicateSelectedOverlay,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.copy_rounded,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ),

                // Bottom-Left: Quick 90 deg Rotation Handle
                Positioned(
                  bottom: -12,
                  left: -12,
                  child: GestureDetector(
                    onTap: () => _rotateSelectedOverlay(math.pi / 2),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.indigo,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.rotate_right_rounded,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ),

                // Bottom-Right: Corner Resize Handle
                Positioned(
                  bottom: -12,
                  right: -12,
                  child: GestureDetector(
                    onPanUpdate: (panDetails) {
                      setState(() {
                        double deltaW = panDetails.delta.dx / canvasW;
                        double deltaH = panDetails.delta.dy / canvasH;
                        overlay.width =
                            (overlay.width + deltaW).clamp(0.08, 0.95);
                        overlay.height =
                            (overlay.height + deltaH).clamp(0.04, 0.95);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.aspect_ratio_rounded,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(
    BuildContext context,
    bool isDark,
    Color primary,
    Color bg,
    Color border,
  ) {
    final sel = _selectedOverlay;
    final int deg = sel != null ? (sel.rotation * 180 / math.pi).round() : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active Overlay Property Controls (Sliders for Size, Opacity, Rotation)
          if (sel != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    sel.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$deg°',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.replay_5_rounded, size: 18),
                  tooltip: 'Rotate -5°',
                  onPressed: () => _rotateSelectedOverlay(-5 * math.pi / 180),
                ),
                IconButton(
                  icon: const Icon(Icons.forward_5_rounded, size: 18),
                  tooltip: 'Rotate +5°',
                  onPressed: () => _rotateSelectedOverlay(5 * math.pi / 180),
                ),
                IconButton(
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  tooltip: 'Reset to 0°',
                  onPressed: () => _setOverlayRotation(0.0),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red, size: 18),
                  tooltip: 'Delete',
                  onPressed: _deleteSelectedOverlay,
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Controlled Rotation Slider (-180 to +180)
            Row(
              children: [
                const Icon(Icons.rotate_90_degrees_cw_rounded,
                    size: 15, color: Color(0xFF4F46E5)),
                const SizedBox(width: 6),
                const Text('Angle',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                Expanded(
                  child: Slider(
                    value: (sel.rotation * 180 / math.pi).clamp(-180.0, 180.0),
                    min: -180.0,
                    max: 180.0,
                    divisions: 72, // 5-degree increments
                    activeColor: const Color(0xFF4F46E5),
                    onChanged: (v) {
                      _setOverlayRotation(v * math.pi / 180.0);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.rotate_90_degrees_cw_rounded, size: 16),
                  tooltip: '+90° Step',
                  onPressed: () => _rotateSelectedOverlay(math.pi / 2),
                ),
              ],
            ),

            // Quick Angle Presets Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in [
                    {'label': '0° (Flat)', 'angle': 0.0},
                    {'label': '15°', 'angle': 15.0 * math.pi / 180},
                    {'label': '45°', 'angle': 45.0 * math.pi / 180},
                    {'label': '90° (Right)', 'angle': 90.0 * math.pi / 180},
                    {'label': '-15°', 'angle': -15.0 * math.pi / 180},
                    {'label': '-45°', 'angle': -45.0 * math.pi / 180},
                    {'label': '-90° (Left)', 'angle': -90.0 * math.pi / 180},
                    {'label': '180°', 'angle': math.pi},
                  ]) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 4),
                      child: ChoiceChip(
                        label: Text(
                          item['label'] as String,
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        selected: ((sel.rotation - (item['angle'] as double))
                                .abs() <
                            0.04),
                        onSelected: (_) =>
                            _setOverlayRotation(item['angle'] as double),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 2),

            // Opacity Slider
            Row(
              children: [
                const Icon(Icons.opacity_rounded, size: 15, color: Colors.grey),
                const SizedBox(width: 6),
                const Text('Opacity', style: TextStyle(fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: sel.opacity,
                    min: 0.2,
                    max: 1.0,
                    divisions: 8,
                    activeColor: primary,
                    onChanged: (v) => setState(() => sel.opacity = v),
                  ),
                ),
                Text('${(sel.opacity * 100).toInt()}%',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
            const Divider(height: 12),
          ],

          // Toolbar Buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildToolButton(
                  icon: Icons.draw_rounded,
                  label: 'Draw Signature',
                  color: const Color(0xFF2563EB),
                  onTap: _openSignaturePad,
                ),
                const SizedBox(width: 8),
                _buildToolButton(
                  icon: Icons.image_rounded,
                  label: 'Upload Image',
                  color: const Color(0xFF0D9488),
                  onTap: _pickSignatureImage,
                ),
                const SizedBox(width: 8),
                _buildToolButton(
                  icon: Icons.approval_rounded,
                  label: 'Stamps',
                  color: const Color(0xFFD97706),
                  onTap: _openStampLibrary,
                ),
                if (_currentPageOverlays.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildToolButton(
                    icon: Icons.clear_all_rounded,
                    label: 'Clear Page',
                    color: Colors.redAccent,
                    onTap: () {
                      setState(() {
                        _currentPageOverlays.clear();
                        _selectedOverlayId = null;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Primary Burn & Export Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _burnAndExportPdf,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.verified_rounded, size: 20),
              label: Text(
                _isSaving ? 'Processing Export...' : 'Save & Export Signed PDF',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// --- Smooth Drawing Signature Pad Dialog ---

class _SignaturePadDialog extends StatefulWidget {
  const _SignaturePadDialog({Key? key}) : super(key: key);

  @override
  State<_SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<_SignaturePadDialog> {
  final List<List<Offset>> _strokes = [];
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.5;

  final List<Color> _palette = const [
    Colors.black,
    Color(0xFF1E40AF), // Dark Navy Blue
    Color(0xFFDC2626), // Deep Red
    Color(0xFF047857), // Forest Green
  ];

  void _clear() {
    setState(() {
      _strokes.clear();
    });
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
    }
  }

  Future<void> _exportSignature() async {
    if (_strokes.isEmpty) {
      Navigator.pop(context, null);
      return;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double width = 600.0;
    const double height = 300.0;

    final paint = Paint()
      ..color = _selectedColor
      ..strokeWidth = _strokeWidth * 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in _strokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke[0].dx, stroke[0].dy);
      for (int i = 1; i < stroke.length; i++) {
        final p0 = stroke[i - 1];
        final p1 = stroke[i];
        path.quadraticBezierTo(
          p0.dx,
          p0.dy,
          (p0.dx + p1.dx) / 2,
          (p0.dy + p1.dy) / 2,
        );
      }
      path.lineTo(stroke.last.dx, stroke.last.dy);
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    if (mounted) {
      Navigator.pop(context, pngBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gesture_rounded,
                    color: Color(0xFF2563EB), size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Draw Signature',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.undo_rounded),
                  tooltip: 'Undo',
                  onPressed: _strokes.isNotEmpty ? _undo : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red),
                  tooltip: 'Clear',
                  onPressed: _strokes.isNotEmpty ? _clear : null,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Canvas Area
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14141E) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2D2D3F)
                      : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _strokes.add([details.localPosition]);
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      if (_strokes.isNotEmpty) {
                        _strokes.last.add(details.localPosition);
                      }
                    });
                  },
                  child: CustomPaint(
                    painter: _SignaturePainter(
                      strokes: _strokes,
                      color: _selectedColor,
                      strokeWidth: _strokeWidth,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Color Palette & Pen Width
            Row(
              children: [
                ..._palette.map((c) {
                  final isSel = _selectedColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSel
                            ? [
                                BoxShadow(
                                  color: c.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                )
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
                const Spacer(),
                const Text('Thickness', style: TextStyle(fontSize: 11)),
                SizedBox(
                  width: 100,
                  child: Slider(
                    value: _strokeWidth,
                    min: 1.5,
                    max: 6.0,
                    divisions: 5,
                    onChanged: (v) => setState(() => _strokeWidth = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Dialog Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _strokes.isNotEmpty ? _exportSignature : null,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Use Signature',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;

  _SignaturePainter({
    required this.strokes,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke[0].dx, stroke[0].dy);
      for (int i = 1; i < stroke.length; i++) {
        final p0 = stroke[i - 1];
        final p1 = stroke[i];
        path.quadraticBezierTo(
          p0.dx,
          p0.dy,
          (p0.dx + p1.dx) / 2,
          (p0.dy + p1.dy) / 2,
        );
      }
      path.lineTo(stroke.last.dx, stroke.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

// --- Rubber Stamp Library Bottom Sheet ---

class _StampLibraryBottomSheet extends StatefulWidget {
  final List<Uint8List> savedSignatures;
  final Function(String text, Color color) onCustomStamp;

  const _StampLibraryBottomSheet({
    Key? key,
    required this.savedSignatures,
    required this.onCustomStamp,
  }) : super(key: key);

  @override
  State<_StampLibraryBottomSheet> createState() =>
      _StampLibraryBottomSheetState();
}

class _StampLibraryBottomSheetState extends State<_StampLibraryBottomSheet> {
  final TextEditingController _customTextController = TextEditingController();
  Color _customColor = const Color(0xFF16A34A);

  @override
  void dispose() {
    _customTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat('dd-MMM-yyyy').format(DateTime.now());

    final standardStamps = [
      {'text': 'APPROVED', 'color': const Color(0xFF16A34A)},
      {'text': 'REJECTED', 'color': const Color(0xFFDC2626)},
      {'text': 'CONFIDENTIAL', 'color': const Color(0xFFD97706)},
      {'text': 'PAID', 'color': const Color(0xFF059669)},
      {'text': 'SIGN HERE', 'color': const Color(0xFF2563EB)},
      {'text': 'VERIFIED', 'color': const Color(0xFF0D9488)},
      {'text': 'DATE: $dateStr', 'color': const Color(0xFF4F46E5), 'isDate': true},
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Stamp & Signature Library',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a standard rubber stamp, saved signature, or create a custom text stamp.',
            style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          // Saved Signatures row if available
          if (widget.savedSignatures.isNotEmpty) ...[
            const Text('Saved Signatures',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.savedSignatures.length,
                itemBuilder: (ctx, i) {
                  final bytes = widget.savedSignatures[i];
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, bytes),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(6),
                      width: 110,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2D2D3F)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Standard Stamps Grid
          const Text('Standard Rubber Stamps',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: standardStamps.map((s) {
              final text = s['text'] as String;
              final color = s['color'] as Color;
              final isDate = s['isDate'] as bool? ?? false;

              return ActionChip(
                backgroundColor: color.withValues(alpha: 0.08),
                side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.2),
                label: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: isDate ? 11.5 : 12,
                  ),
                ),
                onPressed: () async {
                  final bytes = await _PdfSignatureOverlayScreenState
                      ._createStampImage(
                    text: text,
                    color: color,
                    isDate: isDate,
                  );
                  if (context.mounted) {
                    Navigator.pop(context, bytes);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Custom Stamp Input
          const Text('Custom Text Stamp',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final c in [
                const Color(0xFF16A34A),
                const Color(0xFFDC2626),
                const Color(0xFF2563EB),
                const Color(0xFF7C3AED),
                const Color(0xFFD97706),
                const Color(0xFF1F2937),
              ])
                GestureDetector(
                  onTap: () => setState(() => _customColor = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 8),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _customColor == c ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: _customColor == c
                          ? [
                              BoxShadow(
                                color: c.withValues(alpha: 0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customTextController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'e.g. RECEIVED / REVIEWED',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF14141E)
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final text = _customTextController.text.trim();
                  if (text.isNotEmpty) {
                    widget.onCustomStamp(text, _customColor);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _customColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Add Stamp'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
