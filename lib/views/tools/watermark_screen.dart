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
  final _textCtrl = TextEditingController(text: 'CONFIDENTIAL');
  double _opacity = 0.25;
  double _angle = -0.4;
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

  Future<void> _apply() async {
    if (_pdfFile == null ||
        !await FileService().isFileAccessible(_pdfFile!.path)) {
      setState(() {
        _errorMessage = 'Selected file no longer exists or is inaccessible.';
      });
      return;
    }
    if (_textCtrl.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter watermark text.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successPath = null;
    });

    try {
      final path = await PdfService().watermarkPdf(
        pdfPath: _pdfFile!.path,
        watermarkText: _textCtrl.text,
        opacity: _opacity,
        angle: _angle,
        color: _wColor,
      );

      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Watermarked: ${_textCtrl.text}',
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
          'Add a customizable text watermark stamp overlay across all pages of your PDF document.',
      onPickFiles: _pick,
      selectedFiles: _pdfFile != null ? [_pdfFile!.path] : [],
      onRemoveFile: (_) {
        setState(() {
          _pdfFile = null;
          _errorMessage = null;
        });
      },
      onExecute: _pdfFile != null ? _apply : null,
      executeButtonLabel: 'Apply Watermark',
      executeButtonIcon: Icons.branding_watermark_rounded,
      pickButtonLabel: 'Select PDF',
      isLoading: _isLoading,
      loadingMessage: 'Applying watermark to PDF document...',
      errorMessage: _errorMessage,
      onDismissError: () => setState(() => _errorMessage = null),
      onRetry: _pdfFile != null ? _apply : null,
      successPath: _successPath,
      successTitle: 'Watermark Applied!',
      successSubtitle: 'Watermark text "${_textCtrl.text}" overlay complete.',
      defaultSavePrefix: 'WatermarkedPDF',
      onReset: () {
        setState(() {
          _successPath = null;
          _pdfFile = null;
          _errorMessage = null;
        });
      },
      emptyStateIcon: Icons.branding_watermark_rounded,
      emptyStateTitle: 'No PDF Selected',
      emptyStateSubtitle: 'Select a PDF document to overlay a text watermark',
      emptyStateActionLabel: 'Select PDF',
      extraConfig: _pdfFile == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
