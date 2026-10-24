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

  Future<void> _takePhotoWithCamera() async {
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

      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );

      if (!mounted || photo == null) return;

      if (await FileService().isImageFile(photo.path)) {
        setState(() {
          _images.add(File(photo.path));
          _errorMessage = null;
          _successPath = null;
        });
      } else {
        setState(() {
          _errorMessage =
              'The captured image is invalid or unreadable. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to take photo: $e';
      });
    }
  }

  Future<void> _showImageSourceModal() async {
    if (_isLoading) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Photos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose a source to add pages for your PDF document:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt_rounded, color: primary, size: 22),
                  ),
                  title: const Text('Take Photo with Camera',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Capture new photo using your phone camera'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _takePhotoWithCamera();
                  },
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded,
                        color: Color(0xFF8B5CF6), size: 22),
                  ),
                  title: const Text('Choose from Gallery',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Select multiple photos from device album'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImages();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openBigScreenReorder(int initialIndex) async {
    if (_images.isEmpty) return;
    final updatedList = await Navigator.push<List<File>>(
      context,
      MaterialPageRoute(
        builder: (ctx) => JpgToPdfReorderScreen(
          images: List<File>.from(_images),
          initialIndex: initialIndex,
          maxBatchPhotos: maxBatchPhotos,
          onTakeCameraPhoto: _takePhotoWithCamera,
        ),
      ),
    );

    if (updatedList != null && mounted) {
      setState(() {
        _images.clear();
        _images.addAll(updatedList);
        _errorMessage = null;
      });
    }
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

    List<String> preparedPaths = [];
    try {
      final imagePaths = _images.map((f) => f.path).toList();

      // Ensure images are oriented correctly using EXIF metadata (0, 90, 180, 270 deg)
      // and downscaled if exceeding 2048px width/height via background isolate.
      preparedPaths = await FileService().prepareImagesForPdf(imagePaths);

      final path = await PdfService().convertJpgToPdf(
        preparedPaths,
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
    } finally {
      // Clean up temporary prepared files if different from source images
      for (final p in preparedPaths) {
        if (!_images.any((f) => f.path == p)) {
          try {
            final tempF = File(p);
            if (tempF.existsSync()) tempF.deleteSync();
          } catch (_) {}
        }
      }
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
        if (!_isLoading) ...[
          IconButton(
            icon: const Icon(Icons.camera_alt_rounded),
            tooltip: 'Take Photo with Camera',
            onPressed:
                _images.length < maxBatchPhotos ? _takePhotoWithCamera : null,
          ),
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_rounded),
            tooltip: 'Add from Gallery',
            onPressed: _images.length < maxBatchPhotos ? _pickImages : null,
          ),
          if (_images.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_full_rounded),
              tooltip: 'Review & Reorder in Big Screen',
              onPressed: () => _openBigScreenReorder(0),
            ),
        ],
      ],
      onPickFiles: _showImageSourceModal,
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
                  message: 'Tap thumbnail to open Big Screen preview & reorder',
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

          // Big Screen Reorder Callout Banner when images exist
          if (_images.isNotEmpty && !_isLoading) ...[
            Material(
              color: primary.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _openBigScreenReorder(0),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.open_in_full_rounded,
                            color: Colors.white, size: 17),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Review & Reorder in Big Screen',
                              style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Inspect full pages & easily adjust page sequence before converting',
                              style: TextStyle(color: sub, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: primary, size: 13),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Empty state or Reorderable Grid of Selected Images
          if (_images.isEmpty) ...[
            ToolEmptyState(
              icon: Icons.add_photo_alternate_rounded,
              title: 'No Images Selected',
              subtitle:
                  'Take photos with camera or select from gallery to combine into a PDF in seconds',
              actionLabel: 'Select Images',
              onAction: _isLoading ? null : _showImageSourceModal,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _takePhotoWithCamera,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Take Photo',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: primary),
                      foregroundColor: primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickImages,
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('From Gallery',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else
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
            onTap: _isLoading ? null : _showImageSourceModal,
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
          GestureDetector(
            onTap: () => _openBigScreenReorder(index),
            child: Image.file(file, fit: BoxFit.cover),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: GestureDetector(
              onTap: () => _openBigScreenReorder(index),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
          ),
          Positioned(
            bottom: 4,
            left: 4,
            child: GestureDetector(
              onTap: () => _openBigScreenReorder(index),
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.fullscreen_rounded,
                    color: Colors.white, size: 12),
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

/// Full-screen interactive page reviewer and reorder screen.
/// Allows users to view large thumbnails, drag & drop to reorder,
/// use Move Up / Move Down buttons, zoom into full pages, and add camera photos.
class JpgToPdfReorderScreen extends StatefulWidget {
  final List<File> images;
  final int initialIndex;
  final int maxBatchPhotos;
  final Future<void> Function()? onTakeCameraPhoto;

  const JpgToPdfReorderScreen({
    Key? key,
    required this.images,
    this.initialIndex = 0,
    this.maxBatchPhotos = 50,
    this.onTakeCameraPhoto,
  }) : super(key: key);

  @override
  State<JpgToPdfReorderScreen> createState() => _JpgToPdfReorderScreenState();
}

class _JpgToPdfReorderScreenState extends State<JpgToPdfReorderScreen> {
  late List<File> _currentImages;
  bool _isCarouselView = false;
  late PageController _pageController;
  int _activeCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentImages = List<File>.from(widget.images);
    _activeCarouselIndex = widget.initialIndex.clamp(
      0,
      _currentImages.isEmpty ? 0 : _currentImages.length - 1,
    );
    _pageController = PageController(initialPage: _activeCarouselIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _movePage(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _currentImages.length ||
        newIndex < 0 ||
        newIndex >= _currentImages.length) {
      return;
    }
    setState(() {
      final item = _currentImages.removeAt(oldIndex);
      _currentImages.insert(newIndex, item);
      if (_isCarouselView) {
        _activeCarouselIndex = newIndex;
        _pageController.jumpToPage(newIndex);
      }
    });
  }

  void _removePage(int index) {
    if (index < 0 || index >= _currentImages.length) return;
    setState(() {
      _currentImages.removeAt(index);
      if (_activeCarouselIndex >= _currentImages.length &&
          _currentImages.isNotEmpty) {
        _activeCarouselIndex = _currentImages.length - 1;
      }
    });
  }

  Future<void> _capturePhoto() async {
    final remaining = widget.maxBatchPhotos - _currentImages.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Maximum limit of ${widget.maxBatchPhotos} photos reached.')),
      );
      return;
    }
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );
      if (!mounted) return;
      if (photo != null && await FileService().isImageFile(photo.path)) {
        if (!mounted) return;
        setState(() {
          _currentImages.add(File(photo.path));
        });
        if (_isCarouselView) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _pageController.jumpToPage(_currentImages.length - 1);
            }
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: $e')),
      );
    }
  }

  Future<void> _pickGalleryPhotos() async {
    final remaining = widget.maxBatchPhotos - _currentImages.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Maximum limit of ${widget.maxBatchPhotos} photos reached.')),
      );
      return;
    }
    try {
      final picked = await ImagePicker().pickMultiImage(
        imageQuality: 95,
        limit: remaining,
      );
      if (!mounted) return;
      if (picked.isNotEmpty) {
        for (final x in picked) {
          if (_currentImages.length >= widget.maxBatchPhotos) break;
          if (await FileService().isImageFile(x.path)) {
            if (!mounted) return;
            setState(() {
              _currentImages.add(File(x.path));
            });
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gallery error: $e')),
      );
    }
  }

  void _showZoomDialog(File file, int index) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(
                'Page ${index + 1} of ${_currentImages.length}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final bg = isDark ? const Color(0xFF14141E) : Colors.white;
    final border = isDark ? const Color(0xFF1F1F2E) : const Color(0xFFE5E7EB);
    final sub = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Review & Reorder Pages',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(
                '${_currentImages.length} page${_currentImages.length != 1 ? 's' : ''} in PDF',
                style: TextStyle(fontSize: 11, color: sub),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isCarouselView
                    ? Icons.view_agenda_rounded
                    : Icons.view_carousel_rounded,
                color: primary,
              ),
              tooltip: _isCarouselView
                  ? 'Switch to Reorder List'
                  : 'Switch to Full Page View',
              onPressed: () {
                setState(() {
                  _isCarouselView = !_isCarouselView;
                });
              },
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, _currentImages),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Done',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(foregroundColor: primary),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: _currentImages.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 64, color: sub),
                    const SizedBox(height: 12),
                    const Text('No pages remaining',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _capturePhoto,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Take Photo with Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            : _isCarouselView
                ? _buildCarouselView(primary, bg, border, sub)
                : _buildReorderListView(primary, bg, border, sub),
        bottomNavigationBar: _buildBottomActionBar(primary, bg, border),
      ),
    );
  }

  Widget _buildReorderListView(
      Color primary, Color bg, Color border, Color sub) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: primary.withValues(alpha: 0.06),
          child: Row(
            children: [
              Icon(Icons.swap_vert_rounded, size: 18, color: primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Drag handle to reorder, or use the ⬆ ⬇ arrows. Tap image to zoom.',
                  style: TextStyle(
                      fontSize: 12,
                      color: primary,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: _currentImages.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              _movePage(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final file = _currentImages[index];
              final isFirst = index == 0;
              final isLast = index == _currentImages.length - 1;

              return Card(
                key: ValueKey('reorder_item_${file.path}_$index'),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: border),
                ),
                elevation: 0,
                color: bg,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      // Large Preview Thumbnail with Zoom
                      GestureDetector(
                        onTap: () => _showZoomDialog(file, index),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                file,
                                width: 85,
                                height: 110,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(Icons.zoom_in_rounded,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Page Metadata & Quick Arrows
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Page ${index + 1}',
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              FileService().getFileName(file.path),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 10),

                            // Up and Down Reorder Buttons
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed:
                                      isFirst ? null : () => _movePage(index, index - 1),
                                  icon: const Icon(Icons.arrow_upward_rounded,
                                      size: 15),
                                  label: const Text('Up',
                                      style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed:
                                      isLast ? null : () => _movePage(index, index + 1),
                                  icon: const Icon(Icons.arrow_downward_rounded,
                                      size: 15),
                                  label: const Text('Down',
                                      style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Trailing Actions: Remove & Drag Handle
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Color(0xFFDC2626), size: 22),
                            tooltip: 'Remove Page',
                            onPressed: () => _removePage(index),
                          ),
                          const SizedBox(height: 8),
                          ReorderableDragStartListener(
                            index: index,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.drag_handle_rounded,
                                  color: primary, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselView(Color primary, Color bg, Color border, Color sub) {
    return Column(
      children: [
        // Page indicator header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page ${_activeCarouselIndex + 1} of ${_currentImages.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                    onPressed: _activeCarouselIndex > 0
                        ? () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onPressed: _activeCarouselIndex < _currentImages.length - 1
                        ? () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Interactive Full-Page Swiper
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _currentImages.length,
            onPageChanged: (i) => setState(() => _activeCarouselIndex = i),
            itemBuilder: (context, index) {
              final file = _currentImages[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Image.file(file, fit: BoxFit.contain),
                  ),
                ),
              );
            },
          ),
        ),

        // Carousel Page Shift Controls
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _activeCarouselIndex > 0
                    ? () => _movePage(
                        _activeCarouselIndex, _activeCarouselIndex - 1)
                    : null,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Move Left'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: bg,
                  foregroundColor: primary,
                  elevation: 0,
                  side: BorderSide(color: border),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFDC2626)),
                tooltip: 'Delete this page',
                onPressed: () => _removePage(_activeCarouselIndex),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _activeCarouselIndex < _currentImages.length - 1
                    ? () => _movePage(
                        _activeCarouselIndex, _activeCarouselIndex + 1)
                    : null,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Move Right'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: bg,
                  foregroundColor: primary,
                  elevation: 0,
                  side: BorderSide(color: border),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(Color primary, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: _currentImages.length < widget.maxBatchPhotos
                  ? _capturePhoto
                  : null,
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('Camera'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _currentImages.length < widget.maxBatchPhotos
                  ? _pickGalleryPhotos
                  : null,
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              label: const Text('Gallery'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, _currentImages),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  'Apply Order (${_currentImages.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
