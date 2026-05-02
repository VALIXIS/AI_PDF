import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kCardLight, kCardDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';

/// PDF Editor screen
/// Lets the user:
///  • edit/write text content (title + body)
///  • add images from camera or gallery
///  • preview and save as PDF
class PdfEditorScreen extends StatefulWidget {
  /// Optionally pre-fill the title when opened from history
  final String? initialTitle;
  final String? initialContent;

  const PdfEditorScreen({Key? key, this.initialTitle, this.initialContent})
      : super(key: key);

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  final List<File> _images = [];
  bool _isSaving = false;
  final StorageService _storageService = StorageService();
  final AiController _aiController = AiController();

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.initialTitle ?? '');
    _contentController =
        TextEditingController(text: widget.initialContent ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Image pickers
  // -----------------------------------------------------------------------
  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final List<XFile> picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() => _images.addAll(picked.map((x) => File(x.path))));
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final XFile? photo =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (photo == null) return;
    setState(() => _images.add(File(photo.path)));
  }

  // -----------------------------------------------------------------------
  // Save to PDF
  // -----------------------------------------------------------------------
  Future<void> _savePdf() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty && _images.isEmpty) {
      _showSnack('Add some text or images first', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final pdf = pw.Document();
      final lines = content.split('\n');

      // Build content widgets
      List<pw.Widget> contentWidgets = [
        if (title.isNotEmpty) ...[
          pw.Text(
            title,
            style: pw.TextStyle(
                fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Divider(),
          pw.SizedBox(height: 12),
        ],
        if (content.isNotEmpty)
          for (final line in lines) ...[
            pw.Text(
              line,
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
            ),
            pw.SizedBox(height: 3),
          ],
      ];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (_) => contentWidgets,
        ),
      );

      // Add images as separate pages
      for (final imgFile in _images) {
        final bytes = await imgFile.readAsBytes();
        final image = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (_) => pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          ),
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'edited_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      final entryTitle =
          title.isNotEmpty ? title : 'Edited PDF';
      final entry = HistoryEntry(
        id: _aiController.generateId(),
        title: entryTitle,
        date: DateTime.now(),
        filePath: file.path,
        toolType: 'pdf_editor',
      );
      await _storageService.addHistoryEntry(entry);

      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack('PDF saved to history!');
      // Clear editor after save
      _titleController.clear();
      _contentController.clear();
      setState(() => _images.clear());
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('Failed: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        title: const Text('PDF Editor'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _savePdf,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kPrimary),
                  )
                : const Icon(Icons.save_rounded, color: kPrimary),
            label: const Text('Save PDF',
                style: TextStyle(color: kPrimary)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title field ──────────────────────────────────────────
            Text('Document Title',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _StyledField(
              controller: _titleController,
              hintText: 'Enter a title...',
              maxLines: 1,
              cardBg: cardBg,
              borderColor: borderColor,
              subtitleColor: subtitleColor,
            ),
            const SizedBox(height: 20),

            // ── Content field ────────────────────────────────────────
            Text('Content',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _StyledField(
              controller: _contentController,
              hintText:
                  'Write or paste your content here...\n\nSupports # Heading, ## Subheading, - Bullet items',
              maxLines: 14,
              minLines: 8,
              cardBg: cardBg,
              borderColor: borderColor,
              subtitleColor: subtitleColor,
            ),
            const SizedBox(height: 20),

            // ── Images section ───────────────────────────────────────
            Row(
              children: [
                Text('Images',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                // Camera button
                _SmallIconButton(
                  icon: Icons.camera_alt_rounded,
                  color: const Color(0xFF10B981),
                  tooltip: 'Take photo',
                  onTap: _takePhoto,
                ),
                const SizedBox(width: 8),
                // Gallery button
                _SmallIconButton(
                  icon: Icons.photo_library_rounded,
                  color: const Color(0xFF8B5CF6),
                  tooltip: 'Pick from gallery',
                  onTap: _pickImageFromGallery,
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_images.isEmpty)
              GestureDetector(
                onTap: _pickImageFromGallery,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border.all(
                        color: borderColor,
                        style: BorderStyle.solid,
                        width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.add_photo_alternate_rounded,
                          size: 36, color: subtitleColor.withValues(alpha: 0.6)),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add images',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: subtitleColor),
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: _images.length + 1,
                itemBuilder: (_, i) {
                  if (i == _images.length) {
                    // Add more button
                    return GestureDetector(
                      onTap: _pickImageFromGallery,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded,
                                color: subtitleColor, size: 28),
                            const SizedBox(height: 4),
                            Text('Add',
                                style: TextStyle(
                                    fontSize: 12, color: subtitleColor)),
                          ],
                        ),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Image.file(
                          _images[i],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _images.removeAt(i)),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 13),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

            const SizedBox(height: 32),

            // ── Save button (bottom) ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _savePdf,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Save as PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------
class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final int minLines;
  final Color cardBg;
  final Color borderColor;
  final Color subtitleColor;

  const _StyledField({
    required this.controller,
    required this.hintText,
    required this.maxLines,
    this.minLines = 1,
    required this.cardBg,
    required this.borderColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: minLines,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: subtitleColor, fontSize: 13),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _SmallIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
