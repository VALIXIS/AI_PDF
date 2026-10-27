import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;

/// Categories of security or structural issues detected when inspecting a PDF document.
enum PdfIssueType {
  none,
  headerCorrupted,
  formatException,
  passwordRequired,
}

/// Inspection outcome metadata for a PDF file.
class PdfInspectionResult {
  final PdfIssueType issueType;
  final String? errorMessage;
  final bool isEncrypted;
  final int fileSizeBytes;
  final String filePath;
  final String fileName;
  final Uint8List? bytes;

  const PdfInspectionResult({
    required this.issueType,
    this.errorMessage,
    this.isEncrypted = false,
    required this.fileSizeBytes,
    required this.filePath,
    required this.fileName,
    this.bytes,
  });

  bool get isValid => issueType == PdfIssueType.none;
  bool get hasHeaderCorruption => issueType == PdfIssueType.headerCorrupted;
  bool get hasFormatException => issueType == PdfIssueType.formatException;
  bool get isPasswordProtected => issueType == PdfIssueType.passwordRequired;
}

/// Checks whether the raw byte stream begins with the mandatory `%PDF-` signature.
/// According to the PDF specification, the `%PDF-` header must appear within the first 1024 bytes.
bool hasPdfHeaderSignature(Uint8List bytes) {
  if (bytes.length < 5) return false;
  final maxCheck = bytes.length < 1024 ? bytes.length : 1024;
  for (int i = 0; i <= maxCheck - 5; i++) {
    if (bytes[i] == 0x25 && // %
        bytes[i + 1] == 0x50 && // P
        bytes[i + 2] == 0x44 && // D
        bytes[i + 3] == 0x46 && // F
        bytes[i + 4] == 0x2D) { // -
      return true;
    }
  }
  return false;
}

/// Inspects a PDF file on disk or from bytes, detecting header corruption, format exceptions,
/// and password requirements.
Future<PdfInspectionResult> inspectPdfFile(
  String filePath, {
  String? password,
  Uint8List? preloadedBytes,
}) async {
  final file = File(filePath);
  final fileName = p.basename(filePath);

  Uint8List bytes;
  if (preloadedBytes != null) {
    bytes = preloadedBytes;
  } else {
    if (!await file.exists()) {
      return PdfInspectionResult(
        issueType: PdfIssueType.formatException,
        errorMessage: 'File not found at: $filePath',
        fileSizeBytes: 0,
        filePath: filePath,
        fileName: fileName,
      );
    }
    bytes = await file.readAsBytes();
  }

  final fileSize = bytes.length;

  // 1. Header corruption check (empty file or missing %PDF- header magic bytes)
  if (fileSize < 5 || !hasPdfHeaderSignature(bytes)) {
    return PdfInspectionResult(
      issueType: PdfIssueType.headerCorrupted,
      errorMessage: fileSize == 0
          ? 'PDF file is empty (0 bytes).'
          : "Invalid or missing '%PDF-' header signature magic bytes.",
      fileSizeBytes: fileSize,
      filePath: filePath,
      fileName: fileName,
      bytes: bytes,
    );
  }

  // 2. Encryption and format verification using Syncfusion PDF engine
  try {
    final doc = sf.PdfDocument(inputBytes: bytes, password: password);
    doc.dispose();
    return PdfInspectionResult(
      issueType: PdfIssueType.none,
      fileSizeBytes: fileSize,
      filePath: filePath,
      fileName: fileName,
      bytes: bytes,
    );
  } on FormatException catch (fe) {
    return PdfInspectionResult(
      issueType: PdfIssueType.formatException,
      errorMessage: 'FormatException: ${fe.message}',
      fileSizeBytes: fileSize,
      filePath: filePath,
      fileName: fileName,
      bytes: bytes,
    );
  } catch (e) {
    final errStr = e.toString().toLowerCase();

    // Check for password protection signals
    if (errStr.contains('password') ||
        errStr.contains('encrypted') ||
        errStr.contains('protected') ||
        errStr.contains('invalid password') ||
        errStr.contains("can't open the document")) {
      return PdfInspectionResult(
        issueType: PdfIssueType.passwordRequired,
        isEncrypted: true,
        errorMessage: 'Document is password-protected.',
        fileSizeBytes: fileSize,
        filePath: filePath,
        fileName: fileName,
        bytes: bytes,
      );
    }

    // Check for header corruption signals caught by parser
    if (errStr.contains('header') || errStr.contains('%pdf')) {
      return PdfInspectionResult(
        issueType: PdfIssueType.headerCorrupted,
        errorMessage: e.toString(),
        fileSizeBytes: fileSize,
        filePath: filePath,
        fileName: fileName,
        bytes: bytes,
      );
    }

    // Malformed xref, trailer, stream, or syntax format exception
    return PdfInspectionResult(
      issueType: PdfIssueType.formatException,
      errorMessage: e.toString(),
      fileSizeBytes: fileSize,
      filePath: filePath,
      fileName: fileName,
      bytes: bytes,
    );
  }
}

/// Helper that inspects a PDF file and shows the appropriate modal if an issue is detected.
///
/// Returns the validated password (or empty string if no password needed), or `null` if the user
/// canceled password entry or the document cannot be opened due to header corruption/format exception.
Future<String?> handlePdfSecurityAndIntegrity({
  required BuildContext context,
  required String filePath,
  String? existingPassword,
  VoidCallback? onChooseAnother,
}) async {
  final inspection = await inspectPdfFile(filePath, password: existingPassword);

  if (inspection.hasHeaderCorruption) {
    if (!context.mounted) return null;
    await showPdfCorruptionModal(
      context: context,
      issueType: PdfIssueType.headerCorrupted,
      fileName: inspection.fileName,
      fileSizeBytes: inspection.fileSizeBytes,
      technicalDetails: inspection.errorMessage,
      onChooseAnother: onChooseAnother,
    );
    return null;
  }

  if (inspection.hasFormatException) {
    if (!context.mounted) return null;
    await showPdfCorruptionModal(
      context: context,
      issueType: PdfIssueType.formatException,
      fileName: inspection.fileName,
      fileSizeBytes: inspection.fileSizeBytes,
      technicalDetails: inspection.errorMessage,
      onChooseAnother: onChooseAnother,
    );
    return null;
  }

  if (inspection.isPasswordProtected) {
    if (!context.mounted) return null;
    final pass = await showPdfPasswordModal(
      context: context,
      fileName: inspection.fileName,
      onValidatePassword: (inputPass) async {
        final recheck = await inspectPdfFile(filePath, password: inputPass);
        return recheck.isValid;
      },
    );
    return pass;
  }

  // Already valid
  return existingPassword ?? '';
}

/// Formats byte size into human readable string.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

/// Displays an elegant Material 3 modal explaining PDF header corruption or format exceptions.
Future<void> showPdfCorruptionModal({
  required BuildContext context,
  required PdfIssueType issueType,
  required String fileName,
  int? fileSizeBytes,
  String? technicalDetails,
  VoidCallback? onChooseAnother,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final isHeaderCorrupt = issueType == PdfIssueType.headerCorrupted;

  final primaryColor = isHeaderCorrupt
      ? const Color(0xFFF59E0B) // Amber / Warning
      : const Color(0xFFEF4444); // Red / Danger

  final title = isHeaderCorrupt
      ? 'Corrupted PDF Header'
      : 'PDF Format Exception';

  final badgeLabel = isHeaderCorrupt
      ? 'HEADER CORRUPTION'
      : 'FORMAT EXCEPTION';

  final description = isHeaderCorrupt
      ? 'This file does not have a valid PDF header signature (%PDF-). The file header is missing, truncated, or the document data is damaged.'
      : 'The document structure contains malformed data or syntax errors (FormatException). Critical cross-reference tables or object streams cannot be parsed.';

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        key: const Key('pdf_corruption_modal_dialog'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Icon Badge
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.28),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isHeaderCorrupt
                        ? Icons.broken_image_rounded
                        : Icons.error_outline_rounded,
                    color: primaryColor,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Badge Chip
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),

              // File Meta
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF13131F)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_rounded,
                      size: 16,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                    if (fileSizeBytes != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        formatBytes(fileSizeBytes),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // User Explanation
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),

              // Technical Details (if any)
              if (technicalDetails != null && technicalDetails.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F0F17)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF27273A)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    technicalDetails,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  if (onChooseAnother != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('pdf_corruption_choose_another_button'),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onChooseAnother();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: isDark
                                ? const Color(0xFF33334D)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Text(
                          'Choose Another',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('pdf_corruption_dismiss_button'),
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Dismiss',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Displays an elegant Material 3 modal prompting the user for a decryption password.
///
/// If [onValidatePassword] is provided, it validates the password before closing the dialog.
/// If validation fails, it displays an inline error banner and allows the user to re-try without closing.
Future<String?> showPdfPasswordModal({
  required BuildContext context,
  required String fileName,
  String? initialError,
  Future<bool> Function(String password)? onValidatePassword,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PdfPasswordDialog(
      fileName: fileName,
      initialError: initialError,
      onValidatePassword: onValidatePassword,
    ),
  );
}

class _PdfPasswordDialog extends StatefulWidget {
  final String fileName;
  final String? initialError;
  final Future<bool> Function(String password)? onValidatePassword;

  const _PdfPasswordDialog({
    Key? key,
    required this.fileName,
    this.initialError,
    this.onValidatePassword,
  }) : super(key: key);

  @override
  State<_PdfPasswordDialog> createState() => _PdfPasswordDialogState();
}

class _PdfPasswordDialogState extends State<_PdfPasswordDialog> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureText = true;
  bool _isValidating = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _inlineError = widget.initialError;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleUnlock() async {
    final pass = _passwordController.text.trim();
    if (pass.isEmpty) {
      setState(() {
        _inlineError = 'Please enter the document password.';
      });
      return;
    }

    if (widget.onValidatePassword != null) {
      setState(() {
        _isValidating = true;
        _inlineError = null;
      });

      try {
        final isValid = await widget.onValidatePassword!(pass);
        if (!mounted) return;
        if (isValid) {
          Navigator.of(context).pop(pass);
        } else {
          setState(() {
            _isValidating = false;
            _inlineError = 'Incorrect password. Please verify and try again.';
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isValidating = false;
          _inlineError = 'Decryption failed: $e';
        });
      }
    } else {
      Navigator.of(context).pop(pass);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;

    return Dialog(
      key: const Key('pdf_password_modal_dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Lock Icon Badge
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.28),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFFEF4444),
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Password Protected',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle
              Text(
                'This PDF is encrypted. Enter the decryption password to unlock and view its contents.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 14),

              // File Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF13131F)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_rounded,
                      size: 16,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Inline Error Banner
              if (_inlineError != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _inlineError!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Password Input Field
              TextFormField(
                key: const Key('pdf_password_input_field'),
                controller: _passwordController,
                obscureText: _obscureText,
                autofocus: true,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  labelText: 'Document Password',
                  hintText: 'Enter password',
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                  suffixIcon: IconButton(
                    key: const Key('toggle_password_visibility'),
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF13131F)
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF2B2B3D)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF2B2B3D)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                ),
                onFieldSubmitted: (_) => _handleUnlock(),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('pdf_password_cancel_button'),
                      onPressed: _isValidating
                          ? null
                          : () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF33334D)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('pdf_unlock_submit_button'),
                      onPressed: _isValidating ? null : _handleUnlock,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isValidating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Unlock',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
