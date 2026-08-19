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
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({Key? key}) : super(key: key);
  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  final List<File> _pages = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successPath;

  Future<void> _scanDocument() async {
    try {
      final scans = await CunningDocumentScanner.getPictures(
        noOfPages: 20,
        isGalleryImportAllowed: true,
      );
      if (!mounted) return;
      if (scans != null && scans.isNotEmpty) {
        setState(() {
          _pages.addAll(scans.map((p) => File(p)));
          _errorMessage = null;
          _successPath = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Scanner error: $e';
      });
    }
  }

  Future<void> _pickGallery() async {
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 90);
      if (!mounted) return;
      if (picked.isNotEmpty) {
        setState(() {
          _pages.addAll(picked.map((x) => File(x.path)));
          _errorMessage = null;
          _successPath = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to pick from gallery: $e';
      });
    }
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
      if (!mounted) return;
      if (photo != null) {
        setState(() {
          _pages.add(File(photo.path));
          _errorMessage = null;
          _successPath = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to capture photo: $e';
      });
    }
  }

  Future<void> _buildPdf() async {
    if (_pages.isEmpty) {
      setState(() {
        _errorMessage = 'Please scan or add at least one page first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successPath = null;
    });

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

      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await File(path).writeAsBytes(await pdf.save());

      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Scan (${_pages.length} pages)',
        date: DateTime.now(),
        filePath: path,
        toolType: 'scan_to_pdf',
      ));

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successPath = path;
      });

      if (mounted) {
        ShareService.showSaveShareDialog(context, path);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to build PDF: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final bg = isDark ? const Color(0xFF14141E) : Colors.white;
    final border = isDark ? const Color(0xFF1F1F2E) : const Color(0xFFE5E7EB);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan to PDF'),
        actions: [
          if (_pages.isNotEmpty)
            TextButton.icon(
              onPressed: _isLoading ? null : _buildPdf,
              icon: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.picture_as_pdf_rounded, color: primary),
              label: Text('Save PDF (${_pages.length})', style: TextStyle(color: primary, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        // Loading Banner
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: ToolLoadingBanner(
              message: 'Compiling ${_pages.length} scanned page${_pages.length > 1 ? 's' : ''} to PDF...',
            ),
          ),

        // Error Banner
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: ToolErrorBanner(
              message: _errorMessage!,
              onRetry: _pages.isNotEmpty ? _buildPdf : null,
              onDismiss: () => setState(() => _errorMessage = null),
            ),
          ),

        // Success Card
        if (_successPath != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: ToolSuccessCard(
              title: 'Scan Saved Successfully!',
              subtitle: 'Scanned document saved as PDF.',
              filePath: _successPath,
              onShare: () {
                if (_successPath != null && mounted) {
                  ShareService.showSaveShareDialog(context, _successPath!);
                }
              },
              onReset: () {
                setState(() {
                  _successPath = null;
                  _pages.clear();
                  _errorMessage = null;
                });
              },
            ),
          ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            _ScanBtn(icon: Icons.document_scanner_rounded, label: 'Scan Doc', color: primary, onTap: _isLoading ? () {} : _scanDocument),
            const SizedBox(width: 10),
            _ScanBtn(icon: Icons.camera_alt_rounded, label: 'Camera', color: const Color(0xFF059669), onTap: _isLoading ? () {} : _takePhoto),
            const SizedBox(width: 10),
            _ScanBtn(icon: Icons.photo_library_rounded, label: 'Gallery', color: const Color(0xFF8B5CF6), onTap: _isLoading ? () {} : _pickGallery),
          ]),
        ),
        const SizedBox(height: 16),

        // Pages / Empty State
        Expanded(
          child: _pages.isEmpty && _successPath == null
              ? ToolEmptyState(
                  icon: Icons.document_scanner_rounded,
                  title: 'No Scanned Pages Yet',
                  subtitle: 'Tap "Scan Doc" for auto edge detection, or use Camera / Gallery to import pages',
                  actionLabel: 'Start Scanning',
                  onAction: _isLoading ? null : _scanDocument,
                )
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_pages.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(children: [
                        Text(
                          '${_pages.length} page${_pages.length > 1 ? 's' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const Spacer(),
                        if (!_isLoading)
                          TextButton(
                            onPressed: () => setState(() {
                              _pages.clear();
                              _errorMessage = null;
                            }),
                            child: const Text('Clear all', style: TextStyle(color: Color(0xFFDC2626))),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: _pages.length,
                        itemBuilder: (_, i) => Stack(children: [
                          Container(
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: border),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: Image.file(_pages[i], fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                          ),
                          Positioned(
                            bottom: 5,
                            left: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(6)),
                              child: Text('P${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                            ),
                          ),
                          if (!_isLoading)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() => _pages.removeAt(i)),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ],

                  // Bottom Save Button
                  if (_pages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _buildPdf,
                          icon: _isLoading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('Save as PDF', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
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
