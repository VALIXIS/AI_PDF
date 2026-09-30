import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

/// Represents a single visual page in the 3D grid reorganizer.
class VisualPdfPage {
  final String id;
  final int originalPageIndex; // 0-indexed
  int rotationAngle; // 0, 90, 180, 270
  final Uint8List? thumbnailBytes;

  VisualPdfPage({
    required this.id,
    required this.originalPageIndex,
    this.rotationAngle = 0,
    this.thumbnailBytes,
  });

  VisualPdfPage copyWith({
    String? id,
    int? originalPageIndex,
    int? rotationAngle,
    Uint8List? thumbnailBytes,
  }) {
    return VisualPdfPage(
      id: id ?? this.id,
      originalPageIndex: originalPageIndex ?? this.originalPageIndex,
      rotationAngle: rotationAngle ?? this.rotationAngle,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
    );
  }
}

class PdfPageReorganizerScreen extends StatefulWidget {
  final String? initialPdfPath;

  const PdfPageReorganizerScreen({
    Key? key,
    this.initialPdfPath,
  }) : super(key: key);

  @override
  State<PdfPageReorganizerScreen> createState() =>
      PdfPageReorganizerScreenState();
}

class PdfPageReorganizerScreenState extends State<PdfPageReorganizerScreen>
    with TickerProviderStateMixin {
  final FileService _fileService = FileService();
  final PdfService _pdfService = PdfService();
  final StorageService _storageService = StorageService();

  String? _selectedPdfPath;
  String? _pdfFileName;
  int _initialPageCount = 0;
  List<VisualPdfPage> _pages = [];
  List<VisualPdfPage> _initialPagesBackup = [];
  List<VisualPdfPage>? _lastDeletedPagesBackup;

  bool _isLoading = false;
  String _loadingMessage = '';
  String? _errorMessage;

  final ScrollController _scrollController = ScrollController();
  int? _draggingIndex;

  @override
  void initState() {
    super.initState();
    if (widget.initialPdfPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          loadPdf(widget.initialPdfPath!);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAndLoadPdf() async {
    if (_isLoading) return;
    setState(() {
      _errorMessage = null;
    });

    try {
      final selectedPath = await _fileService.pickPdfFile();
      if (!mounted || selectedPath == null) return;
      await loadPdf(selectedPath);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to select PDF: $e';
      });
    }
  }

  Future<void> loadPdf(String filePath) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Inspecting PDF pages...';
      _errorMessage = null;
    });

    try {
      if (!await _fileService.isFileAccessible(filePath)) {
        throw Exception('Selected PDF file does not exist or is inaccessible.');
      }
      if (!await _fileService.isPdfFile(filePath)) {
        throw Exception('Selected file is not a valid PDF document.');
      }

      final pageCount = await _pdfService.getPdfPageCount(filePath);
      if (pageCount <= 0) {
        throw Exception('Selected PDF contains no pages.');
      }

      setState(() {
        _loadingMessage = 'Generating high-definition page thumbnails...';
      });

      List<Uint8List> thumbnails = [];
      try {
        thumbnails = await _pdfService.getPdfPageThumbnails(filePath, scale: 1.0);
      } catch (_) {
        thumbnails = [];
      }

      final List<VisualPdfPage> loadedPages = [];
      for (int i = 0; i < pageCount; i++) {
        loadedPages.add(
          VisualPdfPage(
            id: 'page_${DateTime.now().microsecondsSinceEpoch}_$i',
            originalPageIndex: i,
            rotationAngle: 0,
            thumbnailBytes:
                (i < thumbnails.length && thumbnails[i].isNotEmpty)
                    ? thumbnails[i]
                    : null,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _selectedPdfPath = filePath;
        _pdfFileName = path.basename(filePath);
        _initialPageCount = pageCount;
        _pages = loadedPages;
        _initialPagesBackup = List.from(loadedPages);
        _lastDeletedPagesBackup = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _rotatePage(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      final current = _pages[index];
      final newAngle = (current.rotationAngle + 90) % 360;
      _pages[index] = current.copyWith(rotationAngle: newAngle);
    });
  }

  void _rotateAllPages() {
    HapticFeedback.mediumImpact();
    setState(() {
      for (int i = 0; i < _pages.length; i++) {
        final current = _pages[i];
        final newAngle = (current.rotationAngle + 90) % 360;
        _pages[i] = current.copyWith(rotationAngle: newAngle);
      }
    });
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rotated all pages 90° clockwise'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _deletePage(int index) {
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the last remaining page.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final removed = _pages[index];
    _lastDeletedPagesBackup = List.from(_pages);

    setState(() {
      _pages.removeAt(index);
    });

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Page ${index + 1} deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.amberAccent,
          onPressed: () {
            if (_lastDeletedPagesBackup != null) {
              setState(() {
                _pages = List.from(_lastDeletedPagesBackup!);
              });
            } else {
              setState(() {
                _pages.insert(index, removed);
              });
            }
          },
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _duplicatePage(int index) {
    HapticFeedback.lightImpact();
    final current = _pages[index];
    final duplicated = VisualPdfPage(
      id: 'dup_${DateTime.now().microsecondsSinceEpoch}_${current.originalPageIndex}',
      originalPageIndex: current.originalPageIndex,
      rotationAngle: current.rotationAngle,
      thumbnailBytes: current.thumbnailBytes,
    );

    setState(() {
      _pages.insert(index + 1, duplicated);
    });

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Page ${index + 1} duplicated'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetChanges() {
    if (_initialPagesBackup.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _pages = _initialPagesBackup
          .map((p) => VisualPdfPage(
                id: 'page_${DateTime.now().microsecondsSinceEpoch}_${p.originalPageIndex}',
                originalPageIndex: p.originalPageIndex,
                rotationAngle: 0,
                thumbnailBytes: p.thumbnailBytes,
              ))
          .toList();
    });
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reset all pages to original order'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _reorderPages(int oldIndex, int newIndex) {
    HapticFeedback.selectionClick();
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final VisualPdfPage item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);
    });
  }

  Future<void> _exportAndSave() async {
    if (_selectedPdfPath == null || _pages.isEmpty) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Assembling and saving reorganized PDF...';
      _errorMessage = null;
    });

    try {
      final items = _pages
          .map((p) => PdfPageReorganizeItem(
                originalPageIndex: p.originalPageIndex,
                rotationAngle: p.rotationAngle,
              ))
          .toList();

      final outputPath = await _pdfService.reorganizePdfPages(
        pdfPath: _selectedPdfPath!,
        pages: items,
      );

      // Save to history
      final baseTitle = path.basenameWithoutExtension(_selectedPdfPath!);
      await _storageService.addHistoryEntry(
        HistoryEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: '$baseTitle (Reorganized)',
          date: DateTime.now(),
          filePath: outputPath,
          toolType: 'organize_pages',
        ),
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      _showSuccessDialog(outputPath);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to reorganize PDF: $e';
      });
    }
  }

  void _showSuccessDialog(String outputPath) {
    ShareService.showSaveShareDialog(context, outputPath);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Reorganize & Rotate Pages',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (_selectedPdfPath != null) ...[
            IconButton(
              icon: const Icon(Icons.rotate_90_degrees_cw_rounded),
              tooltip: 'Rotate All 90°',
              onPressed: _isLoading ? null : _rotateAllPages,
            ),
            IconButton(
              icon: const Icon(Icons.restore_rounded),
              tooltip: 'Reset Order & Rotations',
              onPressed: _isLoading ? null : _resetChanges,
            ),
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Pick Another PDF',
              onPressed: _isLoading ? null : _pickAndLoadPdf,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ToolErrorBanner(
                  message: _errorMessage!,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),
              ),
            if (_isLoading)
              ToolLoadingBanner(message: _loadingMessage),
            Expanded(
              child: _selectedPdfPath == null
                  ? _buildEmptyState(isDark, primary, textCol)
                  : _buildReorganizerWorkspace(isDark, primary, textCol),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _selectedPdfPath == null
          ? null
          : _buildBottomActionBar(isDark, primary),
    );
  }

  Widget _buildEmptyState(bool isDark, Color primary, Color textCol) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: primary.withValues(alpha: 0.25),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                Icons.dashboard_customize_rounded,
                size: 64,
                color: primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Visual 3D Page Grid',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textCol,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Drag-and-drop to reorder, rotate pages 90°, delete, or duplicate pages with real-time 3D card physics.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickAndLoadPdf,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 4,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.file_open_rounded),
              label: const Text(
                'Select PDF to Reorganize',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReorganizerWorkspace(
      bool isDark, Color primary, Color textCol) {
    final modifiedCount = _pages.where((p) => p.rotationAngle != 0).length;
    final isPageCountChanged = _pages.length != _initialPageCount;

    return Column(
      children: [
        // Top Document Info Strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF131322).withValues(alpha: 0.9)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF222238)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_rounded,
                  color: Color(0xFFEF4444), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pdfFileName ?? 'Document.pdf',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: textCol,
                      ),
                    ),
                    Text(
                      '${_pages.length} pages total'
                      '${modifiedCount > 0 ? ' • $modifiedCount rotated' : ''}'
                      '${isPageCountChanged ? ' • page count modified' : ''}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Long-press & drag to reorder',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: primary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),

        // Grid of 3D Cards
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildReorderableGrid(isDark, primary),
          ),
        ),
      ],
    );
  }

  Widget _buildReorderableGrid(bool isDark, Color primary) {
    return ReorderableListView.builder(
      scrollController: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 90),
      itemCount: _pages.length,
      onReorderStart: (index) {
        setState(() => _draggingIndex = index);
      },
      onReorderEnd: (index) {
        setState(() => _draggingIndex = null);
      },
      onReorder: _reorderPages,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final double animValue = Curves.easeInOut.transform(animation.value);
            final double scale = lerpDouble(1.0, 1.06, animValue)!;
            return Transform.scale(
              scale: scale,
              child: Material(
                color: Colors.transparent,
                elevation: 16,
                shadowColor: primary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final page = _pages[index];
        return Container(
          key: ValueKey(page.id),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: _buildPageCard(
            page: page,
            displayIndex: index + 1,
            index: index,
            isDark: isDark,
            primary: primary,
          ),
        );
      },
    );
  }

  Widget _buildPageCard({
    required VisualPdfPage page,
    required int displayIndex,
    required int index,
    required bool isDark,
    required Color primary,
  }) {
    final bool isRotated = page.rotationAngle != 0;
    final bool isDuplicated =
        _pages.where((p) => p.originalPageIndex == page.originalPageIndex).length > 1;
    final bool isDragging = _draggingIndex == index;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: isDragging ? 0.35 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131324) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRotated
                ? primary.withValues(alpha: 0.5)
                : (isDark ? const Color(0xFF222238) : const Color(0xFFE2E8F0)),
            width: isRotated ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : const Color(0xFF64748B))
                  .withValues(alpha: 0.16),
              blurRadius: 12,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Top Bar: Page Index & Delete Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: isDark
                  ? const Color(0xFF1B1B2F)
                  : const Color(0xFFF1F5F9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Page $displayIndex',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                        if (displayIndex - 1 != page.originalPageIndex || isDuplicated)
                          Text(
                            ' (Orig #${page.originalPageIndex + 1})',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Delete Badge Button
                  GestureDetector(
                    onTap: () => _deletePage(index),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Thumbnail Area with 3D Animated Rotation
            Container(
              height: 220,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: isDark ? const Color(0xFF0C0C14) : const Color(0xFFF8FAFC),
              alignment: Alignment.center,
              child: AnimatedRotation(
                turns: page.rotationAngle / 360.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: page.thumbnailBytes != null &&
                        page.thumbnailBytes!.isNotEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            page.thumbnailBytes!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                    : _buildFallbackPageThumbnail(page, displayIndex, isDark),
              ),
            ),

            // Bottom Action Overlays: Rotate 90° & Duplicate Page
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: isDark
                  ? const Color(0xFF161628)
                  : const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  // Duplicate Button
                  TextButton.icon(
                    onPressed: () => _duplicatePage(index),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor:
                          primary.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(Icons.content_copy_rounded,
                        size: 14, color: primary),
                    label: Text(
                      'Duplicate',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Rotation angle badge
                  if (page.rotationAngle != 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${page.rotationAngle}°',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  // Rotate Button
                  ElevatedButton.icon(
                    onPressed: () => _rotatePage(index),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: isDark
                          ? const Color(0xFF262640)
                          : const Color(0xFFE2E8F0),
                      foregroundColor:
                          isDark ? Colors.white : const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.rotate_right_rounded, size: 16),
                    label: const Text(
                      'Rotate 90°',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildFallbackPageThumbnail(
      VisualPdfPage page, int displayIndex, bool isDark) {
    return Container(
      width: 140,
      height: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E30) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF33334D) : const Color(0xFFCBD5E1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.description_rounded,
                size: 20,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
              Text(
                '#$displayIndex',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white60 : Colors.black45,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              5,
              (i) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                height: 5,
                width: i == 4 ? 60 : double.infinity,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              'PDF Page',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Total Pages Counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_pages.length}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
                Text(
                  'Pages',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: primary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Primary Save & Export Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _exportAndSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: const Text(
                'Save & Export PDF',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
