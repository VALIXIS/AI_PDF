import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:flutter/services.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kCardLight, kCardDark;
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';

class AiScreen extends StatefulWidget {
  final String? initialInput;

  const AiScreen({Key? key, this.initialInput}) : super(key: key);

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  late final TextEditingController _inputController;
  final AiController _aiController = AiController();
  final PdfService _pdfService = PdfService();
  final StorageService _storageService = StorageService();

  String _selectedMode = AiMode.notes;
  String? _previewText;
  bool _isLoading = false;
  bool _isGenerating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: widget.initialInput ?? '');
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Actions
  // -----------------------------------------------------------------------
  Future<void> _handlePreview() async {
    if (_inputController.text.trim().isEmpty) {
      _showError('Please enter some text first.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _previewText = null;
    });
    try {
      final result = await _aiController.processText(
        input: _inputController.text,
        mode: _selectedMode,
      );
      setState(() {
        _previewText = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDownloadPdf() async {
    if (_previewText == null) return;
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });
    try {
      final title =
          '${_selectedMode.toUpperCase()} · ${TimeOfDay.now().format(context)}';
      final filePath = await _pdfService.generatePdfFromText(
        title: title,
        content: _previewText!,
      );
      final entry = HistoryEntry(
        id: _aiController.generateId(),
        title: title,
        date: DateTime.now(),
        filePath: filePath,
        toolType: 'ai_to_pdf',
      );
      await _storageService.addHistoryEntry(entry);
      setState(() {
        _isGenerating = false;
        _previewText = null;
      });
      if (mounted) {
        ShareService.showSaveShareDialog(context, filePath);
      }
      _inputController.clear();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isGenerating = false;
      });
    }
  }

  void _showError(String msg) => setState(() => _errorMessage = msg);

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? kCardDark : kCardLight;
    final borderColor =
        isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    final subtitleColor =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Generate PDF'),
        actions: [
          if (_previewText != null)
            TextButton.icon(
              onPressed: _isGenerating ? null : _handleDownloadPdf,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              label: const Text('Download PDF'),
              style: TextButton.styleFrom(foregroundColor: kPrimary),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Mode chips ───────────────────────────────────────────
              Text(
                'Output format',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: _aiController.getAvailableModes().map((mode) {
                  final selected = _selectedMode == mode;
                  return ChoiceChip(
                    label: Text(mode[0].toUpperCase() + mode.substring(1)),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _selectedMode = mode;
                      _previewText = null;
                      _errorMessage = null;
                    }),
                    selectedColor: kPrimary.withOpacity(0.15),
                    checkmarkColor: kPrimary,
                    labelStyle: TextStyle(
                      color: selected ? kPrimary : subtitleColor,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    backgroundColor: cardBg,
                    side: BorderSide(
                      color: selected ? kPrimary : borderColor,
                      width: selected ? 1.5 : 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              Text(
                _aiController.getPromptDescription(_selectedMode),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),

              // ── Input ────────────────────────────────────────────────
              Text(
                'Your text',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.25)
                          : const Color(0xFF0F172A).withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: TextField(
                  controller: _inputController,
                  maxLines: 12,
                  minLines: 6,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Paste your ChatGPT response or any text...',
                    hintStyle: TextStyle(color: subtitleColor),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Error ────────────────────────────────────────────────
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFDC2626).withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: const Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Loading ──────────────────────────────────────────────
              if (_isLoading) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: kPrimary),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'AI is processing your text…',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: subtitleColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Preview ──────────────────────────────────────────────
              if (_previewText != null) ...[
                Row(
                  children: [
                    Text(
                      'Preview',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _previewText!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy'),
                      style: TextButton.styleFrom(
                          foregroundColor: subtitleColor,
                          textStyle: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _previewText!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Buttons ──────────────────────────────────────────────
              Row(
                children: [
                  // Process with AI
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handlePreview,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Process with AI'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimary,
                        side: const BorderSide(color: kPrimary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Download PDF (active only when preview is ready)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_isGenerating || _previewText == null)
                          ? null
                          : _handleDownloadPdf,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: kPrimary.withOpacity(0.35),
                        disabledForegroundColor: Colors.white.withOpacity(0.6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
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
