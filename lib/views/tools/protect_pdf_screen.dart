import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/widgets/tool_screen_shell.dart';

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
            throw Exception(
                'Current password required to re-encrypt a protected PDF.');
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
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
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
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8)),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1)),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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

    return ToolScreenShell(
      title: 'Protect PDF',
      explanation:
          'Secure your PDF with user and owner passwords and configure document permissions.',
      onPickFiles: _pick,
      selectedFiles: _pdfFile != null ? [_pdfFile!.path] : [],
      onRemoveFile: (_) {
        setState(() {
          _pdfFile = null;
          _errorMessage = null;
        });
      },
      onExecute: _pdfFile != null ? _protect : null,
      executeButtonLabel: 'Protect PDF',
      executeButtonIcon: Icons.lock_rounded,
      pickButtonLabel: 'Select PDF',
      isLoading: _isLoading,
      loadingMessage: 'Encrypting and protecting PDF document...',
      errorMessage: _errorMessage,
      onDismissError: () => setState(() => _errorMessage = null),
      onRetry: _pdfFile != null ? _protect : null,
      successPath: _successPath,
      successTitle: 'PDF Protected Successfully!',
      successSubtitle: 'Password protection applied.',
      defaultSavePrefix: 'ProtectedPDF',
      onReset: () {
        setState(() {
          _successPath = null;
          _pdfFile = null;
          _errorMessage = null;
          _passCtrl.clear();
          _confirmCtrl.clear();
          _ownerPassCtrl.clear();
        });
      },
      emptyStateIcon: Icons.lock_rounded,
      emptyStateTitle: 'No PDF Selected',
      emptyStateSubtitle:
          'Select a PDF document to secure with password protection',
      emptyStateActionLabel: 'Select PDF',
      extraConfig: _pdfFile == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set Password',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
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
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
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
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
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
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'User password unlocks the document. Owner password permits modifying security settings.',
                        style: TextStyle(color: sub, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Document Permissions',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
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
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        dense: true,
                        title: const Text('Allow Printing',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Permit printing high resolution copies',
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
            ),
    );
  }
}
