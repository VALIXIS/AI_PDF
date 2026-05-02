import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';

class AiRefineScreen extends StatefulWidget {
  const AiRefineScreen({Key? key}) : super(key: key);

  @override
  State<AiRefineScreen> createState() => _AiRefineScreenState();
}

class _AiRefineScreenState extends State<AiRefineScreen> {
  final TextEditingController _inputController = TextEditingController();
  final AiController _aiController = AiController();

  String _selectedMode = AiMode.clean;
  String? _refinedText;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Refine'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Polish Your Text with AI',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose a refining mode to improve your text',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
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
                maxLines: 6,
                minLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter text to refine...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),

              // Mode Selection Label
              Text(
                'Refining Mode',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              // Mode Options
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: AiMode.clean,
                    label: Text('Clean'),
                    icon: Icon(Icons.cleaning_services),
                  ),
                  ButtonSegment<String>(
                    value: AiMode.summary,
                    label: Text('Summary'),
                    icon: Icon(Icons.short_text),
                  ),
                  ButtonSegment<String>(
                    value: AiMode.notes,
                    label: Text('Notes'),
                    icon: Icon(Icons.note),
                  ),
                ],
                selected: {_selectedMode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _selectedMode = selection.first;
                    _refinedText = null;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 0, 0, 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color.fromRGBO(255, 0, 0, 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
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

              // Loading
              if (_isLoading) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 20),
              ],

              // Result Section
              if (_refinedText != null) ...[
                Text(
                  'Refined Text',
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
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _refinedText!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _inputController.text = _refinedText!;
                          setState(() {
                            _refinedText = null;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Use This Version'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Refine Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _refineText,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.edit_note),
                  label: const Text('Refine Text'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.primary,
                    foregroundColor:
                        Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refineText() async {
    if (_inputController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter text to refine';
      });
      return;
    }

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
        _refinedText = result;
        _isLoading = false;
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
