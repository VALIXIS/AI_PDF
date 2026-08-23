import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf_ai_toolkit/main.dart'
    show themeNotifier, kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/views/tools/tools_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/chat_with_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/camera_scan_screen.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _promptController = TextEditingController();
  final StorageService _storageService = StorageService();

  List<HistoryEntry> _recentHistory = [];
  bool _loadingHistory = true;
  bool _isPromptFocused = false;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_rebuild);
    _loadRecentHistory();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_rebuild);
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentHistory() async {
    try {
      final entries = await _storageService.getHistoryEntriesSortedByDate();
      if (mounted) {
        setState(() {
          _recentHistory = entries.take(3).toList();
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  void _push(Widget screen) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => screen,
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
    );
    _loadRecentHistory();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardBg = isDark ? const Color(0xFF13131F) : Colors.white;
    final borderCol =
        isDark ? const Color(0xFF1F1F35) : const Color(0xFFF1F5F9);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/ICON.png',
                width: 34,
                height: 34,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'PDF AI Toolkit',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textCol,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            color: isDark ? Colors.white70 : const Color(0xFF475569),
            onPressed: () => _push(const SizedBox()), // Handled via route
            tooltip: 'Settings',
          ),
          const SizedBox(width: 8),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── MAIN AI COMPANION ASK CARD ─────────────────────────────────
              Text(
                'What can I help you with?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textCol,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131326) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isPromptFocused
                        ? primary
                        : (isDark
                            ? const Color(0xFF252538)
                            : const Color(0xFFE2E8F0)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(isDark ? 0.15 : 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFF7C3AED),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'AI PDF Assistant',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textCol.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Focus(
                      onFocusChange: (hasFocus) {
                        setState(() {
                          _isPromptFocused = hasFocus;
                        });
                      },
                      child: TextField(
                        controller: _promptController,
                        maxLines: 3,
                        minLines: 2,
                        style: TextStyle(
                          fontSize: 14,
                          color: textCol,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Ask or type document requests...\n(e.g., "Merge my PDFs" or "Summarize report")',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        final text = _promptController.text.trim();
                        _promptController.clear();
                        _push(ChatWithPdfScreen(
                            initialPrompt: text.isNotEmpty ? text : null));
                      },
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text(
                        'Start AI Chat',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── RECENTLY USED SECTION ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recently Used',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textCol,
                    ),
                  ),
                  if (_recentHistory.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/history'),
                      child: const Text('View All'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _buildRecentlyUsedSection(isDark, textCol, cardBg, borderCol),
              const SizedBox(height: 28),

              // ── MOST USED TOOLS ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Most Used Tools',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textCol,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        _push(const ToolsScreen(showBackButton: true)),
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildMostUsedToolsGrid(isDark),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, isDark, primary),
    );
  }

  Widget _buildRecentlyUsedSection(
      bool isDark, Color textCol, Color cardBg, Color borderCol) {
    if (_loadingHistory) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_recentHistory.isEmpty) {
      // Premium visual empty state
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol, width: 1.2),
        ),
        child: Column(
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 40,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            const SizedBox(height: 8),
            Text(
              'No recent PDF documents',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textCol.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Your processed files will appear here',
              style: TextStyle(
                fontSize: 11,
                color: textCol.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _recentHistory.map((entry) {
        final dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(entry.date);
        final fileName = entry.filePath.split('/').last.split('\\').last;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderCol, width: 1.2),
          ),
          color: cardBg,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE03131).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Color(0xFFE03131),
                size: 20,
              ),
            ),
            title: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  'Tool: ${entry.toolType.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.share_rounded, size: 18),
                  onPressed: () {
                    ShareService.showSaveShareDialog(context, entry.filePath);
                  },
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMostUsedToolsGrid(bool isDark) {
    // Filter out our top 4 most used tools from the list
    final mostUsed = appTools
        .where((t) =>
            t.title == 'Merge PDF' ||
            t.title == 'PDF Editor' ||
            t.title == 'Compress PDF' ||
            t.title == 'Images to PDF')
        .toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: mostUsed.length,
      itemBuilder: (context, index) {
        final item = mostUsed[index];
        final cardBg = isDark ? const Color(0xFF13131F) : Colors.white;
        final borderCol =
            isDark ? const Color(0xFF1F1F35) : const Color(0xFFE2E8F0);

        return GestureDetector(
          onTap: () => _push(item.screen),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    color: item.color,
                    size: 20,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar(
      BuildContext context, bool isDark, Color primary) {
    final barBg = isDark ? const Color(0xFF10101C) : Colors.white;
    final borderCol =
        isDark ? const Color(0xFF1D1D2C) : const Color(0xFFE2E8F0);
    final actionColor = isDark ? Colors.white70 : const Color(0xFF475569);

    return Container(
      height: 84,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      decoration: BoxDecoration(
        color: barBg,
        border: Border(top: BorderSide(color: borderCol, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Action: History
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/history'),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 60,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, color: actionColor, size: 22),
                  const SizedBox(height: 3),
                  Text(
                    'History',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: actionColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center Shutter Button: dominant action Scan
          GestureDetector(
            onTap: () => _push(const CameraScanScreen()),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [primary, const Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
                border: Border.all(
                  color: isDark ? const Color(0xFF0A0A10) : Colors.white,
                  width: 3.5,
                ),
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),

          // Right Action: Tools
          GestureDetector(
            onTap: () => _push(const ToolsScreen(showBackButton: true)),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 60,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_rounded, color: actionColor, size: 22),
                  const SizedBox(height: 3),
                  Text(
                    'Tools',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: actionColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
