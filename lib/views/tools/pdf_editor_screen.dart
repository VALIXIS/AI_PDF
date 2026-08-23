import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/models/pdf_annotation.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

class PdfEditorScreen extends StatefulWidget {
  const PdfEditorScreen({Key? key}) : super(key: key);
  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  File? _pdfFile;
  pdfx.PdfDocument? _document;
  pdfx.PdfController? _pdfController;
  PageController? _pageController;
  int _pageCount = 0;
  int _currentPage = 0;
  bool _loading = false;
  bool _saving = false;
  bool _editMode = false;
  String? _activeTool; // 'text' | 'image' | null

  final Map<int, List<Annotation>> _annotations = {};
  Annotation? _selected;
  final _textEditCtrl = TextEditingController();
  String? _errorMessage;
  String? _successPath;

  @override
  void dispose() {
    _pageController?.dispose();
    _pdfController?.dispose();
    _document?.close();
    _textEditCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.isEmpty || result.files.single.path == null) return;
      setState(() {
        _loading = true;
        _pdfFile = null;
        _document = null;
        _pageController?.dispose();
        _pageController = null;
        _pdfController?.dispose();
        _pdfController = null;
        _annotations.clear();
        _selected = null;
        _errorMessage = null;
        _successPath = null;
      });

      final file = File(result.files.single.path!);
      if (!await FileService().isFileAccessible(file.path)) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorMessage = 'Selected file does not exist or is inaccessible';
        });
        return;
      }

      final doc = await pdfx.PdfDocument.openFile(file.path);
      final pdfCtrl = pdfx.PdfController(
        document: pdfx.PdfDocument.openFile(file.path),
        initialPage: 1,
      );
      final pageCtrl = PageController(initialPage: 0);

      if (!mounted) return;
      setState(() {
        _pdfFile = file;
        _document = doc;
        _pdfController = pdfCtrl;
        _pageController = pageCtrl;
        _pageCount = doc.pagesCount;
        _currentPage = 0;
        _loading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Could not open PDF: $e';
      });
    }
  }

  List<Annotation> get _pageAnnotations =>
      _annotations.putIfAbsent(_currentPage, () => []);

  void _addText(double rx, double ry) {
    const double defaultW = 0.4;
    const double defaultH = 0.06;
    final double clampedX = rx.clamp(0.0, (1.0 - defaultW).clamp(0.0, 1.0));
    final double clampedY = ry.clamp(0.0, (1.0 - defaultH).clamp(0.0, 1.0));
    final ann = Annotation.text(
      id: UniqueKey().toString(),
      x: clampedX,
      y: clampedY,
      width: defaultW,
      height: defaultH,
    );
    setState(() {
      _pageAnnotations.add(ann);
      _selected = ann;
      _textEditCtrl.text = ann.text;
      _activeTool = 'text';
    });
  }

  Future<void> _addImage(double rx, double ry) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Selected image file is empty';
        });
        return;
      }
      const double defaultW = 0.4;
      const double defaultH = 0.3;
      final double clampedX = rx.clamp(0.0, (1.0 - defaultW).clamp(0.0, 1.0));
      final double clampedY = ry.clamp(0.0, (1.0 - defaultH).clamp(0.0, 1.0));
      final ann = Annotation.image(
        id: UniqueKey().toString(),
        x: clampedX,
        y: clampedY,
        width: defaultW,
        height: defaultH,
        imageBytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _pageAnnotations.add(ann);
        _selected = ann;
        _activeTool = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to select image: $e';
      });
    }
  }

  Future<void> _savePdf() async {
    if (_pdfFile == null || _document == null) return;
    if (!await FileService().isFileAccessible(_pdfFile!.path)) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Original PDF file no longer exists or is inaccessible';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
      _successPath = null;
    });

    try {
      final savePath = await PdfService().saveEditedPdf(
        sourcePdfPath: _pdfFile!.path,
        annotationsByPage: _annotations,
      );

      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Edited: ${FileService().getFileName(_pdfFile!.path)}',
        date: DateTime.now(),
        filePath: savePath,
        toolType: 'pdf_editor',
      ));

      if (!mounted) return;
      setState(() {
        _saving = false;
        _successPath = savePath;
      });

      if (mounted) {
        ShareService.showSaveShareDialog(context, savePath);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'Save failed: $e';
      });
    }
  }

  void _nextPage() {
    if (_currentPage < _pageCount - 1) {
      final targetPage = _currentPage + 1;
      _pageController?.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
      _pdfController?.animateToPage(
        targetPage + 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      final targetPage = _currentPage - 1;
      _pageController?.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
      _pdfController?.animateToPage(
        targetPage + 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  int get _totalAnnotationsCount =>
      _annotations.values.fold(0, (sum, list) => sum + list.length);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0B13) : const Color(0xFFF0F0F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _pdfFile == null
                  ? 'PDF Editor'
                  : FileService().getFileName(_pdfFile!.path),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_pdfFile != null)
              Text(
                '$_pageCount page${_pageCount > 1 ? 's' : ''}'
                '${_totalAnnotationsCount > 0 ? ' • $_totalAnnotationsCount edit${_totalAnnotationsCount > 1 ? 's' : ''}' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          if (_document != null) ...[
            IconButton(
              icon: Icon(
                _editMode ? Icons.edit_off_rounded : Icons.edit_rounded,
                color: _editMode ? primary : null,
              ),
              tooltip: _editMode ? 'Switch to View Mode' : 'Switch to Edit Mode',
              onPressed: () => setState(() {
                _editMode = !_editMode;
                _selected = null;
                _activeTool = null;
              }),
            ),
            TextButton.icon(
              onPressed: _saving ? null : _savePdf,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.save_rounded, color: primary),
              label: Text(
                'Save',
                style: TextStyle(color: primary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Loading Banner
          if (_loading || _saving)
            ToolLoadingBanner(
              message: _loading ? 'Opening PDF document...' : 'Saving edited PDF...',
            ),

          // Error Banner
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ToolErrorBanner(
                message: _errorMessage!,
                onRetry: _pdfFile != null ? (_saving ? _savePdf : _pickPdf) : _pickPdf,
                onDismiss: () => setState(() => _errorMessage = null),
              ),
            ),

          // Success Card
          if (_successPath != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ToolSuccessCard(
                title: 'PDF Saved Successfully!',
                subtitle: 'Exported with annotations preserved.',
                filePath: _successPath,
                onShare: () {
                  if (_successPath != null && mounted) {
                    ShareService.showSaveShareDialog(context, _successPath!);
                  }
                },
                onReset: () {
                  setState(() {
                    _successPath = null;
                    _errorMessage = null;
                  });
                },
              ),
            ),

          // Main Editor or Empty State
          Expanded(
            child: _document == null
                ? ToolEmptyState(
                    icon: Icons.edit_document,
                    title: 'Open a PDF to Edit',
                    subtitle: 'View document pages, add text & image annotations, and export a clean PDF',
                    actionLabel: 'Choose PDF File',
                    onAction: _loading ? null : _pickPdf,
                  )
                : _buildEditorView(primary, isDark),
          ),
        ],
      ),
      floatingActionButton: _document != null && _editMode && _activeTool == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'img_fab',
                  backgroundColor: const Color(0xFF8B5CF6),
                  tooltip: 'Add Image Annotation',
                  onPressed: _saving ? null : () => setState(() => _activeTool = 'image'),
                  child: const Icon(Icons.image_rounded, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'txt_fab',
                  backgroundColor: primary,
                  tooltip: 'Add Text Annotation',
                  onPressed: _saving ? null : () => setState(() => _activeTool = 'text'),
                  child: const Icon(Icons.text_fields_rounded, color: Colors.white),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildEditorView(Color primary, bool isDark) {
    final cardBg = isDark ? const Color(0xFF14141E) : Colors.white;
    final border = isDark ? const Color(0xFF1F1F2E) : const Color(0xFFE5E7EB);

    return Column(
      children: [
        // Editor Control Header Barts
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: border)),
          ),
          child: Row(
            children: [
              // Mode switcher chips
              FilterChip(
                selected: !_editMode,
                avatar: const Icon(Icons.visibility_rounded, size: 16),
                label: const Text('View', style: TextStyle(fontSize: 12)),
                onSelected: (sel) {
                  if (sel) {
                    setState(() {
                      _editMode = false;
                      _selected = null;
                      _activeTool = null;
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: _editMode,
                avatar: Icon(Icons.edit_rounded, size: 16, color: _editMode ? Colors.white : null),
                label: Text(
                  'Edit Mode',
                  style: TextStyle(fontSize: 12, color: _editMode ? Colors.white : null),
                ),
                selectedColor: primary,
                onSelected: (sel) {
                  setState(() {
                    _editMode = sel;
                    if (!sel) {
                      _selected = null;
                      _activeTool = null;
                    }
                  });
                },
              ),
              const Spacer(),
              if (_editMode) ...[
                IconButton(
                  icon: Icon(
                    Icons.text_fields_rounded,
                    color: _activeTool == 'text' ? primary : null,
                  ),
                  tooltip: 'Text Tool',
                  onPressed: () => setState(() => _activeTool = _activeTool == 'text' ? null : 'text'),
                ),
                IconButton(
                  icon: Icon(
                    Icons.image_rounded,
                    color: _activeTool == 'image' ? const Color(0xFF8B5CF6) : null,
                  ),
                  tooltip: 'Image Tool',
                  onPressed: () => setState(() => _activeTool = _activeTool == 'image' ? null : 'image'),
                ),
              ],
            ],
          ),
        ),

        // Active Tool Instruction Banner
        if (_editMode && _activeTool != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: primary.withValues(alpha: 0.12),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded, color: primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap anywhere on Page ${_currentPage + 1} to place ${_activeTool == 'text' ? 'text' : 'an image'}',
                    style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _activeTool = null),
                  child: Icon(Icons.close_rounded, color: primary, size: 18),
                ),
              ],
            ),
          ),

        // Text Annotation Property Panel
        if (_editMode && _selected != null && _selected!.kind == AnnotationKind.text)
          _TextToolbar(
            annotation: _selected!,
            controller: _textEditCtrl,
            primary: primary,
            isDark: isDark,
            onChange: () => setState(() {}),
            onDelete: () => setState(() {
              _pageAnnotations.remove(_selected);
              _selected = null;
              _activeTool = null;
            }),
            onClose: () => setState(() => _selected = null),
          ),

        // Image Annotation Property Panel
        if (_editMode && _selected != null && _selected!.kind == AnnotationKind.image)
          _ImageToolbar(
            annotation: _selected!,
            primary: primary,
            isDark: isDark,
            onChange: () => setState(() {}),
            onDelete: () => setState(() {
              _pageAnnotations.remove(_selected);
              _selected = null;
            }),
          ),

        // Document Canvas View
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _pageCount,
            onPageChanged: (i) {
              setState(() {
                _currentPage = i;
                _selected = null;
              });
              if (_pdfController != null) {
                _pdfController!.animateToPage(
                  i + 1,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                );
              }
            },
            itemBuilder: (_, idx) => _buildPageCanvas(idx, primary, isDark),
          ),
        ),

        // Page Navigation & Control Bottom Bar
        _buildBottomPageBar(primary, isDark),
      ],
    );
  }

  Widget _buildPageCanvas(int pageIdx, Color primary, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            return GestureDetector(
              onTapUp: _editMode ? (details) {
                final rx = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 0.9);
                final ry = (details.localPosition.dy / constraints.maxHeight).clamp(0.0, 0.9);
                if (_activeTool == 'text') {
                  _addText(rx, ry);
                } else if (_activeTool == 'image') {
                  _addImage(rx, ry);
                } else {
                  setState(() {
                    _selected = null;
                  });
                }
              } : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    ignoring: _editMode,
                    child: _pdfController != null
                        ? pdfx.PdfView(
                            controller: _pdfController!,
                            pageSnapping: true,
                            scrollDirection: Axis.vertical,
                            physics: const NeverScrollableScrollPhysics(),
                            onPageChanged: (page) {
                              if (page - 1 != _currentPage) {
                                setState(() {
                                  _currentPage = page - 1;
                                  _selected = null;
                                });
                              }
                            },
                          )
                        : const SizedBox(),
                  ),
                  ...(_annotations[pageIdx] ?? []).map((ann) => _buildAnnotationWidget(ann, constraints, primary)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnnotationWidget(Annotation ann, BoxConstraints c, Color primary) {
    final isSel = _selected?.id == ann.id;
    final double left = (ann.x * c.maxWidth).clamp(0.0, c.maxWidth);
    final double top = (ann.y * c.maxHeight).clamp(0.0, c.maxHeight);
    final double width = (ann.width * c.maxWidth).clamp(20.0, c.maxWidth);
    final double height = (ann.height * c.maxHeight).clamp(15.0, c.maxHeight);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: _editMode
            ? () => setState(() {
                  _selected = ann;
                  if (ann.kind == AnnotationKind.text) {
                    _textEditCtrl.text = ann.text;
                    _activeTool = 'text';
                  } else {
                    _activeTool = null;
                  }
                })
            : null,
        onPanUpdate: _editMode
            ? (details) => setState(() {
                  final maxW = ann.width.clamp(0.01, 1.0);
                  final maxH = ann.height.clamp(0.01, 1.0);
                  ann.x = (ann.x + details.delta.dx / c.maxWidth).clamp(0.0, (1.0 - maxW).clamp(0.0, 1.0));
                  ann.y = (ann.y + details.delta.dy / c.maxHeight).clamp(0.0, (1.0 - maxH).clamp(0.0, 1.0));
                })
            : null,
        child: Container(
          decoration: isSel && _editMode
              ? BoxDecoration(
                  border: Border.all(color: primary, width: 2),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.25),
                      blurRadius: 6,
                    ),
                  ],
                )
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ann.kind == AnnotationKind.text
                    ? SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Text(
                          ann.text,
                          style: TextStyle(
                            fontSize: ann.fontSize,
                            fontWeight: ann.bold ? FontWeight.bold : FontWeight.normal,
                            color: ann.color,
                          ),
                        ),
                      )
                    : (ann.imageBytes != null && ann.imageBytes!.isNotEmpty
                        ? Image.memory(ann.imageBytes!, fit: BoxFit.contain)
                        : const SizedBox.shrink()),
              ),
              if (isSel && _editMode)
                Positioned(
                  top: -10,
                  right: -10,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _pageAnnotations.remove(ann);
                      _selected = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPageBar(Color primary, bool isDark) {
    final bg = isDark ? const Color(0xFF14141E) : Colors.white;
    final border = isDark ? const Color(0xFF1F1F2E) : const Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page Navigation Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: (_currentPage > 0 && !_saving) ? _prevPage : null,
                tooltip: 'Previous Page',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Page ${_currentPage + 1} of $_pageCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: (_currentPage < _pageCount - 1 && !_saving) ? _nextPage : null,
                tooltip: 'Next Page',
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Primary Actions
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickPdf,
                icon: const Icon(Icons.folder_open_rounded, size: 16),
                label: const Text('Change File'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary.withValues(alpha: 0.5)),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _saving ? null : _savePdf,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Text Annotation Property Toolbar ──────────────────────────────────────
class _TextToolbar extends StatelessWidget {
  final Annotation annotation;
  final TextEditingController controller;
  final Color primary;
  final bool isDark;
  final VoidCallback onChange;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const _TextToolbar({
    required this.annotation,
    required this.controller,
    required this.primary,
    required this.isDark,
    required this.onChange,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1A26) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF2D2D3F) : const Color(0xFFE2E8F0);

    const colors = [
      Colors.black,
      Colors.white,
      Color(0xFFE03131), // Red
      Color(0xFF2563EB), // Blue
      Color(0xFF16A34A), // Green
      Color(0xFFD97706), // Amber
      Color(0xFF7C3AED), // Purple
      Color(0xFF0D9488), // Teal
    ];

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Text Properties',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                tooltip: 'Delete Annotation',
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Close Panel',
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Text Field
          TextField(
            controller: controller,
            onChanged: (v) {
              annotation.text = v;
              onChange();
            },
            decoration: InputDecoration(
              hintText: 'Enter annotation text…',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        controller.clear();
                        annotation.text = '';
                        onChange();
                      },
                    )
                  : null,
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 10),

          // Size, Bold & Colors Row
          Row(
            children: [
              Text(
                '${annotation.fontSize.toInt()} pt',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                onPressed: annotation.fontSize > 8
                    ? () {
                        annotation.fontSize = (annotation.fontSize - 2).clamp(8, 48);
                        onChange();
                      }
                    : null,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Slider(
                  value: annotation.fontSize.clamp(8, 48),
                  min: 8,
                  max: 48,
                  activeColor: primary,
                  onChanged: (v) {
                    annotation.fontSize = v;
                    onChange();
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                onPressed: annotation.fontSize < 48
                    ? () {
                        annotation.fontSize = (annotation.fontSize + 2).clamp(8, 48);
                        onChange();
                      }
                    : null,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.format_bold_rounded,
                  color: annotation.bold ? primary : null,
                  size: 20,
                ),
                tooltip: 'Bold',
                onPressed: () {
                  annotation.bold = !annotation.bold;
                  onChange();
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Color Palette Swatches
          Row(
            children: [
              const Text(
                'Color:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  children: colors.map((c) {
                    final isSelected = annotation.color == c;
                    return GestureDetector(
                      onTap: () {
                        annotation.color = c;
                        onChange();
                      },
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? primary : Colors.grey.withValues(alpha: 0.4),
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: primary.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: c == Colors.white ? Colors.black : Colors.white,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Image toolbar ─────────────────────────────────────────────────────────
class _ImageToolbar extends StatelessWidget {
  final Annotation annotation;
  final Color primary;
  final bool isDark;
  final VoidCallback onChange, onDelete;
  const _ImageToolbar({
    required this.annotation,
    required this.primary,
    required this.isDark,
    required this.onChange,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF14141E) : Colors.white;
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        const Icon(Icons.photo_size_select_large_rounded, size: 20),
        const SizedBox(width: 8),
        const Text('Size:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Expanded(
          child: Slider(
            value: annotation.width.clamp(0.1, 0.95),
            min: 0.1,
            max: 0.95,
            activeColor: primary,
            onChanged: (v) {
              final ratio = annotation.height / (annotation.width > 0 ? annotation.width : 1.0);
              annotation.width = v;
              annotation.height = (v * (ratio.isFinite && ratio > 0 ? ratio : 0.75)).clamp(0.05, 0.95);
              onChange();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_rounded, color: Color(0xFFDC2626)),
          tooltip: 'Delete image annotation',
          onPressed: onDelete,
        ),
      ]),
    );
  }
}
