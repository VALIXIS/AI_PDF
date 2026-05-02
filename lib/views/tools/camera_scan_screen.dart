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
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({Key? key}) : super(key: key);
  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  final List<File> _pages = [];
  bool _building = false;

  Future<void> _scanDocument() async {
    try {
      final scans = await CunningDocumentScanner.getPictures(
        noOfPages: 20,
        isGalleryImportAllowed: true,
      );
      if (scans == null || scans.isEmpty) return;
      setState(() => _pages.addAll(scans.map((p) => File(p))));
    } catch (e) {
      _snack('Scanner error: $e', error: true);
    }
  }

  Future<void> _pickGallery() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 90);
    if (picked.isEmpty) return;
    setState(() => _pages.addAll(picked.map((x) => File(x.path))));
  }

  Future<void> _takePhoto() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
    if (photo == null) return;
    setState(() => _pages.add(File(photo.path)));
  }

  Future<void> _buildPdf() async {
    if (_pages.isEmpty) return;
    setState(() => _building = true);
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
      final dir  = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await File(path).writeAsBytes(await pdf.save());
      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Scan (${_pages.length} pages)',
        date: DateTime.now(), filePath: path, toolType: 'scan_to_pdf',
      ));
      setState(() { _building = false; _pages.clear(); });
      if (mounted) { ShareService.showSaveShareDialog(context, path); }
      _snack('PDF saved to history!');
    } catch (e) {
      setState(() => _building = false);
      _snack('Failed: $e', error: true);
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
    final sub     = isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    final bg      = isDark ? const Color(0xFF14141E) : Colors.white;
    final border  = isDark ? const Color(0xFF1F1F2E) : const Color(0xFFE5E7EB);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan to PDF'),
        actions: [
          if (_pages.isNotEmpty)
            TextButton.icon(
              onPressed: _building ? null : _buildPdf,
              icon: _building
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.picture_as_pdf_rounded, color: primary),
              label: Text('Save PDF (${_pages.length})',
                  style: TextStyle(color: primary, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        // ── Action buttons ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            _ScanBtn(icon: Icons.document_scanner_rounded, label: 'Scan Doc', color: primary, onTap: _scanDocument),
            const SizedBox(width: 10),
            _ScanBtn(icon: Icons.camera_alt_rounded, label: 'Camera', color: const Color(0xFF059669), onTap: _takePhoto),
            const SizedBox(width: 10),
            _ScanBtn(icon: Icons.photo_library_rounded, label: 'Gallery', color: const Color(0xFF8B5CF6), onTap: _pickGallery),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Pages / empty state ────────────────────────────────────
        Expanded(
          child: _pages.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.document_scanner_rounded, size: 72, color: sub.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('No pages yet', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Tap "Scan Doc" for auto edge detection\nor use Camera / Gallery',
                      textAlign: TextAlign.center, style: TextStyle(color: sub)),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: _scanDocument,
                    icon: const Icon(Icons.document_scanner_rounded),
                    label: const Text('Start Scanning'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ]))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(children: [
                      Text('${_pages.length} page${_pages.length > 1 ? 's' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => _pages.clear()),
                        child: const Text('Clear all', style: TextStyle(color: Color(0xFFDC2626))),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.72),
                      itemCount: _pages.length,
                      itemBuilder: (_, i) => Stack(children: [
                        Container(
                          decoration: BoxDecoration(
                            color: bg, borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: border),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Image.file(_pages[i], fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                        ),
                        Positioned(bottom: 5, left: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(6)),
                            child: Text('P${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        Positioned(top: 4, right: 4,
                          child: GestureDetector(
                            onTap: () => setState(() => _pages.removeAt(i)),
                            child: Container(
                              width: 22, height: 22,
                              decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  // Save button
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _building ? null : _buildPdf,
                        icon: _building
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('Save as PDF', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ]),
        ),
      ]),
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
          child: Column(children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      ),
    );
  }
}
