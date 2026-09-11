import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/main.dart' show themeNotifier, kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/views/tools/tools_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/chat_with_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_rebuild);
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.offset > 20 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 20 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_rebuild);
    _scrollController.dispose();
    super.dispose();
  }

  void _push(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => screen,
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: a, child: child),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool isDark, Color textCol) {
    return SliverAppBar(
      pinned: true,
      elevation: _isScrolled ? 4 : 0,
      backgroundColor: isDark 
          ? const Color(0xFF0A0A10).withOpacity(0.85) 
          : const Color(0xFFF8FAFC).withOpacity(0.85),
      surfaceTintColor: Colors.transparent,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            title: Row(
              children: [
                Hero(
                  tag: 'app_logo',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/ICON.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'AI PDF Maker',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textCol,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          color: isDark ? Colors.white70 : const Color(0xFF475569),
          onPressed: () => _push(const SettingsScreen()),
          tooltip: 'Settings',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCategoryHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: isDark ? Colors.white54 : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildToolsGrid(List<ToolItem> tools, bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.88,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final tool = tools[index];
            return ILovePdfToolCard(
              tool: tool,
              isDark: isDark,
              onTap: () => _push(tool.screen),
            );
          },
          childCount: tools.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    
    // Group tools by category
    final Map<String, List<ToolItem>> groupedTools = {};
    for (var tool in appTools) {
      if (!groupedTools.containsKey(tool.category)) {
        groupedTools[tool.category] = [];
      }
      groupedTools[tool.category]!.add(tool);
    }

    final slivers = <Widget>[
      _buildSliverAppBar(context, isDark, textCol),
    ];

    // Build categories
    final categories = ['Convert', 'Organize', 'Edit', 'Security'];
    for (var cat in categories) {
      if (groupedTools.containsKey(cat)) {
        slivers.add(SliverToBoxAdapter(child: _buildCategoryHeader(cat, isDark)));
        slivers.add(_buildToolsGrid(groupedTools[cat]!, isDark));
      }
    }

    // Add remaining categories if any
    groupedTools.keys.where((k) => !categories.contains(k)).forEach((cat) {
      slivers.add(SliverToBoxAdapter(child: _buildCategoryHeader(cat, isDark)));
      slivers.add(_buildToolsGrid(groupedTools[cat]!, isDark));
    });

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 40)));

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _push(const ChatWithPdfScreen()),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
        label: const Text('AI Chat', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF0A0E1A), Color(0xFF0F172A), Color(0xFF0A0A10)]
                : const [Color(0xFFF8FAFC), Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
          ),
        ),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: slivers,
        ),
      ),
    );
  }
}

class ILovePdfToolCard extends StatefulWidget {
  final ToolItem tool;
  final bool isDark;
  final VoidCallback onTap;

  const ILovePdfToolCard({
    Key? key,
    required this.tool,
    required this.isDark,
    required this.onTap,
  }) : super(key: key);

  @override
  State<ILovePdfToolCard> createState() => _ILovePdfToolCardState();
}

class _ILovePdfToolCardState extends State<ILovePdfToolCard> with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? const Color(0xFF13131F) : Colors.white;
    final textCol = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final borderCol = widget.isDark ? const Color(0xFF1F1F35) : const Color(0xFFF1F5F9);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _hoverController.forward(),
        onTapUp: (_) {
          _hoverController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _hoverController.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered ? widget.tool.color.withOpacity(0.5) : borderCol,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.tool.color.withOpacity(_isHovered ? 0.2 : 0.05),
                  blurRadius: _isHovered ? 20 : 10,
                  offset: const Offset(0, 4),
                  spreadRadius: _isHovered ? 2 : 0,
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  // Subtle background glow
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.tool.color.withOpacity(0.1),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.tool.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            widget.tool.icon,
                            color: widget.tool.color,
                            size: 28,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          widget.tool.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textCol,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.tool.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: widget.isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
