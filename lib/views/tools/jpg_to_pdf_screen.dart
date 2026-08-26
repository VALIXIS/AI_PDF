import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
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
    if (_isLoading) return;
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 90);
      if (!mounted) return;
      if (picked.isNotEmpty) {
        final validImages = <File>[];
        int unsupportedCount = 0;
        for (final x in picked) {
          if (await FileService().isImageFile(x.path)) {
            validImages.add(File(x.path));
          } else {
            unsupportedCount++;
          }
        }
        if (validImages.isEmpty) {
          setState(() {
            _errorMessage =
                'Selected file(s) are unsupported, corrupt, or empty. Only valid image files (JPG, PNG, WEBP, GIF, BMP) are supported.';
          });
          return;
        }
        setState(() {
          _images.addAll(validImages);
          if (unsupportedCount > 0) {
            _errorMessage =
                '$unsupportedCount unsupported file(s) were skipped. Added ${validImages.length} valid image(s).';
          } else {
            _errorMessage = null;
          }
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
      final pdf = pw.Document();
      for (final f in _images) {
        if (!await FileService().isImageFile(f.path)) {
          throw Exception(
              'Image file is missing, empty, corrupt, or invalid: ${FileService().getFileName(f.path)}');
        }
        final bytes = await f.readAsBytes();
        pw.MemoryImage img;
        try {
          img = pw.MemoryImage(bytes);
        } catch (e) {
          throw Exception(
              'Corrupt image format: ${FileService().getFileName(f.path)}');
        }
        pdf.addPage(pw.Page(
          pageFormat: _pageFormat,
          margin: _fitPage ? pw.EdgeInsets.zero : const pw.EdgeInsets.all(20),
          build: (_) => _fitPage
              ? pw.Image(img, fit: pw.BoxFit.contain)
              : pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
        ));
      }
      final dir = await getApplicationDocumentsDirectory();
      final path = FileService().joinPaths(
          dir.path, 'images_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await File(path).writeAsBytes(await pdf.save());

      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Images to PDF (${_images.length} images)',
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
        _errorMessage = 'Failed to convert images: $e';
        _isLoading = false;
      });
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final bg = isDark ? const Color(0xFF13131F) : Colors.white;
    final border = isDark ? const Color(0xFF1F1F2E) : const Color(0xFFE5E7EB);

    return Scaffold(
      appBar: AppBar(title: const Text('Images to PDF')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Loading Banner
          if (_isLoading)
            ToolLoadingBanner(
              message:
                  'Converting ${_images.length} image${_images.length > 1 ? 's' : ''} to PDF...',
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
          Text('Options',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Material(
            color: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  const Text('Page size',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  DropdownButton<PdfPageFormat>(
                    value: _pageFormat,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                          value: PdfPageFormat.a4, child: Text('A4')),
                      DropdownMenuItem(
                          value: PdfPageFormat.letter, child: Text('Letter')),
                      DropdownMenuItem(
                          value: PdfPageFormat.a3, child: Text('A3')),
                    ],
                    onChanged: _isLoading
                        ? null
                        : (v) {
                            if (v != null) setState(() => _pageFormat = v);
                          },
                  ),
                ]),
                const Divider(),
                SwitchListTile.adaptive(
                  title: const Text('Fit to page',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Scale image to fill page'),
                  value: _fitPage,
                  activeThumbColor: primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged:
                      _isLoading ? null : (v) => setState(() => _fitPage = v),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // Images Section Header
          Row(
            children: [
              Text('Images (${_images.length})',
                  style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_images.isNotEmpty && !_isLoading)
                TextButton(
                  onPressed: () => setState(() {
                    _images.clear();
                    _errorMessage = null;
                  }),
                  child: const Text('Clear all',
                      style: TextStyle(color: Color(0xFFDC2626))),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Empty state or Grid of selected images
          if (_images.isEmpty)
            ToolEmptyState(
              icon: Icons.image_rounded,
              title: 'No Images Selected',
              subtitle:
                  'Select photos or images (JPG, PNG, WEBP, GIF, BMP) from your gallery to create a PDF document',
              actionLabel: 'Select Images',
              onAction: _isLoading ? null : _pickImages,
            )
          else ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _images.length + 1,
              itemBuilder: (context, index) {
                if (index == _images.length) {
                  return InkWell(
                    onTap: _isLoading ? null : _pickImages,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2A2A40)
                              : const Color(0xFFE5E7EB),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded,
                              color: primary),
                          const SizedBox(height: 4),
                          Text(
                            'Add More',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final file = _images[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(file, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: _isLoading ? null : () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isLoading || _images.isEmpty) ? null : _convert,
              icon: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(_isLoading
                  ? 'Converting to PDF...'
                  : (_images.isEmpty
                      ? 'Select images first'
                      : 'Create PDF (${_images.length} pages)')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
