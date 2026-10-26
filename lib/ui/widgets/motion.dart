import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Fades in and rises [offset] pixels the first time it is built, once.
///
/// Pass the same [seen] set for a list so items that scroll out and back in
/// do not animate again. Shows the child as-is when motion is reduced.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.id, required this.seen, required this.child, this.offset = 24});

  final Object id;
  final Set<Object> seen;
  final Widget child;
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> {
  late final bool _animate = widget.seen.add(widget.id);

  @override
  Widget build(BuildContext context) {
    if (!_animate || Motion.reduced(context)) return widget.child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.slow,
      curve: Motion.curve,
      child: widget.child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, widget.offset * (1 - t)), child: child),
      ),
    );
  }
}

/// Sinks slightly while pressed, like a print pressed against glass.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down && !reduced ? 0.98 : 1,
        duration: Motion.fast,
        curve: Motion.curve,
        child: AnimatedOpacity(
          opacity: _down ? 0.8 : 1,
          duration: Motion.fast,
          curve: Motion.curve,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A section heading: a small spaced English label over a Japanese title.
class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.label, required this.title, this.trailing});

  final String label;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 11,
                  letterSpacing: 2.4,
                  color: Palette.gold,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: Palette.text,
                    ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// A white label laid on a photo (category, "今日の一枚").
class PhotoTag extends StatelessWidget {
  const PhotoTag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: Colors.white,
      child: Text(
        text,
        style: const TextStyle(color: Palette.room, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
      ),
    );
  }
}
