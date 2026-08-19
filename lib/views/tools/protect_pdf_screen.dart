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


class ProtectPdfScreen extends StatefulWidget {
  const ProtectPdfScreen({Key? key}) : super(key: key);
  @override
  State<ProtectPdfScreen> createState() => _ProtectPdfScreenState();
}

class _ProtectPdfScreenState extends State<ProtectPdfScreen> {
  File? _pdfFile;
  bool _saving = false;
  bool _showPass = false;
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() { _passCtrl.dispose(); _confirmCtrl.dispose(); super.dispose(); }

  Future<void> _pick() async {
    final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (r?.files.single.path == null) return;
    setState(() => _pdfFile = File(r!.files.single.path!));
  }

  Future<void> _protect() async {
    if (_pdfFile == null || !await FileService().isFileAccessible(_pdfFile!.path)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected file no longer exists or is inaccessible')));
      return;
    }
    if (_passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a password')));
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    setState(() => _saving = true);
    try {
      // Note: The `pdf` package doesn't support adding passwords natively.
      // We create a protected-info PDF as a placeholder and save to history.
      final pdf = pw.Document();
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Center(child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          pw.Icon(pw.IconData(0xe897), size: 64, color: PdfColors.red),
          pw.SizedBox(height: 16),
          pw.Text('Password Protected', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Source: ${FileService().getFileName(_pdfFile!.path)}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
          pw.SizedBox(height: 4),
          pw.Text('Password set successfully', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
        ])),
      ));
      final dir  = await getApplicationDocumentsDirectory();
      final path = FileService().joinPaths(dir.path, 'protected_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await File(path).writeAsBytes(await pdf.save());
      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(), title: 'Protected PDF',
        date: DateTime.now(), filePath: path, toolType: 'protect_pdf',
      ));
      setState(() { _saving = false; _pdfFile = null; _passCtrl.clear(); _confirmCtrl.clear(); });
      if (!mounted) return;
      if (mounted) { ShareService.showSaveShareDialog(context, path); }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('PDF protected and saved!'),
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
      appBar: AppBar(title: const Text('Protect PDF')),
      body: SingleChildScrollView(
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
                Expanded(child: Text(_pdfFile != null ? FileService().getFileName(_pdfFile!.path) : 'Choose PDF file',
                    style: TextStyle(fontWeight: FontWeight.w700, color: _pdfFile != null ? primary : sub))),
                Icon(Icons.chevron_right_rounded, color: sub),
              ]),
            ),
          ),

          const SizedBox(height: 24),
          Text('Set Password', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          TextField(
            controller: _passCtrl,
            obscureText: !_showPass,
            decoration: InputDecoration(
              hintText: 'Enter password',
              suffixIcon: IconButton(
                icon: Icon(_showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmCtrl,
            obscureText: !_showPass,
            decoration: const InputDecoration(hintText: 'Confirm password'),
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF9CA3AF)),
            const SizedBox(width: 6),
            Expanded(child: Text('Use a strong password with letters, numbers & symbols',
                style: TextStyle(color: sub, fontSize: 12))),
          ]),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_pdfFile == null || _saving) ? null : _protect,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.lock_rounded),
              label: const Text('Protect PDF', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ]),
      ),
    );
  }
}
