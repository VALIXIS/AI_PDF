import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_cache_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';

/// Representation of a rasterized PDF page texture held in memory.
class _PageTextureData {
  final int pageNumber;
  final Uint8List bytes;
  final double width;
  final double height;
  final MemoryImage imageProvider;

  _PageTextureData({
    required this.pageNumber,
    required this.bytes,
    required this.width,
    required this.height,
    required this.imageProvider,
  });

  /// Releases resources and evicts the texture from Flutter's engine image cache.
  void dispose() {
    try {
      imageProvider.evict();
    } catch (_) {}
  }
}

class PdfDocumentViewerScreen extends StatefulWidget {
  final String filePath;

  const PdfDocumentViewerScreen({
    Key? key,
    required this.filePath,
  }) : super(key: key);

  @override
  State<PdfDocumentViewerScreen> createState() =>
      _PdfDocumentViewerScreenState();
}

class _PdfDocumentViewerScreenState extends State<PdfDocumentViewerScreen> {
  pdfx.PdfDocument? _pdfDocument;
  late final PageController _pageController;

  int _pageCount = 0;
  int _currentPage = 1;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isDisposed = false;

  // Viewport virtualized memory texture cache:
  // Strictly contains only visible page(s) + 1 ahead lookahead.
  // Offscreen page textures are discarded immediately to keep memory <120MB on large books.
  final Map<int, _PageTextureData> _renderedTextures = {};
  final Map<int, double> _aspectRatios = {};
  final Map<int, String> _renderErrors = {};
  final List<int> _renderQueue = [];
  bool _isProcessingQueue = false;

  int? _savedMaxImageCacheBytes;
  int? _savedMaxImageCacheCount;

  /// Visible page count currently rendered in memory.
  int get inMemoryPageCount => _renderedTextures.length;

  /// Estimated uncompressed texture memory currently in RAM/VRAM.
  int get estimatedTextureMemoryBytes {
    int total = 0;
    for (final tex in _renderedTextures.values) {
      total += (tex.width * tex.height * 4).toInt();
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    // Enforce strict image cache limits while viewing PDF to keep memory <120MB on large books
    _savedMaxImageCacheBytes =
        PaintingBinding.instance.imageCache.maximumSizeBytes;
    _savedMaxImageCacheCount = PaintingBinding.instance.imageCache.maximumSize;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 40 * 1024 * 1024; // 40 MB max
    PaintingBinding.instance.imageCache.maximumSize = 8;

    _initPdf();
  }

  Future<void> _initPdf() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'PDF file not found at: ${widget.filePath}';
        });
        return;
      }

      if (await file.length() == 0) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'PDF file is empty (0 bytes).';
        });
        return;
      }

      final doc = await pdfx.PdfDocument.openFile(widget.filePath);
      if (!mounted) {
        await doc.close();
        return;
      }

      final count = doc.pagesCount;
      if (count == 0) {
        await doc.close();
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'PDF document contains no pages.';
        });
        return;
      }

      _pdfDocument = doc;
      _pageCount = count;
      _currentPage = 1;

      // Extract initial page aspect ratio for placeholder layout stability
      try {
        final firstPage = await doc.getPage(1);
        final w = firstPage.width;
        final h = firstPage.height;
        if (w > 0 && h > 0) {
          _aspectRatios[1] = w / h;
        }
        await firstPage.close();
      } catch (_) {
        _aspectRatios[1] = 1.0 / 1.4142; // Standard A4 portrait aspect
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      // Virtualized render: visible page 1 and prefetch page 2 (+1 ahead)
      _updateViewportAndPrefetch(1);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load PDF: $e';
      });
    }
  }

  /// Calculates the active window of pages that are allowed in memory.
  /// Rule: strictly visible pages (+ 1 ahead).
  Set<int> _getActiveWindow() {
    if (_pageController.hasClients && _pageController.page != null) {
      final fractional = _pageController.page!;
      final floorP = fractional.floor() + 1;
      final ceilP = fractional.ceil() + 1;

      final window = <int>{floorP};
      if (ceilP <= _pageCount) {
        window.add(ceilP);
      }
      final lookAhead = ceilP + 1;
      if (lookAhead <= _pageCount) {
        window.add(lookAhead);
      }
      return window;
    } else {
      final window = <int>{_currentPage};
      if (_currentPage + 1 <= _pageCount) {
        window.add(_currentPage + 1);
      }
      return window;
    }
  }

  /// Discards offscreen page textures from memory and Flutter engine image cache.
  void _evictOffscreenTextures(Set<int> keepPages) {
    final toEvict = _renderedTextures.keys
        .where((pageNum) => !keepPages.contains(pageNum))
        .toList();

    for (final pageNum in toEvict) {
      final texture = _renderedTextures.remove(pageNum);
      texture?.dispose();
    }

    if (toEvict.isNotEmpty) {
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
  }

  /// Updates the active window, discards offscreen textures, and enqueues visible +1 ahead rendering.
  void _updateViewportAndPrefetch(int page) {
    if (_isDisposed || _pdfDocument == null) return;

    final activeWindow = _getActiveWindow();
    _evictOffscreenTextures(activeWindow);

    // Enqueue visible page first (highest priority)
    _enqueuePageRender(page);

    // Enqueue +1 ahead page (prefetch buffer)
    final nextAhead = page + 1;
    if (nextAhead <= _pageCount) {
      _enqueuePageRender(nextAhead);
    }
  }

  void _enqueuePageRender(int pageNumber) {
    if (pageNumber < 1 || pageNumber > _pageCount) return;
    if (_renderedTextures.containsKey(pageNumber)) return;
    if (_renderQueue.contains(pageNumber)) return;

    _renderQueue.add(pageNumber);
    _processRenderQueue();
  }

  Future<void> _processRenderQueue() async {
    if (_isProcessingQueue || _isDisposed || _pdfDocument == null) return;
    _isProcessingQueue = true;

    try {
      while (_renderQueue.isNotEmpty && !_isDisposed && mounted) {
        // Prioritize: ensure visible page is processed before prefetch pages
        if (_renderQueue.contains(_currentPage)) {
          _renderQueue.remove(_currentPage);
          _renderQueue.insert(0, _currentPage);
        }

        final pageNum = _renderQueue.removeAt(0);

        // Discard obsolete render request if page moved outside active window
        final currentActive = _getActiveWindow();
        if (!currentActive.contains(pageNum)) {
          continue;
        }

        if (_renderedTextures.containsKey(pageNum)) {
          continue;
        }

        await _renderSinglePage(pageNum);
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<void> _renderSinglePage(int pageNum) async {
    if (_isDisposed || !mounted || _pdfDocument == null) return;

    try {
      final page = await _pdfDocument!.getPage(pageNum);
      try {
        if (_isDisposed || !mounted || !_getActiveWindow().contains(pageNum)) {
          return;
        }

        final double pageWidth = page.width > 0 ? page.width : 595.0;
        final double pageHeight = page.height > 0 ? page.height : 842.0;
        _aspectRatios[pageNum] = pageWidth / pageHeight;

        // Render at crisp 2x scale for retina clarity without texture memory bloat
        const double scale = 2.0;
        final double targetW = pageWidth * scale;
        final double targetH = pageHeight * scale;

        final pageImage = await page.render(
          width: targetW,
          height: targetH,
          format: pdfx.PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );

        if (_isDisposed || !mounted || !_getActiveWindow().contains(pageNum)) {
          return;
        }

        if (pageImage != null && pageImage.bytes.isNotEmpty) {
          final imageProvider = MemoryImage(pageImage.bytes);
          final texture = _PageTextureData(
            pageNumber: pageNum,
            bytes: pageImage.bytes,
            width: targetW,
            height: targetH,
            imageProvider: imageProvider,
          );

          _renderedTextures[pageNum] = texture;

          // Evict any textures that slipped offscreen while rendering
          _evictOffscreenTextures(_getActiveWindow());

          if (mounted) {
            setState(() {});
          }
        }
      } finally {
        await page.close();
      }
    } catch (e) {
      debugPrint('Failed to render PDF page $pageNum: $e');
      if (mounted) {
        _renderErrors[pageNum] = e.toString();
        setState(() {});
      }
    }
  }

  void _jumpToPage(int page) {
    if (page < 1 || page > _pageCount) return;
    setState(() {
      _currentPage = page;
    });
    if (_pageController.hasClients) {
      final currentFractional = _pageController.page ?? (_currentPage - 1).toDouble();
      if ((page - 1 - currentFractional).abs() > 3) {
        _pageController.jumpToPage(page - 1);
      } else {
        _pageController.animateToPage(
          page - 1,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    }
    _updateViewportAndPrefetch(page);
  }

  void _showJumpToPageDialog() {
    final textController = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Jump to Page'),
          content: TextField(
            controller: textController,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Page Number (1 - $_pageCount)',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final target = int.tryParse(textController.text.trim());
                Navigator.of(dialogContext).pop();
                if (target != null && target >= 1 && target <= _pageCount) {
                  _jumpToPage(target);
                }
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _renderQueue.clear();
    _pageController.dispose();

    // Discard all rendered page textures and evict from imageCache
    for (final texture in _renderedTextures.values) {
      texture.dispose();
    }
    _renderedTextures.clear();
    _renderErrors.clear();
    _aspectRatios.clear();

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // Restore previous imageCache limits
    if (_savedMaxImageCacheBytes != null) {
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          _savedMaxImageCacheBytes!;
    }
    if (_savedMaxImageCacheCount != null) {
      PaintingBinding.instance.imageCache.maximumSize =
          _savedMaxImageCacheCount!;
    }

    try {
      _pdfDocument?.close();
    } catch (_) {}

    // Purge scratch export directories and cached bitmaps for this document
    FileService().purgeScratchExportDirectories();
    PdfCacheService().onToolOrViewerExit(pdfPath: widget.filePath);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final fileName = FileService().getFileName(widget.filePath);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fileName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_pageCount > 0)
              Text(
                'Page $_currentPage of $_pageCount',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
          ],
        ),
        actions: [
          if (_pageCount > 1)
            IconButton(
              icon: const Icon(Icons.find_in_page_outlined),
              tooltip: 'Jump to Page',
              onPressed: _showJumpToPageDialog,
            ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Save to Downloads',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final saved = await ShareService.saveFileDirectToPublicDownloads(
                sourcePath: widget.filePath,
                customFileName: fileName,
              );
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    saved != null
                        ? 'Saved to Downloads: $fileName'
                        : 'Download saved to device storage',
                  ),
                  backgroundColor: const Color(0xFF16A34A),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share Document',
            onPressed: () {
              ShareService.shareFile(
                context,
                filePath: widget.filePath,
                text: 'Here is my PDF document: $fileName',
              );
            },
          ),
        ],
      ),
      body: _buildBody(primary, isDark),
      bottomNavigationBar: _pageCount > 1
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14141E) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0xFF1F1F2E)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pageCount > 5) ...[
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: primary,
                        inactiveTrackColor:
                            isDark ? Colors.white12 : Colors.black12,
                        thumbColor: primary,
                      ),
                      child: Slider(
                        value: _currentPage
                            .toDouble()
                            .clamp(1.0, _pageCount.toDouble()),
                        min: 1,
                        max: _pageCount.toDouble(),
                        onChanged: (val) {
                          final page = val.round();
                          if (page != _currentPage) {
                            _jumpToPage(page);
                          }
                        },
                      ),
                    ),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: _currentPage > 1
                            ? () => _jumpToPage(_currentPage - 1)
                            : null,
                      ),
                      InkWell(
                        onTap: _showJumpToPageDialog,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Page $_currentPage / $_pageCount',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit_note_rounded,
                                size: 16,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: _currentPage < _pageCount
                            ? () => _jumpToPage(_currentPage + 1)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildBody(Color primary, bool isDark) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _initPdf();
                },
              ),
            ],
          ),
        ),
      );
    }

    if (_pageCount == 0 || _pdfDocument == null) {
      return const Center(child: Text('Document preview unavailable.'));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (_pageController.hasClients && _pageController.page != null) {
          final fractional = _pageController.page!;
          final floorPage = fractional.floor() + 1;
          final ceilPage = fractional.ceil() + 1;

          final active = <int>{floorPage};
          if (ceilPage <= _pageCount) {
            active.add(ceilPage);
          }
          final lookAhead = ceilPage + 1;
          if (lookAhead <= _pageCount) {
            active.add(lookAhead);
          }

          _evictOffscreenTextures(active);

          for (final p in active) {
            _enqueuePageRender(p);
          }
        }
        return false;
      },
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _pageCount,
        onPageChanged: (index) {
          final pageNum = index + 1;
          setState(() {
            _currentPage = pageNum;
          });
          _updateViewportAndPrefetch(pageNum);
        },
        itemBuilder: (context, index) {
          final pageNum = index + 1;
          return _buildPageItem(pageNum, primary, isDark);
        },
      ),
    );
  }

  Widget _buildPageItem(int pageNum, Color primary, bool isDark) {
    final texture = _renderedTextures[pageNum];
    final error = _renderErrors[pageNum];
    final aspect =
        _aspectRatios[pageNum] ?? _aspectRatios[1] ?? (1.0 / 1.4142);

    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      clipBehavior: Clip.none,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: AspectRatio(
            aspectRatio: aspect,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: texture != null
                  ? Image(
                      image: texture.imageProvider,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    )
                  : error != null
                      ? _buildPageError(pageNum, error, primary, isDark)
                      : _buildPagePlaceholder(pageNum, primary, isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPagePlaceholder(int pageNum, Color primary, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF9FAFB),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: primary.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Rendering page $pageNum...',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageError(
      int pageNum, String error, Color primary, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF2C1E1E) : const Color(0xFFFEE2E2),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 36),
            const SizedBox(height: 8),
            Text(
              'Could not render page $pageNum',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              onPressed: () {
                _renderErrors.remove(pageNum);
                _enqueuePageRender(pageNum);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}
