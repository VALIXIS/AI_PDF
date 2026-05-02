import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/main.dart' show themeNotifier, kPrimary;
import 'package:pdf_ai_toolkit/services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDark = false;
  int _historyCount = 0;

  @override
  void initState() {
    super.initState();
    _isDark = themeNotifier.isDark;
    themeNotifier.addListener(_onThemeChange);
    _loadHistoryCount();
  }

  void _onThemeChange() {
    if (mounted) setState(() => _isDark = themeNotifier.isDark);
  }

  Future<void> _loadHistoryCount() async {
    final count = await StorageService().getHistoryCount();
    if (mounted) setState(() => _historyCount = count);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);
    final sectionColor =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF94A3B8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Appearance ────────────────────────────────────────────
          _SectionHeader(label: 'APPEARANCE', color: sectionColor),
          _SettingsTile(
            icon: Icons.dark_mode_rounded,
            iconColor: const Color(0xFF6366F1),
            title: 'Dark Mode',
            subtitle: _isDark ? 'Currently on' : 'Currently off',
            trailing: Switch.adaptive(
              value: _isDark,
              activeThumbColor: kPrimary,
              activeTrackColor: kPrimary.withValues(alpha: 0.4),
              onChanged: (_) => themeNotifier.toggle(),
            ),
          ),

          // ── Data ─────────────────────────────────────────────────
          _SectionHeader(label: 'DATA', color: sectionColor),
          _SettingsTile(
            icon: Icons.history_rounded,
            iconColor: const Color(0xFF06B6D4),
            title: 'History',
            subtitle: '$_historyCount saved file${_historyCount == 1 ? '' : 's'}',
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: subtitleColor,
            ),
            onTap: () => Navigator.of(context).pushNamed('/history'),
          ),
          _SettingsTile(
            icon: Icons.delete_sweep_rounded,
            iconColor: const Color(0xFFEF4444),
            title: 'Clear History',
            subtitle: 'Remove all saved PDF records',
            onTap: () => _confirmClearHistory(context),
          ),

          // ── About ────────────────────────────────────────────────
          _SectionHeader(label: 'ABOUT', color: sectionColor),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF2563EB),
            title: 'PDF AI Toolkit',
            subtitle: 'Version 1.0.0',
          ),
          _SettingsTile(
            icon: Icons.description_rounded,
            iconColor: const Color(0xFF10B981),
            title: 'Open Source',
            subtitle: 'Built with Flutter & Dart',
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear History'),
        content: Text(
            'This will remove all $_historyCount saved records. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await StorageService().clearAllHistory();
              if (!mounted) return;
              setState(() => _historyCount = 0);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('History cleared'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Clear',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable settings tile
// ---------------------------------------------------------------------------
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? const Color(0xFF8B949E)
                                    : const Color(0xFF64748B),
                              ),
                    ),
                  ]
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: color,
        ),
      ),
    );
  }
}
