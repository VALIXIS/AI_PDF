import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';

// ── Annotation types ──────────────────────────────────────────────────────
enum AnnotationKind { text, image }

class Annotation {
  final String id;
  AnnotationKind kind;
  double x, y, width, height;
  String text;
  double fontSize;
  Color color;
  bool bold;
  Uint8List? imageBytes;

  Annotation.text({
    required this.id, required this.x, required this.y,
    this.text = 'Text', this.fontSize = 16, this.color = Colors.black, this.bold = false,
    this.width = 0.4, this.height = 0.06, this.imageBytes,
    this.kind = AnnotationKind.text,
  });

  Annotation.image({
    required this.id, required this.x, required this.y, required this.imageBytes,
    this.width = 0.4, this.height = 0.3, this.text = '', this.fontSize = 16,
    this.color = Colors.black, this.bold = false,
    this.kind = AnnotationKind.image,
  });
}

// ─────────────────────────────────────────────────────────────────────────
class PdfEditorScreen extends StatefulWidget {
  const PdfEditorScreen({Key? key}) : super(key: key);
  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  File? _pdfFile;
  pdfx.PdfDocument? _document;
  int _pageCount = 0;
  int _currentPage = 0;
  bool _loading = false;
  bool _saving  = false;
  bool _editMode = false;
  String? _activeToolbar; // 'text' | 'image' | null

  final Map<int, List<Annotation>> _annotations = {};
  Annotation? _selected;
  final _textEditCtrl = TextEditingController();

  @override
  void dispose() {
    _document?.close();
    _textEditCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;
    setState(() { _loading = true; _pdfFile = null; _document = null; _annotations.clear(); });
    try {
      final file = File(result.files.single.path!);
      final doc  = await pdfx.PdfDocument.openFile(file.path);
      setState(() {
        _pdfFile = file; _document = doc;
        _pageCount = doc.pagesCount; _currentPage = 0; _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack('Could not open PDF: $e', error: true);
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
      _activeToolbar = 'text';
    });
  }

  Future<void> _addImage(double rx, double ry) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ann   = Annotation.image(id: UniqueKey().toString(), x: rx, y: ry, imageBytes: bytes);
    setState(() {
      _pageAnnotations.add(ann);
      _selected = ann;
      _activeToolbar = null;
    });
  }

  Future<void> _savePdf() async {
    if (_pdfFile == null || _document == null) return;
    setState(() => _saving = true);
    try {
      final newPdf = pw.Document();
      for (int p = 0; p < _pageCount; p++) {
        final page   = await _document!.getPage(p + 1);
        final double pw_ = page.width;
        final double ph  = page.height;
        final render = await page.render(
          width: pw_ * 2, height: ph * 2,
          format: pdfx.PdfPageImageFormat.jpeg,
        );
        await page.close();
        final bgImage = pw.MemoryImage(render!.bytes);
        final fmt = PdfPageFormat(pw_, ph);
        final List<Annotation> anns = _annotations[p] ?? [];

        newPdf.addPage(pw.Page(
          pageFormat: fmt,
          margin: pw.EdgeInsets.zero,
          build: (ctx) => pw.Stack(children: [
            pw.Positioned.fill(child: pw.Image(bgImage, fit: pw.BoxFit.fill)),
            for (final ann in anns)
              pw.Positioned(
                left: ann.x * pw_, top: ann.y * ph,
                child: ann.kind == AnnotationKind.text
                    ? pw.Text(ann.text, style: pw.TextStyle(
                        fontSize: ann.fontSize,
                        fontWeight: ann.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                        color: PdfColor.fromInt(ann.color.toARGB32()),
                      ))
                    : pw.SizedBox(
                        width: ann.width * pw_, height: ann.height * ph,
                        child: pw.Image(pw.MemoryImage(ann.imageBytes!), fit: pw.BoxFit.contain),
                      ),
              ),
          ]),
        ));
      }

      final dir  = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await File(path).writeAsBytes(await newPdf.save());
      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Edited: ${_pdfFile!.path.split('/').last}',
        date: DateTime.now(), filePath: path, toolType: 'pdf_editor',
      ));
      setState(() => _saving = false);
      if (mounted) { ShareService.showSaveShareDialog(context, path); }
      _snack('PDF saved to history!');
    } catch (e) {
      setState(() => _saving = false);
      _snack('Save failed: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0B13) : const Color(0xFFF0F0F5),
      appBar: AppBar(
        title: Text(_pdfFile == null ? 'PDF Editor'
            : _pdfFile!.path.split('\\').last.split('/').last, overflow: TextOverflow.ellipsis),
        actions: [
          if (_document != null) ...[
            IconButton(
              icon: Icon(_editMode ? Icons.edit_off_rounded : Icons.edit_rounded,
                  color: _editMode ? primary : null),
              tooltip: _editMode ? 'View mode' : 'Edit mode',
              onPressed: () => setState(() { _editMode = !_editMode; _selected = null; _activeToolbar = null; }),
            ),
            TextButton.icon(
              onPressed: _saving ? null : _savePdf,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.save_rounded, color: primary),
              label: Text('Save', style: TextStyle(color: primary, fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: _document == null ? _buildEmpty(primary, isDark) : _buildEditor(primary, isDark),
      floatingActionButton: _document != null && _editMode
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              FloatingActionButton.small(
                heroTag: 'img', backgroundColor: const Color(0xFF8B5CF6),
                onPressed: () => setState(() => _activeToolbar = 'image'),
                child: const Icon(Icons.image_rounded, color: Colors.white),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'txt', backgroundColor: kPrimary,
                onPressed: () => setState(() => _activeToolbar = 'text'),
                child: const Icon(Icons.text_fields_rounded, color: Colors.white),
              ),
            ])
          : null,
    );
  }

  Widget _buildEmpty(Color primary, bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final sub = isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(Icons.edit_document, color: primary, size: 40),
        ),
        const SizedBox(height: 24),
        Text('Open a PDF to edit', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('View pages, add text & images,\nthen export a new PDF',
            textAlign: TextAlign.center, style: TextStyle(color: sub, height: 1.5)),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: _pickPdf,
          icon: const Icon(Icons.folder_open_rounded),
          label: const Text('Choose PDF File'),
          style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
      ]),
    ));
  }

  Widget _buildEditor(Color primary, bool isDark) {
    return Column(children: [
      if (_editMode && _activeToolbar == 'text' && _selected?.kind == AnnotationKind.text)
        _TextToolbar(
          annotation: _selected!, controller: _textEditCtrl, primary: primary, isDark: isDark,
          onChange: () => setState(() {}),
          onDelete: () => setState(() {
            _pageAnnotations.remove(_selected);
            _selected = null; _activeToolbar = null;
          }),
        ),
      if (_editMode && _activeToolbar != null && _selected == null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: primary.withValues(alpha: 0.1),
          child: Row(children: [
            Icon(Icons.touch_app_rounded, color: primary, size: 16),
            const SizedBox(width: 8),
            Text('Tap on the page to place ${_activeToolbar == 'text' ? 'text' : 'image'}',
                style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      Expanded(child: Column(children: [
        Expanded(child: PageView.builder(
          itemCount: _pageCount,
          onPageChanged: (i) => setState(() { _currentPage = i; _selected = null; }),
          itemBuilder: (_, idx) => _buildPage(idx, primary, isDark),
        )),
        if (_pageCount > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Page ${_currentPage + 1} of $_pageCount',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
      ])),
      _buildBottomBar(primary, isDark),
    ]);
  }

  Widget _buildPage(int pageIdx, Color primary, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(builder: (ctx, constraints) {
          return GestureDetector(
            onTapUp: _editMode && _activeToolbar != null ? (details) {
              final rx = details.localPosition.dx / constraints.maxWidth;
              final ry = details.localPosition.dy / constraints.maxHeight;
              if (_activeToolbar == 'text') { _addText(rx, ry); }
              else if (_activeToolbar == 'image') {
                _addImage(rx, ry);
                setState(() => _activeToolbar = null);
              }
            } : null,
            child: Stack(fit: StackFit.expand, children: [
              IgnorePointer(
                ignoring: _editMode,
                child: pdfx.PdfView(
                  controller: pdfx.PdfController(
                    document: pdfx.PdfDocument.openFile(_pdfFile!.path),
                  ),
                  pageSnapping: true,
                  scrollDirection: Axis.vertical,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (_) {},
                ),
              ),
              ...(_annotations[pageIdx] ?? []).map((ann) => _buildAnn(ann, constraints)),
            ]),
          );
        }),
      ),
    );
  }

  Widget _buildAnn(Annotation ann, BoxConstraints c) {
    final isSel = _selected?.id == ann.id;
    return Positioned(
      left: ann.x * c.maxWidth, top: ann.y * c.maxHeight,
      width: ann.width * c.maxWidth, height: ann.height * c.maxHeight,
      child: GestureDetector(
        onTap: _editMode ? () => setState(() {
          _selected = ann;
          _textEditCtrl.text = ann.text;
          _activeToolbar = ann.kind == AnnotationKind.text ? 'text' : null;
        }) : null,
        onPanUpdate: _editMode ? (details) => setState(() {
          ann.x += details.delta.dx / c.maxWidth;
          ann.y += details.delta.dy / c.maxHeight;
        }) : null,
        child: Container(
          decoration: isSel && _editMode
              ? BoxDecoration(border: Border.all(color: kPrimary, width: 1.5),
                  borderRadius: BorderRadius.circular(4))
              : null,
          child: ann.kind == AnnotationKind.text
              ? Text(ann.text, style: TextStyle(fontSize: ann.fontSize,
                  fontWeight: ann.bold ? FontWeight.bold : FontWeight.normal, color: ann.color))
              : Image.memory(ann.imageBytes!, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildBottomBar(Color primary, bool isDark) {
    final bg     = isDark ? const Color(0xFF14141E) : Colors.white;
    final border = isDark ? const Color(0xFF1F1F2E) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(color: bg, border: Border(top: BorderSide(color: border))),
      child: Row(children: [
        OutlinedButton.icon(
          onPressed: _pickPdf,
          icon: const Icon(Icons.folder_open_rounded, size: 16),
          label: const Text('Change File'),
          style: OutlinedButton.styleFrom(foregroundColor: primary, side: BorderSide(color: primary)),
        ),
        const Spacer(),
        if (_document != null)
          ElevatedButton.icon(
            onPressed: _saving ? null : _savePdf,
            icon: _saving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 16),
            label: const Text('Save PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
          ),
      ]),
    );
  }
}

// ── Text toolbar ──────────────────────────────────────────────────────────
class _TextToolbar extends StatelessWidget {
  final Annotation annotation;
  final TextEditingController controller;
  final Color primary;
  final bool isDark;
  final VoidCallback onChange, onDelete;
  const _TextToolbar({required this.annotation, required this.controller,
    required this.primary, required this.isDark, required this.onChange, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF14141E) : Colors.white;
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: controller,
          onChanged: (v) { annotation.text = v; onChange(); },
          decoration: const InputDecoration(hintText: 'Enter text…', isDense: true),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Text('Size:', style: TextStyle(fontSize: 12)),
          Expanded(child: Slider(
            value: annotation.fontSize, min: 8, max: 48, activeColor: primary,
            onChanged: (v) { annotation.fontSize = v; onChange(); },
          )),
          IconButton(
            icon: Icon(Icons.format_bold, color: annotation.bold ? primary : null),
            onPressed: () { annotation.bold = !annotation.bold; onChange(); },
          ),
          for (final c in [Colors.black, Colors.white, Colors.red, Colors.blue, Colors.green])
            GestureDetector(
              onTap: () { annotation.color = c; onChange(); },
              child: Container(
                width: 20, height: 20, margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: c, shape: BoxShape.circle,
                  border: Border.all(color: annotation.color == c ? primary : Colors.transparent, width: 2),
                ),
              ),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_rounded, color: Color(0xFFDC2626)),
            onPressed: onDelete,
          ),
        ]),
      ]),
    );
  }
}
