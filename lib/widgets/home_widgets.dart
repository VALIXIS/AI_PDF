import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kCardLight, kCardDark, kTextLight;

/// Hero input section – large text field + Generate PDF button.
class HeroInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onGenerate;

  const HeroInputWidget({
    Key? key,
    required this.controller,
    required this.onGenerate,
  }) : super(key: key);

  @override
  State<HeroInputWidget> createState() => _HeroInputWidgetState();
}

class _HeroInputWidgetState extends State<HeroInputWidget> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? kCardDark : kCardLight;
    final borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFE2E8F0);
    final subtitleColor = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input field
          TextField(
            controller: widget.controller,
            minLines: 5,
            maxLines: 8,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: const InputDecoration(
              hintText: 'Paste your ChatGPT or notes here...',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 16),

          // Divider
          Divider(
            height: 1,
            color: isDark
                ? const Color(0xFF30363D)
                : const Color(0xFFE2E8F0),
          ),
          const SizedBox(height: 16),

          // Row: character count + button
          Row(
            children: [
              // Live character count
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (_, v, __) => Text(
                  '${v.text.length} chars',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                      ),
                ),
              ),
              const Spacer(),

              // Generate PDF button
              GestureDetector(
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) {
                  setState(() => _pressed = false);
                  widget.onGenerate();
                },
                onTapCancel: () => setState(() => _pressed = false),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 100),
                  scale: _pressed ? 0.96 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 13),
                    decoration: BoxDecoration(
                      color: kPrimary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimary.withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Generate PDF',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact tool card – icon + title only, scale-on-tap animation.
class ToolCardWidget extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;
  final VoidCallback onTap;

  const ToolCardWidget({
    Key? key,
    required this.icon,
    required this.title,
    this.iconColor,
    required this.onTap,
  }) : super(key: key);

  @override
  State<ToolCardWidget> createState() => _ToolCardWidgetState();
}

class _ToolCardWidgetState extends State<ToolCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 110),
      value: 1.0,
    );
    _scale =
        Tween(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _ctl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _down(_) => _ctl.reverse();
  void _up(_) => _ctl.forward();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? kCardDark : kCardLight;
    final borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFE2E8F0);
    final iconColor = widget.iconColor ??
        (isDark ? const Color(0xFF60A5FA) : kPrimary);
    final titleColor = isDark ? Colors.white : kTextLight;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: () => _ctl.forward(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark
                    ? const Color(0xFF4B5563)
                    : const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
