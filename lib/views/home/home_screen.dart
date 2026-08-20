import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/main.dart'
    show themeNotifier, kPrimary, kPrimaryDark;
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

// ── Tool model ────────────────────────────────────────────────────────────
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

const _tools = <ToolItem>[
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
    title: 'Word/TXT to PDF',
    subtitle: 'Doc/Text to PDF',
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

  // Organize
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

  // Edit
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
    title: 'Protect PDF',
    subtitle: 'Set PDF password',
    icon: Icons.lock_rounded,
    color: Color(0xFFEF4444),
    screen: ProtectPdfScreen(),
    category: 'Edit',
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
];

// ── Home Screen ───────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _inputCtrl = TextEditingController();
  late final AnimationController _heroAnim;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  Timer? _heroTimer;
  String _category = 'All';
  bool _buttonPressed = false;

  final _categories = const ['All', 'Convert', 'Organize', 'Edit', 'AI'];

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_rebuild);
    _heroAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _heroFade  = CurvedAnimation(parent: _heroAnim, curve: Curves.easeOut);
    _heroSlide = Tween(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _heroAnim, curve: Curves.easeOutCubic));
    _heroTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) _heroAnim.forward();
    });
  }

  void _rebuild() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _inputCtrl.dispose();
    _heroAnim.dispose();
    themeNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _push(Widget screen) {
    if (!mounted) return;
    try {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, a, __) => screen,
          transitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (_, a, __, child) => SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open screen: $e')),
        );
      }
    }
  }

  List<ToolItem> get _filtered => _category == 'All'
      ? _tools
      : _tools.where((t) => t.category == _category).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final sub = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Sliver AppBar ──────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 0,
            backgroundColor: isDark ? const Color(0xFF0B0B13) : const Color(0xFFF7F7F9),
            title: Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 9),
              Text('PDF AI Toolkit',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF111827))),
            ]),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                color: isDark ? Colors.white : const Color(0xFF111827),
                onPressed: () => Navigator.of(context).pushNamed('/settings'),
                tooltip: 'Settings',
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ── Body content ──────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Hero title
                Text('What would you like\nto do today?',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 26, letterSpacing: -0.8)),
                const SizedBox(height: 4),
                Text('Paste AI text or pick a tool below', style: TextStyle(color: sub, fontSize: 14)),
                const SizedBox(height: 22),

                // ── Hero card ──────────────────────────────────────
                FadeTransition(
                  opacity: _heroFade,
                  child: SlideTransition(
                    position: _heroSlide,
                    child: _HeroCard(
                      controller: _inputCtrl,
                      primary: primary,
                      isDark: isDark,
                      pressed: _buttonPressed,
                      onPressDown: () => setState(() => _buttonPressed = true),
                      onPressUp: () => setState(() => _buttonPressed = false),
                      onGenerate: () => _push(AiScreen(initialInput: _inputCtrl.text.trim())),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Quick actions ─────────────────────────────────
                Row(children: [
                  _QuickBtn(icon: Icons.document_scanner_rounded, label: 'Scan', color: const Color(0xFF059669), onTap: () => _push(const CameraScanScreen())),
                  const SizedBox(width: 10),
                  _QuickBtn(icon: Icons.edit_document,             label: 'Edit PDF', color: kPrimary,              onTap: () => _push(const PdfEditorScreen())),
                  const SizedBox(width: 10),
                  _QuickBtn(icon: Icons.image_rounded,             label: 'Img to PDF', color: const Color(0xFF0EA5E9), onTap: () => _push(const JpgToPdfScreen())),
                ]),
                const SizedBox(height: 28),

                // ── Pro Tips ──────────────────────────────────────
                Text('Pro Tips', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 114,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _TipCard(
                        title: 'Perfect Scans',
                        subtitle: 'Use the Camera Scan tool for auto edge-detection.',
                        icon: Icons.document_scanner_rounded,
                        color: const Color(0xFF059669),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 12),
                      _TipCard(
                        title: 'Annotate Freely',
                        subtitle: 'Drag and drop text or images right onto any PDF.',
                        icon: Icons.edit_document,
                        color: kPrimary,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 12),
                      _TipCard(
                        title: 'Convert to Word',
                        subtitle: 'Extract text from PDFs directly into Word/TXT.',
                        icon: Icons.text_snippet_rounded,
                        color: const Color(0xFF6366F1),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Category tabs ─────────────────────────────────
                Text('All Tools', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final cat = _categories[i];
                      final sel = _category == cat;
                      return GestureDetector(
                        key: ValueKey('category_tab_$cat'),
                        onTap: () {
                          if (mounted) {
                            setState(() => _category = cat);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? primary : (isDark ? const Color(0xFF1C1C28) : const Color(0xFFEEEEF4)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(cat,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                color: sel ? Colors.white : sub,
                              )),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // ── Tool grid or Empty State ──────────────────────
                _filtered.isEmpty
                    ? Container(
                        key: const ValueKey('empty_category_state'),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF14141E) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1F1F2E) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 44,
                              color: isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No tools available',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No tools found in "$_category"',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        key: ValueKey('tool_grid_$_category'),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.55,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _ToolCard(
                          key: ValueKey('tool_card_${_filtered[i].title}'),
                          item: _filtered[i],
                          isDark: isDark,
                          onTap: () => _push(_filtered[i].screen),
                        ),
                      ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14141E) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF1F1F2E) : const Color(0xFFE5E7EB))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BottomAction(
              icon: Icons.history_rounded,
              label: 'History',
              color: const Color(0xFF6366F1),
              onTap: () => Navigator.of(context).pushNamed('/history'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _push(const CameraScanScreen()),
                icon: const Icon(Icons.document_scanner_rounded),
                label: const Text('Start Scan', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _BottomAction(
              icon: Icons.photo_library_rounded,
              label: 'Gallery',
              color: const Color(0xFF0EA5E9),
              onTap: () => _push(const JpgToPdfScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BottomAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Hero input card ───────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final TextEditingController controller;
  final Color primary;
  final bool isDark, pressed;
  final VoidCallback onPressDown, onPressUp, onGenerate;
  const _HeroCard({required this.controller, required this.primary,
    required this.isDark, required this.pressed,
    required this.onPressDown, required this.onPressUp, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? const Color(0xFF14141E) : Colors.white;
    final border = isDark ? const Color(0xFF1F1F2E) : const Color(0xFFE5E7EB);
    final hint   = isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text('AI Powered', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primary)),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          minLines: 4,
          maxLines: 6,
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: 'Paste your ChatGPT or notes here…',
            hintStyle: TextStyle(color: hint, fontSize: 14),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 14),
        Divider(height: 1, color: border),
        const SizedBox(height: 14),
        GestureDetector(
          onTapDown: (_) => onPressDown(),
          onTapUp: (_) { onPressUp(); onGenerate(); },
          onTapCancel: onPressUp,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 100),
            scale: pressed ? 0.96 : 1.0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Generate PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Quick action button ───────────────────────────────────────────────────
class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 5),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      ),
    );
  }
}

// ── Tool card ─────────────────────────────────────────────────────────────
class _ToolCard extends StatefulWidget {
  final ToolItem item;
  final bool isDark;
  final VoidCallback onTap;
  const _ToolCard({Key? key, required this.item, required this.isDark, required this.onTap}) : super(key: key);
  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 100), value: 1);
    _scale = Tween(begin: 1.0, end: 0.94).animate(CurvedAnimation(parent: _ctl, curve: Curves.easeOut));
  }
  @override
  void dispose() { _ctl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bg     = widget.isDark ? const Color(0xFF14141E) : Colors.white;
    final border = widget.isDark ? const Color(0xFF1F1F2E) : const Color(0xFFE5E7EB);
    final col    = widget.item.color;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _ctl.reverse(),
      onTapUp: (_) => _ctl.forward(),
      onTapCancel: () => _ctl.forward(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: col.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(widget.item.icon, color: col, size: 19),
            ),
            const Spacer(),
            Text(widget.item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(widget.item.subtitle, style: TextStyle(fontSize: 11, color: widget.isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

// ── Tip Card ──────────────────────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _TipCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF1F1F2E) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }
}
