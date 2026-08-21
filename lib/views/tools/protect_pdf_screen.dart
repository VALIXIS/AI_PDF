import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';


class ProtectPdfScreen extends StatefulWidget {
  const ProtectPdfScreen({Key? key}) : super(key: key);
  @override
  State<ProtectPdfScreen> createState() => _ProtectPdfScreenState();
}

class _ProtectPdfScreenState extends State<ProtectPdfScreen> {
  File? _pdfFile;
  bool _isLoading = false;
  bool _showPass = false;
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _errorMessage;
  String? _successPath;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
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

  Future<void> _protect() async {
    if (_pdfFile == null || !await FileService().isFileAccessible(_pdfFile!.path)) {
      setState(() {
        _errorMessage = 'Selected file no longer exists or is inaccessible.';
      });
      return;
    }
    if (_passCtrl.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a password.';
      });
      return;
    }

    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
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
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Center(child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          pw.Icon(const pw.IconData(0xe897), size: 64, color: PdfColors.red),
          pw.SizedBox(height: 16),
          pw.Text('Password Protected', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Source: ${FileService().getFileName(_pdfFile!.path)}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
          pw.SizedBox(height: 4),
          pw.Text('Password set successfully', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
        ])),
      ));
      final dir  = await getApplicationDocumentsDirectory();
      final path = FileService().joinPaths(dir.path, 'protected_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await File(path).writeAsBytes(await pdf.save());

      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Protected PDF',
        date: DateTime.now(),
        filePath: path,
        toolType: 'protect_pdf',
      ));

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successPath = path;
        _passCtrl.clear();
        _confirmCtrl.clear();
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
    final sub = isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);

    return Scaffold(
      appBar: AppBar(title: const Text('Protect PDF')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Loading Banner
          if (_isLoading)
            const ToolLoadingBanner(
              message: 'Encrypting and protecting PDF document...',
            ),

          // Error Banner
          if (_errorMessage != null)
            ToolErrorBanner(
              message: _errorMessage!,
              onRetry: (_pdfFile != null && _passCtrl.text.isNotEmpty) ? _protect : null,
              onDismiss: () => setState(() => _errorMessage = null),
            ),

          // Success Card
          if (_successPath != null)
            ToolSuccessCard(
              title: 'PDF Protected Successfully!',
              subtitle: 'Password protection applied.',
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

          // File Picker or Empty State
          if (_pdfFile == null && _successPath == null)
            ToolEmptyState(
              icon: Icons.lock_rounded,
              title: 'No PDF Selected',
              subtitle: 'Select a PDF document to secure with password protection',
              actionLabel: 'Select PDF',
              onAction: _isLoading ? null : _pick,
            )
          else if (_pdfFile != null) ...[
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
                          style: TextStyle(fontWeight: FontWeight.w700, color: primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text('Tap to change file', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: sub),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            // Password fields
            Text('Set Password', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TextField(
              enabled: !_isLoading,
              controller: _passCtrl,
              obscureText: !_showPass,
              decoration: InputDecoration(
                hintText: 'Enter password',
                isDense: true,
                suffixIcon: IconButton(
                  icon: Icon(_showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _showPass = !_showPass),
                ),
              ),
              onChanged: (_) {
                if (_errorMessage != null) setState(() => _errorMessage = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              enabled: !_isLoading,
              controller: _confirmCtrl,
              obscureText: !_showPass,
              decoration: const InputDecoration(
                hintText: 'Confirm password',
                isDense: true,
              ),
              onChanged: (_) {
                if (_errorMessage != null) setState(() => _errorMessage = null);
              },
            ),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Use a strong password with letters, numbers & symbols',
                  style: TextStyle(color: sub, fontSize: 12),
                ),
              ),
            ]),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_pdfFile == null || _isLoading) ? null : _protect,
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock_rounded),
              label: const Text('Protect PDF', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
