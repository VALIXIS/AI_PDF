import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/saved_signature.dart';
import 'package:pdf_ai_toolkit/services/signature_storage_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/views/tools/signature_viewer_screen.dart';
import 'package:uuid/uuid.dart';

/// Represents a single continuous stroke drawn on the canvas.
class SignatureStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  SignatureStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}

class SignatureCanvasScreen extends StatefulWidget {
  final bool returnSignature;

  const SignatureCanvasScreen({
    Key? key,
    this.returnSignature = false,
  }) : super(key: key);

  @override
  State<SignatureCanvasScreen> createState() => _SignatureCanvasScreenState();
}

class _SignatureCanvasScreenState extends State<SignatureCanvasScreen> {
  final SignatureStorageService _storageService = SignatureStorageService();
  final List<SignatureStroke> _strokes = [];
  SignatureStroke? _currentStroke;

  Color _selectedColor = const Color(0xFF0F172A); // Default Classic Black
  double _strokeWidth = 3.5;

  final List<Color> _colorPalette = const [
    Color(0xFF0F172A), // Classic Black / Charcoal
    Color(0xFF000000), // Jet Black
    Color(0xFF475569), // Slate Grey
    Color(0xFF2563EB), // Royal Blue
    Color(0xFF1E3A8A), // Dark Navy
    Color(0xFF4F46E5), // Deep Indigo
    Color(0xFF059669), // Emerald Green
    Color(0xFF0D9488), // Teal Cyan
    Color(0xFFDC2626), // Crimson Red
    Color(0xFFE11D48), // Rose Coral
    Color(0xFFD97706), // Warm Amber / Bronze
    Color(0xFF7C3AED), // Violet Purple
    Color(0xFF831843), // Burgundy / Wine
  ];

  bool _isSaving = false;

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentStroke = SignatureStroke(
        points: [details.localPosition],
        color: _selectedColor,
        strokeWidth: _strokeWidth,
      );
      _strokes.add(_currentStroke!);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_currentStroke == null) return;
    setState(() {
      _currentStroke!.points.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _currentStroke = null;
    });
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
    }
  }

  void _clear() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.clear();
      });
    }
  }

  /// Renders current strokes to a transparent high-res PNG
  Future<Uint8List?> _renderSignatureToPng() async {
    if (_strokes.isEmpty) return null;

    // Calculate bounding box of signature strokes
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final stroke in _strokes) {
      for (final pt in stroke.points) {
        if (pt.dx < minX) minX = pt.dx;
        if (pt.dy < minY) minY = pt.dy;
        if (pt.dx > maxX) maxX = pt.dx;
        if (pt.dy > maxY) maxY = pt.dy;
      }
    }

    if (minX.isInfinite || minY.isInfinite) return null;

    const padding = 24.0;
    final strokeWidthPadding = _strokeWidth * 2;
    final effectivePadding = padding + strokeWidthPadding;

    final contentWidth = maxX - minX;
    final contentHeight = maxY - minY;
    final width = (contentWidth + effectivePadding * 2).clamp(120.0, 2000.0);
    final height = (contentHeight + effectivePadding * 2).clamp(80.0, 1500.0);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width * 2, height * 2),
    );

    // Apply 2x scale for high DPI crispness
    canvas.scale(2.0, 2.0);

    // Translate so signature content is cleanly centered with padding
    final offsetX = -minX + effectivePadding;
    final offsetY = -minY + effectivePadding;
    canvas.translate(offsetX, offsetY);

    final painter = SignaturePainter(strokes: _strokes);
    painter.paint(canvas, Size(maxX + effectivePadding, maxY + effectivePadding));

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      (width * 2).toInt(),
      (height * 2).toInt(),
    );
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _handleSaveSignature() async {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw your signature first.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final pngBytes = await _renderSignatureToPng();
    setState(() => _isSaving = false);

    if (pngBytes == null || !mounted) return;

    if (widget.returnSignature) {
      // Return directly to caller (e.g. PDF Editor)
      Navigator.pop(context, pngBytes);
      return;
    }

    // Prompt for title
    final now = DateTime.now();
    final titleController = TextEditingController(
      text: 'Signature ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save E-Signature',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Center(
                child: Image.memory(pngBytes, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Signature Label',
                hintText: 'e.g. Official Signature',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final savedSig = SavedSignature(
      id: const Uuid().v4(),
      title: titleController.text.trim().isEmpty
          ? 'My Signature'
          : titleController.text.trim(),
      createdAt: now,
      pngBytes: pngBytes,
      colorValue: _selectedColor.toARGB32(),
      strokeWidth: _strokeWidth,
    );

    await _storageService.saveSignature(savedSig);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Signature "${savedSig.title}" saved successfully!'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'View Full Screen',
          textColor: Colors.white,
          onPressed: () => _openSignatureViewer(savedSig),
        ),
      ),
    );
  }

  void _openSignatureViewer(SavedSignature sig) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignatureViewerScreen(signature: sig),
      ),
    );
  }

  void _openSavedSignaturesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SavedSignaturesSheet(
        onSignatureSelected: (sig) {
          if (widget.returnSignature) {
            Navigator.pop(ctx);
            Navigator.pop(context, sig.pngBytes);
          } else {
            Navigator.pop(ctx);
            _openSignatureViewer(sig);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final canvasBg = isDark ? const Color(0xFF181824) : Colors.white;
    final borderCol =
        isDark ? const Color(0xFF28283C) : const Color(0xFFE2E8F0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital E-Signature Pad',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_special_rounded),
            tooltip: 'Saved Signatures',
            onPressed: _openSavedSignaturesSheet,
          ),
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Undo',
            onPressed: _strokes.isEmpty ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear Canvas',
            onPressed: _strokes.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Instructions Banner
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.draw_rounded, color: primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Draw your signature smoothly below. Signatures are saved as high-res transparent PNGs.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Interactive Signature Canvas
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color: canvasBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      // Subtle signing guideline
                      Positioned(
                        left: 32,
                        right: 32,
                        bottom: 48,
                        child: IgnorePointer(
                          child: Row(
                            children: [
                              const Text(
                                'X',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 1.2,
                                  color: Colors.grey.withValues(alpha: 0.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_strokes.isEmpty)
                        IgnorePointer(
                          child: Center(
                            child: Text(
                              'Sign Here',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.withValues(alpha: 0.35),
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),

                      // Gesture Detector & Custom Painter
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: _onPanEnd,
                          child: CustomPaint(
                            painter: SignaturePainter(strokes: _strokes),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Controls: Stroke Width & Color Palette
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13131F) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
              ),
              child: Column(
                children: [
                  // Stroke width slider
                  Row(
                    children: [
                      const Text(
                        'Thickness:',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Expanded(
                        child: Slider(
                          value: _strokeWidth,
                          min: 1.5,
                          max: 8.0,
                          divisions: 13,
                          activeColor: _selectedColor,
                          label: '${_strokeWidth.toStringAsFixed(1)} pt',
                          onChanged: (val) =>
                              setState(() => _strokeWidth = val),
                        ),
                      ),
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        child: Container(
                          width: _strokeWidth * 2.5,
                          height: _strokeWidth * 2.5,
                          decoration: BoxDecoration(
                            color: _selectedColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 16),

                  // Color Palette
                  Row(
                    children: [
                      const Text(
                        'Ink Color:',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: _colorPalette.map((col) {
                              final isSelected = _selectedColor == col;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedColor = col),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? primary
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: col,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check,
                                            size: 16, color: Colors.white)
                                        : null,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Bottom Action Bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openSavedSignaturesSheet,
                      icon: const Icon(Icons.folder_special_rounded),
                      label: const Text('Saved Signatures',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _handleSaveSignature,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(widget.returnSignature
                              ? Icons.check_circle_rounded
                              : Icons.save_rounded),
                      label: Text(
                        widget.returnSignature
                            ? 'Use Signature'
                            : 'Save Signature',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter rendering smooth Bézier curve strokes
class SignaturePainter extends CustomPainter {
  final List<SignatureStroke> strokes;

  SignaturePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      if (stroke.points.length == 1) {
        // Draw single dot
        canvas.drawCircle(
          stroke.points.first,
          stroke.strokeWidth / 2,
          Paint()
            ..color = stroke.color
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
        continue;
      }

      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

      for (int i = 0; i < stroke.points.length - 1; i++) {
        final p0 = stroke.points[i];
        final p1 = stroke.points[i + 1];
        // Quadratic Bézier mid-point smoothing
        final midX = (p0.dx + p1.dx) / 2;
        final midY = (p0.dy + p1.dy) / 2;
        path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
      }
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) {
    return true;
  }
}

/// Bottom sheet widget allowing users to manage, preview, and select saved signatures.
class SavedSignaturesSheet extends StatefulWidget {
  final ValueChanged<SavedSignature>? onSignatureSelected;

  const SavedSignaturesSheet({
    Key? key,
    this.onSignatureSelected,
  }) : super(key: key);

  @override
  State<SavedSignaturesSheet> createState() => _SavedSignaturesSheetState();
}

class _SavedSignaturesSheetState extends State<SavedSignaturesSheet> {
  final SignatureStorageService _storageService = SignatureStorageService();
  List<SavedSignature> _signatures = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSignatures();
  }

  Future<void> _loadSignatures() async {
    setState(() => _isLoading = true);
    final list = await _storageService.getAllSignatures();
    if (mounted) {
      setState(() {
        _signatures = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteSignature(SavedSignature sig) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Signature?'),
        content: Text('Are you sure you want to delete "${sig.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _storageService.deleteSignature(sig.id);
      _loadSignatures();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF14141E) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1C1C28) : const Color(0xFFF8FAFC);
    final borderCol =
        isDark ? const Color(0xFF28283C) : const Color(0xFFE2E8F0);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Saved Signatures',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_signatures.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Column(
                      children: [
                        Icon(Icons.draw_outlined,
                            size: 48,
                            color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          'No saved signatures yet',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Draw and save your signature to access it here.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: _signatures.length,
                    itemBuilder: (context, index) {
                      final sig = _signatures[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderCol),
                        ),
                        child: InkWell(
                          onTap: () {
                            if (widget.onSignatureSelected != null) {
                              widget.onSignatureSelected!(sig);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SignatureViewerScreen(signature: sig),
                                ),
                              ).then((_) => _loadSignatures());
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                          alpha: isDark ? 0.05 : 0.8),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: Image.memory(
                                      sig.pngBytes,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        sig.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                SignatureViewerScreen(
                                              signature: sig,
                                              allowUse:
                                                  widget.onSignatureSelected !=
                                                      null,
                                            ),
                                          ),
                                        );
                                        _loadSignatures();
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(3.0),
                                        child: Icon(Icons.fullscreen_rounded,
                                            size: 18, color: Colors.blue),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    InkWell(
                                      onTap: () => _deleteSignature(sig),
                                      child: const Padding(
                                        padding: EdgeInsets.all(3.0),
                                        child: Icon(Icons.delete_outline_rounded,
                                            size: 16, color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
