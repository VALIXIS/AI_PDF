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
      title: 'Rotate PDF',
      explanation:
          'Rotate page orientation of your PDF document (90°, 180°, or 270°).',
      onPickFiles: _pick,
      selectedFiles: _pdfFile != null ? [_pdfFile!.path] : [],
      onRemoveFile: (_) {
        setState(() {
          _pdfFile = null;
          _errorMessage = null;
        });
      },
      onExecute: _pdfFile != null ? _rotate : null,
      executeButtonLabel: 'Rotate PDF',
      executeButtonIcon: Icons.rotate_right_rounded,
      pickButtonLabel: 'Select PDF',
      isLoading: _isLoading,
      loadingMessage: 'Rotating PDF by $_rotation°...',
      errorMessage: _errorMessage,
      onDismissError: () => setState(() => _errorMessage = null),
      onRetry: _pdfFile != null ? _rotate : null,
      successPath: _successPath,
      successTitle: 'PDF Rotated Successfully!',
      successSubtitle: 'Orientation rotated by $_rotation°.',
      defaultSavePrefix: 'RotatedPDF',
      onReset: () {
        setState(() {
          _successPath = null;
          _pdfFile = null;
          _errorMessage = null;
        });
      },
      emptyStateIcon: Icons.rotate_right_rounded,
      emptyStateTitle: 'No PDF Selected',
      emptyStateSubtitle: 'Select a PDF document to rotate page orientation',
      emptyStateActionLabel: 'Select PDF',
      extraConfig: _pdfFile == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rotation Angle',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
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
                          child: Column(
                            children: [
                              Icon(Icons.rotate_right_rounded,
                                  color: sel ? Colors.white : sub, size: 28),
                              const SizedBox(height: 6),
                              Text('$deg°',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: sel ? Colors.white : sub,
                                      fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }
}
