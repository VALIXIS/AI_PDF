import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/views/ai/ai_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/merge_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/split_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/text_to_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_to_text_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/compress_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/ai_refine_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/camera_scan_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_editor_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/watermark_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/jpg_to_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/rotate_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/protect_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/chat_with_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_to_image_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/markdown_to_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/html_to_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/signature_canvas_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_page_reorganizer_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_signature_overlay_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/ai_summarizer_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_form_filler_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/redaction_screen.dart';
import 'package:pdf_ai_toolkit/views/viewer/pdf_document_viewer_screen.dart';
import 'package:pdf_ai_toolkit/widgets/pdf_security_dialogs.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

class ToolItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget screen;
  final String category;

  const ToolItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.screen,
    required this.category,
  });
}

const List<ToolItem> appTools = [
  // Convert
  ToolItem(
    title: 'Images to PDF',
    subtitle: 'Gallery to document',
    icon: Icons.image_rounded,
    color: Color(0xFF0EA5E9),
    screen: JpgToPdfScreen(),
    category: 'Convert',
  ),
  ToolItem(
    title: 'TXT to PDF',
    subtitle: 'Plain text to PDF',
    icon: Icons.text_fields_rounded,
    color: Color(0xFF10B981),
    screen: TextToPdfScreen(),
    category: 'Convert',
  ),
  ToolItem(
    title: 'PDF to Text',
    subtitle: 'Extract text from PDF',
    icon: Icons.text_snippet_rounded,
    color: Color(0xFF6366F1),
    screen: PdfToTextScreen(),
    category: 'Convert',
  ),
  ToolItem(
    title: 'Camera Scan',
    subtitle: 'Scan physical docs',
    icon: Icons.document_scanner_rounded,
    color: Color(0xFF059669),
    screen: CameraScanScreen(),
    category: 'Convert',
  ),
  ToolItem(
    title: 'PDF to Image',
    subtitle: 'Extract PNG pages',
    icon: Icons.collections_rounded,
    color: Color(0xFF8B5CF6),
    screen: PdfToImageScreen(),
    category: 'Convert',
  ),
  ToolItem(
    title: 'Markdown to PDF',
    subtitle: 'Convert Markdown to PDF',
    icon: Icons.description_rounded,
    color: Color(0xFF6366F1),
    screen: MarkdownToPdfScreen(),
    category: 'Convert',
  ),
  ToolItem(
    title: 'HTML to PDF',
    subtitle: 'Convert HTML to PDF',
    icon: Icons.html_rounded,
    color: Color(0xFFE11D48),
    screen: HtmlToPdfScreen(),
    category: 'Convert',
  ),

  // Organize
  ToolItem(
    title: 'Organize Pages',
    subtitle: 'Reorder, rotate & delete',
    icon: Icons.dashboard_customize_rounded,
    color: Color(0xFF6366F1),
    screen: PdfPageReorganizerScreen(),
    category: 'Organize',
  ),
  ToolItem(
    title: 'Merge PDF',
    subtitle: 'Combine multiple PDFs',
    icon: Icons.call_merge_rounded,
    color: Color(0xFF8B5CF6),
    screen: MergePdfScreen(),
    category: 'Organize',
  ),
  ToolItem(
    title: 'Split PDF',
    subtitle: 'Extract page ranges',
    icon: Icons.call_split_rounded,
    color: Color(0xFFEC4899),
    screen: SplitPdfScreen(),
    category: 'Organize',
  ),
  ToolItem(
    title: 'Compress PDF',
    subtitle: 'Reduce file size',
    icon: Icons.compress_rounded,
    color: Color(0xFFF59E0B),
    screen: CompressPdfScreen(),
    category: 'Organize',
  ),
  ToolItem(
    title: 'Rotate PDF',
    subtitle: 'Rotate orientation',
    icon: Icons.rotate_right_rounded,
    color: Color(0xFF10B981),
    screen: RotatePdfScreen(),
    category: 'Organize',
  ),
  ToolItem(
    title: 'PDF Viewer',
    subtitle: 'Open & inspect documents',
    icon: Icons.menu_book_rounded,
    color: Color(0xFF2563EB),
    screen: PdfViewerLauncherScreen(),
    category: 'Organize',
  ),

  // Edit
  ToolItem(
    title: 'Sign & Stamp PDF',
    subtitle: 'Place signatures & stamps',
    icon: Icons.draw_rounded,
    color: Color(0xFF0284C7),
    screen: PdfSignatureOverlayScreen(),
    category: 'Edit',
  ),
  ToolItem(
    title: 'Form Filler',
    subtitle: 'Fill forms & annotate PDF',
    icon: Icons.assignment_turned_in_rounded,
    color: Color(0xFF10B981),
    screen: PdfFormFillerScreen(),
    category: 'Edit',
  ),
  ToolItem(
    title: 'PDF Editor',
    subtitle: 'Edit & annotate',
    icon: Icons.edit_document,
    color: Color(0xFFE03131),
    screen: PdfEditorScreen(),
    category: 'Edit',
  ),
  ToolItem(
    title: 'Watermark PDF',
    subtitle: 'Add text & stamps',
    icon: Icons.branding_watermark_rounded,
    color: Color(0xFFD97706),
    screen: WatermarkScreen(),
    category: 'Edit',
  ),
  ToolItem(
    title: 'E-Signature Pad',
    subtitle: 'Sign & save digital signatures',
    icon: Icons.draw_rounded,
    color: Color(0xFF2563EB),
    screen: SignatureCanvasScreen(),
    category: 'Edit',
  ),
  ToolItem(
    title: 'Protect PDF',
    subtitle: 'Set PDF password',
    icon: Icons.lock_rounded,
    color: Color(0xFFEF4444),
    screen: ProtectPdfScreen(),
    category: 'Security',
  ),
  ToolItem(
    title: 'Redact PDF',
    subtitle: 'Blackout sensitive content',
    icon: Icons.find_replace_rounded,
    color: Color(0xFF1E293B),
    screen: RedactionScreen(),
    category: 'Security',
  ),

  // AI
  ToolItem(
    title: 'AI to PDF',
    subtitle: 'ChatGPT → PDF',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFF7C3AED),
    screen: AiScreen(),
    category: 'AI',
  ),
  ToolItem(
    title: 'AI Refine',
    subtitle: 'Polish with AI',
    icon: Icons.auto_fix_high_rounded,
    color: Color(0xFF0284C7),
    screen: AiRefineScreen(),
    category: 'AI',
  ),
  ToolItem(
    title: 'Chat with PDF',
    subtitle: 'AI Document Q&A',
    icon: Icons.chat_rounded,
    color: Color(0xFF10B981),
    screen: ChatWithPdfScreen(),
    category: 'AI',
  ),
  ToolItem(
    title: 'AI Summarizer',
    subtitle: 'Executive Brief & Actions',
    icon: Icons.summarize_rounded,
    color: Color(0xFFEC4899),
    screen: AiSummarizerScreen(),
    category: 'AI',
  ),
];

class ToolsScreen extends StatefulWidget {
  final bool showBackButton;

  const ToolsScreen({Key? key, this.showBackButton = false}) : super(key: key);

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  String _category = 'All';
  final List<String> _categories = const [
    'All',
    'Convert',
    'Organize',
    'Edit',
    'Security',
    'AI'
  ];

  Future<void> _pickAndInspectPdf(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        if (!context.mounted) return;
        final pass = await handlePdfSecurityAndIntegrity(
          context: context,
          filePath: path,
          onChooseAnother: () => _pickAndInspectPdf(context),
        );
        if (pass != null && context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PdfDocumentViewerScreen(
                filePath: path,
                password: pass.isEmpty ? null : pass,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final filteredTools = _category == 'All'
        ? appTools
        : appTools.where((t) => t.category == _category).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'All Tools',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: false,
        automaticallyImplyLeading: widget.showBackButton,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            key: const Key('tools_open_pdf_action_button'),
            icon: const Icon(Icons.file_open_rounded),
            tooltip: 'Open PDF',
            onPressed: () => _pickAndInspectPdf(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Selector Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _category == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _category = cat;
                      });
                    },
                    selectedColor: primary,
                    checkmarkColor: Colors.white,
                    backgroundColor: isDark
                        ? const Color(0xFF1E1E2E)
                        : const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    side: BorderSide.none,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Tools Grid View
          Expanded(
            child: filteredTools.isEmpty
                ? ToolEmptyState(
                    icon: Icons.category_rounded,
                    title: 'No Tools in "$_category"',
                    subtitle:
                        'Try selecting another category or "All" to view available tools.',
                    actionLabel: 'Show All Tools',
                    onAction: () => setState(() => _category = 'All'),
                  )
                : GridView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.35,
                    ),
                    itemCount: filteredTools.length,
                    itemBuilder: (context, index) {
                      final item = filteredTools[index];
                      return _ToolsScreenCard(item: item, isDark: isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ToolsScreenCard extends StatefulWidget {
  final ToolItem item;
  final bool isDark;

  const _ToolsScreenCard({Key? key, required this.item, required this.isDark})
      : super(key: key);

  @override
  State<_ToolsScreenCard> createState() => _ToolsScreenCardState();
}

class _ToolsScreenCardState extends State<_ToolsScreenCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation =
        Tween<double>(begin: 1.0, end: 0.95).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool _isNavigating = false;

  void _onTap() {
    if (_isNavigating) return;
    _isNavigating = true;
    _animController.forward().then((_) {
      if (!mounted) return;
      _animController.reverse();
      Navigator.of(context)
          .push(
        PageRouteBuilder(
          pageBuilder: (_, a, __) => widget.item.screen,
          transitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (_, a, __, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.08, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: FadeTransition(
              opacity: a,
              child: child,
            ),
          ),
        ),
      )
          .then((_) {
        if (mounted) {
          setState(() => _isNavigating = false);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? const Color(0xFF13131F) : Colors.white;
    final borderCol =
        widget.isDark ? const Color(0xFF232335) : const Color(0xFFE2E8F0);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderCol, width: 1.2),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon container with soft brand background tint
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.item.icon,
                  color: widget.item.color,
                  size: 22,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isDark ? Colors.white60 : Colors.black54,
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

/// Standalone PDF viewer launcher screen accessible from Tools.
/// Inspects PDF integrity, intercepts corruption/format exceptions, and handles decryption passwords.
class PdfViewerLauncherScreen extends StatefulWidget {
  final String? initialFilePath;

  const PdfViewerLauncherScreen({Key? key, this.initialFilePath})
      : super(key: key);

  @override
  State<PdfViewerLauncherScreen> createState() =>
      _PdfViewerLauncherScreenState();
}

class _PdfViewerLauncherScreenState extends State<PdfViewerLauncherScreen> {
  bool _isProcessing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inspectAndOpen(widget.initialFilePath!);
      });
    }
  }

  Future<void> _pickAndOpen() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        await _inspectAndOpen(result.files.single.path!);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error choosing file: $e')),
      );
    }
  }

  Future<void> _inspectAndOpen(String path) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Inspecting document integrity...';
    });

    try {
      final pass = await handlePdfSecurityAndIntegrity(
        context: context,
        filePath: path,
        onChooseAnother: _pickAndOpen,
      );

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      if (pass != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfDocumentViewerScreen(
              filePath: path,
              password: pass.isEmpty ? null : pass,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process document: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Document Viewer'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Open & Inspect PDF',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Open any PDF document to read, inspect structure, or decrypt password-protected files.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 30),
              if (_isProcessing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  _statusMessage ?? 'Processing...',
                  style: const TextStyle(fontSize: 13),
                ),
              ] else ...[
                ElevatedButton.icon(
                  key: const Key('tools_launcher_pick_pdf_button'),
                  icon: const Icon(Icons.file_open_rounded),
                  label: const Text('Select PDF to View'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _pickAndOpen,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
