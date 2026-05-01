import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/views/ai/ai_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/merge_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/split_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/text_to_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_to_text_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/compress_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/ai_refine_screen.dart';
import 'package:pdf_ai_toolkit/views/history/history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<ToolTile> tools = [
    ToolTile(
      title: 'Merge PDF',
      icon: Icons.merge_type,
      description: 'Combine multiple PDFs',
      screen: const MergePdfScreen(),
      isHighlighted: false,
    ),
    ToolTile(
      title: 'Split PDF',
      icon: Icons.call_split,
      description: 'Extract pages from PDF',
      screen: const SplitPdfScreen(),
      isHighlighted: false,
    ),
    ToolTile(
      title: 'Text to PDF',
      icon: Icons.text_fields,
      description: 'Create PDF from text',
      screen: const TextToPdfScreen(),
      isHighlighted: false,
    ),
    ToolTile(
      title: 'AI to PDF',
      icon: Icons.auto_awesome,
      description: 'Transform with AI power',
      screen: const AiScreen(),
      isHighlighted: true, // This is the main feature
    ),
    ToolTile(
      title: 'AI Refine',
      icon: Icons.edit_note,
      description: 'Polish your text with AI',
      screen: const AiRefineScreen(),
      isHighlighted: false,
    ),
    ToolTile(
      title: 'PDF to Text',
      icon: Icons.description,
      description: 'Extract text from PDF',
      screen: const PdfToTextScreen(),
      isHighlighted: false,
    ),
    ToolTile(
      title: 'Compress PDF',
      icon: Icons.compress,
      description: 'Reduce file size',
      screen: const CompressPdfScreen(),
      isHighlighted: false,
    ),
    ToolTile(
      title: 'History',
      icon: Icons.history,
      description: 'View saved files',
      screen: const HistoryScreen(),
      isHighlighted: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF AI Toolkit'),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Welcome to PDF AI Toolkit',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a tool to get started',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tools Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                ),
                itemCount: tools.length,
                itemBuilder: (context, index) {
                  return _buildToolCard(context, tools[index]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, ToolTile tool) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => tool.screen),
        );
      },
      child: Card(
        elevation: tool.isHighlighted ? 8 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: tool.isHighlighted
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : BorderSide.none,
        ),
        child: Container(
          decoration: tool.isHighlighted
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  tool.icon,
                  size: 48,
                  color: tool.isHighlighted
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  tool.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: tool.isHighlighted
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  tool.description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (tool.isHighlighted) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Featured',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ToolTile {
  final String title;
  final IconData icon;
  final String description;
  final Widget screen;
  final bool isHighlighted;

  ToolTile({
    required this.title,
    required this.icon,
    required this.description,
    required this.screen,
    required this.isHighlighted,
  });
}
