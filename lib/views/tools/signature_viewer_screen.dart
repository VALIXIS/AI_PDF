import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/saved_signature.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/signature_storage_service.dart';

/// Full-screen viewer for saved digital signatures with pinch-to-zoom,
/// background mode switcher, metadata inspect, and sharing/export actions.
class SignatureViewerScreen extends StatefulWidget {
  final SavedSignature signature;
  final bool allowUse;

  const SignatureViewerScreen({
    Key? key,
    required this.signature,
    this.allowUse = false,
  }) : super(key: key);

  @override
  State<SignatureViewerScreen> createState() => _SignatureViewerScreenState();
}

class _SignatureViewerScreenState extends State<SignatureViewerScreen> {
  final SignatureStorageService _storageService = SignatureStorageService();
  int _backgroundIndex = 0; // 0: White Paper, 1: Transparent Checkerboard, 2: Dark Slate
  bool _isExporting = false;

  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _exportSignature() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14141E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
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
                'Export Signature PNG',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select background format for saving and sharing:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.wb_sunny_outlined,
                    color: Colors.amber, size: 28),
                title: const Text(
                  'White Paper Background (Recommended)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Clearly visible on WhatsApp, Gallery apps, Email & Printing',
                  style: TextStyle(fontSize: 11),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: isDark
                    ? const Color(0xFF1C1C28)
                    : const Color(0xFFF8FAFC),
                onTap: () {
                  Navigator.pop(ctx);
                  _doExport(withWhiteBg: true);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.grid_on_rounded,
                    color: Colors.blue, size: 28),
                title: const Text(
                  'Transparent Background',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Ideal for stamping onto PDFs & official documents',
                  style: TextStyle(fontSize: 11),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: isDark
                    ? const Color(0xFF1C1C28)
                    : const Color(0xFFF8FAFC),
                onTap: () {
                  Navigator.pop(ctx);
                  _doExport(withWhiteBg: false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doExport({required bool withWhiteBg}) async {
    setState(() => _isExporting = true);
    try {
      final filePath = await _storageService.exportSignatureToFile(
        widget.signature,
        withWhiteBackground: withWhiteBg,
      );
      if (!mounted) return;
      ShareService.showSaveShareDialog(context, filePath);
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _deleteSignature() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Signature?'),
        content: Text(
            'Are you sure you want to permanently delete "${widget.signature.title}"?'),
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
      await _storageService.deleteSignature(widget.signature.id);
      if (!mounted) return;
      Navigator.pop(context, true); // Pop with deletion flag
    }
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final sig = widget.signature;
    final sigColor = Color(sig.colorValue);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sig.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              '${sig.createdAt.day}/${sig.createdAt.month}/${sig.createdAt.year}  ${sig.createdAt.hour}:${sig.createdAt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map_rounded),
            tooltip: 'Reset Zoom',
            onPressed: _resetZoom,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Export / Share',
            onPressed: _isExporting ? null : _exportSignature,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent),
            tooltip: 'Delete',
            onPressed: _deleteSignature,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Background switcher & hint bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14141E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF28283C)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Canvas Background:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      _buildBgOption(0, 'White', Icons.crop_square_rounded,
                          Colors.white, Colors.black),
                      const SizedBox(width: 6),
                      _buildBgOption(1, 'Grid', Icons.grid_on_rounded,
                          Colors.grey[200]!, Colors.black87),
                      const SizedBox(width: 6),
                      _buildBgOption(2, 'Dark', Icons.dark_mode_rounded,
                          const Color(0xFF0F172A), Colors.white),
                    ],
                  ),
                ],
              ),
            ),

            // Main Full-Screen Interactive Signature Preview
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      // Background layer
                      Positioned.fill(
                        child: _buildCanvasBackground(),
                      ),

                      // Interactive Pinch-To-Zoom Signature Image
                      Positioned.fill(
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: 0.5,
                          maxScale: 6.0,
                          boundaryMargin: const EdgeInsets.all(80),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Image.memory(
                                sig.pngBytes,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Floating Zoom Hint
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.pinch_rounded,
                                  size: 14, color: Colors.white70),
                              SizedBox(width: 4),
                              Text(
                                'Pinch to Zoom',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Metadata & Action Panel
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14141E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF28283C)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Ink Color
                      Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: sigColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.4)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ink Color',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      // Stroke Width
                      Row(
                        children: [
                          Icon(Icons.line_weight_rounded,
                              size: 16, color: primary),
                          const SizedBox(width: 6),
                          Text(
                            '${sig.strokeWidth.toStringAsFixed(1)} pt',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      // PNG Format
                      Row(
                        children: [
                          const Icon(Icons.image_outlined,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 6),
                          Text(
                            'Transparent PNG',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isExporting ? null : _exportSignature,
                          icon: _isExporting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Export / Share PNG'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      if (widget.allowUse) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context, sig),
                            icon:
                                const Icon(Icons.check_circle_rounded, size: 18),
                            label: const Text('Use Signature'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBgOption(
      int index, String label, IconData icon, Color bg, Color fg) {
    final isSelected = _backgroundIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _backgroundIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasBackground() {
    switch (_backgroundIndex) {
      case 0:
        return Container(
          color: Colors.white,
          child: CustomPaint(
            painter: _SigningLinePainter(),
          ),
        );
      case 1:
        return Container(
          color: const Color(0xFFF8FAFC),
          child: CustomPaint(
            painter: _CheckerboardPainter(),
          ),
        );
      case 2:
      default:
        return Container(
          color: const Color(0xFF0F172A),
        );
    }
  }
}

class _SigningLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.25)
      ..strokeWidth = 1.0;

    // Draw guideline at bottom third
    final y = size.height * 0.75;
    canvas.drawLine(Offset(24, y), Offset(size.width - 24, y), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const squareSize = 14.0;
    final paint = Paint()..color = const Color(0xFFE2E8F0);

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        if (((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, squareSize, squareSize), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
