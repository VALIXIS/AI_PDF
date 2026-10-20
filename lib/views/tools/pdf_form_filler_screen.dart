import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/pdf_annotation.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

class PdfFormFillerScreen extends StatefulWidget {
  final String? initialFilePath;

  const PdfFormFillerScreen({Key? key, this.initialFilePath}) : super(key: key);

  /// Calculates the standard PDF text field height in PDF points for a given font size.
  /// Standard single-line PDF form text fields conform to ~1.45x font size (typically 20-24pt for 12-14pt fonts).
  static double standardPdfFieldHeight(double fontSize) {
    return (fontSize * 1.45).clamp(18.0, 72.0);
  }

  /// Calculates the calibrated font baseline offset from the top of a standard PDF text field.
  /// In standard PDF text fields (AcroForm single-line fields), text is vertically centered
  /// with the font baseline positioned at:
  ///   baseline = (fieldHeight - (ascent + descent)) / 2 + ascent
  /// Using Helvetica metrics per ISO 32000-1 (ascent ~ 0.772, descent ~ 0.228).
  static double standardPdfFontBaseline({
    required double fontSize,
    required double fieldHeight,
  }) {
    const ascentRatio = 0.772;
    const descentRatio = 0.228;
    final fontAscent = fontSize * ascentRatio;
    final fontDescent = fontSize * descentRatio;
    final verticalMargin = (fieldHeight - (fontAscent + fontDescent)) / 2.0;
    return verticalMargin + fontAscent;
  }

  @override
  State<PdfFormFillerScreen> createState() => _PdfFormFillerScreenState();
}

enum FormToolMode { select, text, checkmark, dateStamp, highlight }

class _PdfFormFillerScreenState extends State<PdfFormFillerScreen> {
  File? _pdfFile;
  pdfx.PdfDocument? _document;
  pdfx.PdfController? _pdfController;
  int _pageCount = 0;
  int _currentPage = 0;
  bool _loading = false;
  bool _exporting = false;
  String? _errorMessage;

  FormToolMode _activeTool = FormToolMode.text;
  Annotation? _selectedAnnotation;

  // Annotations stored by page index (0-indexed)
  final Map<int, List<Annotation>> _annotations = {};

  final TextEditingController _textController = TextEditingController();
  double _pdfPageWidth = 595.2;
  double _pdfPageHeight = 841.8;

  // Presets
  final List<Color> _colorPalette = const [
    Colors.black,
    Color(0xFF1E293B), // Dark Slate
    Color(0xFFE03131), // Brand Red
    Color(0xFF0EA5E9), // Sky Blue
    Color(0xFF10B981), // Emerald
    Color(0xFF8B5CF6), // Violet
    Color(0xFFF59E0B), // Amber
    Colors.white,
  ];

  final List<Color> _highlightPalette = const [
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF818CF8), // Soft Purple
    Color(0xFF34D399), // Soft Green
    Color(0xFF38BDF8), // Soft Blue
    Color(0xFFFB7185), // Soft Pink
    Color(0xFFFBBF24), // Amber
  ];

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
    _pdfController?.dispose();
    _document?.close();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadPdfFile(String filePath) async {
    try {
      if (!mounted) return;
      setState(() {
        _loading = true;
        _errorMessage = null;
      });

      if (_document != null) {
        await _document?.close();
      }
      _pdfController?.dispose();

      _pdfFile = null;
      _document = null;
      _pdfController = null;
      _annotations.clear();
      _selectedAnnotation = null;

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
        _document = doc;
        _pdfController = pdfCtrl;
        _pageCount = doc.pagesCount;
        _currentPage = 0;
        _pdfPageWidth = pdfW;
        _pdfPageHeight = pdfH;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Could not open PDF document: $e';
      });
    }
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
        _errorMessage = 'File selection failed: $e';
      });
    }
  }

  static double standardPdfFieldHeight(double fontSize) =>
      PdfFormFillerScreen.standardPdfFieldHeight(fontSize);

  static double standardPdfFontBaseline({
    required double fontSize,
    required double fieldHeight,
  }) =>
      PdfFormFillerScreen.standardPdfFontBaseline(
        fontSize: fontSize,
        fieldHeight: fieldHeight,
      );

  List<Annotation> get _currentPageAnnotations =>
      _annotations.putIfAbsent(_currentPage, () => []);

  void _addAnnotationAt(double rx, double ry) {
    if (_pdfFile == null) return;
    Annotation ann;
    final id = UniqueKey().toString();

    switch (_activeTool) {
      case FormToolMode.text:
        const fontSize = 14.0;
        final fieldH = standardPdfFieldHeight(fontSize);
        final baselineOffset = standardPdfFontBaseline(
          fontSize: fontSize,
          fieldHeight: fieldH,
        );
        final normH = fieldH / _pdfPageHeight;
        final normBaselineOffset = baselineOffset / _pdfPageHeight;
        // User tapped on the form line: calibrate baseline to land directly on the tapped position
        final startY = (ry - normBaselineOffset).clamp(0.0, 1.0 - normH);

        ann = Annotation.text(
          id: id,
          x: rx.clamp(0.0, 0.75),
          y: startY,
          text: 'Tap to edit text',
          fontSize: fontSize,
          color: Colors.black,
          width: 0.28,
          height: normH,
        );
        break;
      case FormToolMode.checkmark:
        const checkFontSize = 22.0;
        final checkSize = checkFontSize * 1.1;
        final normW = checkSize / _pdfPageWidth;
        final normH = checkSize / _pdfPageHeight;
        // Center checkmark directly on tapped position (e.g. inside checkbox)
        final startX = (rx - normW / 2).clamp(0.0, 1.0 - normW);
        final startY = (ry - normH / 2).clamp(0.0, 1.0 - normH);

        ann = Annotation.checkmark(
          id: id,
          x: startX,
          y: startY,
          color: const Color(0xFF10B981),
          fontSize: checkFontSize,
          width: normW,
          height: normH,
        );
        break;
      case FormToolMode.dateStamp:
        final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        const fontSize = 12.0;
        final fieldH = standardPdfFieldHeight(fontSize);
        final baselineOffset = standardPdfFontBaseline(
          fontSize: fontSize,
          fieldHeight: fieldH,
        );
        final normH = fieldH / _pdfPageHeight;
        final normBaselineOffset = baselineOffset / _pdfPageHeight;
        final startY = (ry - normBaselineOffset).clamp(0.0, 1.0 - normH);

        ann = Annotation.dateStamp(
          id: id,
          x: rx.clamp(0.0, 0.7),
          y: startY,
          text: dateStr,
          fontSize: fontSize,
          color: const Color(0xFF1E293B),
          width: 0.25,
          height: normH,
        );
        break;
      case FormToolMode.highlight:
        ann = Annotation.highlight(
          id: id,
          x: rx.clamp(0.0, 0.6),
          y: (ry - 0.018).clamp(0.0, 0.96),
          width: 0.35,
          height: 0.035,
          color: const Color(0xFFFFEB3B),
          opacity: 0.4,
        );
        break;
      case FormToolMode.select:
        return;
    }

    setState(() {
      _currentPageAnnotations.add(ann);
      _selectedAnnotation = ann;
      _textController.text = ann.text;
    });
  }

  void _selectAnnotation(Annotation ann) {
    setState(() {
      _selectedAnnotation = ann;
      _textController.text = ann.text;
    });
  }

  void _deleteSelectedAnnotation() {
    if (_selectedAnnotation == null) return;
    setState(() {
      _currentPageAnnotations.removeWhere((a) => a.id == _selectedAnnotation!.id);
      _selectedAnnotation = null;
    });
  }

  Future<void> _pickDateForSelected() async {
    if (_selectedAnnotation == null) return;
    final initialDate = DateTime.tryParse(_selectedAnnotation!.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final formatted = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        _selectedAnnotation!.text = formatted;
        _textController.text = formatted;
      });
    }
  }

  Future<void> _exportPdf() async {
    if (_pdfFile == null) return;

    int totalAnnotations = 0;
    _annotations.forEach((_, list) => totalAnnotations += list.length);

    if (totalAnnotations == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one annotation or form field to export.'),
        ),
      );
      return;
    }

    try {
      setState(() {
        _exporting = true;
        _errorMessage = null;
      });

      final pdfService = PdfService();
      final String outputPath = await pdfService.saveEditedPdf(
        sourcePdfPath: _pdfFile!.path,
        annotationsByPage: _annotations,
      );

      // Save to history log
      try {
        await StorageService().addHistoryEntry(
          HistoryEntry(
            id: UniqueKey().toString(),
            title: 'Form Filled - ${FileService().getFileName(_pdfFile!.path)}',
            filePath: outputPath,
            date: DateTime.now(),
            toolType: 'pdf_form_filler',
          ),
        );
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _exporting = false;
      });

      _showExportSuccessDialog(outputPath);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _errorMessage = 'Export failed: $e';
      });
    }
  }

  void _showExportSuccessDialog(String outputPath) {
    final fileName = FileService().getFileName(outputPath);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              alignment: Alignment.center,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF10B981),
              size: 54,
            ),
            const SizedBox(height: 12),
            const Text(
              'PDF Exported Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              fileName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ShareService.shareFile(context, filePath: outputPath);
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ShareService.promptAndSaveFileDirectToDownloads(
                        context,
                        sourcePath: outputPath,
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Save to Device'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Form Filler & Annotator'),
        elevation: 0,
        actions: [
          if (_pdfFile != null) ...[
            TextButton.icon(
              onPressed: _exporting ? null : _exportPdf,
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_alt_rounded, size: 20),
              label: const Text('Export'),
              style: TextButton.styleFrom(
                foregroundColor: primary,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ToolErrorBanner(
                  message: _errorMessage!,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),
              ),

            if (_pdfFile == null && !_loading)
              Expanded(child: _buildEmptyState(primary, isDark))
            else if (_loading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading PDF document...'),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    // Toolbar
                    _buildToolBar(primary, isDark),

                    // Main PDF Canvas View
                    Expanded(
                      child: Stack(
                        children: [
                          _buildPdfCanvas(isDark),
                          if (_exporting)
                            Container(
                              color: Colors.black.withValues(alpha: 0.4),
                              child: const Center(
                                child: Card(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text(
                                          'Burning Vector Annotations...',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Page Navigation & Footer Controls
                    _buildPageControls(isDark),

                    // Annotation Property Editor Panel (when annotation selected)
                    if (_selectedAnnotation != null)
                      _buildAnnotationEditorPanel(primary, isDark),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color primary, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_turned_in_rounded,
                size: 64,
                color: primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Interactive PDF Form Filler',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap anywhere on a PDF to add text fields, checkmarks,\ndate stamps, or highlight boxes without quality loss.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickPdf,
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Select PDF Document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolBar(Color primary, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildToolChip(
              mode: FormToolMode.text,
              icon: Icons.text_fields_rounded,
              label: 'Text Field',
              primary: primary,
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildToolChip(
              mode: FormToolMode.checkmark,
              icon: Icons.check_box_rounded,
              label: 'Checkmark',
              primary: primary,
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildToolChip(
              mode: FormToolMode.dateStamp,
              icon: Icons.today_rounded,
              label: 'Date Stamp',
              primary: primary,
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildToolChip(
              mode: FormToolMode.highlight,
              icon: Icons.border_color_rounded,
              label: 'Highlight Box',
              primary: primary,
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildToolChip(
              mode: FormToolMode.select,
              icon: Icons.near_me_rounded,
              label: 'Select / Move',
              primary: primary,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolChip({
    required FormToolMode mode,
    required IconData icon,
    required String label,
    required Color primary,
    required bool isDark,
  }) {
    final isSelected = _activeTool == mode;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48.0),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        avatar: Icon(
          icon,
          size: 16,
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        ),
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        ),
        selectedColor: primary,
        backgroundColor: isDark ? const Color(0xFF2A2A3C) : const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected
                ? primary
                : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
          ),
        ),
        onSelected: (_) {
          setState(() {
            _activeTool = mode;
            _selectedAnnotation = null;
          });
        },
      ),
    );
  }

  Widget _buildPdfCanvas(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasW = constraints.maxWidth * 0.95;
        final canvasH = canvasW * (_pdfPageHeight / _pdfPageWidth);

        return Container(
          color: isDark ? const Color(0xFF0F0F16) : const Color(0xFFE2E8F0),
          child: Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              clipBehavior: Clip.none,
              child: GestureDetector(
                onTapUp: (details) {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final localPos = details.localPosition;
                  final width = box.size.width;
                  final height = box.size.height;
                  if (width > 0 && height > 0) {
                    final rx = localPos.dx / width;
                    final ry = localPos.dy / height;
                    _addAnnotationAt(rx, ry);
                  }
                },
                child: Container(
                  width: canvasW,
                  height: canvasH,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // PDF Renderer page
                      if (_pdfController != null)
                        pdfx.PdfView(
                          controller: _pdfController!,
                          onPageChanged: (page) {
                            setState(() {
                              _currentPage = page - 1;
                              _selectedAnnotation = null;
                            });
                          },
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                        ),

                      // Overlay Interactive Annotations
                      ..._currentPageAnnotations.map((ann) {
                        return _buildAnnotationWidget(
                          ann,
                          canvasW,
                          canvasH,
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnnotationWidget(
      Annotation ann, double canvasWidth, double canvasHeight) {
    final isSelected = _selectedAnnotation?.id == ann.id;
    final left = ann.x * canvasWidth;
    final top = ann.y * canvasHeight;
    final scale = _pdfPageHeight > 0 ? (canvasHeight / _pdfPageHeight) : 0.5;

    double visualWidth;
    double visualHeight;
    if (ann.kind == AnnotationKind.checkmark) {
      visualWidth = (ann.fontSize * 1.1 * scale).clamp(12.0, canvasWidth);
      visualHeight = (ann.fontSize * 1.1 * scale).clamp(12.0, canvasHeight);
    } else {
      visualWidth = (ann.width * canvasWidth).clamp(20.0, canvasWidth);
      visualHeight = (ann.height * canvasHeight).clamp(14.0, canvasHeight);
    }

    // Ensure tap targets have at least 48x48dp padding to prevent accidental misses on small screens
    const double minTapTargetSize = 48.0;
    final double touchWidth = math.max(minTapTargetSize, visualWidth);
    final double touchHeight = math.max(minTapTargetSize, visualHeight);
    final double padX = (touchWidth - visualWidth) / 2.0;
    final double padY = (touchHeight - visualHeight) / 2.0;

    return Positioned(
      key: ValueKey(ann.id),
      left: left - padX,
      top: top - padY,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _selectAnnotation(ann),
        onPanStart: ann.isLocked ? null : (_) => _selectAnnotation(ann),
        onPanUpdate: ann.isLocked
            ? null
            : (details) {
                if (canvasWidth <= 0 || canvasHeight <= 0) return;
                setState(() {
                  ann.x = (ann.x + details.delta.dx / canvasWidth).clamp(0.0, 0.95);
                  ann.y = (ann.y + details.delta.dy / canvasHeight).clamp(0.0, 0.95);
                });
              },
        child: Container(
          width: touchWidth,
          height: touchHeight,
          color: Colors.transparent, // Ensures entire 48x48dp hit area is responsive
          alignment: Alignment.center,
          child: Container(
            width: visualWidth,
            height: visualHeight,
            decoration: BoxDecoration(
              color: ann.kind == AnnotationKind.highlight
                  ? ann.color.withValues(alpha: ann.opacity)
                  : (ann.backgroundColor ?? Colors.transparent),
              border: Border.all(
                color: ann.isLocked
                    ? Colors.amber.withValues(alpha: 0.6)
                    : (isSelected
                        ? kPrimary
                        : (ann.kind == AnnotationKind.highlight
                            ? Colors.transparent
                            : Colors.blue.withValues(alpha: 0.3))),
                width: isSelected ? 2.0 : 1.0,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: EdgeInsets.zero,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _renderAnnotationContent(
                  ann,
                  scale,
                  visualWidth,
                  visualHeight,
                ),
                if (ann.isLocked)
                  const Positioned(
                    right: -4,
                    top: -4,
                    child: Icon(
                      Icons.lock_rounded,
                      size: 10,
                      color: Colors.amber,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _renderAnnotationContent(
    Annotation ann,
    double scale,
    double visualWidth,
    double visualHeight,
  ) {
    switch (ann.kind) {
      case AnnotationKind.text:
      case AnnotationKind.dateStamp:
        final scaledFontSize = ann.fontSize * scale;
        // Calibrate font baseline offset relative to standard PDF text fields
        final baselineOffset = standardPdfFontBaseline(
          fontSize: scaledFontSize,
          fieldHeight: visualHeight,
        );
        return SizedBox(
          width: visualWidth,
          height: visualHeight,
          child: Align(
            alignment: Alignment.topLeft,
            child: Baseline(
              baseline: baselineOffset,
              baselineType: TextBaseline.alphabetic,
              child: Text(
                ann.text,
                style: TextStyle(
                  fontSize: scaledFontSize,
                  color: ann.color,
                  fontWeight: ann.bold ? FontWeight.bold : FontWeight.normal,
                  fontFamily: 'Helvetica',
                  height: 1.0,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        );

      case AnnotationKind.checkmark:
        return Center(
          child: Icon(
            Icons.check_rounded,
            size: ann.fontSize * 1.1 * scale,
            color: ann.color,
          ),
        );

      case AnnotationKind.highlight:
        return Container(); // Highlight color is in the container background

      case AnnotationKind.image:
        if (ann.imageBytes != null) {
          return Image.memory(ann.imageBytes!, fit: BoxFit.cover);
        }
        return const Icon(Icons.image);
    }
  }

  Widget _buildPageControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: const EdgeInsets.all(12),
                onPressed: _currentPage > 0
                    ? () => _pdfController?.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        )
                    : null,
              ),
              Text(
                'Page ${_currentPage + 1} of $_pageCount',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: const EdgeInsets.all(12),
                onPressed: _currentPage < _pageCount - 1
                    ? () => _pdfController?.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        )
                    : null,
              ),
            ],
          ),
          Row(
            children: [
              if (_currentPageAnnotations.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      final allLocked =
                          _currentPageAnnotations.every((a) => a.isLocked);
                      for (final a in _currentPageAnnotations) {
                        a.isLocked = !allLocked;
                      }
                    });
                  },
                  icon: Icon(
                    _currentPageAnnotations.every((a) => a.isLocked)
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                    size: 16,
                    color: Colors.amber[700],
                  ),
                  label: Text(
                    _currentPageAnnotations.every((a) => a.isLocked)
                        ? 'Locked'
                        : 'Lock All',
                    style: TextStyle(fontSize: 12.5, color: Colors.amber[800]),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                '${_currentPageAnnotations.length} item(s)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnnotationEditorPanel(Color primary, bool isDark) {
    final ann = _selectedAnnotation!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181824) : const Color(0xFFF8FAFC),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Title, Quick Actions & Delete
          Row(
            children: [
              Icon(
                ann.kind == AnnotationKind.checkmark
                    ? Icons.check_circle_outline_rounded
                    : ann.kind == AnnotationKind.dateStamp
                        ? Icons.event_rounded
                        : ann.kind == AnnotationKind.highlight
                            ? Icons.border_color_rounded
                            : Icons.title_rounded,
                size: 18,
                color: primary,
              ),
              const SizedBox(width: 8),
              Text(
                ann.kind == AnnotationKind.checkmark
                    ? 'Checkmark Properties'
                    : ann.kind == AnnotationKind.dateStamp
                        ? 'Date Stamp Properties'
                        : ann.kind == AnnotationKind.highlight
                            ? 'Highlight Properties'
                            : 'Text Field Properties',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              const Spacer(),
              if (ann.kind == AnnotationKind.dateStamp)
                IconButton(
                  icon: const Icon(Icons.edit_calendar_rounded, size: 20),
                  onPressed: _pickDateForSelected,
                  tooltip: 'Select Date',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  padding: const EdgeInsets.all(12),
                ),
              IconButton(
                icon: Icon(
                  ann.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: ann.isLocked ? Colors.amber[700] : Colors.grey[600],
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    ann.isLocked = !ann.isLocked;
                  });
                },
                tooltip: ann.isLocked ? 'Unlock Position' : 'Lock Field in Place',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: const EdgeInsets.all(12),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 20),
                onPressed: _deleteSelectedAnnotation,
                tooltip: 'Delete Field',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: const EdgeInsets.all(12),
              ),
            ],
          ),

          // Row 2: Text Editing Input (for text and dateStamp)
          if (ann.kind == AnnotationKind.text ||
              ann.kind == AnnotationKind.dateStamp) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Enter text value...',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (val) {
                setState(() {
                  ann.text = val;
                });
              },
            ),
          ],

          const SizedBox(height: 10),

          // Row 3: Styling controls (Font size / Size slider & Color Palette)
          Row(
            children: [
              // Font Size Slider
              if (ann.kind != AnnotationKind.highlight) ...[
                const Text('Size: ', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: ann.fontSize.clamp(10.0, 48.0),
                    min: 10,
                    max: 48,
                    divisions: 19,
                    activeColor: primary,
                    label: '${ann.fontSize.round()} pt',
                    onChanged: (val) {
                      setState(() {
                        if (ann.kind == AnnotationKind.text ||
                            ann.kind == AnnotationKind.dateStamp) {
                          final oldBaselinePoints = standardPdfFontBaseline(
                            fontSize: ann.fontSize,
                            fieldHeight: standardPdfFieldHeight(ann.fontSize),
                          );
                          final oldBaselineY =
                              ann.y + (oldBaselinePoints / _pdfPageHeight);

                          ann.fontSize = val;
                          final newFieldH = standardPdfFieldHeight(val);
                          ann.height = newFieldH / _pdfPageHeight;

                          final newBaselinePoints = standardPdfFontBaseline(
                            fontSize: val,
                            fieldHeight: newFieldH,
                          );
                          // Pin baseline in place relative to form line when adjusting font size
                          ann.y = (oldBaselineY - (newBaselinePoints / _pdfPageHeight))
                              .clamp(0.0, 1.0 - ann.height);
                        } else {
                          ann.fontSize = val;
                        }
                      });
                    },
                  ),
                ),
              ] else ...[
                // Highlight width/height scale sliders
                const Text('Width: ', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: ann.width.clamp(0.1, 0.9),
                    min: 0.1,
                    max: 0.9,
                    activeColor: primary,
                    onChanged: (val) {
                      setState(() {
                        ann.width = val;
                      });
                    },
                  ),
                ),
              ],
            ],
          ),

          // Color Palette Swatches (at least 48x48dp tap target)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: (ann.kind == AnnotationKind.highlight
                      ? _highlightPalette
                      : _colorPalette)
                  .map((color) {
                final isSelected = ann.color.toARGB32() == color.toARGB32();
                return InkWell(
                  onTap: () {
                    setState(() {
                      ann.color = color;
                    });
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? primary
                              : (color == Colors.white
                                  ? Colors.black26
                                  : Colors.transparent),
                          width: isSelected ? 2.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: color.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
