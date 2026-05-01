import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({Key? key}) : super(key: key);

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final TextEditingController _inputController = TextEditingController();
  final AiController _aiController = AiController();
  final PdfService _pdfService = PdfService();
  final StorageService _storageService = StorageService();

  String _selectedMode = AiMode.notes;
  String? _previewText;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI to PDF'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary
                        .withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enter your text and let AI transform it',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Input Label
              Text(
                'Your Text',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),

              // Input TextField
              TextField(
                controller: _inputController,
                maxLines: 8,
                minLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter text to transform...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),

              // Mode Selection Label
              Text(
                'Select Mode',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              // Mode Selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (String mode in _aiController.getAvailableModes())
                      _buildModeButton(context, mode),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Mode Description
              Text(
                _aiController.getPromptDescription(_selectedMode),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 20),

              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Loading Indicator
              if (_isLoading) ...[
                const Center(
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(height: 20),
              ],

              // Preview Section
              if (_previewText != null) ...[
                Text(
                  'Preview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _previewText!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isLoading ? null : () => _handlePreview(context),
                      icon: const Icon(Icons.preview),
                      label: const Text('Preview'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading || _previewText == null
                          ? null
                          : () => _handleGeneratePdf(context),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Generate PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
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

  Widget _buildModeButton(BuildContext context, String mode) {
    final isSelected = _selectedMode == mode;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: FilterChip(
        label: Text(
          mode.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedMode = mode;
            _previewText = null; // Reset preview when mode changes
            _errorMessage = null;
          });
        },
        backgroundColor: Colors.transparent,
        selectedColor:
            Theme.of(context).colorScheme.primary.withOpacity(0.3),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
    );
  }

  Future<void> _handlePreview(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
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
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGeneratePdf(BuildContext context) async {
    if (_previewText == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final title =
          '${_selectedMode.toUpperCase()} - ${DateTime.now().hour}:${DateTime.now().minute}';
      final filePath = await _pdfService.generatePdfFromText(
        title: title,
        content: _previewText!,
      );

      // Save to history
      final entry = HistoryEntry(
        id: _aiController.generateId(),
        title: title,
        date: DateTime.now(),
        filePath: filePath,
        toolType: 'ai_to_pdf',
      );
      await _storageService.addHistoryEntry(entry);

      setState(() {
        _isLoading = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF generated successfully!'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'View History',
            onPressed: () {
              Navigator.pushNamed(context, '/history');
            },
          ),
        ),
      );

      // Reset form
      _inputController.clear();
      setState(() {
        _previewText = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}
