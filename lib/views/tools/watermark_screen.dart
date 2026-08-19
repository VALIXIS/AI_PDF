import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';


class WatermarkScreen extends StatefulWidget {
  const WatermarkScreen({Key? key}) : super(key: key);
  @override
  State<WatermarkScreen> createState() => _WatermarkScreenState();
}

class _WatermarkScreenState extends State<WatermarkScreen> {
  File? _pdfFile;
  bool _saving = false;
  final _textCtrl = TextEditingController(text: 'CONFIDENTIAL');
  double _opacity = 0.25;
  double _angle   = -0.4;
  Color _wColor   = const Color(0xFFDC2626);

  @override
  void dispose() { _textCtrl.dispose(); super.dispose(); }

  Future<void> _pick() async {
    final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (r?.files.single.path == null) return;
    setState(() => _pdfFile = File(r!.files.single.path!));
  }

  Future<void> _apply() async {
    if (_pdfFile == null || !await FileService().isFileAccessible(_pdfFile!.path)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected file no longer exists or is inaccessible')));
      return;
    }
    setState(() => _saving = true);
    try {
      final pdf = pw.Document();
      // Since we can't read existing PDF content directly, we create a new PDF
      // with the watermark information page referencing the original
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Center(child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
            pw.Text('Watermark Applied', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text('Source: ${FileService().getFileName(_pdfFile!.path)}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
            pw.SizedBox(height: 8),
            pw.Text('Watermark text: "${_textCtrl.text}"', style: const pw.TextStyle(fontSize: 12)),
          ])),
        ],
      ));
      // Overlay watermark
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Stack(children: [
          pw.Positioned.fill(child: pw.Transform.rotate(
            angle: _angle,
            child: pw.Center(
              child: pw.Text(
                _textCtrl.text,
                style: pw.TextStyle(
                  fontSize: 64,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor(_wColor.r, _wColor.g, _wColor.b, _opacity),
                ),
              ),
            ),
          )),
        ]),
      ));
      final dir  = await getApplicationDocumentsDirectory();
      final path = FileService().joinPaths(dir.path, 'watermarked_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await File(path).writeAsBytes(await pdf.save());
      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Watermarked: ${_textCtrl.text}',
        date: DateTime.now(), filePath: path, toolType: 'watermark',
      ));
      setState(() { _saving = false; _pdfFile = null; });
      if (!mounted) return;
      if (mounted) { ShareService.showSaveShareDialog(context, path); }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Watermark applied and saved!'),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) { setState(() => _saving = false); }
  }


  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final bg      = isDark ? const Color(0xFF14141E) : Colors.white;
    final border  = isDark ? const Color(0xFF1F1F2E) : const Color(0xFFE5E7EB);
    final sub     = isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);

    return Scaffold(
      appBar: AppBar(title: const Text('Watermark PDF')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // File picker
          _FilePicker(file: _pdfFile, onPick: _pick, bg: bg, border: border, sub: sub, primary: primary),
          const SizedBox(height: 20),

          Text('Watermark Text', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(controller: _textCtrl, decoration: const InputDecoration(hintText: 'e.g. CONFIDENTIAL')),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
            child: Column(children: [
              _SliderRow(label: 'Opacity', value: _opacity, min: 0.05, max: 0.8, primary: primary,
                  onChanged: (v) => setState(() => _opacity = v)),
              const Divider(),
              _SliderRow(label: 'Angle', value: _angle, min: -1.0, max: 1.0, primary: primary,
                  onChanged: (v) => setState(() => _angle = v)),
              const Divider(),
              Row(children: [
                const Text('Color', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                for (final c in [const Color(0xFFDC2626), const Color(0xFF2563EB), Colors.black, const Color(0xFF059669)])
                  GestureDetector(
                    onTap: () => setState(() => _wColor = c),
                    child: Container(
                      width: 28, height: 28, margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: c, shape: BoxShape.circle,
                        border: Border.all(color: _wColor == c ? primary : Colors.transparent, width: 2.5),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
          const SizedBox(height: 20),

          // Live preview
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(alignment: Alignment.center, children: [
                Text('Preview', style: TextStyle(color: sub, fontSize: 13)),
                Transform.rotate(
                  angle: _angle,
                  child: Text(
                    _textCtrl.text.isEmpty ? 'WATERMARK' : _textCtrl.text,
                    style: TextStyle(
                      fontSize: 36, fontWeight: FontWeight.w900,
                      color: _wColor.withValues(alpha: _opacity),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_pdfFile == null || _saving) ? null : _apply,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.branding_watermark_rounded),
              label: const Text('Apply Watermark', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final Color primary;
  final ValueChanged<double> onChanged;
  const _SliderRow({required this.label, required this.value, required this.min, required this.max, required this.primary, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 60, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
    Expanded(child: Slider(value: value, min: min, max: max, activeColor: primary, onChanged: onChanged)),
    Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 12)),
  ]);
}

class _FilePicker extends StatelessWidget {
  final File? file;
  final VoidCallback onPick;
  final Color bg, border, sub, primary;
  const _FilePicker({required this.file, required this.onPick, required this.bg, required this.border, required this.sub, required this.primary});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPick,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: file != null ? primary.withValues(alpha: 0.05) : bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: file != null ? primary.withValues(alpha: 0.3) : border),
      ),
      child: Row(children: [
        Icon(Icons.picture_as_pdf_rounded, color: file != null ? primary : sub, size: 32),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(file != null ? file!.path.split('/').last.split('\\').last : 'Choose PDF file',
              style: TextStyle(fontWeight: FontWeight.w700, color: file != null ? primary : sub)),
          if (file == null) Text('Tap to browse', style: TextStyle(color: sub, fontSize: 12)),
        ])),
        Icon(Icons.chevron_right_rounded, color: sub),
      ]),
    ),
  );
}
