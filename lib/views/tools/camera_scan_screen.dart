import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kCardLight, kCardDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';

/// Camera / Document Scanner screen
/// Allows user to:
///  • scan multi-page docs with cunning_document_scanner
///  • pick images from gallery
///  • build a PDF from scanned pages
///  • save to history
class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({Key? key}) : super(key: key);

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  final List<File> _pages = [];
  bool _isBuilding = false;
  final StorageService _storageService = StorageService();
  final AiController _aiController = AiController();

  // -----------------------------------------------------------------------
  // Scan document using cunning_document_scanner (auto-edge detection)
  // -----------------------------------------------------------------------
  Future<void> _scanDocument() async {
    try {
      final List<String>? scans =
          await CunningDocumentScanner.getPictures(noOfPages: 10);
      if (scans == null || scans.isEmpty) return;
      setState(() {
        _pages.addAll(scans.map((p) => File(p)));
      });
    } catch (e) {
      _showError('Scanner error: $e');
    }
  }

  // -----------------------------------------------------------------------
  // Pick images from gallery
  // -----------------------------------------------------------------------
  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final List<XFile> picked = await picker.pickMultiImage(imageQuality: 90);
    if (picked.isEmpty) return;
    setState(() {
      _pages.addAll(picked.map((x) => File(x.path)));
    });
  }

  // -----------------------------------------------------------------------
  // Take single photo
  // -----------------------------------------------------------------------
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final XFile? photo =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (photo == null) return;
    setState(() => _pages.add(File(photo.path)));
  }

  // -----------------------------------------------------------------------
  // Build PDF from pages
  // -----------------------------------------------------------------------
  Future<void> _buildPdf() async {
    if (_pages.isEmpty) return;
    setState(() => _isBuilding = true);

    try {
      final pdf = pw.Document();

      for (final pageFile in _pages) {
        final imageBytes = await pageFile.readAsBytes();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Image(image, fit: pw.BoxFit.contain),
          ),
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      final entry = HistoryEntry(
        id: _aiController.generateId(),
        title: 'Scan — ${_pages.length} page${_pages.length > 1 ? 's' : ''}',
        date: DateTime.now(),
        filePath: file.path,
        toolType: 'scan_to_pdf',
      );
      await _storageService.addHistoryEntry(entry);

      if (!mounted) return;
      setState(() {
        _isBuilding = false;
        _pages.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF created and saved to history!'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      setState(() => _isBuilding = false);
      _showError('Failed to build PDF: $e');
    }
  }

  void _removePage(int index) => setState(() => _pages.removeAt(index));

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? kCardDark : kCardLight;
    final borderColor =
        isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    final subtitleColor =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan to PDF'),
        actions: [
          if (_pages.isNotEmpty)
            TextButton.icon(
              onPressed: _isBuilding ? null : _buildPdf,
              icon: _isBuilding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: kPrimary),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded, color: kPrimary),
              label: Text(
                'Save PDF (${_pages.length})',
                style: const TextStyle(color: kPrimary),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Action buttons ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.document_scanner_rounded,
                    label: 'Scan Doc',
                    color: kPrimary,
                    onTap: _scanDocument,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: const Color(0xFF10B981),
                    onTap: _takePhoto,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: const Color(0xFF8B5CF6),
                    onTap: _pickFromGallery,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Pages list / empty state ──────────────────────────────
          Expanded(
            child: _pages.isEmpty
                ? _EmptyState(
                    subtitleColor: subtitleColor,
                    onScan: _scanDocument,
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_pages.length} page${_pages.length > 1 ? 's' : ''} added',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: _pages.length,
                            itemBuilder: (_, i) => _PageThumbnail(
                              file: _pages[i],
                              index: i,
                              cardBg: cardBg,
                              borderColor: borderColor,
                              onRemove: () => _removePage(i),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF161B22) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageThumbnail extends StatelessWidget {
  final File file;
  final int index;
  final Color cardBg;
  final Color borderColor;
  final VoidCallback onRemove;

  const _PageThumbnail({
    required this.file,
    required this.index,
    required this.cardBg,
    required this.borderColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          clipBehavior: Clip.hardEdge,
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        // Page number badge
        Positioned(
          bottom: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'P${index + 1}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
        // Remove button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color subtitleColor;
  final VoidCallback onScan;

  const _EmptyState({required this.subtitleColor, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.document_scanner_rounded,
              size: 64, color: subtitleColor.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No pages yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan a document, take a photo,\nor pick images from your gallery',
            textAlign: TextAlign.center,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: subtitleColor),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.document_scanner_rounded),
            label: const Text('Start Scanning'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
