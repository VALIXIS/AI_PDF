import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Watermark PDF')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Loading Banner
          if (_isLoading)
            const ToolLoadingBanner(
              message: 'Applying watermark to PDF document...',
            ),

          // Error Banner
          if (_errorMessage != null)
            ToolErrorBanner(
              message: _errorMessage!,
              onRetry: _pdfFile != null ? _apply : null,
              onDismiss: () => setState(() => _errorMessage = null),
            ),

          // Success Card
          if (_successPath != null)
            ToolSuccessCard(
              title: 'Watermark Applied!',
              subtitle: 'Watermark text "${_textCtrl.text}" overlay complete.',
              filePath: _successPath,
              onSave: () {
                if (_successPath != null && mounted) {
                  ShareService.saveFileToUserDestination(context, sourcePath: _successPath!);
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
                  _pdfFile = null;
                  _errorMessage = null;
                });
              },
            ),

          // File Picker or Empty State
          if (_pdfFile == null && _successPath == null)
            ToolEmptyState(
              icon: Icons.branding_watermark_rounded,
              title: 'No PDF Selected',
              subtitle: 'Select a PDF document to overlay a text watermark',
              actionLabel: 'Select PDF',
              onAction: _isLoading ? null : _pick,
            )
          else if (_pdfFile != null) ...[
            _FilePicker(
              file: _pdfFile,
              onPick: _isLoading ? () {} : _pick,
              bg: bg,
              border: border,
              sub: sub,
              primary: primary,
            ),
            const SizedBox(height: 20),

            Text('Watermark Text',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              enabled: !_isLoading,
              controller: _textCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. CONFIDENTIAL',
                isDense: true,
              ),
              onChanged: (_) {
                if (_errorMessage != null) setState(() => _errorMessage = null);
              },
            ),
            const SizedBox(height: 20),

            // Settings Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border)),
              child: Column(children: [
                _SliderRow(
                  label: 'Opacity',
                  value: _opacity,
                  min: 0.05,
                  max: 0.8,
                  primary: primary,
                  onChanged:
                      _isLoading ? (_) {} : (v) => setState(() => _opacity = v),
                ),
                const Divider(),
                _SliderRow(
                  label: 'Angle',
                  value: _angle,
                  min: -1.0,
                  max: 1.0,
                  primary: primary,
                  onChanged:
                      _isLoading ? (_) {} : (v) => setState(() => _angle = v),
                ),
                const Divider(),
                Row(children: [
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
                      onTap:
                          _isLoading ? null : () => setState(() => _wColor = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color:
                                  _wColor == c ? primary : Colors.transparent,
                              width: 2.5),
                        ),
                      ),
                    ),
                ]),
              ]),
            ),
            const SizedBox(height: 20),

            // Live preview
            Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(alignment: Alignment.center, children: [
                  Text('Preview', style: TextStyle(color: sub, fontSize: 13)),
                  Transform.rotate(
                    angle: _angle,
                    child: Text(
                      _textCtrl.text.isEmpty ? 'WATERMARK' : _textCtrl.text,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: _wColor.withValues(alpha: _opacity),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_pdfFile == null || _isLoading) ? null : _apply,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.branding_watermark_rounded),
              label: const Text('Apply Watermark',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final Color primary;
  final ValueChanged<double> onChanged;
  const _SliderRow(
      {required this.label,
      required this.value,
      required this.min,
      required this.max,
      required this.primary,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(
            child: Slider(
                value: value,
                min: min,
                max: max,
                activeColor: primary,
                onChanged: onChanged)),
        Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 12)),
      ]);
}

class _FilePicker extends StatelessWidget {
  final File? file;
  final VoidCallback onPick;
  final Color bg, border, sub, primary;
  const _FilePicker(
      {required this.file,
      required this.onPick,
      required this.bg,
      required this.border,
      required this.sub,
      required this.primary});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onPick,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: file != null ? primary.withValues(alpha: 0.05) : bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: file != null ? primary.withValues(alpha: 0.3) : border),
          ),
          child: Row(children: [
            Icon(Icons.picture_as_pdf_rounded,
                color: file != null ? primary : sub, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        file != null
                            ? FileService().getFileName(file!.path)
                            : 'Choose PDF file',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: file != null ? primary : sub)),
                    if (file == null)
                      Text('Tap to browse',
                          style: TextStyle(color: sub, fontSize: 12)),
                  ]),
            ),
            Icon(Icons.chevron_right_rounded, color: sub),
          ]),
        ),
      );
}
