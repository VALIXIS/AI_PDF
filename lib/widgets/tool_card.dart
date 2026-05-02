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

class _ToolCardState extends State<ToolCard> with SingleTickerProviderStateMixin {
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
    _scale = Tween(begin: 1.0, end: 0.98).animate(CurvedAnimation(parent: _ctl, curve: Curves.easeOut));
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
    final cardColor = const Color(0xFF161B22);
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
            gradient: LinearGradient(
              colors: [cardColor, cardColor.withOpacity(0.95)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
            border: widget.highlighted
                ? Border.all(color: const Color(0xFF4DA3FF).withOpacity(0.25), width: 1.5)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon, size: 28, color: widget.highlighted ? const Color(0xFF4DA3FF) : Colors.white70),
                  const Spacer(),
                  if (widget.highlighted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4DA3FF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('AI', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF4DA3FF), fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(widget.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 6),
              Text(widget.subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[400])),
            ],
          ),
        ),
      ),
    );
  }
}
