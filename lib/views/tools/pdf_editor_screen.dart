import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/models/pdf_annotation.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/ai_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_vector_editor_engine.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

class PdfEditorScreen extends StatefulWidget {
  final String? initialFilePath;
  const PdfEditorScreen({Key? key, this.initialFilePath}) : super(key: key);
  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  File? _pdfFile;
  Uint8List? _pdfBytes;
  pdfx.PdfDocument? _document;
  pdfx.PdfController? _pdfController;
  final PageController _pageController = PageController();
  int _pageCount = 0;
  int _currentPage = 0;
  bool _loading = false;
  bool _saving = false;
  bool _editMode = true;
  bool _detectTextMode = true;
  String? _activeTool; // 'text' | 'image' | 'vector_edit' | null

  double _pdfPageWidth = 595.2;
  double _pdfPageHeight = 841.8;

  final Map<int, List<Annotation>> _annotations = {};
  List<PdfTextBlock> _detectedBlocks = [];
  Annotation? _selected;
  final _textEditCtrl = TextEditingController();
  String? _errorMessage;
  String? _successPath;
  final AiService _aiService = AiService();

  @override
  void initState() {
    super.initState();
    if (widget.initialFilePath != null && widget.initialFilePath!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPdfFile(widget.initialFilePath!);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pdfController?.dispose();
    _document?.close();
    _textEditCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPdfFile(String filePath) async {
    try {
      if (!mounted) return;
      setState(() {
        _loading = true;
        _errorMessage = null;
        _successPath = null;
      });

      if (_document != null) {
        await _document?.close();
      }
      _pdfController?.dispose();

      _pdfFile = null;
      _pdfBytes = null;
      _document = null;
      _pdfController = null;
      _annotations.clear();
      _detectedBlocks.clear();
      _selected = null;
      _activeTool = null;

      final file = File(filePath);
      if (!await FileService().isFileAccessible(file.path) ||
          !await FileService().isPdfFile(file.path)) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorMessage = 'Selected file does not exist or is not a valid PDF.';
        });
        return;
      }

      final bytes = await file.readAsBytes();
      final doc = await pdfx.PdfDocument.openData(bytes);
      final pdfCtrl = pdfx.PdfController(
        document: Future.value(doc),
        initialPage: 1,
      );

      double pdfW = 595.2;
      double pdfH = 841.8;
      try {
        final sfDoc = sf.PdfDocument(inputBytes: bytes);
        if (sfDoc.pages.count > 0) {
          pdfW = sfDoc.pages[0].size.width;
          pdfH = sfDoc.pages[0].size.height;
        }
        sfDoc.dispose();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _pdfFile = file;
        _pdfBytes = bytes;
        _document = doc;
        _pdfController = pdfCtrl;
        _pageCount = doc.pagesCount;
        _currentPage = 0;
        _pdfPageWidth = pdfW;
        _pdfPageHeight = pdfH;
        _loading = false;
        _errorMessage = null;
      });

      _extractTextForCurrentPage();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Could not open PDF: $e';
      });
    }
  }

  Future<void> _reloadFromBytes(Uint8List newBytes, {int? targetPage}) async {
    try {
      setState(() {
        _loading = true;
      });

      if (_document != null) {
        await _document?.close();
      }
      _pdfController?.dispose();

      final doc = await pdfx.PdfDocument.openData(newBytes);
      final initialP = ((targetPage ?? _currentPage) + 1).clamp(1, doc.pagesCount);
      final pdfCtrl = pdfx.PdfController(
        document: Future.value(doc),
        initialPage: initialP,
      );

      // Persist working bytes to temporary file
      if (_pdfFile != null) {
        await _pdfFile!.writeAsBytes(newBytes, flush: true);
      }

      if (!mounted) return;
      setState(() {
        _pdfBytes = newBytes;
        _document = doc;
        _pdfController = pdfCtrl;
        _pageCount = doc.pagesCount;
        _currentPage = initialP - 1;
        _loading = false;
      });

      _extractTextForCurrentPage();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Error updating document: $e';
      });
    }
  }

  Future<void> _extractTextForCurrentPage() async {
    if (_pdfBytes == null) return;
    try {
      final blocks = await PdfVectorEditorEngine.extractTextBlocks(
        _pdfBytes!,
        _currentPage,
      );
      if (mounted) {
        setState(() {
          _detectedBlocks = blocks;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null) {
        return;
      }
      await _loadPdfFile(result.files.single.path!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'File selection failed: $e';
      });
    }
  }

  List<Annotation> get _pageAnnotations =>
      _annotations.putIfAbsent(_currentPage, () => []);

  void _addText(double rx, double ry) {
    final ann = Annotation.text(id: UniqueKey().toString(), x: rx, y: ry);
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
      final ann = Annotation.image(
        id: UniqueKey().toString(),
        x: rx,
        y: ry,
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

  /// Opens the interactive In-Place Vector Text Editor Dialog for a detected text block.
  void _editDetectedTextBlock(PdfTextBlock block) {
    final textCtrl = TextEditingController(text: block.text);
    final aiPromptCtrl = TextEditingController();
    bool isAiLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
            final primary = isDark ? kPrimaryDark : kPrimary;

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.edit_note_rounded, color: primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Edit Text In-Place',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Modify existing PDF text line directly:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: textCtrl,
                    maxLines: 3,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Enter replacement text',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF14141E) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // AI Restyler Section
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Color(0xFF8B5CF6), size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'AI Section Restyler / Polish',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: aiPromptCtrl,
                                decoration: InputDecoration(
                                  hintText: 'e.g. Fix grammar, make formal, translate to Spanish',
                                  filled: true,
                                  isDense: true,
                                  fillColor: isDark ? const Color(0xFF14141E) : const Color(0xFFF1F5F9),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: isAiLoading
                                  ? null
                                  : () async {
                                      final prompt = aiPromptCtrl.text.trim();
                                      if (prompt.isEmpty) return;
                                      setModalState(() => isAiLoading = true);
                                      try {
                                        final res = await _aiService.generateText(
                                          'Instruction: $prompt\nOriginal text: "${textCtrl.text}"\nOutput ONLY the rewritten text:',
                                          AiService.modeClean,
                                        );
                                        final clean = res.replaceAll(RegExp(r'^["`\*\s]+|["`\*\s]+$'), '').trim();
                                        if (clean.isNotEmpty) {
                                          textCtrl.text = clean;
                                        }
                                      } catch (_) {} finally {
                                        setModalState(() => isAiLoading = false);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: isAiLoading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Apply AI'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final newText = textCtrl.text.trim();
                            if (newText.isEmpty || _pdfBytes == null) return;
                            Navigator.pop(ctx);

                            final updatedBytes = await PdfVectorEditorEngine.replaceTextBlock(
                              pdfBytes: _pdfBytes!,
                              pageIndex: _currentPage,
                              targetBounds: block.bounds,
                              replacementText: newText,
                              newFontSize: block.fontSize,
                              isBold: block.isBold,
                              isItalic: block.isItalic,
                            );

                            await _reloadFromBytes(updatedBytes);
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Save Text Edit', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Opens Page Organizer Manager (Add blank page, delete page, reorder pages).
  void _openPageManager() {
    if (_pdfBytes == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.layers_rounded, color: Color(0xFF2563EB), size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Page Organizer ($_pageCount pages)',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.add_to_photos_rounded, color: Color(0xFF10B981)),
                  title: const Text('Insert Blank Page', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Add after Page ${_currentPage + 1}'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final updated = await PdfVectorEditorEngine.insertBlankPage(
                      pdfBytes: _pdfBytes!,
                      atIndex: _currentPage + 1,
                    );
                    await _reloadFromBytes(updated, targetPage: _currentPage + 1);
                  },
                ),
                if (_pageCount > 1) ...[
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    title: Text(
                      'Delete Page ${_currentPage + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.red),
                    ),
                    subtitle: const Text('Permanently remove this page from PDF'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final updated = await PdfVectorEditorEngine.deletePage(
                        pdfBytes: _pdfBytes!,
                        pageIndex: _currentPage,
                      );
                      await _reloadFromBytes(updated, targetPage: (_currentPage - 1).clamp(0, _pageCount - 2));
                    },
                  ),
                  if (_currentPage > 0)
                    ListTile(
                      leading: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF2563EB)),
                      title: const Text('Move Page Up / Left', style: TextStyle(fontWeight: FontWeight.w700)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final updated = await PdfVectorEditorEngine.reorderPages(
                          pdfBytes: _pdfBytes!,
                          oldIndex: _currentPage,
                          newIndex: _currentPage - 1,
                        );
                        await _reloadFromBytes(updated, targetPage: _currentPage - 1);
                      },
                    ),
                  if (_currentPage < _pageCount - 1)
                    ListTile(
                      leading: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF2563EB)),
                      title: const Text('Move Page Down / Right', style: TextStyle(fontWeight: FontWeight.w700)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final updated = await PdfVectorEditorEngine.reorderPages(
                          pdfBytes: _pdfBytes!,
                          oldIndex: _currentPage,
                          newIndex: _currentPage + 1,
                        );
                        await _reloadFromBytes(updated, targetPage: _currentPage + 1);
                      },
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
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

      // Prompt user to save directly to public Downloads/AIPDFMaker
      await ShareService.promptAndSaveFileDirectToDownloads(
        context,
        sourcePath: savePath,
        defaultPrefix: 'AIPDF_Edited',
      );
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
      setState(() {
        _currentPage = targetPage;
        _selected = null;
      });
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
      _pdfController?.animateToPage(
        targetPage + 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
      _extractTextForCurrentPage();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      final targetPage = _currentPage - 1;
      setState(() {
        _currentPage = targetPage;
        _selected = null;
      });
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
      _pdfController?.animateToPage(
        targetPage + 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
      _extractTextForCurrentPage();
    }
  }

  int get _totalAnnotationsCount =>
      _annotations.values.fold(0, (sum, list) => sum + list.length);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0B13) : const Color(0xFFF0F0F5),
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
                  color: isDark
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          if (_document != null) ...[
            IconButton(
              icon: const Icon(Icons.layers_rounded),
              tooltip: 'Manage Pages',
              onPressed: _openPageManager,
            ),
            IconButton(
              icon: Icon(
                _detectTextMode ? Icons.find_in_page_rounded : Icons.find_in_page_outlined,
                color: _detectTextMode ? const Color(0xFF10B981) : null,
              ),
              tooltip: _detectTextMode ? 'Text Detection ON' : 'Text Detection OFF',
              onPressed: () => setState(() => _detectTextMode = !_detectTextMode),
            ),
            TextButton.icon(
              onPressed: _saving ? null : _savePdf,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.download_rounded, color: primary),
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
              message:
                  _loading ? 'Processing vector PDF...' : 'Saving edited PDF...',
            ),

          // Error Banner
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ToolErrorBanner(
                message: _errorMessage!,
                onRetry: _pdfFile != null
                    ? (_saving ? _savePdf : _pickPdf)
                    : _pickPdf,
                onDismiss: () => setState(() => _errorMessage = null),
              ),
            ),

          // Success Card
          if (_successPath != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ToolSuccessCard(
                title: 'PDF Exported Successfully!',
                subtitle: 'Directly downloadable to Downloads/AIPDFMaker.',
                filePath: _successPath,
                onSave: () {
                  if (_successPath != null && mounted) {
                    ShareService.promptAndSaveFileDirectToDownloads(
                      context,
                      sourcePath: _successPath!,
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
                    subtitle:
                        'Detect and edit text in-place, manage pages, add annotations, and restyle with AI',
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
                  onPressed: _saving
                      ? null
                      : () => setState(() => _activeTool = 'image'),
                  child: const Icon(Icons.image_rounded, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'txt_fab',
                  backgroundColor: primary,
                  tooltip: 'Add Custom Text',
                  onPressed: _saving
                      ? null
                      : () => setState(() => _activeTool = 'text'),
                  child: const Icon(Icons.text_fields_rounded,
                      color: Colors.white),
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
        // Editor Control Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: border)),
          ),
          child: Row(
            children: [
              FilterChip(
                selected: _editMode,
                avatar: Icon(Icons.edit_rounded,
                    size: 16, color: _editMode ? Colors.white : null),
                label: Text(
                  'Vector Edit',
                  style: TextStyle(
                      fontSize: 12, color: _editMode ? Colors.white : null),
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
              const SizedBox(width: 8),
              FilterChip(
                selected: _detectTextMode,
                avatar: Icon(Icons.text_format_rounded,
                    size: 16, color: _detectTextMode ? Colors.white : null),
                label: Text(
                  'Text Detection',
                  style: TextStyle(
                      fontSize: 12, color: _detectTextMode ? Colors.white : null),
                ),
                selectedColor: const Color(0xFF10B981),
                onSelected: (sel) {
                  setState(() {
                    _detectTextMode = sel;
                  });
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.layers_outlined),
                tooltip: 'Page Organizer',
                onPressed: _openPageManager,
              ),
              IconButton(
                icon: Icon(
                  Icons.text_fields_rounded,
                  color: _activeTool == 'text' ? primary : null,
                ),
                tooltip: 'Add Custom Text',
                onPressed: () => setState(() =>
                    _activeTool = _activeTool == 'text' ? null : 'text'),
              ),
              IconButton(
                icon: Icon(
                  Icons.image_rounded,
                  color:
                      _activeTool == 'image' ? const Color(0xFF8B5CF6) : null,
                ),
                tooltip: 'Add Image',
                onPressed: () => setState(() =>
                    _activeTool = _activeTool == 'image' ? null : 'image'),
              ),
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
                    style: TextStyle(
                        color: primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
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
        if (_editMode &&
            _selected != null &&
            _selected!.kind == AnnotationKind.text)
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
        if (_editMode &&
            _selected != null &&
            _selected!.kind == AnnotationKind.image)
          _ImageToolbar(
            annotation: _selected!,
            primary: primary,
            isDark: isDark,
            onChange: () => setState(() {}),
            onDelete: () => setState(() {
              _pageAnnotations.remove(_selected);
              _selected = null;
              _activeTool = null;
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
              _pdfController?.jumpToPage(i + 1);
              _extractTextForCurrentPage();
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
              onTapUp: _editMode
                  ? (details) {
                      final rx =
                          (details.localPosition.dx / constraints.maxWidth)
                              .clamp(0.0, 0.9);
                      final ry =
                          (details.localPosition.dy / constraints.maxHeight)
                              .clamp(0.0, 0.9);
                      if (_activeTool == 'text') {
                        _addText(rx, ry);
                      } else if (_activeTool == 'image') {
                        _addImage(rx, ry);
                      } else {
                        setState(() {
                          _selected = null;
                        });
                      }
                    }
                  : null,
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
                                _extractTextForCurrentPage();
                              }
                            },
                          )
                        : const SizedBox(),
                  ),
                  // Detected Text Bounding Box Highlights (Tap to edit in-place)
                  if (_editMode && _detectTextMode && pageIdx == _currentPage)
                    ..._detectedBlocks.map((block) {
                      final pageWidth = _pdfPageWidth > 0 ? _pdfPageWidth : 595.2;
                      final pageHeight = _pdfPageHeight > 0 ? _pdfPageHeight : 841.8;

                      final pageAspect = pageWidth / pageHeight;
                      final containerAspect = constraints.maxWidth / constraints.maxHeight;

                      double renderW, renderH, offsetX, offsetY;
                      if (pageAspect > containerAspect) {
                        renderW = constraints.maxWidth;
                        renderH = constraints.maxWidth / pageAspect;
                        offsetX = 0;
                        offsetY = (constraints.maxHeight - renderH) / 2;
                      } else {
                        renderH = constraints.maxHeight;
                        renderW = constraints.maxHeight * pageAspect;
                        offsetX = (constraints.maxWidth - renderW) / 2;
                        offsetY = 0;
                      }

                      final scaleX = renderW / pageWidth;
                      final scaleY = renderH / pageHeight;

                      final left = (offsetX + block.bounds.left * scaleX).clamp(0.0, constraints.maxWidth - 20);
                      final top = (offsetY + block.bounds.top * scaleY).clamp(0.0, constraints.maxHeight - 15);
                      final width = (block.bounds.width * scaleX).clamp(15.0, constraints.maxWidth - left);
                      final height = (block.bounds.height * scaleY).clamp(10.0, 60.0);

                      return Positioned(
                        left: left,
                        top: top,
                        width: width,
                        height: height,
                        child: GestureDetector(
                          onTap: () => _editDetectedTextBlock(block),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      );
                    }),
                  ...(_annotations[pageIdx] ?? []).map((ann) =>
                      _buildAnnotationWidget(ann, constraints, primary)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnnotationWidget(
      Annotation ann, BoxConstraints c, Color primary) {
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
                  ann.x = (ann.x + details.delta.dx / c.maxWidth)
                      .clamp(0.0, 1.0 - (ann.width.clamp(0.01, 1.0)));
                  ann.y = (ann.y + details.delta.dy / c.maxHeight)
                      .clamp(0.0, 1.0 - (ann.height.clamp(0.01, 1.0)));
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
                            fontWeight:
                                ann.bold ? FontWeight.bold : FontWeight.normal,
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
                      child: const Icon(Icons.close_rounded,
                          size: 12, color: Colors.white),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                onPressed: (_currentPage < _pageCount - 1 && !_saving)
                    ? _nextPage
                    : null,
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
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFDC2626), size: 20),
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                onPressed: annotation.fontSize > 8
                    ? () {
                        annotation.fontSize =
                            (annotation.fontSize - 2).clamp(8, 48);
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
                        annotation.fontSize =
                            (annotation.fontSize + 2).clamp(8, 48);
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
                            color: isSelected
                                ? primary
                                : Colors.grey.withValues(alpha: 0.4),
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
                                color: c == Colors.white
                                    ? Colors.black
                                    : Colors.white,
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
        const Text('Size:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Expanded(
          child: Slider(
            value: annotation.width.clamp(0.1, 0.95),
            min: 0.1,
            max: 0.95,
            activeColor: primary,
            onChanged: (v) {
              final ratio = annotation.height /
                  (annotation.width > 0 ? annotation.width : 1.0);
              annotation.width = v;
              annotation.height =
                  (v * (ratio.isFinite && ratio > 0 ? ratio : 0.75))
                      .clamp(0.05, 0.95);
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
