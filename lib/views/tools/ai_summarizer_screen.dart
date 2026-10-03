import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/ai_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/ad_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

class AiSummarizerScreen extends StatefulWidget {
  const AiSummarizerScreen({Key? key}) : super(key: key);

  @override
  State<AiSummarizerScreen> createState() => _AiSummarizerScreenState();
}

class _AiSummarizerScreenState extends State<AiSummarizerScreen> {
  final FileService _fileService = FileService();
  final PdfService _pdfService = PdfService();
  final AiService _aiService = AiService();
  final StorageService _storageService = StorageService();

  String? _selectedFile;
  String? _extractedText;
  int _pageCount = 0;
  int _wordCount = 0;

  bool _isAnalyzingText = false;
  bool _isGeneratingSummary = false;
  bool _isExportingPdf = false;

  String? _errorMessage;
  String? _summaryMarkdown;
  String? _exportedPdfPath;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardBg = isDark ? const Color(0xFF13131F) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1F1F35) : const Color(0xFFE2E8F0);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Document Summarizer',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Explanation banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primary.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Extract text from multi-page PDFs to generate Executive Summaries, Key Action Items, and Critical Dates via Gemini AI.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: textCol.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Loading Banner
              if (_isAnalyzingText)
                const ToolLoadingBanner(
                  message: 'Analyzing PDF pages & calculating telemetry...',
                ),
              if (_isGeneratingSummary)
                const ToolLoadingBanner(
                  message: 'Querying Gemini AI for Executive Brief & Action Items...',
                ),
              if (_isExportingPdf)
                const ToolLoadingBanner(
                  message: 'Exporting Executive Summary to PDF document...',
                ),

              // Error Banner
              if (_errorMessage != null)
                ToolErrorBanner(
                  message: _errorMessage!,
                  onRetry: _selectedFile != null && _summaryMarkdown == null
                      ? _generateSummary
                      : null,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),

              // Document Upload Dropzone & Telemetry Card (When no summary generated yet)
              if (_summaryMarkdown == null) ...[
                if (_selectedFile == null)
                  Expanded(
                    child: ToolEmptyState(
                      icon: Icons.upload_file_rounded,
                      title: 'Upload Multi-Page PDF',
                      subtitle:
                          'Select a PDF document to calculate telemetry and extract AI executive brief',
                      actionLabel: 'Select PDF Document',
                      onAction: _isBusy ? null : _pickPdf,
                    ),
                  )
                else ...[
                  // Document Telemetry Card
                  _buildTelemetryCard(isDark, cardBg, borderCol, primary),
                  const SizedBox(height: 16),
                  const Spacer(),
                ],
              ],

              // Generated Summary Result Container (When summary exists)
              if (_summaryMarkdown != null) ...[
                if (_exportedPdfPath != null) ...[
                  ToolSuccessCard(
                    title: 'Executive Brief Exported to PDF!',
                    subtitle: 'Summary PDF file successfully compiled.',
                    filePath: _exportedPdfPath,
                    onSave: _saveExportedPdf,
                    onShare: _shareExportedPdf,
                    onReset: () {
                      setState(() {
                        _exportedPdfPath = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Telemetry Header Info Bar
                _buildSummaryTelemetryHeader(isDark, cardBg, borderCol, primary),
                const SizedBox(height: 10),

                // Markdown Renderer Container
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderCol, width: 1.2),
                    ),
                    child: Markdown(
                      data: _summaryMarkdown!,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        h1: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                        h2: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.lightBlueAccent : const Color(0xFF0284C7),
                        ),
                        p: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: textCol,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Summary Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copySummaryToClipboard,
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text(
                          'Copy Summary',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isBusy ? null : _exportSummaryToPdf,
                        icon: _isExportingPdf
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: Text(
                          _isExportingPdf ? 'Exporting...' : 'Export Summary to PDF',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _resetScreen,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Start New Summary'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                  ),
                ),
              ],

              // Bottom Action Row when file selected but no summary generated yet
              if (_selectedFile != null && _summaryMarkdown == null) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isBusy ? null : _pickPdf,
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Change PDF'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isBusy ? null : _generateSummary,
                        icon: _isGeneratingSummary
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.auto_awesome_rounded),
                        label: const Text(
                          'Generate Brief',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool get _isBusy =>
      _isAnalyzingText || _isGeneratingSummary || _isExportingPdf;

  Widget _buildTelemetryCard(
      bool isDark, Color cardBg, Color borderCol, Color primary) {
    final fileName = _fileService.getFileName(_selectedFile!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ready for Gemini Document Summarizer',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded),
                tooltip: 'Change Document',
                onPressed: _isBusy ? null : _pickPdf,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            'Document Telemetry',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTelemetryStatTile(
                  icon: Icons.filter_none_rounded,
                  title: 'Page Count',
                  value: '$_pageCount ${_pageCount == 1 ? 'Page' : 'Pages'}',
                  color: const Color(0xFF0EA5E9),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTelemetryStatTile(
                  icon: Icons.article_rounded,
                  title: 'Word Count',
                  value: '$_wordCount Words',
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          if (_pageCount > 1) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Color(0xFF8B5CF6), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Multi-Page AI Document',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          AdService().isFeatureUnlocked(UnlockFeature.aiSummaries)
                              ? '✨ Unlocked (${AdService().getRemainingMinutes(UnlockFeature.aiSummaries)}m remaining)'
                              : 'Watch a quick video ad for free 1-hour access.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  WatchAdUnlockButton(
                    feature: UnlockFeature.aiSummaries,
                    onUnlocked: () => setState(() {}),
                    customLabel: 'Watch Ad',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTelemetryStatTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTelemetryHeader(
      bool isDark, Color cardBg, Color borderCol, Color primary) {
    final fileName =
        _selectedFile != null ? _fileService.getFileName(_selectedFile!) : 'Document';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Icon(Icons.description_rounded, size: 18, color: primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$_pageCount pgs • $_wordCount words',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPdf() async {
    if (_isBusy) return;
    try {
      final file = await _fileService.pickPdfFile();
      if (!mounted) return;

      if (file != null) {
        if (!await _fileService.isPdfFile(file)) {
          setState(() {
            _selectedFile = null;
            _errorMessage =
                'Selected file is not a valid PDF document. Please select a valid .pdf file.';
          });
          return;
        }

        setState(() {
          _selectedFile = file;
          _summaryMarkdown = null;
          _exportedPdfPath = null;
          _errorMessage = null;
          _isAnalyzingText = true;
        });

        // Compute Telemetry: Page Count and Word Count
        try {
          final pageCount = await _pdfService.getPdfPageCount(file);
          final text = await _pdfService.extractPdfText(file);
          final words = text.trim().isEmpty
              ? 0
              : text
                  .trim()
                  .split(RegExp(r'\s+'))
                  .where((w) => w.isNotEmpty)
                  .length;

          if (!mounted) return;
          setState(() {
            _pageCount = pageCount;
            _wordCount = words;
            _extractedText = text;
            _isAnalyzingText = false;
          });
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _isAnalyzingText = false;
            _errorMessage = 'Failed to analyze PDF telemetry: $e';
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzingText = false;
        _errorMessage = 'Failed to select PDF: $e';
      });
    }
  }

  Future<void> _generateSummary() async {
    if (_selectedFile == null) {
      setState(() {
        _errorMessage = 'Please select a PDF document first.';
      });
      return;
    }

    // Gate multi-page summaries with High-eCPM Rewarded Ad
    if (_pageCount > 1 && !AdService().isFeatureUnlocked(UnlockFeature.aiSummaries)) {
      final unlocked = await AdService().ensureFeatureUnlocked(
        context,
        feature: UnlockFeature.aiSummaries,
        customPrompt:
            'Unlock Gemini AI multi-page document intelligence for executive summaries & action items.',
      );
      if (!unlocked) {
        return;
      }
    }

    setState(() {
      _isGeneratingSummary = true;
      _errorMessage = null;
    });

    try {
      String textToUse = _extractedText ?? '';
      if (textToUse.trim().isEmpty) {
        textToUse = await _pdfService.extractPdfText(_selectedFile!);
        _extractedText = textToUse;
      }

      if (textToUse.trim().isEmpty) {
        throw Exception(
            'No extractable text found in this PDF document. Scanned or image-only PDFs do not have readable text layers.');
      }

      final summary =
          await _aiService.generateExecutiveBrief(pdfText: textToUse);

      if (!mounted) return;
      setState(() {
        _summaryMarkdown = summary;
        _isGeneratingSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGeneratingSummary = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _copySummaryToClipboard() {
    if (_summaryMarkdown != null && _summaryMarkdown!.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _summaryMarkdown!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Executive Summary copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _exportSummaryToPdf() async {
    if (_summaryMarkdown == null || _summaryMarkdown!.trim().isEmpty) return;

    final isUnlocked = AdService().isFeatureUnlocked(UnlockFeature.aiSummaries) ||
        AdService().isFeatureUnlocked(UnlockFeature.vectorExport);

    if (!isUnlocked) {
      final unlocked = await AdService().ensureFeatureUnlocked(
        context,
        feature: UnlockFeature.vectorExport,
        customPrompt:
            'Watch a short video ad to unlock crisp High-Resolution Vector PDF Export for 1 hour.',
      );
      if (!unlocked) return;
    }

    setState(() {
      _isExportingPdf = true;
      _errorMessage = null;
    });

    try {
      final docName = _selectedFile != null
          ? _fileService.getFileName(_selectedFile!).replaceAll(RegExp(r'\.[^.]+$'), '')
          : 'Document';

      final title = 'Executive Brief - $docName';
      final pdfPath = await _pdfService.generatePdfFromMarkdownContent(
        title: title,
        markdownContent: _summaryMarkdown!,
      );

      // Save to History
      await _storageService.addHistoryEntry(HistoryEntry(
        id: AiController().generateId(),
        title: 'Summary: $docName',
        date: DateTime.now(),
        filePath: pdfPath,
        toolType: 'ai_summarizer',
      ));

      if (!mounted) return;
      setState(() {
        _exportedPdfPath = pdfPath;
        _isExportingPdf = false;
      });

      // Prompt to save / open / share the exported summary PDF
      ShareService.promptAndSaveFileDirectToDownloads(
        context,
        sourcePath: pdfPath,
        defaultPrefix: 'ExecutiveSummary',
        dialogTitle: 'Save Summary PDF',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExportingPdf = false;
        _errorMessage = 'Failed to export PDF: $e';
      });
    }
  }

  void _saveExportedPdf() {
    if (_exportedPdfPath != null && mounted) {
      ShareService.promptAndSaveFileDirectToDownloads(
        context,
        sourcePath: _exportedPdfPath!,
        defaultPrefix: 'ExecutiveSummary',
        dialogTitle: 'Save Summary PDF',
      );
    }
  }

  void _shareExportedPdf() {
    if (_exportedPdfPath != null && mounted) {
      ShareService.shareFile(
        context,
        filePath: _exportedPdfPath!,
        text: 'Executive Summary PDF',
      );
    }
  }

  void _resetScreen() {
    setState(() {
      _selectedFile = null;
      _extractedText = null;
      _pageCount = 0;
      _wordCount = 0;
      _summaryMarkdown = null;
      _exportedPdfPath = null;
      _errorMessage = null;
    });
  }
}
