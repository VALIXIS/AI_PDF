import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_editor_screen.dart';

class JpgToPdfScreen extends StatefulWidget {
  const JpgToPdfScreen({Key? key}) : super(key: key);

  @override
  State<JpgToPdfScreen> createState() => _JpgToPdfScreenState();
}

class _JpgToPdfScreenState extends State<JpgToPdfScreen> {
  static const int maxBatchPhotos = 50;

  final List<File> _images = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successPath;
  double _conversionSeconds = 0.0;

  // Conversion options: null = Auto (Fit to photo size)
  PdfPageFormat? _pageFormat;
  bool _fitPage = true;
  double _qualitySliderValue = 1.0; // 0 = Low, 1 = Medium, 2 = High

  String get _qualityName {
    if (_qualitySliderValue <= 0.4) return 'low';
    if (_qualitySliderValue >= 1.6) return 'high';
    return 'medium';
  }

  String get _qualityLabel {
    if (_qualitySliderValue <= 0.4) return 'Low (72 DPI - Small Size)';
    if (_qualitySliderValue >= 1.6) return 'High (300 DPI - Print Quality)';
    return 'Medium (150 DPI - Balanced)';
  }

  Future<void> _pickImages() async {
    if (_isLoading) return;
    try {
      final remainingSlots = maxBatchPhotos - _images.length;
      if (remainingSlots <= 0) {
        setState(() {
          _errorMessage =
              'Maximum limit of $maxBatchPhotos photos reached. Please remove some images before adding more.';
        });
        return;
      }

      final picked = await ImagePicker().pickMultiImage(
        imageQuality: 95,
        limit: remainingSlots,
      );

      if (!mounted) return;
      if (picked.isNotEmpty) {
        final validImages = <File>[];
        int unsupportedCount = 0;

        for (final x in picked) {
          if (validImages.length + _images.length >= maxBatchPhotos) {
            break;
          }
          if (await FileService().isImageFile(x.path)) {
            validImages.add(File(x.path));
          } else {
            unsupportedCount++;
          }
        }

        if (validImages.isEmpty) {
          setState(() {
            _errorMessage =
                'Selected file(s) are unsupported, corrupt, or empty. Only valid images (JPG, PNG, WEBP, GIF, BMP) are supported.';
          });
          return;
        }

        setState(() {
          _images.addAll(validImages);
          if (unsupportedCount > 0) {
            _errorMessage =
                '$unsupportedCount unsupported file(s) skipped. Added ${validImages.length} photo(s).';
          } else if (picked.length > remainingSlots) {
            _errorMessage =
                'Added ${validImages.length} photo(s) (capped at $maxBatchPhotos limit).';
          } else {
            _errorMessage = null;
          }
          _successPath = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to select images: $e';
      });
    }
  }

  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
    });
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

    final stopwatch = Stopwatch()..start();

    try {
      final imagePaths = _images.map((f) => f.path).toList();
      final path = await PdfService().computeBatchImageToPdf(
        imagePaths: imagePaths,
        quality: _qualityName,
        pageFormat: _pageFormat,
        fitPage: _fitPage,
      );

      stopwatch.stop();
      final elapsed = stopwatch.elapsedMilliseconds / 1000.0;

      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Batch Images to PDF (${_images.length})',
        date: DateTime.now(),
        filePath: path,
        toolType: 'jpg_to_pdf',
      ));

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successPath = path;
        _conversionSeconds = elapsed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('PdfServiceException: ', '');
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
      appBar: AppBar(
        title: const Text('Images to PDF'),
        actions: [
          if (_images.isNotEmpty && !_isLoading)
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_rounded),
              tooltip: 'Add More Photos',
              onPressed: _images.length < maxBatchPhotos ? _pickImages : null,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Loading Banner
          if (_isLoading)
            ToolLoadingBanner(
              message:
                  'Compressing & bundling ${_images.length} photos in background isolate...',
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
              subtitle:
                  'Bundled ${_images.length} photos in ${_conversionSeconds.toStringAsFixed(2)}s using background isolate compression.',
              filePath: _successPath,
              onSave: () {
                if (_successPath != null && mounted) {
                  ShareService.promptAndSaveFileDirectToDownloads(
                    context,
                    sourcePath: _successPath!,
                    defaultPrefix: 'BatchImages',
                    onOpen: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PdfEditorScreen(initialFilePath: _successPath!),
                        ),
                      );
                    },
                  );
                }
              },
              onShare: () {
                if (_successPath != null && mounted) {
                  ShareService.shareFile(context, filePath: _successPath!);
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

          // Compression & Layout Options Card
          Text('Compression & Output Settings',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quality Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('DPI & Quality',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        _qualityLabel,
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Slider(
                    value: _qualitySliderValue,
                    min: 0,
                    max: 2,
                    divisions: 2,
                    activeColor: primary,
                    label: _qualityName.toUpperCase(),
                    onChanged: _isLoading
                        ? null
                        : (v) {
                            setState(() => _qualitySliderValue = v);
                          },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Low (72 DPI)',
                          style: TextStyle(fontSize: 11, color: sub)),
                      Text('Medium (150 DPI)',
                          style: TextStyle(fontSize: 11, color: sub)),
                      Text('High (300 DPI)',
                          style: TextStyle(fontSize: 11, color: sub)),
                    ],
                  ),
                  const Divider(height: 24),

                  // Page Size Selection
                  Row(children: [
                    const Text('Page size',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    DropdownButton<PdfPageFormat?>(
                      value: _pageFormat,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem<PdfPageFormat?>(
                            value: null,
                            child: Text('Auto (Fit to Photo)')),
                        DropdownMenuItem<PdfPageFormat?>(
                            value: PdfPageFormat.a4,
                            child: Text('A4 Document')),
                        DropdownMenuItem<PdfPageFormat?>(
                            value: PdfPageFormat.letter,
                            child: Text('US Letter')),
                        DropdownMenuItem<PdfPageFormat?>(
                            value: PdfPageFormat.a3,
                            child: Text('A3 Poster')),
                      ],
                      onChanged: _isLoading
                          ? null
                          : (v) {
                              setState(() => _pageFormat = v);
                            },
                    ),
                  ]),
                  const Divider(height: 16),

                  // Fit Page Switch
                  SwitchListTile.adaptive(
                    title: const Text('Fit to page',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Scale images edge-to-edge with zero white bars'),
                    value: _fitPage,
                    activeThumbColor: primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged:
                        _isLoading ? null : (v) => setState(() => _fitPage = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Selected Photos Header
          Row(
            children: [
              Text('Selected Photos (${_images.length}/$maxBatchPhotos)',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              if (_images.isNotEmpty)
                Tooltip(
                  message: 'Long-press and drag thumbnails to reorder pages',
                  child: Icon(Icons.info_outline_rounded, size: 16, color: sub),
                ),
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

          // Empty state or Reorderable Grid of Selected Images
          if (_images.isEmpty && _successPath == null)
            ToolEmptyState(
              icon: Icons.add_photo_alternate_rounded,
              title: 'No Images Selected',
              subtitle:
                  'Select up to $maxBatchPhotos gallery photos to compress and combine into a PDF in seconds',
              actionLabel: 'Select Images',
              onAction: _isLoading ? null : _pickImages,
            )
          else if (_images.isNotEmpty)
            _buildDraggableThumbnailGrid(bg, border, sub, primary),

          const SizedBox(height: 24),

          // Convert Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_images.isEmpty || _isLoading) ? null : _convert,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(
                _images.isEmpty
                    ? 'Select images first'
                    : 'Convert ${_images.length} Photo${_images.length > 1 ? 's' : ''} to PDF',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildDraggableThumbnailGrid(
      Color bg, Color border, Color sub, Color primary) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemCount: _images.length < maxBatchPhotos
          ? _images.length + 1
          : _images.length,
      itemBuilder: (context, index) {
        if (index == _images.length) {
          return GestureDetector(
            onTap: _isLoading ? null : _pickImages,
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border, style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: primary, size: 28),
                  const SizedBox(height: 4),
                  Text('Add More',
                      style: TextStyle(
                          color: primary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600)),
                  Text(
                    '${maxBatchPhotos - _images.length} left',
                    style: TextStyle(color: sub, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        }

        final file = _images[index];

        return DragTarget<int>(
          onWillAcceptWithDetails: (details) => details.data != index,
          onAcceptWithDetails: (details) {
            _reorderImages(details.data, index);
          },
          builder: (context, candidateData, rejectedData) {
            final isTargeted = candidateData.isNotEmpty;

            return LongPressDraggable<int>(
              data: index,
              feedback: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 100,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primary, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.file(file, fit: BoxFit.cover),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.35,
                child: _buildThumbnailCard(
                    file, index, bg, border, isTargeted, primary),
              ),
              child: _buildThumbnailCard(
                  file, index, bg, border, isTargeted, primary),
            );
          },
        );
      },
    );
  }

  Widget _buildThumbnailCard(File file, int index, Color bg, Color border,
      bool isTargeted, Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTargeted ? primary : border,
          width: isTargeted ? 2.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(file, fit: BoxFit.cover),
          // Page number pill
          Positioned(
            top: 5,
            left: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '#${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Reorder drag hint indicator
          Positioned(
            bottom: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.drag_indicator_rounded,
                  color: Colors.white, size: 13),
            ),
          ),
          // Delete badge
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _images.removeAt(index);
                        _errorMessage = null;
                      });
                    },
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
