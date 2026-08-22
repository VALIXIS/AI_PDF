import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';
import 'package:uuid/uuid.dart';

class TextToPdfScreen extends StatefulWidget {
  const TextToPdfScreen({Key? key}) : super(key: key);

  @override
  State<TextToPdfScreen> createState() => _TextToPdfScreenState();
}

class _TextToPdfScreenState extends State<TextToPdfScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final PdfService _pdfService = PdfService();
  final StorageService _storageService = StorageService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text to PDF'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create PDF from Text',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter text and generate a formatted PDF document',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),

              // Loading Banner
              if (_isLoading)
                const ToolLoadingBanner(
                  message: 'Generating PDF document from text...',
                ),

              // Error Banner
              if (_errorMessage != null)
                ToolErrorBanner(
                  message: _errorMessage!,
                  onRetry: (_titleController.text.isNotEmpty &&
                          _textController.text.isNotEmpty)
                      ? _generatePdf
                      : null,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),

              // Success Card
              if (_successPath != null)
                ToolSuccessCard(
                  title: 'PDF Generated Successfully!',
                  subtitle: 'Formatted PDF document created.',
                  filePath: _successPath,
                  onShare: () {
                    if (_successPath != null && mounted) {
                      ShareService.showSaveShareDialog(context, _successPath!);
                    }
                  },
                  onReset: () {
                    setState(() {
                      _successPath = null;
                      _titleController.clear();
                      _textController.clear();
                      _errorMessage = null;
                    });
                  },
                ),

              // Title Field
              Text(
                'PDF Title',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                enabled: !_isLoading,
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'Enter PDF document title...',
                  isDense: true,
                ),
                onChanged: (_) {
                  if (_errorMessage != null)
                    setState(() => _errorMessage = null);
                },
              ),
              const SizedBox(height: 20),

              // Content Field
              Text(
                'Content',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                enabled: !_isLoading,
                controller: _textController,
                maxLines: 10,
                minLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Enter text to convert to PDF...',
                ),
                onChanged: (_) {
                  if (_errorMessage != null)
                    setState(() => _errorMessage = null);
                },
              ),
              const SizedBox(height: 8),

              Text(
                'Tip: Use # for headers, • for bullet points',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 24),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _generatePdf,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: const Text('Generate PDF'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generatePdf() async {
    if (_titleController.text.trim().isEmpty ||
        _textController.text.trim().isEmpty) {
      setState(() {
        _errorMessage =
            'Please enter both a title and content to generate a PDF.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successPath = null;
    });

    try {
      final filePath = await _pdfService.generatePdfFromText(
        title: _titleController.text.trim(),
        content: _textController.text.trim(),
      );

      final entry = HistoryEntry(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        date: DateTime.now(),
        filePath: filePath,
        toolType: 'text_to_pdf',
      );
      await _storageService.addHistoryEntry(entry);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successPath = filePath;
      });

      if (mounted) {
        ShareService.showSaveShareDialog(context, filePath);
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
  void dispose() {
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }
}
