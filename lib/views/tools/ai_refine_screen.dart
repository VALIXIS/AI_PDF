import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';

class AiRefineScreen extends StatefulWidget {
  const AiRefineScreen({Key? key}) : super(key: key);

  @override
  State<AiRefineScreen> createState() => _AiRefineScreenState();
}

class _AiRefineScreenState extends State<AiRefineScreen> {
  final TextEditingController _inputController = TextEditingController();
  final AiController _aiController = AiController();
  final StorageService _storageService = StorageService();

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
              Column(
                children: [
                  ListTile(
                    leading: Radio<String>(
                      value: AiMode.clean,
                      groupValue: _selectedMode,
                      onChanged: (value) {
                        setState(() {
                          _selectedMode = value!;
                          _refinedText = null;
                          _errorMessage = null;
                        });
                      },
                    ),
                    title: const Text('Polish & Clean'),
                    subtitle: const Text(
                        'Fix grammar and improve clarity'),
                  ),
                  ListTile(
                    leading: Radio<String>(
                      value: AiMode.summary,
                      groupValue: _selectedMode,
                      onChanged: (value) {
                        setState(() {
                          _selectedMode = value!;
                          _refinedText = null;
                          _errorMessage = null;
                        });
                      },
                    ),
                    title: const Text('Condense'),
                    subtitle: const Text(
                        'Make it concise and short'),
                  ),
                  ListTile(
                    leading: Radio<String>(
                      value: AiMode.notes,
                      groupValue: _selectedMode,
                      onChanged: (value) {
                        setState(() {
                          _selectedMode = value!;
                          _refinedText = null;
                          _errorMessage = null;
                        });
                      },
                    ),
                    title: const Text('Organize'),
                    subtitle: const Text(
                        'Structure into sections'),
                  ),
                ],
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
