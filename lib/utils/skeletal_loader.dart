import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pixel-perfect shimmer skeleton system
// Key fixes vs previous version:
//   • LinearGradient always has explicit begin/end → no sub-pixel jitter
//   • No double.infinity width inside unconstrained Column
//   • ShimmerScope uses RepaintBoundary for GPU isolation
//   • All sizes are concrete (never reliant on unconstrained parent)
// ─────────────────────────────────────────────────────────────────────────────

// ── Shared animation via InheritedWidget ─────────────────────────────────────
class _ShimmerData extends InheritedWidget {
  const _ShimmerData({required this.animation, required super.child});
  final Animation<double> animation;
  static _ShimmerData? of(BuildContext ctx) =>
      ctx.dependOnInheritedWidgetOfExactType<_ShimmerData>();
  @override
  bool updateShouldNotify(_ShimmerData old) => old.animation != animation;
}

class ShimmerScope extends StatefulWidget {
  const ShimmerScope({super.key, required this.child});
  final Widget child;
  @override State<ShimmerScope> createState() => _ShimmerScopeState();
}

class _ShimmerScopeState extends State<ShimmerScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: _ShimmerData(animation: _anim, child: widget.child),
      );
}

// ── Core shimmer box ──────────────────────────────────────────────────────────
class SkeletalLoader extends StatelessWidget {
  const SkeletalLoader({
    super.key,
    this.height = 16,
    this.width,
    this.borderRadius = 8,
  });

  final double  height;
  final double? width;       // null = expand to fill parent
  final double  borderRadius;

  @override
  Widget build(BuildContext context) {
    final data = _ShimmerData.of(context);

    Widget box(Color color) => Container(
          height: height,
          width:  width,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        );

    if (data == null) {
      // Outside ShimmerScope — simple static grey
      return box(const Color(0xFFE8ECF0));
    }

    return AnimatedBuilder(
      animation: data.animation,
      builder: (_, __) {
        final t = data.animation.value;
        // Lerp between two greys — no complex gradient, no sub-pixel issues
        final color = Color.lerp(
          const Color(0xFFE2E8F0),
          const Color(0xFFF1F5F9),
          t,
        )!;
        return box(color);
      },
    );
  }
}

// ── Convenience wrappers ──────────────────────────────────────────────────────

/// Full-width shimmer line (expands horizontally)
class ShimmerLine extends StatelessWidget {
  const ShimmerLine({super.key, required this.height, this.borderRadius = 6});
  final double height;
  final double borderRadius;
  @override
  Widget build(BuildContext context) => SkeletalLoader(
      height: height, borderRadius: borderRadius);
}

/// Fixed-width shimmer block
class ShimmerBox extends StatelessWidget {
  const ShimmerBox(
      {super.key,
      required this.width,
      required this.height,
      this.borderRadius = 8});
  final double width, height, borderRadius;
  @override
  Widget build(BuildContext context) =>
      SkeletalLoader(width: width, height: height, borderRadius: borderRadius);
}

/// Circle shimmer (avatar placeholder)
class ShimmerCircle extends StatelessWidget {
  const ShimmerCircle({super.key, required this.size});
  final double size;
  @override
  Widget build(BuildContext context) =>
      SkeletalLoader(width: size, height: size, borderRadius: size / 2);
}

// ── List skeleton ─────────────────────────────────────────────────────────────
class SkeletonCardList extends StatelessWidget {
  const SkeletonCardList({
    super.key,
    this.count = 5,
    this.itemHeight = 76,
    this.padding,
  });

  final int         count;
  final double      itemHeight;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => ShimmerScope(
        child: ListView.separated(
          padding:     padding ?? const EdgeInsets.all(16),
          itemCount:   count,
          physics:     const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder:  (_, __) => _ListItemSkeleton(height: itemHeight),
        ),
      );
}

class _ListItemSkeleton extends StatelessWidget {
  const _ListItemSkeleton({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const ShimmerCircle(size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerLine(height: 13),
                SizedBox(height: 8),
                ShimmerBox(width: 110, height: 10),
              ],
            ),
          ),
        ]),
      );
}

// ── Profile card skeleton ─────────────────────────────────────────────────────
class SkeletonProfileCard extends StatelessWidget {
  const SkeletonProfileCard({super.key});

  @override
  Widget build(BuildContext context) => ShimmerScope(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Center(child: ShimmerCircle(size: 64)),
              SizedBox(height: 14),
              Center(child: ShimmerBox(width: 160, height: 16)),
              SizedBox(height: 8),
              Center(child: ShimmerBox(width: 220, height: 11)),
              SizedBox(height: 20),
              Divider(),
              SizedBox(height: 12),
              Center(child: ShimmerBox(width: 80, height: 11)),
              SizedBox(height: 6),
              Center(child: ShimmerBox(width: 120, height: 28)),
            ],
          ),
        ),
      );
}
