import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';

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
  pdfx.PdfController? _pdfController;
  int _pageCount = 0;
  int _currentPage = 1;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'PDF file not found at: ${widget.filePath}';
        });
        return;
      }

      final doc = await pdfx.PdfDocument.openFile(widget.filePath);
      if (!mounted) return;

      setState(() {
        _pageCount = doc.pagesCount;
        _pdfController = pdfx.PdfController(
          document: Future.value(doc),
          initialPage: 1,
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load PDF: $e';
      });
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: _currentPage > 1
                        ? () => _pdfController?.previousPage(
                              curve: Curves.ease,
                              duration: const Duration(milliseconds: 200),
                            )
                        : null,
                  ),
                  Text(
                    'Page $_currentPage / $_pageCount',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: _currentPage < _pageCount
                        ? () => _pdfController?.nextPage(
                              curve: Curves.ease,
                              duration: const Duration(milliseconds: 200),
                            )
                        : null,
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
            ],
          ),
        ),
      );
    }

    if (_pdfController == null) {
      return const Center(child: Text('Document preview unavailable.'));
    }

    return pdfx.PdfView(
      controller: _pdfController!,
      scrollDirection: Axis.vertical,
      pageSnapping: true,
      onPageChanged: (page) {
        if (mounted) {
          setState(() {
            _currentPage = page;
          });
        }
      },
    );
  }
}
