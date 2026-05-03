import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Animated three-dot indicator — safe replacement for flutter_animate
/// `onPlay: (c) => c.repeat()` which triggers a Dart Stack Overflow on repeat.
class BouncingDots extends StatelessWidget {
  final String? label;
  final Color color;

  const BouncingDots({
    super.key,
    this.label,
    this.color = AppTheme.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < 3; i++)
          _Dot(delay: Duration(milliseconds: 140 * i), color: color),
        if (label != null) ...[
          const SizedBox(width: 10),
          Text(
            label!,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class _Dot extends StatefulWidget {
  final Duration delay;
  final Color color;

  const _Dot({required this.delay, required this.color});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _anim = Tween<double>(begin: 0.0, end: -7.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
