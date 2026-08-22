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

class RotatePdfScreen extends StatefulWidget {
  const RotatePdfScreen({Key? key}) : super(key: key);
  @override
  State<RotatePdfScreen> createState() => _RotatePdfScreenState();
}

class _RotatePdfScreenState extends State<RotatePdfScreen> {
  File? _pdfFile;
  bool _isLoading = false;
  int _rotation = 90;
  String? _errorMessage;
  String? _successPath;

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

  Future<void> _rotate() async {
    if (_pdfFile == null ||
        !await FileService().isFileAccessible(_pdfFile!.path)) {
      setState(() {
        _errorMessage = 'Selected file no longer exists or is inaccessible.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successPath = null;
    });

    try {
      final path = await PdfService().rotatePdf(
        pdfPath: _pdfFile!.path,
        rotationAngle: _rotation,
      );

      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Rotated $_rotation°',
        date: DateTime.now(),
        filePath: path,
        toolType: 'rotate_pdf',
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
      appBar: AppBar(title: const Text('Rotate PDF')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Loading Banner
          if (_isLoading)
            ToolLoadingBanner(
              message: 'Rotating PDF by $_rotation°...',
            ),

          // Error Banner
          if (_errorMessage != null)
            ToolErrorBanner(
              message: _errorMessage!,
              onRetry: _pdfFile != null ? _rotate : null,
              onDismiss: () => setState(() => _errorMessage = null),
            ),

          // Success Card
          if (_successPath != null)
            ToolSuccessCard(
              title: 'PDF Rotated Successfully!',
              subtitle: 'Orientation rotated by $_rotation°.',
              filePath: _successPath,
              onShare: () {
                if (_successPath != null && mounted) {
                  ShareService.showSaveShareDialog(context, _successPath!);
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

          // Selected File or Empty State
          if (_pdfFile != null) ...[
            GestureDetector(
              onTap: _isLoading ? null : _pick,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primary.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.picture_as_pdf_rounded, color: primary, size: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FileService().getFileName(_pdfFile!.path),
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text('Tap to change file',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: sub),
                ]),
              ),
            ),
            const SizedBox(height: 28),

            // Rotation selector
            Text('Rotation Angle',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [90, 180, 270].map((deg) {
                final sel = _rotation == deg;
                return Expanded(
                  child: GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () => setState(() => _rotation = deg),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: sel ? primary : bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: sel ? primary : border),
                      ),
                      child: Column(children: [
                        Icon(Icons.rotate_right_rounded,
                            color: sel ? Colors.white : sub, size: 28),
                        const SizedBox(height: 6),
                        Text('$deg°',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: sel ? Colors.white : sub,
                                fontSize: 16)),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
            const Spacer(),
          ] else if (_successPath == null) ...[
            Expanded(
              child: ToolEmptyState(
                icon: Icons.rotate_right_rounded,
                title: 'No PDF Selected',
                subtitle: 'Select a PDF document to rotate page orientation',
                actionLabel: 'Select PDF',
                onAction: _isLoading ? null : _pick,
              ),
            ),
          ] else
            const Spacer(),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_pdfFile == null || _isLoading) ? null : _rotate,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.rotate_right_rounded),
              label: const Text('Rotate PDF',
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
