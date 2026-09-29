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
  String _selectedCategory = 'All Tools';

  final List<String> _categoryTabs = const [
    'All Tools',
    'AI Tools',
    'Edit & Sign',
    'Convert & Organize',
  ];

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
    final primary = isDark ? kPrimaryDark : kPrimary;

    return SliverAppBar(
      pinned: true,
      elevation: _isScrolled ? 4 : 0,
      backgroundColor: isDark
          ? const Color(0xFF0A0A10).withValues(alpha: 0.88)
          : const Color(0xFFF8FAFC).withValues(alpha: 0.88),
      surfaceTintColor: Colors.transparent,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            title: Row(
              children: [
                Hero(
                  tag: 'app_logo',
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/ICON.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'AI PDF Maker',
                  style: TextStyle(
                    fontSize: 19,
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

  Widget _buildCategoryFilterChips(bool isDark) {
    final primary = isDark ? kPrimaryDark : kPrimary;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _categoryTabs.map((tab) {
              final isSelected = _selectedCategory == tab;

              IconData tabIcon;
              switch (tab) {
                case 'AI Tools':
                  tabIcon = Icons.auto_awesome_rounded;
                  break;
                case 'Edit & Sign':
                  tabIcon = Icons.edit_note_rounded;
                  break;
                case 'Convert & Organize':
                  tabIcon = Icons.transform_rounded;
                  break;
                default:
                  tabIcon = Icons.grid_view_rounded;
              }

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = tab;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                              ? primary.withValues(alpha: 0.18)
                              : primary.withValues(alpha: 0.12))
                          : (isDark
                              ? const Color(0xFF131320).withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.8)),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? primary.withValues(alpha: 0.6)
                            : (isDark
                                ? const Color(0xFF1F1F35)
                                : const Color(0xFFE2E8F0)),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tabIcon,
                              size: 16,
                              color: isSelected
                                  ? primary
                                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tab,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected
                                    ? (isDark ? Colors.white : primary)
                                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                        if (isSelected) ...[
                          const SizedBox(height: 3),
                          Container(
                            width: 16,
                            height: 2,
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: isDark ? kPrimaryDark : kPrimary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsGrid(List<ToolItem> tools, bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
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

  List<ToolItem> _getFilteredTools(String category) {
    if (category == 'AI Tools') {
      return appTools.where((t) => t.category == 'AI').toList();
    } else if (category == 'Edit & Sign') {
      return appTools
          .where((t) => t.category == 'Edit' || t.category == 'Security')
          .toList();
    } else if (category == 'Convert & Organize') {
      return appTools
          .where((t) => t.category == 'Convert' || t.category == 'Organize')
          .toList();
    }
    return appTools;
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
      _buildCategoryFilterChips(isDark),
    ];

    if (_selectedCategory == 'All Tools') {
      final categories = ['Convert', 'Organize', 'Edit', 'Security', 'AI'];
      for (var cat in categories) {
        if (groupedTools.containsKey(cat)) {
          slivers.add(SliverToBoxAdapter(child: _buildCategoryHeader(cat, isDark)));
          slivers.add(_buildToolsGrid(groupedTools[cat]!, isDark));
        }
      }
      // Add any other categories
      groupedTools.keys.where((k) => !categories.contains(k)).forEach((cat) {
        slivers.add(SliverToBoxAdapter(child: _buildCategoryHeader(cat, isDark)));
        slivers.add(_buildToolsGrid(groupedTools[cat]!, isDark));
      });
    } else {
      final filteredTools = _getFilteredTools(_selectedCategory);
      slivers.add(SliverToBoxAdapter(child: _buildCategoryHeader(_selectedCategory, isDark)));
      slivers.add(_buildToolsGrid(filteredTools, isDark));
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 50)));

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _push(const ChatWithPdfScreen()),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        elevation: 4,
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
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark
        ? const Color(0xFF131322).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.92);
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderCol = isDark
        ? const Color(0xFF222238)
        : const Color(0xFFE2E8F0);

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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered
                    ? widget.tool.color.withValues(alpha: 0.6)
                    : (isDark
                        ? widget.tool.color.withValues(alpha: 0.15)
                        : borderCol),
                width: _isHovered ? 1.8 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.tool.color.withValues(alpha: _isHovered ? 0.22 : 0.06),
                  blurRadius: _isHovered ? 20 : 10,
                  offset: const Offset(0, 4),
                  spreadRadius: _isHovered ? 1 : 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Stack(
                  children: [
                    // Subtle background glow in corner
                    Positioned(
                      right: -16,
                      top: -16,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.tool.color.withValues(alpha: isDark ? 0.12 : 0.08),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Colored Icon Container with gradient background
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  widget.tool.color.withValues(alpha: 0.22),
                                  widget.tool.color.withValues(alpha: 0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: widget.tool.color.withValues(alpha: 0.25),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.tool.color.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              widget.tool.icon,
                              color: widget.tool.color,
                              size: 26,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            widget.tool.title,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: textCol,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.tool.subtitle,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
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
      ),
    );
  }
}
