import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({Key? key}) : super(key: key);
  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  final List<File> _pages = [];
  final Set<int> _selectedIndices = {};
  bool _isLoading = false;
  bool _isCapturing = false;
  bool _isReorderMode = false;
  String? _errorMessage;
  String? _successPath;

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
        setState(() {
          _pages.addAll(scans.map((p) => File(p)));
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

  Future<void> _pickGallery() async {
    if (_isCapturing || _isLoading) return;
    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 90);
      if (!mounted) return;
      setState(() => _isCapturing = false);
      if (picked.isNotEmpty) {
        setState(() {
          _pages.addAll(picked.map((x) => File(x.path)));
          _errorMessage = null;
          _successPath = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _errorMessage = 'Failed to pick from gallery: $e';
      });
    }
  }

  Future<void> _takePhoto() async {
    if (_isCapturing || _isLoading) return;
    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
      if (!mounted) return;
      setState(() => _isCapturing = false);
      if (photo != null) {
        setState(() {
          _pages.add(File(photo.path));
          _errorMessage = null;
          _successPath = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _errorMessage = 'Failed to capture photo: $e';
      });
    }
  }

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
      final path = FileService().joinPaths(dir.path, 'scan_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await File(path).writeAsBytes(await pdf.save());

      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Scan (${_pages.length} pages)',
        date: DateTime.now(),
        filePath: path,
        toolType: 'scan_to_pdf',
      ));

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successPath = path;
        _selectedIndices.clear();
      });

      if (mounted) {
        ShareService.showSaveShareDialog(context, path);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to build PDF: $e';
        _isLoading = false;
      });
    }
  }

  void _removePage(int index) {
    setState(() {
      _pages.removeAt(index);
      _selectedIndices.remove(index);
      if (_pages.isEmpty) {
        _isReorderMode = false;
        _selectedIndices.clear();
      }
    });
  }

  void _deleteSelectedPages() {
    if (_selectedIndices.isEmpty) return;
    setState(() {
      final sortedList = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
      for (final idx in sortedList) {
        if (idx < _pages.length) {
          _pages.removeAt(idx);
        }
      }
      _selectedIndices.clear();
      if (_pages.isEmpty) {
        _isReorderMode = false;
      }
    });
  }

  void _toggleSelectPage(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _showFullPreview(int initialIndex) {
    int currentIndex = initialIndex;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final file = _pages[currentIndex];
          return Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  title: Text('Page ${currentIndex + 1} of ${_pages.length}', style: const TextStyle(fontSize: 16)),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                      tooltip: 'Delete Page',
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        _removePage(currentIndex);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                    ),
                  ],
                ),
                Flexible(
                  child: InteractiveViewer(
                    child: Image.file(file, fit: BoxFit.contain),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: currentIndex > 0
                            ? () => setDialogState(() => currentIndex--)
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        label: const Text('Previous'),
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                      ),
                      Text(
                        FileService().getFileName(file.path),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      TextButton.icon(
                        onPressed: currentIndex < _pages.length - 1
                            ? () => setDialogState(() => currentIndex++)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: const Text('Next'),
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
                    ? 'Processing scanner input...'
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
                title: 'Scan Saved Successfully!',
                subtitle: 'Scanned document saved as PDF.',
                filePath: _successPath,
                onShare: () {
                  if (_successPath != null && mounted) {
                    ShareService.showSaveShareDialog(context, _successPath!);
                  }
                },
                onReset: () {
                  setState(() {
                    _successPath = null;
                    _pages.clear();
                    _errorMessage = null;
                    _isReorderMode = false;
                    _selectedIndices.clear();
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
                  onTap: (_isLoading || _isCapturing) ? () {} : _scanDocument,
                ),
                const SizedBox(width: 10),
                _ScanBtn(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: const Color(0xFF059669),
                  onTap: (_isLoading || _isCapturing) ? () {} : _takePhoto,
                ),
                const SizedBox(width: 10),
                _ScanBtn(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: const Color(0xFF8B5CF6),
                  onTap: (_isLoading || _isCapturing) ? () {} : _pickGallery,
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
                    subtitle: 'Tap "Scan Doc" for auto edge detection, or use Camera / Gallery to import pages',
                    actionLabel: 'Start Scanning',
                    onAction: (_isLoading || _isCapturing) ? null : _scanDocument,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_pages.isNotEmpty) ...[
                        // Page Count & Control Toolbar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Text(
                                '${_pages.length} scanned page${_pages.length > 1 ? 's' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              if (_selectedIndices.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_selectedIndices.length} selected',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primary),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (_selectedIndices.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626)),
                                  tooltip: 'Delete Selected',
                                  onPressed: _deleteSelectedPages,
                                ),
                              IconButton(
                                icon: Icon(
                                  _isReorderMode ? Icons.grid_view_rounded : Icons.reorder_rounded,
                                  color: primary,
                                  size: 20,
                                ),
                                tooltip: _isReorderMode ? 'Switch to Grid View' : 'Reorder Pages',
                                onPressed: () => setState(() => _isReorderMode = !_isReorderMode),
                              ),
                              if (!_isLoading && !_isCapturing)
                                TextButton(
                                  onPressed: () => setState(() {
                                    _pages.clear();
                                    _selectedIndices.clear();
                                    _errorMessage = null;
                                    _isReorderMode = false;
                                  }),
                                  child: const Text('Clear all', style: TextStyle(color: Color(0xFFDC2626))),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Main Page Content (Reorderable List vs Grid View)
                        Expanded(
                          child: _isReorderMode
                              ? ReorderableListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  itemCount: _pages.length,
                                  onReorder: (oldIndex, newIndex) {
                                    setState(() {
                                      if (newIndex > oldIndex) newIndex -= 1;
                                      final item = _pages.removeAt(oldIndex);
                                      _pages.insert(newIndex, item);
                                      _selectedIndices.clear();
                                    });
                                  },
                                  itemBuilder: (context, index) {
                                    final page = _pages[index];
                                    final isSelected = _selectedIndices.contains(index);
                                    return Card(
                                      key: ValueKey(page.path),
                                      margin: const EdgeInsets.only(bottom: 10),
                                      color: isSelected
                                          ? primary.withValues(alpha: isDark ? 0.2 : 0.08)
                                          : null,
                                      child: ListTile(
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Image.file(page, width: 44, height: 56, fit: BoxFit.cover),
                                        ),
                                        title: Text(
                                          'Page ${index + 1}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                                              icon: Icon(
                                                isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                                                color: isSelected ? primary : Colors.grey,
                                                size: 22,
                                              ),
                                              onPressed: () => _toggleSelectPage(index),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFDC2626), size: 20),
                                              onPressed: () => _removePage(index),
                                            ),
                                            ReorderableDragStartListener(
                                              index: index,
                                              child: const Icon(Icons.drag_handle_rounded),
                                            ),
                                          ],
                                        ),
                                        onTap: () => _showFullPreview(index),
                                      ),
                                    );
                                  },
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 0.72,
                                  ),
                                  itemCount: _pages.length,
                                  itemBuilder: (_, i) {
                                    final isSelected = _selectedIndices.contains(i);
                                    return GestureDetector(
                                      onTap: () => _showFullPreview(i),
                                      onLongPress: () => _toggleSelectPage(i),
                                      child: Stack(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color: bg,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isSelected ? primary : border,
                                                width: isSelected ? 2.5 : 1.0,
                                              ),
                                            ),
                                            clipBehavior: Clip.hardEdge,
                                            child: Image.file(_pages[i], fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                                          ),
                                          Positioned(
                                            bottom: 5,
                                            left: 5,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.65),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text('P${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                            ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            left: 4,
                                            child: GestureDetector(
                                              onTap: () => _toggleSelectPage(i),
                                              child: Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  color: isSelected ? primary : Colors.black.withValues(alpha: 0.4),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  isSelected ? Icons.check_rounded : Icons.circle_outlined,
                                                  color: Colors.white,
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
                                                  decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
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

                      // Bottom Action Toolbar (Save as PDF & Add Page)
                      if (_pages.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton.icon(
                                onPressed: (_isLoading || _isCapturing) ? null : _scanDocument,
                                icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                                label: const Text('Add Another Page', style: TextStyle(fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  minimumSize: const Size(double.infinity, 44),
                                  side: BorderSide(color: primary),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: (_isLoading || _isCapturing) ? null : _buildPdf,
                                  icon: _isLoading
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.picture_as_pdf_rounded),
                                  label: Text('Save as PDF (${_pages.length} pages)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
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

class _ScanBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ScanBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
