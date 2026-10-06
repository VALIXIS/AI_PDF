import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

class RedactionScreen extends StatefulWidget {
  const RedactionScreen({Key? key}) : super(key: key);

  @override
  State<RedactionScreen> createState() => _RedactionScreenState();
}

class _RedactionScreenState extends State<RedactionScreen> {
  final FileService _fileService = FileService();
  final PdfService _pdfService = PdfService();
  final StorageService _storageService = StorageService();

  File? _pdfFile;
  pdfx.PdfDocument? _pdfDocument;
  int _pageCount = 0;
  int _currentPageIndex = 0; // 0-indexed
  pdfx.PdfPageImage? _currentRenderedPage;
  double _pageAspectRatio = 1.0 / 1.414;

  bool _isLoadingPdf = false;
  bool _isProcessing = false;
  String? _errorMessage;
  String? _successPath;

  // Map of 0-indexed page index -> list of normalized Rects [0..1]
  final Map<int, List<Rect>> _redactionsByPage = {};

  // Active drag tracking (normalized points 0..1)
  Offset? _dragStartNormalized;
  Offset? _dragCurrentNormalized;

  @override
  void dispose() {
    _pdfDocument?.close();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    if (_isLoadingPdf || _isProcessing) return;
    setState(() {
      _errorMessage = null;
      _successPath = null;
      _redactionsByPage.clear();
    });

    try {
      final path = await _fileService.pickPdfFile();
      if (!mounted) return;
      if (path != null) {
        if (!await _fileService.isPdfFile(path)) {
          setState(() {
            _errorMessage = 'Selected file is empty or not a valid PDF.';
          });
          return;
        }
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
      _redactionsByPage.clear();
    });

    try {
      pdfx.PdfDocument? doc;
      final bytes = await File(path).readAsBytes();

      bool isEncrypted = false;
      try {
        final sfCheck = sf.PdfDocument(inputBytes: bytes);
        sfCheck.dispose();
      } catch (sfErr) {
        final sfErrStr = sfErr.toString().toLowerCase();
        if (sfErrStr.contains('encrypted') ||
            sfErrStr.contains('password') ||
            sfErrStr.contains('invalid')) {
          isEncrypted = true;
        }
      }

      if (isEncrypted) {
        if (!mounted) return;
        final pass = await _promptPasswordDialog(context);
        if (pass != null && pass.isNotEmpty) {
          try {
            doc = await pdfx.PdfDocument.openData(bytes, password: pass);
          } catch (_) {
            throw Exception('Incorrect password provided for protected PDF.');
          }
        } else {
          throw Exception('Password required to open protected PDF.');
        }
      } else {
        try {
          doc = await pdfx.PdfDocument.openFile(path);
        } catch (e) {
          if (!mounted) return;
          final pass = await _promptPasswordDialog(context);
          if (pass != null && pass.isNotEmpty) {
            try {
              doc = await pdfx.PdfDocument.openData(bytes, password: pass);
            } catch (_) {
              throw Exception('Incorrect password or corrupt PDF document.');
            }
          } else {
            throw Exception('Failed to open PDF document: $e');
          }
        }
      }

      final count = doc.pagesCount;
      if (count == 0) {
        throw Exception('Selected PDF document contains no pages.');
      }

      _pdfDocument?.close();
      _pdfDocument = doc;
      _pdfFile = File(path);
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

  Future<String?> _promptPasswordDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Color(0xFFEF4444), size: 24),
              const SizedBox(width: 10),
              Text(
                'Password Protected',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This PDF document is encrypted. Enter password to unlock:',
                style: TextStyle(
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter password',
                  hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Unlock Document'),
            ),
          ],
        );
      },
    );
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
        _errorMessage = 'Failed to render page: $e';
      });
    }
  }

  Future<void> _changePage(int newIndex) async {
    if (newIndex < 0 || newIndex >= _pageCount || _isLoadingPdf) return;
    setState(() {
      _currentPageIndex = newIndex;
      _currentRenderedPage = null;
      _dragStartNormalized = null;
      _dragCurrentNormalized = null;
    });
    await _renderCurrentPage();
  }

  void _addRedaction(Rect rectNormalized) {
    if (rectNormalized.width < 0.01 || rectNormalized.height < 0.01) return;
    setState(() {
      _redactionsByPage.putIfAbsent(_currentPageIndex, () => []).add(rectNormalized);
    });
  }

  void _undoPageRedaction() {
    setState(() {
      final list = _redactionsByPage[_currentPageIndex];
      if (list != null && list.isNotEmpty) {
        list.removeLast();
      }
    });
  }

  void _clearPageRedactions() {
    setState(() {
      _redactionsByPage.remove(_currentPageIndex);
    });
  }

  void _clearAllRedactions() {
    setState(() {
      _redactionsByPage.clear();
    });
  }

  int get _totalRedactionCount {
    int total = 0;
    for (final list in _redactionsByPage.values) {
      total += list.length;
    }
    return total;
  }

  Future<void> _applyRedaction() async {
    if (_pdfFile == null || _totalRedactionCount == 0) {
      setState(() {
        _errorMessage = 'Please drag on the document to draw at least one blackout redaction box.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _successPath = null;
    });

    try {
      final savedPath = await _pdfService.redactPdf(
        pdfPath: _pdfFile!.path,
        redactionsByPage: _redactionsByPage,
      );

      await _storageService.addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Redacted PDF · ${FileService().getFileName(_pdfFile!.path)}',
        date: DateTime.now(),
        filePath: savedPath,
        toolType: 'redact_pdf',
      ));

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _successPath = savedPath;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final sub = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Redact PDF'),
        actions: [
          if (_pdfFile != null && _totalRedactionCount > 0 && !_isProcessing)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear All Redactions',
              onPressed: _clearAllRedactions,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Processing Banner
            if (_isProcessing)
              const ToolLoadingBanner(
                message: 'Rasterizing and permanently blacking out redacted areas...',
              ),

            // Error Banner
            if (_errorMessage != null)
              ToolErrorBanner(
                message: _errorMessage!,
                onRetry: (_pdfFile != null && _totalRedactionCount > 0)
                    ? _applyRedaction
                    : null,
                onDismiss: () => setState(() => _errorMessage = null),
              ),

            // Success Card
            if (_successPath != null)
              ToolSuccessCard(
                title: 'PDF Redacted Successfully!',
                subtitle: '$_totalRedactionCount sensitive region(s) blacked out permanently.',
                filePath: _successPath,
                onSave: () {
                  if (_successPath != null && mounted) {
                    ShareService.promptAndSaveFileDirectToDownloads(
                      context,
                      sourcePath: _successPath!,
                      defaultPrefix: 'RedactedPDF',
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
                    _pdfFile = null;
                    _pdfDocument?.close();
                    _pdfDocument = null;
                    _redactionsByPage.clear();
                  });
                },
              ),

            // Empty State
            if (_pdfFile == null && _successPath == null)
              ToolEmptyState(
                icon: Icons.find_replace_rounded,
                title: 'No PDF Selected',
                subtitle: 'Select a PDF document to blackout sensitive text or areas',
                actionLabel: 'Select PDF',
                onAction: (_isLoadingPdf || _isProcessing) ? null : _pickPdf,
              )
            else if (_pdfFile != null && _successPath == null) ...[
              // File Info Card & Pick Button
              GestureDetector(
                onTap: (_isLoadingPdf || _isProcessing) ? null : _pickPdf,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_rounded, color: primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              FileService().getFileName(_pdfFile!.path),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, color: primary),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$_pageCount pages · $_totalRedactionCount total redaction(s)',
                              style: TextStyle(fontSize: 12, color: sub),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.swap_horiz_rounded, color: sub),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Instruction Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_rounded, size: 18, color: primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Drag your finger/mouse across sensitive areas to draw blackout rectangles.',
                        style: TextStyle(fontSize: 12, color: sub, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Page Canvas with Drag-to-Draw Blackout Overlay
              if (_isLoadingPdf || _currentRenderedPage == null)
                Container(
                  height: 350,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: const CircularProgressIndicator(),
                )
              else
                Center(
                  child: AspectRatio(
                    aspectRatio: _pageAspectRatio,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final boxW = constraints.maxWidth;
                        final boxH = constraints.maxHeight;

                        final pageRedactions = _redactionsByPage[_currentPageIndex] ?? [];

                        return GestureDetector(
                          onPanStart: (details) {
                            if (_isProcessing) return;
                            final dx = details.localPosition.dx.clamp(0.0, boxW);
                            final dy = details.localPosition.dy.clamp(0.0, boxH);
                            setState(() {
                              _dragStartNormalized = Offset(dx / boxW, dy / boxH);
                              _dragCurrentNormalized = _dragStartNormalized;
                            });
                          },
                          onPanUpdate: (details) {
                            if (_dragStartNormalized == null || _isProcessing) return;
                            final dx = details.localPosition.dx.clamp(0.0, boxW);
                            final dy = details.localPosition.dy.clamp(0.0, boxH);
                            setState(() {
                              _dragCurrentNormalized = Offset(dx / boxW, dy / boxH);
                            });
                          },
                          onPanEnd: (details) {
                            if (_dragStartNormalized != null && _dragCurrentNormalized != null) {
                              final start = _dragStartNormalized!;
                              final current = _dragCurrentNormalized!;
                              final rect = Rect.fromLTRB(
                                start.dx < current.dx ? start.dx : current.dx,
                                start.dy < current.dy ? start.dy : current.dy,
                                start.dx > current.dx ? start.dx : current.dx,
                                start.dy > current.dy ? start.dy : current.dy,
                              );
                              _addRedaction(rect);
                            }
                            setState(() {
                              _dragStartNormalized = null;
                              _dragCurrentNormalized = null;
                            });
                          },
                          child: Stack(
                            children: [
                              // Background rendered PDF page
                              Positioned.fill(
                                child: Image.memory(
                                  _currentRenderedPage!.bytes,
                                  fit: BoxFit.fill,
                                ),
                              ),

                              // Existing Blackout Redaction Rectangles on Current Page
                              for (int i = 0; i < pageRedactions.length; i++) ...[
                                Positioned(
                                  left: pageRedactions[i].left * boxW,
                                  top: pageRedactions[i].top * boxH,
                                  width: pageRedactions[i].width * boxW,
                                  height: pageRedactions[i].height * boxH,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1),
                                    ),
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              // Active Dragging Preview Rectangle
                              if (_dragStartNormalized != null && _dragCurrentNormalized != null) ...[
                                Builder(
                                  builder: (context) {
                                    final start = _dragStartNormalized!;
                                    final current = _dragCurrentNormalized!;
                                    final l = (start.dx < current.dx ? start.dx : current.dx) * boxW;
                                    final t = (start.dy < current.dy ? start.dy : current.dy) * boxH;
                                    final w = (start.dx - current.dx).abs() * boxW;
                                    final h = (start.dy - current.dy).abs() * boxH;
                                    return Positioned(
                                      left: l,
                                      top: t,
                                      width: w,
                                      height: h,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.75),
                                          border: Border.all(color: Colors.redAccent, width: 2),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Page Controls Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: (_currentPageIndex > 0 && !_isLoadingPdf)
                        ? () => _changePage(_currentPageIndex - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: const Text('Prev'),
                  ),
                  Text(
                    'Page ${_currentPageIndex + 1} of $_pageCount',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  OutlinedButton.icon(
                    onPressed: (_currentPageIndex < _pageCount - 1 && !_isLoadingPdf)
                        ? () => _changePage(_currentPageIndex + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: const Text('Next'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Page Action Tools (Undo / Clear Page)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_redactionsByPage[_currentPageIndex]?.isNotEmpty ?? false)
                          ? _undoPageRedaction
                          : null,
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      label: const Text('Undo Last'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_redactionsByPage[_currentPageIndex]?.isNotEmpty ?? false)
                          ? _clearPageRedactions
                          : null,
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      label: const Text('Clear Page'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Main Export Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_totalRedactionCount == 0 || _isProcessing)
                      ? null
                      : _applyRedaction,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.find_replace_rounded),
                  label: Text(
                    'Redact & Export PDF ($_totalRedactionCount)',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
