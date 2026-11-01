import 'package:flutter/material.dart';

class ToolCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlighted;
  final VoidCallback onTap;

  const ToolCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.highlighted = false,
    required this.onTap,
  }) : super(key: key);

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 120),
      value: 1.0,
    );
    _scale = Tween(begin: 1.0, end: 0.98)
        .animate(CurvedAnimation(parent: _ctl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _ctl.reverse();
  void _onTapUp(_) => _ctl.forward();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF161B26) : Colors.white;
    final cardBorder = widget.highlighted
        ? const Color(0xFF38BDF8)
        : (isDark ? const Color(0xFF262D3D) : const Color(0xFFE2E8F0));
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final iconColor = widget.highlighted
        ? const Color(0xFF38BDF8)
        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155));

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapCancel: () => _ctl.forward(),
      onTapUp: _onTapUp,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.4)
                    : const Color(0x0A0F172A),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: cardBorder,
              width: widget.highlighted ? 1.8 : 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon, size: 28, color: iconColor),
                  const Spacer(),
                  if (widget.highlighted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'AI',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF0284C7),
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: subtitleColor,
                      height: 1.3,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
