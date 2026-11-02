import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_500.dart';

import '../theme.dart';

typedef Ic = LucideIcons500;

bool reduceMotion(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

Color lighten(Color c, double t) => Color.lerp(c, Colors.white, t)!;
Color darken(Color c, double t) => Color.lerp(c, Colors.black, t)!;

/// Khối nổi kiểu "đất sét": sáng ở mép trên, có gờ tối ở đáy và bóng đổ mềm.
class Clay extends StatelessWidget {
  const Clay({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.radius = 22,
    this.padding = EdgeInsets.zero,
    this.depth = 1,
    this.tint = kShadowTint,
    this.width,
    this.height,
  });

  final Widget child;
  final Color color;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double depth;
  final Color tint;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lighten(color, 0.30), color, darken(color, 0.03)],
          stops: const [0, 0.35, 1],
        ),
        boxShadow: depth > 0 ? clayShadow(tint, depth: depth) : null,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: br,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.07),
          ],
          stops: const [0, 0.07, 0.88, 1],
        ),
      ),
      child: child,
    );
  }
}

/// Rãnh lõm (ô nhập, thanh trượt…).
BoxDecoration wellDecoration({double radius = 16, Color color = kWell}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(radius),
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darken(color, 0.05), color, lighten(color, 0.4)],
    stops: const [0, 0.25, 1],
  ),
);

/// Nhấn vào thì lún xuống một chút rồi bật lại.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.label, this.scale = 0.95});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? label;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 140),
          curve: _down ? Curves.easeOut : Curves.elasticOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Nút khối màu chính.
class ClayButton extends StatelessWidget {
  const ClayButton({
    super.key,
    required this.label,
    this.onTap,
    this.color = kPrimary,
    this.icon,
    this.expand = false,
    this.light = false,
    this.height = 54,
  });
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;
  final bool expand;
  final bool light;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fg = light ? kInk : Colors.white;
    final bg = light ? kWell : color;
    return Pressable(
      onTap: onTap,
      label: label,
      child: Clay(
        color: bg,
        radius: 18,
        depth: light ? 0.4 : 1,
        tint: light ? kShadowTint : color,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 19, color: fg), const SizedBox(width: 8)],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: ts(15, w: FontWeight.w800, c: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nút vuông chỉ có icon.
class ClayIconButton extends StatelessWidget {
  const ClayIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.color = Colors.white,
    this.fg = kInk,
    this.size = 44,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color fg;
  final double size;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    label: label,
    child: Clay(
      color: color,
      radius: size * 0.34,
      depth: color == Colors.white ? 0.55 : 0.9,
      tint: color == Colors.white ? kShadowTint : color,
      width: size,
      height: size,
      child: Icon(icon, size: size * 0.45, color: fg),
    ),
  );
}

/// Ô icon nhỏ màu pastel.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, required this.color, this.size = 42});
  final IconData icon;
  final String color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = pastel(color);
    return Clay(
      color: p.bg,
      radius: size * 0.33,
      depth: 0.35,
      tint: p.fg,
      width: size,
      height: size,
      child: Icon(icon, size: size * 0.48, color: p.fg),
    );
  }
}

/// Xuất hiện bằng cách mờ dần + trượt lên, có độ trễ để tạo hiệu ứng lần lượt.
class FadeUp extends StatefulWidget {
  const FadeUp({super.key, required this.child, this.delay = Duration.zero, this.offset = 18});
  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<FadeUp> createState() => _FadeUpState();
}

class _FadeUpState extends State<FadeUp> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _t = Timer(widget.delay, _c.forward);
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(offset: Offset(0, widget.offset * (1 - _a.value)), child: child),
      ),
    );
  }
}

/// Bộ đếm lặp vô hạn 0 → 1 → 0 cho các hiệu ứng trôi / nhịp.
class Loop extends StatefulWidget {
  const Loop({super.key, required this.builder, this.period = const Duration(seconds: 4), this.child});
  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Duration period;
  final Widget? child;

  @override
  State<Loop> createState() => _LoopState();
}

class _LoopState extends State<Loop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (ctx, child) => widget.builder(ctx, Curves.easeInOut.transform(_c.value), child),
  );
}

/// Thẻ nghiêng 3D, trôi lên xuống nhẹ.
class Float3D extends StatelessWidget {
  const Float3D({
    super.key,
    required this.child,
    this.tiltX = 0.13,
    this.tiltY = 0,
    this.lift = 6,
    this.period = const Duration(milliseconds: 2600),
  });
  final Widget child;
  final double tiltX;
  final double tiltY;
  final double lift;
  final Duration period;

  @override
  Widget build(BuildContext context) => Loop(
    period: period,
    child: child,
    builder: (_, t, c) => Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateX(tiltX + 0.03 * t)
        ..rotateY(tiltY * (1 - 2 * t))
        ..translateByDouble(0.0, -lift * t, 0.0, 1.0),
      child: c,
    ),
  );
}

/// Chấm tròn nhấp nháy (đang diễn ra).
class PulseDot extends StatelessWidget {
  const PulseDot({super.key, this.color = Colors.white, this.size = 8});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Loop(
    period: const Duration(milliseconds: 900),
    builder: (_, t, _) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5 * (1 - t)),
            spreadRadius: 7 * t,
          ),
        ],
      ),
    ),
  );
}

/// Vòng tiến độ có hoạt ảnh chạy tới giá trị.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 70, this.stroke = 7, this.color = Colors.white, this.track, this.child});
  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color? track;
  final Widget? child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.clamp(0, 1)),
    duration: const Duration(milliseconds: 1400),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(v, stroke, color, track ?? color.withValues(alpha: 0.25)),
        child: Center(child: child),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.stroke, this.color, this.track);
  final double v;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    if (v > 0) canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, p..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.color != color;
}

/// Thanh tiến độ có vệt sáng chạy qua.
class ShineBar extends StatelessWidget {
  const ShineBar({super.key, required this.value, this.color = kViolet, this.height = 12});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: wellDecoration(radius: height / 2, color: kTrack),
    alignment: Alignment.centerLeft,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => FractionallySizedBox(
        widthFactor: v,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Loop(
            period: const Duration(milliseconds: 1600),
            builder: (_, t, _) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, lighten(color, 0.35), color],
                  stops: [(t - 0.25).clamp(0, 1), t, (t + 0.25).clamp(0, 1)],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Công tắc gạt dạng khối.
class ClaySwitch extends StatelessWidget {
  const ClaySwitch({super.key, required this.value, required this.onChanged, this.label, this.color = kPrimary});
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    label: label,
    child: GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: onChanged == null ? kLine : (value ? color : const Color(0xFFE4D3E2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 3, offset: const Offset(0, 1.5), blurStyle: BlurStyle.inner),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Color(0xFFF3EAF2)],
              ),
              boxShadow: [BoxShadow(color: kShadowTint.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 3))],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Ô tick dạng khối: chưa xong thì nổi, xong thì lún và chuyển xanh.
class ClayCheck extends StatelessWidget {
  const ClayCheck({super.key, required this.value, required this.onChanged, this.label, this.size = 44});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: value,
    label: label,
    child: Pressable(
      onTap: () => onChanged(!value),
      scale: 0.88,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        transform: Matrix4.translationValues(0, value ? 2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.32),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: value ? [darken(kGreen, 0.12), kGreen] : [Colors.white, kWell],
          ),
          border: value ? null : Border.all(color: const Color(0xFFE6CFE2), width: 1.5),
          boxShadow: value ? null : clayShadow(kShadowTint, depth: 0.35),
        ),
        child: AnimatedScale(
          scale: value ? 1 : 0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.elasticOut,
          child: const Icon(Ic.check, color: Colors.white, size: 22),
        ),
      ),
    ),
  );
}

/// Bộ chọn dạng viên thuốc, có "con trượt" nổi chạy qua lại.
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.height = 40,
  });
  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final idx = values.indexOf(selected);
    return Container(
      height: height + 8,
      padding: const EdgeInsets.all(4),
      decoration: wellDecoration(radius: 16, color: kTrack),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / values.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                left: w * idx,
                top: 0,
                bottom: 0,
                width: w,
                child: const Clay(radius: 12, depth: 0.45, child: SizedBox.expand()),
              ),
              Row(
                children: [
                  for (var i = 0; i < values.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == idx,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(values[i]),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: ts(13, w: FontWeight.w700, c: i == idx ? kPrimary : kMuted),
                              child: Text(labels[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Nền vân sọc chéo cho khung giờ cố định.
Decoration stripes(Color a, Color b, {double radius = 16}) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius),
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: const Alignment(-0.82, -0.82),
    colors: [a, a, b, b],
    stops: const [0, 0.5, 0.5, 1],
    tileMode: TileMode.repeated,
  ),
);

class ScreenTitle extends StatelessWidget {
  const ScreenTitle({super.key, required this.title, this.caption, this.trailing});
  final String title;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (caption != null) Text(caption!, style: ts(13, c: kMuted)),
            Text(title, style: ts(28, w: FontWeight.w800, h: 1.15, ls: -0.5)),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: ts(17, w: FontWeight.w800)),
        ),
        ?trailing,
      ],
    ),
  );
}
