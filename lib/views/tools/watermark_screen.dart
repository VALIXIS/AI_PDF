import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/widgets/tool_screen_shell.dart';

class WatermarkScreen extends StatefulWidget {
  const WatermarkScreen({Key? key}) : super(key: key);
  @override
  State<WatermarkScreen> createState() => _WatermarkScreenState();
}

class _WatermarkScreenState extends State<WatermarkScreen> {
  File? _pdfFile;
  bool _isLoading = false;
  bool _isImageMode = false;
  File? _imageFile;
  final _textCtrl = TextEditingController(text: 'CONFIDENTIAL');
  double _opacity = 0.25;
  double _angle = -0.4;
  double _imageScale = 0.6;
  Color _wColor = const Color(0xFFDC2626);
  String? _errorMessage;
  String? _successPath;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final r = await FilePicker.pickFiles(
          type: FileType.custom, allowedExtensions: ['pdf']);
      if (!mounted) return;
      if (r?.files.single.path != null) {
        setState(() {
          _pdfFile = File(r!.files.single.path!);
          _errorMessage = null;
          _successPath = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to pick file: $e';
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final r = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (!mounted) return;
      if (r?.files.single.path != null) {
        setState(() {
          _imageFile = File(r!.files.single.path!);
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to pick watermark image: $e';
      });
    }
  }

  Future<void> _apply() async {
    if (_pdfFile == null ||
        !await FileService().isFileAccessible(_pdfFile!.path)) {
      setState(() {
        _errorMessage = 'Selected file no longer exists or is inaccessible.';
      });
      return;
    }
    if (!_isImageMode && _textCtrl.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter watermark text.';
      });
      return;
    }
    if (_isImageMode && (_imageFile == null || !await _imageFile!.exists())) {
      setState(() {
        _errorMessage = 'Please select a watermark image.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successPath = null;
    });

    try {
      String path;
      if (_isImageMode) {
        final imageBytes = await _imageFile!.readAsBytes();
        path = await PdfService().watermarkPdf(
          pdfPath: _pdfFile!.path,
          watermarkImageBytes: imageBytes,
          opacity: _opacity,
          angle: _angle,
          imageScale: _imageScale,
        );
      } else {
        path = await PdfService().watermarkPdf(
          pdfPath: _pdfFile!.path,
          watermarkText: _textCtrl.text,
          opacity: _opacity,
          angle: _angle,
          color: _wColor,
        );
      }

      final title = _isImageMode
          ? 'Image Watermarked'
          : 'Watermarked: ${_textCtrl.text}';

      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: title,
        date: DateTime.now(),
        filePath: path,
        toolType: 'watermark',
      ));

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successPath = path;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
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
    final sub = isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);

    return ToolScreenShell(
      title: 'Watermark PDF',
      explanation:
          'Add a customizable text or image watermark overlay across all pages of your PDF, auto-aligned to rotated pages and crop boxes.',
      onPickFiles: _pick,
      selectedFiles: _pdfFile != null ? [_pdfFile!.path] : [],
      onRemoveFile: (_) {
        setState(() {
          _pdfFile = null;
          _errorMessage = null;
        });
      },
      onExecute: _pdfFile != null ? _apply : _pick,
      executeButtonLabel:
          _pdfFile == null ? 'Select PDF to Apply' : 'Apply Watermark',
      executeButtonIcon: Icons.branding_watermark_rounded,
      pickButtonLabel: 'Select PDF',
      showPickButton: false,
      scrollable: true,
      isLoading: _isLoading,
      loadingMessage: 'Applying watermark to PDF document...',
      errorMessage: _errorMessage,
      onDismissError: () => setState(() => _errorMessage = null),
      onRetry: _pdfFile != null ? _apply : null,
      successPath: _successPath,
      successTitle: 'Watermark Applied!',
      successSubtitle: _isImageMode
          ? 'Image watermark overlay complete.'
          : 'Watermark text "${_textCtrl.text}" overlay complete.',
      defaultSavePrefix: 'WatermarkedPDF',
      onReset: () {
        setState(() {
          _successPath = null;
          _pdfFile = null;
          _imageFile = null;
          _errorMessage = null;
        });
      },
      emptyStateIcon: Icons.branding_watermark_rounded,
      emptyStateTitle: 'No PDF Selected',
      emptyStateSubtitle: 'Select a PDF document to overlay a text or image watermark',
      emptyStateActionLabel: 'Select PDF',
      customContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected PDF Document Status / Picker Card
          GestureDetector(
            onTap: _isLoading ? null : _pick,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _pdfFile != null
                      ? primary.withValues(alpha: 0.4)
                      : primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _pdfFile != null
                        ? Icons.picture_as_pdf_rounded
                        : Icons.file_upload_outlined,
                    color: primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pdfFile != null
                              ? FileService().getFileName(_pdfFile!.path)
                              : 'Select PDF Document',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _pdfFile != null
                              ? 'Tap to select another file'
                              : 'Tap to choose a PDF to watermark',
                          style: TextStyle(fontSize: 12, color: sub),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _pdfFile != null
                        ? Icons.swap_horiz_rounded
                        : Icons.chevron_right_rounded,
                    color: sub,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Rotation & CropBox Offset Auto-Alignment info badge
          Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.crop_rotate_rounded, size: 18, color: primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Auto-aligns to page rotation (90°, 180°, 270°) & CropBox offsets',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Watermark Type Segmented Button
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Text Watermark'),
                      icon: Icon(Icons.text_fields_rounded),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Image Watermark'),
                      icon: Icon(Icons.image_outlined),
                    ),
                  ],
                  selected: {_isImageMode},
                  onSelectionChanged: _isLoading
                      ? null
                      : (newSelection) {
                          setState(() {
                            _isImageMode = newSelection.first;
                            _errorMessage = null;
                          });
                        },
                ),
                const SizedBox(height: 16),

                if (!_isImageMode) ...[
                  Text(
                    'Watermark Text',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    enabled: !_isLoading,
                    controller: _textCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. CONFIDENTIAL',
                      isDense: true,
                    ),
                    onChanged: (_) {
                      if (_errorMessage != null) {
                        setState(() => _errorMessage = null);
                      }
                    },
                  ),
                ] else ...[
                  Text(
                    'Watermark Image',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _pickImage,
                    icon: Icon(
                      _imageFile == null
                          ? Icons.add_photo_alternate_outlined
                          : Icons.check_circle_outline_rounded,
                      color: _imageFile == null ? null : primary,
                    ),
                    label: Text(
                      _imageFile == null
                          ? 'Select PNG / JPG Logo'
                          : FileService().getFileName(_imageFile!.path),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    children: [
                      _SliderRow(
                        label: 'Opacity',
                        value: _opacity,
                        min: 0.05,
                        max: 0.8,
                        primary: primary,
                        onChanged: _isLoading
                            ? (_) {}
                            : (v) => setState(() => _opacity = v),
                      ),
                      const Divider(),
                      _SliderRow(
                        label: 'Angle',
                        value: _angle,
                        min: -1.0,
                        max: 1.0,
                        primary: primary,
                        onChanged: _isLoading
                            ? (_) {}
                            : (v) => setState(() => _angle = v),
                      ),
                      if (_isImageMode) ...[
                        const Divider(),
                        _SliderRow(
                          label: 'Scale',
                          value: _imageScale,
                          min: 0.2,
                          max: 1.5,
                          primary: primary,
                          onChanged: _isLoading
                              ? (_) {}
                              : (v) => setState(() => _imageScale = v),
                        ),
                      ],
                      if (!_isImageMode) ...[
                        const Divider(),
                        Row(
                          children: [
                            const Text('Color',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const Spacer(),
                            for (final c in [
                              const Color(0xFFDC2626),
                              const Color(0xFF2563EB),
                              Colors.black,
                              const Color(0xFF059669)
                            ])
                              GestureDetector(
                                onTap: _isLoading
                                    ? null
                                    : () => setState(() => _wColor = c),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _wColor == c
                                          ? primary
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text('Preview',
                            style: TextStyle(color: sub, fontSize: 13)),
                        if (!_isImageMode)
                          Transform.rotate(
                            angle: _angle,
                            child: Text(
                              _textCtrl.text.isEmpty
                                  ? 'WATERMARK'
                                  : _textCtrl.text,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: _wColor.withValues(alpha: _opacity),
                              ),
                            ),
                          )
                        else if (_imageFile != null)
                          Transform.rotate(
                            angle: _angle,
                            child: Opacity(
                              opacity: _opacity,
                              child: Image.file(
                                _imageFile!,
                                height: 80 * _imageScale,
                                fit: BoxFit.contain,
                              ),
                            ),
                          )
                        else
                          Text(
                            'No image chosen',
                            style: TextStyle(color: sub, fontSize: 12),
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

class _SliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final Color primary;
  final ValueChanged<double> onChanged;
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.primary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              activeColor: primary,
              onChanged: onChanged,
            ),
          ),
          Text(value.toStringAsFixed(2),
              style: const TextStyle(fontSize: 12)),
        ],
      );
}
