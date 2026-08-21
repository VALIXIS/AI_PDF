import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF14141E) : Colors.white;
    final border = isDark ? const Color(0xFF1F1F2E) : const Color(0xFFE5E7EB);

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
              const SizedBox(height: 4),
              Text(
                'Choose a refining mode to clean, summarize, or structure your notes',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),

              // Loading Banner
              if (_isLoading)
                ToolLoadingBanner(
                  message: 'Refining text with AI ($_selectedMode mode)...',
                ),

              // Error Banner
              if (_errorMessage != null)
                ToolErrorBanner(
                  message: _errorMessage!,
                  onRetry: _inputController.text.isNotEmpty ? _refineText : null,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),

              // Input Label
              Text(
                'Your Text',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),

              // Input TextField
              TextField(
                enabled: !_isLoading,
                controller: _inputController,
                maxLines: 6,
                minLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Enter or paste text to refine with AI...',
                ),
                onChanged: (_) {
                  if (_errorMessage != null) setState(() => _errorMessage = null);
                },
              ),
              const SizedBox(height: 20),

              // Mode Selection Label
              Text(
                'Refining Mode',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),

              // Mode Options
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: AiMode.clean,
                    label: Text('Clean'),
                    icon: Icon(Icons.cleaning_services_rounded),
                  ),
                  ButtonSegment<String>(
                    value: AiMode.summary,
                    label: Text('Summary'),
                    icon: Icon(Icons.short_text_rounded),
                  ),
                  ButtonSegment<String>(
                    value: AiMode.notes,
                    label: Text('Notes'),
                    icon: Icon(Icons.note_alt_rounded),
                  ),
                ],
                selected: {_selectedMode},
                onSelectionChanged: _isLoading
                    ? null
                    : (selection) {
                        setState(() {
                          _selectedMode = selection.first;
                          _refinedText = null;
                          _errorMessage = null;
                        });
                      },
              ),
              const SizedBox(height: 20),

              // Result Section
              if (_refinedText != null) ...[
                Row(
                  children: [
                    Text(
                      'Refined Text Output',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy output',
                      onPressed: _copyOutput,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _refinedText!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _inputController.text = _refinedText!;
                          setState(() {
                            _refinedText = null;
                            _errorMessage = null;
                          });
                        },
                        icon: const Icon(Icons.swap_vert_rounded),
                        label: const Text('Use This Version'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _copyOutput,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Output'),
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
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_fix_high_rounded),
                  label: const Text('Refine Text with AI'),
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

  Future<void> _refineText() async {
    if (_inputController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter text to refine with AI.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _aiController.processText(
        input: _inputController.text.trim(),
        mode: _selectedMode,
      );

      if (!mounted) return;
      setState(() {
        _refinedText = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _copyOutput() {
    if (_refinedText != null && _refinedText!.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _refinedText!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refined text copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}
