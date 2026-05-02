import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/main.dart' show themeNotifier, kPrimary;
import 'package:pdf_ai_toolkit/views/ai/ai_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/merge_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/split_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/text_to_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_to_text_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/compress_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/ai_refine_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/camera_scan_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_editor_screen.dart';
import 'package:pdf_ai_toolkit/views/history/history_screen.dart';
import 'package:pdf_ai_toolkit/views/settings/settings_screen.dart';
import 'package:pdf_ai_toolkit/widgets/home_widgets.dart';

// ---------------------------------------------------------------------------
// Tool data model
// ---------------------------------------------------------------------------
class _ToolItem {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget screen;
  const _ToolItem(
      {required this.title,
      required this.icon,
      required this.iconColor,
      required this.screen});
}

// ---------------------------------------------------------------------------
// Shell – holds the bottom nav + tab bodies
// ---------------------------------------------------------------------------
class AppShell extends StatefulWidget {
  const AppShell({Key? key}) : super(key: key);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  static const _screens = [
    HomeScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);

    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(top: BorderSide(color: borderColor, width: 1)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                _NavItem(
                  icon: Icons.history_rounded,
                  label: 'History',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  selected: _tab == 2,
                  onTap: () => setState(() => _tab = 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor =
        isDark ? const Color(0xFF4B5563) : const Color(0xFF94A3B8);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: selected ? kPrimary : inactiveColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? kPrimary : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HomeScreen
// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _inputController = TextEditingController();

  final List<_ToolItem> _tools = const [
    _ToolItem(
      title: 'Scan to PDF',
      icon: Icons.document_scanner_rounded,
      iconColor: Color(0xFF2563EB),
      screen: CameraScanScreen(),
    ),
    _ToolItem(
      title: 'PDF Editor',
      icon: Icons.edit_document,
      iconColor: Color(0xFFF59E0B),
      screen: PdfEditorScreen(),
    ),
    _ToolItem(
      title: 'Merge PDF',
      icon: Icons.merge_type_rounded,
      iconColor: Color(0xFF8B5CF6),
      screen: MergePdfScreen(),
    ),
    _ToolItem(
      title: 'Split PDF',
      icon: Icons.call_split_rounded,
      iconColor: Color(0xFFEF4444),
      screen: SplitPdfScreen(),
    ),
    _ToolItem(
      title: 'Text to PDF',
      icon: Icons.text_fields_rounded,
      iconColor: Color(0xFF10B981),
      screen: TextToPdfScreen(),
    ),
    _ToolItem(
      title: 'AI Refine',
      icon: Icons.auto_fix_high_rounded,
      iconColor: Color(0xFFEC4899),
      screen: AiRefineScreen(),
    ),
    _ToolItem(
      title: 'PDF to Text',
      icon: Icons.text_snippet_rounded,
      iconColor: Color(0xFF06B6D4),
      screen: PdfToTextScreen(),
    ),
    _ToolItem(
      title: 'Compress',
      icon: Icons.compress_rounded,
      iconColor: Color(0xFFFF6B35),
      screen: CompressPdfScreen(),
    ),
  ];

  bool _heroVisible = false;
  late final List<bool> _toolsVisible;
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _isDark = themeNotifier.isDark;
    _toolsVisible = List.generate(_tools.length, (_) => false);
    themeNotifier.addListener(_onThemeChange);

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _heroVisible = true);
    });
    for (int i = 0; i < _tools.length; i++) {
      Future.delayed(Duration(milliseconds: 300 + i * 60), () {
        if (mounted) setState(() => _toolsVisible[i] = true);
      });
    }
  }

  void _onThemeChange() {
    if (mounted) setState(() => _isDark = themeNotifier.isDark);
  }

  @override
  void dispose() {
    _inputController.dispose();
    themeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, a, __) => screen,
      transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut),
        child: child,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final subtitleColor = _isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF64748B);
    final sectionTitleColor = _isDark
        ? const Color(0xFFE2E8F0)
        : const Color(0xFF1E293B);

    return Scaffold(
      appBar: _buildAppBar(subtitleColor),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildHeader(subtitleColor),
              const SizedBox(height: 24),

              // ── Hero ─────────────────────────────────────────────────
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                opacity: _heroVisible ? 1.0 : 0.0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  offset:
                      _heroVisible ? Offset.zero : const Offset(0, 0.06),
                  child: HeroInputWidget(
                    controller: _inputController,
                    onGenerate: () => _navigateTo(
                      AiScreen(initialInput: _inputController.text.trim()),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Quick Actions row ─────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.document_scanner_rounded,
                      label: 'Scan',
                      color: const Color(0xFF2563EB),
                      onTap: () => _navigateTo(const CameraScanScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.edit_document,
                      label: 'Edit PDF',
                      color: const Color(0xFFF59E0B),
                      onTap: () => _navigateTo(const PdfEditorScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.merge_type_rounded,
                      label: 'Merge',
                      color: const Color(0xFF8B5CF6),
                      onTap: () => _navigateTo(const MergePdfScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── All Tools ─────────────────────────────────────────────
              Text(
                'All Tools',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: sectionTitleColor,
                    ),
              ),
              const SizedBox(height: 12),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _tools.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final t = _tools[i];
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 350),
                    opacity: _toolsVisible[i] ? 1.0 : 0.0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 350),
                      offset: _toolsVisible[i]
                          ? Offset.zero
                          : const Offset(0, 0.08),
                      child: ToolCardWidget(
                        icon: t.icon,
                        title: t.title,
                        iconColor: t.iconColor,
                        onTap: () => _navigateTo(t.screen),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Color subtitleColor) {
    return AppBar(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'PDF AI Toolkit',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        Icon(
          _isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          size: 18,
          color: subtitleColor,
        ),
        const SizedBox(width: 4),
        Switch.adaptive(
          value: _isDark,
          activeThumbColor: kPrimary,
          activeTrackColor: kPrimary.withValues(alpha: 0.5),
          onChanged: (_) => themeNotifier.toggle(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeader(Color subtitleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PDF AI Toolkit',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Convert AI responses into clean PDFs',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: subtitleColor),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Quick action button
// ---------------------------------------------------------------------------
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF161B22) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark
                  ? const Color(0xFF30363D)
                  : const Color(0xFFE2E8F0),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
