import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
    try {
      final count = await StorageService().getHistoryCount();
      if (mounted) setState(() => _historyCount = count);
    } catch (_) {
      if (mounted) setState(() => _historyCount = 0);
    }
  }

  static const String _privacyPolicyUrl =
      'https://metspy9069.github.io/AI_PDF/privacy-policy/';

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(_privacyPolicyUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        final fallbackLaunched = await launchUrl(uri);
        if (!fallbackLaunched && mounted) {
          _showLaunchErrorSnackBar();
        }
      }
    } catch (_) {
      if (mounted) {
        _showLaunchErrorSnackBar();
      }
    }
  }

  void _showLaunchErrorSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Could not open browser. Privacy Policy: $_privacyPolicyUrl',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Copy URL',
          onPressed: () {
            Clipboard.setData(const ClipboardData(text: _privacyPolicyUrl));
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final bgCol = isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFC);
    final subtitleColor =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);
    final sectionColor =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: bgCol,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textCol,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textCol),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF0A0E1A),
                    Color(0xFF0F172A),
                    Color(0xFF0A0A10),
                  ]
                : const [
                    Color(0xFFF8FAFC),
                    Color(0xFFF1F5F9),
                    Color(0xFFE2E8F0),
                  ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            children: [
              // ── Appearance ────────────────────────────────────────────
              _SectionHeader(label: 'APPEARANCE', color: sectionColor),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14141E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF1F1F2E)
                          : const Color(0xFFE5E7EB)),
                ),
                child: _SettingsTile(
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
                  isLast: true,
                ),
              ),
              const SizedBox(height: 24),

              // ── AI Assistant ──────────────────────────────────────────
              _SectionHeader(label: 'AI ASSISTANT', color: sectionColor),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14141E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF1F1F2E)
                          : const Color(0xFFE5E7EB)),
                ),
                child: const Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.auto_awesome_rounded,
                      iconColor: Color(0xFF7C3AED),
                      title: 'AI Provider Engine',
                      subtitle:
                          'Google Gemini 2.5 Flash (Resilient Fallback Active)',
                    ),
                    _SettingsTile(
                      icon: Icons.document_scanner_rounded,
                      iconColor: Color(0xFF0284C7),
                      title: 'Multi-Format Understanding',
                      subtitle: 'Full PDF, DOCX, and TXT contextual extraction',
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Data ─────────────────────────────────────────────────
              _SectionHeader(label: 'DATA & STORAGE', color: sectionColor),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14141E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF1F1F2E)
                          : const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.history_rounded,
                      iconColor: const Color(0xFF06B6D4),
                      title: 'History Records',
                      subtitle:
                          '$_historyCount saved file${_historyCount == 1 ? '' : 's'}',
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
                      onTap: _confirmClearHistory,
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── About ────────────────────────────────────────────────
              _SectionHeader(label: 'ABOUT', color: sectionColor),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14141E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF1F1F2E)
                          : const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    _SettingsTile(
                      leadingWidget: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/ICON.png',
                          width: 38,
                          height: 38,
                          fit: BoxFit.contain,
                        ),
                      ),
                      title: 'PDF AI Toolkit',
                      subtitle: 'Version 1.0.0+1 (Founder Edition)',
                    ),
                    _SettingsTile(
                      icon: Icons.shield_rounded,
                      iconColor: const Color(0xFF10B981),
                      title: 'Privacy & Security',
                      subtitle:
                          'Local document parsing with zero persistent cloud storage',
                      trailing: Icon(
                        Icons.open_in_new_rounded,
                        size: 18,
                        color: subtitleColor,
                      ),
                      onTap: _openPrivacyPolicy,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Clear History'),
        content: Text(
            'This will remove all $_historyCount saved records. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogCtx);
              await StorageService().clearAllHistory();
              if (!mounted) return;
              setState(() => _historyCount = 0);
              messenger.showSnackBar(
                SnackBar(
                  content: const Text('History cleared'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child:
                const Text('Clear', style: TextStyle(color: Color(0xFFEF4444))),
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
  final IconData? icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isLast;
  final Widget? leadingWidget;

  const _SettingsTile({
    this.icon,
    this.iconColor = const Color(0xFF2563EB),
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isLast = false,
    this.leadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: isLast
                ? null
                : BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: isDark
                                ? const Color(0xFF1F1F2E)
                                : const Color(0xFFE5E7EB))),
                  ),
            child: Row(
              children: [
                leadingWidget ??
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
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
        ));
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
