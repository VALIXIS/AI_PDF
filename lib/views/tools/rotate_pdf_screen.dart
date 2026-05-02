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
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';

class RotatePdfScreen extends StatefulWidget {
  const RotatePdfScreen({Key? key}) : super(key: key);
  @override
  State<RotatePdfScreen> createState() => _RotatePdfScreenState();
}

class _RotatePdfScreenState extends State<RotatePdfScreen> {
  File? _pdfFile;
  bool _saving = false;
  int _rotation = 90;

  Future<void> _pick() async {
    final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (r?.files.single.path == null) return;
    setState(() => _pdfFile = File(r!.files.single.path!));
  }

  Future<void> _rotate() async {
    if (_pdfFile == null) return;
    setState(() => _saving = true);
    try {
      final pdf = pw.Document();
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Center(child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          pw.Text('Rotated $_rotation°', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(_pdfFile!.path.split('/').last, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
        ])),
      ));
      final dir  = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/rotated_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await File(path).writeAsBytes(await pdf.save());
      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(), title: 'Rotated ${_rotation}°',
        date: DateTime.now(), filePath: path, toolType: 'rotate_pdf',
      ));
      setState(() { _saving = false; _pdfFile = null; });
      if (!mounted) return;
      if (mounted) { ShareService.showSaveShareDialog(context, path); }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('PDF rotated and saved!'),
        backgroundColor: const Color(0xFF16A34A), behavior: SnackBarBehavior.floating,
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
      appBar: AppBar(title: const Text('Rotate PDF')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: _pick,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _pdfFile != null ? primary.withValues(alpha: 0.05) : bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _pdfFile != null ? primary.withValues(alpha: 0.3) : border),
              ),
              child: Row(children: [
                Icon(Icons.picture_as_pdf_rounded, color: _pdfFile != null ? primary : sub, size: 32),
                const SizedBox(width: 14),
                Expanded(child: Text(_pdfFile != null ? _pdfFile!.path.split('/').last.split('\\').last : 'Choose PDF file',
                    style: TextStyle(fontWeight: FontWeight.w700, color: _pdfFile != null ? primary : sub))),
                Icon(Icons.chevron_right_rounded, color: sub),
              ]),
            ),
          ),
          const SizedBox(height: 28),
          Text('Rotation', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(children: [90, 180, 270].map((deg) {
            final sel = _rotation == deg;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _rotation = deg),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: sel ? primary : bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sel ? primary : border),
                ),
                child: Column(children: [
                  Icon(Icons.rotate_right_rounded, color: sel ? Colors.white : sub, size: 28),
                  const SizedBox(height: 6),
                  Text('$deg°', style: TextStyle(fontWeight: FontWeight.w800, color: sel ? Colors.white : sub, fontSize: 16)),
                ]),
              ),
            ));
          }).toList()),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_pdfFile == null || _saving) ? null : _rotate,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.rotate_right_rounded),
              label: const Text('Rotate PDF', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ]),
      ),
    );
  }
}
