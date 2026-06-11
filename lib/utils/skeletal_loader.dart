import 'package:flutter/material.dart';
import 'app_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BASE SHIMMER WIDGET — single AnimationController shared via InheritedWidget
// ─────────────────────────────────────────────────────────────────────────────
class ShimmerTheme extends InheritedWidget {
  final Animation<double> animation;
  const ShimmerTheme({super.key, required this.animation, required super.child});

  static ShimmerTheme? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShimmerTheme>();

  @override
  bool updateShouldNotify(ShimmerTheme old) => old.animation != animation;
}

class ShimmerScope extends StatefulWidget {
  final Widget child;
  const ShimmerScope({super.key, required this.child});
  @override State<ShimmerScope> createState() => _ShimmerScopeState();
}
class _ShimmerScopeState extends State<ShimmerScope>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext ctx) =>
      ShimmerTheme(animation: _anim, child: widget.child);
}

// ─────────────────────────────────────────────────────────────────────────────
// SkeletalLoader — drop-in replacement, now uses shimmer gradient
// ─────────────────────────────────────────────────────────────────────────────
class SkeletalLoader extends StatelessWidget {
  final double height;
  final double width;
  final double borderRadius;

  const SkeletalLoader({
    super.key,
    this.height = 20,
    this.width  = double.infinity,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShimmerTheme.of(context);
    // If no ShimmerScope above us, fall back to simple fade
    if (theme == null) {
      return _FadeBox(h: height, w: width, r: borderRadius);
    }
    return AnimatedBuilder(
      animation: theme.animation,
      builder: (_, __) => Container(
        height: height,
        width:  width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            colors: [
              Color.lerp(const Color(0xFFE8ECF0), const Color(0xFFF8FAFC), theme.animation.value)!,
              Color.lerp(const Color(0xFFF8FAFC), const Color(0xFFE8ECF0), theme.animation.value)!,
            ],
          ),
        ),
      ),
    );
  }
}

class _FadeBox extends StatefulWidget {
  final double h, w, r;
  const _FadeBox({required this.h, required this.w, required this.r});
  @override State<_FadeBox> createState() => _FadeBoxState();
}
class _FadeBoxState extends State<_FadeBox> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext ctx) => FadeTransition(
    opacity: Tween(begin: 0.4, end: 1.0).animate(_c),
    child: Container(
      height: widget.h, width: widget.w,
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECF0),
        borderRadius: BorderRadius.circular(widget.r),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE SKELETON PATTERNS
// ─────────────────────────────────────────────────────────────────────────────

/// Standard card list skeleton — wraps in ShimmerScope automatically
class SkeletonCardList extends StatelessWidget {
  final int count;
  final double itemHeight;
  final EdgeInsets? padding;
  const SkeletonCardList({
    super.key,
    this.count = 5,
    this.itemHeight = 80,
    this.padding,
  });

  @override
  Widget build(BuildContext context) => ShimmerScope(
    child: ListView.separated(
      padding: padding ?? const EdgeInsets.all(16),
      itemCount: count,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => _SkeletonCard(height: itemHeight),
    ),
  );
}

class _SkeletonCard extends StatelessWidget {
  final double height;
  const _SkeletonCard({required this.height});
  @override Widget build(BuildContext ctx) => Container(
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
    ),
    padding: const EdgeInsets.all(14),
    child: Row(children: [
      SkeletalLoader(width: 44, height: 44, borderRadius: 22),
      const SizedBox(width: 12),
      Expanded(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletalLoader(width: double.infinity, height: 14),
          const SizedBox(height: 8),
          SkeletalLoader(width: 120, height: 11),
        ],
      )),
    ]),
  );
}

/// Profile card skeleton
class SkeletonProfileCard extends StatelessWidget {
  const SkeletonProfileCard({super.key});
  @override
  Widget build(BuildContext context) => ShimmerScope(
    child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
      ),
      child: Column(
        children: [
          const SkeletalLoader(width: 72, height: 72, borderRadius: 36),
          const SizedBox(height: 14),
          const SkeletalLoader(width: 160, height: 18),
          const SizedBox(height: 8),
          const SkeletalLoader(width: 220, height: 12),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          const SkeletalLoader(width: 80, height: 11),
          const SizedBox(height: 6),
          const SkeletalLoader(width: 110, height: 28),
        ],
      ),
    ),
  );
}
