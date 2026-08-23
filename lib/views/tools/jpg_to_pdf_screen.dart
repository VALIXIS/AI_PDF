import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

class JpgToPdfScreen extends StatefulWidget {
  const JpgToPdfScreen({Key? key}) : super(key: key);
  @override
  State<JpgToPdfScreen> createState() => _JpgToPdfScreenState();
}

class _JpgToPdfScreenState extends State<JpgToPdfScreen> {
  final List<File> _images = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successPath;
  PdfPageFormat _pageFormat = PdfPageFormat.a4;
  bool _fitPage = true;

  Future<void> _pickImages() async {
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 90);
      if (!mounted) return;
      if (picked.isNotEmpty) {
        setState(() {
          _images.addAll(picked.map((x) => File(x.path)));
          _errorMessage = null;
          _successPath = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to pick images: $e';
      });
    }
  }

  Future<void> _convert() async {
    if (_images.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one image.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successPath = null;
    });

    try {
      final imagePaths = _images.map((f) => f.path).toList();
      final path = await PdfService().convertImagesToPdf(
        imagePaths: imagePaths,
        pageFormat: _pageFormat,
        fitPage: _fitPage,
      );

      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Images to PDF (${_images.length})',
        date: DateTime.now(),
        filePath: path,
        toolType: 'jpg_to_pdf',
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
        _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('PdfServiceException: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final sub = isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    final bg = isDark ? const Color(0xFF14141E) : Colors.white;
    final border = isDark ? const Color(0xFF1F1F2E) : const Color(0xFFE5E7EB);

    return Scaffold(
      appBar: AppBar(title: const Text('JPG / Images to PDF')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Loading Banner
          if (_isLoading)
            ToolLoadingBanner(
              message: 'Converting ${_images.length} image${_images.length > 1 ? 's' : ''} to PDF...',
            ),

          // Error Banner
          if (_errorMessage != null)
            ToolErrorBanner(
              message: _errorMessage!,
              onRetry: _images.isNotEmpty ? _convert : null,
              onDismiss: () => setState(() => _errorMessage = null),
            ),

          // Success Card
          if (_successPath != null)
            ToolSuccessCard(
              title: 'PDF Created Successfully!',
              subtitle: 'Combined ${_images.length} images into PDF.',
              filePath: _successPath,
              onShare: () {
                if (_successPath != null && mounted) {
                  ShareService.showSaveShareDialog(context, _successPath!);
                }
              },
              onReset: () {
                setState(() {
                  _successPath = null;
                  _images.clear();
                  _errorMessage = null;
                });
              },
            ),

          // Options Card
          Text('Options', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
            child: Column(children: [
              Row(children: [
                const Text('Page size', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                DropdownButton<PdfPageFormat>(
                  value: _pageFormat,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: PdfPageFormat.a4, child: Text('A4')),
                    DropdownMenuItem(value: PdfPageFormat.letter, child: Text('Letter')),
                    DropdownMenuItem(value: PdfPageFormat.a3, child: Text('A3')),
                  ],
                  onChanged: _isLoading ? null : (v) { if (v != null) setState(() => _pageFormat = v); },
                ),
              ]),
              const Divider(),
              SwitchListTile.adaptive(
                title: const Text('Fit to page', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Scale image to fill page'),
                value: _fitPage,
                activeThumbColor: primary,
                contentPadding: EdgeInsets.zero,
                onChanged: _isLoading ? null : (v) => setState(() => _fitPage = v),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Images Section Header
          Row(
            children: [
              Text('Images (${_images.length})', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_images.isNotEmpty && !_isLoading)
                TextButton(
                  onPressed: () => setState(() { _images.clear(); _errorMessage = null; }),
                  child: const Text('Clear all', style: TextStyle(color: Color(0xFFDC2626))),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Empty state or Grid of selected images
          if (_images.isEmpty && _successPath == null)
            ToolEmptyState(
              icon: Icons.add_photo_alternate_rounded,
              title: 'No Images Selected',
              subtitle: 'Select one or more photos from your gallery to create a PDF',
              actionLabel: 'Select Images',
              onAction: _isLoading ? null : _pickImages,
            )
          else if (_images.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemCount: _images.length + 1,
              itemBuilder: (_, i) {
                if (i == _images.length) {
                  return GestureDetector(
                    onTap: _isLoading ? null : _pickImages,
                    child: Container(
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_rounded, color: sub, size: 28),
                        Text('Add', style: TextStyle(color: sub, fontSize: 12)),
                      ]),
                    ),
                  );
                }
                return Stack(children: [
                  Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
                    clipBehavior: Clip.hardEdge,
                    child: Image.file(_images[i], fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: _isLoading ? null : () => setState(() => _images.removeAt(i)),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 13),
                      ),
                    ),
                  ),
                ]);
              },
            ),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_images.isEmpty || _isLoading) ? null : _convert,
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(_images.isEmpty ? 'Select images first' : 'Convert to PDF', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
