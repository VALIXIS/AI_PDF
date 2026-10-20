import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/ad_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';
import 'package:pdf_ai_toolkit/widgets/tool_screen_shell.dart';

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
        _errorMessage = 'Failed to select photos: $e';
      });
    }
  }

  void _reorderImages(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _images.length ||
        newIndex < 0 ||
        newIndex >= _images.length) {
      return;
    }
    setState(() {
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
    });
  }

  Future<void> _convert() async {
    if (_images.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one photo to convert.';
      });
      return;
    }

    // Gatekeeper: Ultra Vector / High Resolution 300 DPI mode
    if (_qualityName == 'high') {
      final isUnlocked =
          AdService().isFeatureUnlocked(UnlockFeature.vectorExport);
      if (!isUnlocked) {
        final shouldWatch = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lock_rounded, color: Color(0xFF0EA5E9), size: 24),
                SizedBox(width: 8),
                Text('High DPI Mode'),
              ],
            ),
            content: const Text(
              '300 DPI High-Resolution mode creates pristine print-ready vector documents. Watch a short sponsored ad to unlock unlimited High-Res exports for 30 minutes!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Use Standard (150 DPI)'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('Watch Video & Unlock'),
              ),
            ],
          ),
        );

        if (shouldWatch == true) {
          final rewarded =
              await AdService().showRewardedAd(UnlockFeature.vectorExport);
          if (!mounted) return;
          if (!rewarded) {
            setState(() {
              _errorMessage =
                  'Ad could not be loaded. Defaulting to 150 DPI Balanced quality.';
              _qualitySliderValue = 1.0;
            });
          }
        } else {
          setState(() {
            _qualitySliderValue = 1.0; // fallback to medium
          });
        }
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successPath = null;
    });

    final stopwatch = Stopwatch()..start();

    try {
      final imagePaths = _images.map((f) => f.path).toList();
      final path = await PdfService().convertJpgToPdf(
        imagePaths,
        format: _pageFormat,
        fitPage: _fitPage,
        quality: _qualityName,
      );

      stopwatch.stop();

      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: '${_images.length} Photos → PDF',
        date: DateTime.now(),
        filePath: path,
        toolType: 'jpg_to_pdf',
      ));

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successPath = path;
        _conversionSeconds = stopwatch.elapsedMilliseconds / 1000.0;
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

    return ToolScreenShell(
      title: 'Images to PDF',
      explanation:
          'Convert multiple photos or gallery images into a single professional PDF document.',
      actions: [
        if (_images.isNotEmpty && !_isLoading)
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_rounded),
            tooltip: 'Add More Photos',
            onPressed: _images.length < maxBatchPhotos ? _pickImages : null,
          ),
      ],
      onPickFiles: _pickImages,
      selectedFiles: _images.map((f) => f.path).toList(),
      onRemoveFile: (idx) {
        setState(() {
          _images.removeAt(idx);
          _errorMessage = null;
        });
      },
      onExecute: _images.isNotEmpty ? _convert : null,
      executeButtonLabel: _images.isEmpty
          ? 'Select images first'
          : 'Convert ${_images.length} Photo${_images.length > 1 ? 's' : ''} to PDF',
      executeButtonIcon: Icons.picture_as_pdf_rounded,
      alwaysShowExecuteButton: true,
      showPickButton: false,
      isLoading: _isLoading,
      loadingMessage:
          'Compressing & bundling ${_images.length} photos in background isolate...',
      errorMessage: _errorMessage,
      onDismissError: () => setState(() => _errorMessage = null),
      onRetry: _images.isNotEmpty ? _convert : null,
      successPath: _successPath,
      successTitle: 'PDF Created Successfully!',
      successSubtitle:
          'Bundled ${_images.length} photos in ${_conversionSeconds.toStringAsFixed(2)}s using background isolate compression.',
      defaultSavePrefix: 'BatchImages',
      onReset: () {
        setState(() {
          _successPath = null;
          _images.clear();
          _errorMessage = null;
        });
      },
      scrollable: true,
      customContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compression & Layout Options Card
          Text(
            'Compression & Output Settings',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
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
                  if (_qualitySliderValue == 2) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF0EA5E9)
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.high_quality_rounded,
                              color: Color(0xFF0EA5E9), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AdService().isFeatureUnlocked(
                                      UnlockFeature.vectorExport)
                                  ? '✨ High-Res Vector Export Unlocked (${AdService().getRemainingMinutes(UnlockFeature.vectorExport)}m left)'
                                  : '300 DPI Ultra Vector Mode (High-eCPM Feature)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          WatchAdUnlockButton(
                            feature: UnlockFeature.vectorExport,
                            onUnlocked: () => setState(() {}),
                            customLabel: 'Unlock Free',
                          ),
                        ],
                      ),
                    ),
                  ],
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
                            value: null, child: Text('Auto (Fit to Photo)')),
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
                    subtitle: const Text(
                        'Scale images edge-to-edge with zero white bars'),
                    value: _fitPage,
                    activeThumbColor: primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: _isLoading
                        ? null
                        : (v) => setState(() => _fitPage = v),
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
                  child:
                      Icon(Icons.info_outline_rounded, size: 16, color: sub),
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
          if (_images.isEmpty)
            ToolEmptyState(
              icon: Icons.add_photo_alternate_rounded,
              title: 'No Images Selected',
              subtitle:
                  'Select up to $maxBatchPhotos gallery photos to compress and combine into a PDF in seconds',
              actionLabel: 'Select Images',
              onAction: _isLoading ? null : _pickImages,
            )
          else
            _buildDraggableThumbnailGrid(bg, border, sub, primary),
        ],
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
                opacity: 0.3,
                child: _buildGridItem(
                    file, index, bg, border, sub, primary, false),
              ),
              child: _buildGridItem(
                  file, index, bg, border, sub, primary, isTargeted),
            );
          },
        );
      },
    );
  }

  Widget _buildGridItem(File file, int index, Color bg, Color border, Color sub,
      Color primary, bool isTargeted) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTargeted ? primary : border,
          width: isTargeted ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(file, fit: BoxFit.cover),
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _images.removeAt(index);
                      });
                    },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
