import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
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
  final _ownerPassCtrl = TextEditingController();
  bool _allowPrinting = true;
  bool _allowCopying = true;
  String? _errorMessage;
  String? _successPath;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _ownerPassCtrl.dispose();
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

  Future<void> _protect() async {
    if (_pdfFile == null ||
        !await FileService().isFileAccessible(_pdfFile!.path)) {
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

    String? inputPass;
    try {
      String savedPath;
      try {
        savedPath = await PdfService().protectPdf(
          pdfPath: _pdfFile!.path,
          userPassword: _passCtrl.text,
          ownerPassword:
              _ownerPassCtrl.text.isNotEmpty ? _ownerPassCtrl.text : null,
          allowPrinting: _allowPrinting,
          allowCopying: _allowCopying,
        );
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('already password-protected') ||
            errStr.contains('encrypted') ||
            errStr.contains('password')) {
          if (!mounted) return;
          inputPass = await _promptPasswordDialog(context);
          if (inputPass == null || inputPass.isEmpty) {
            throw Exception('Current password required to re-encrypt a protected PDF.');
          }
          savedPath = await PdfService().protectPdf(
            pdfPath: _pdfFile!.path,
            userPassword: _passCtrl.text,
            inputPassword: inputPass,
            ownerPassword:
                _ownerPassCtrl.text.isNotEmpty ? _ownerPassCtrl.text : null,
            allowPrinting: _allowPrinting,
            allowCopying: _allowCopying,
          );
        } else {
          rethrow;
        }
      }

      await StorageService().addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Protected PDF · ${FileService().getFileName(_pdfFile!.path)}',
        date: DateTime.now(),
        filePath: savedPath,
        toolType: 'protect_pdf',
      ));

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successPath = savedPath;
        _passCtrl.clear();
        _confirmCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().replaceAll(RegExp(r'^Exception:\s*'), '');
      final cleanMsg = raw.contains('PdfServiceException')
          ? raw.split(':').last.trim()
          : raw;
      setState(() {
        _errorMessage = cleanMsg;
        _isLoading = false;
      });
    }
  }

  Future<String?> _promptPasswordDialog(BuildContext ctx) async {
    final controller = TextEditingController();
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return showDialog<String>(
      context: ctx,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          'Protected PDF File',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This document is already password-protected. Enter its current password to re-encrypt:',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Enter current password',
                hintStyle: TextStyle(
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Unlock & Re-encrypt'),
          ),
        ],
      ),
    );
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
              onRetry: (_pdfFile != null && _passCtrl.text.isNotEmpty)
                  ? _protect
                  : null,
              onDismiss: () => setState(() => _errorMessage = null),
            ),

          // Success Card
          if (_successPath != null)
            ToolSuccessCard(
              title: 'PDF Protected Successfully!',
              subtitle: 'Password protection applied.',
              filePath: _successPath,
              onSave: () {
                if (_successPath != null && mounted) {
                  ShareService.promptAndSaveFileDirectToDownloads(
                    context,
                    sourcePath: _successPath!,
                    defaultPrefix: 'ProtectedPDF',
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
              subtitle:
                  'Select a PDF document to secure with password protection',
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
            const SizedBox(height: 24),

            // Password fields
            Text('Set Password',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TextField(
              enabled: !_isLoading,
              controller: _passCtrl,
              obscureText: !_showPass,
              decoration: InputDecoration(
                hintText: 'Enter password',
                isDense: true,
                suffixIcon: IconButton(
                  icon: Icon(_showPass
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded),
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
            const SizedBox(height: 12),
            TextField(
              enabled: !_isLoading,
              controller: _ownerPassCtrl,
              obscureText: !_showPass,
              decoration: const InputDecoration(
                labelText: 'Owner / Admin Password (Optional)',
                hintText: 'Required to modify permissions or edit PDF',
                isDense: true,
              ),
              onChanged: (_) {
                if (_errorMessage != null) setState(() => _errorMessage = null);
              },
            ),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'User password unlocks the document. Owner password permits modifying security settings.',
                  style: TextStyle(color: sub, fontSize: 12),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // Document Permissions Section
            Text('Document Permissions',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    dense: true,
                    title: const Text('Allow Printing',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Permit printing high resolution copies',
                        style: TextStyle(fontSize: 12)),
                    value: _allowPrinting,
                    activeThumbColor: primary,
                    onChanged: _isLoading
                        ? null
                        : (val) => setState(() => _allowPrinting = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    dense: true,
                    title: const Text('Allow Copying Content',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Permit text selection and copying',
                        style: TextStyle(fontSize: 12)),
                    value: _allowCopying,
                    activeThumbColor: primary,
                    onChanged: _isLoading
                        ? null
                        : (val) => setState(() => _allowCopying = val),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_pdfFile == null || _isLoading) ? null : _protect,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock_rounded),
              label: const Text('Protect PDF',
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
