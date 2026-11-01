import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'theme.dart';

/// Slowly drifting dusk-sky background.
class Aurora extends StatefulWidget {
  const Aurora({super.key});
  @override
  State<Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<Aurora> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 28))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _blob(Color color, double size, double alpha, Alignment a) => Align(
        alignment: a,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value * 2 * pi;
          return Container(
            color: C.night,
            child: Stack(fit: StackFit.expand, children: [
              _blob(C.dusk, 640, 0.95, Alignment(sin(t) * .7, cos(t) * .5 - .6)),
              _blob(C.coral, 460, 0.28, Alignment(cos(t + 1) * .9, sin(t) * .5 + .85)),
              _blob(C.lagoon, 360, 0.16, Alignment(sin(t + 2) * .8, cos(t + 2) * .8)),
            ]),
          );
        },
      ),
    );
  }
}

/// Frosted panel.
class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double opacity;
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.opacity = 0.07,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Boarding-pass card: notches on both sides, dashed tear line under the header.
class TicketCard extends StatelessWidget {
  final Widget badge;
  final String title;
  final Widget body;
  static const headH = 68.0;
  const TicketCard({super.key, required this.badge, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _TicketClipper(headH),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withValues(alpha: 0.13), Colors.white.withValues(alpha: 0.05)],
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: headH,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(children: [
                  badge,
                  const SizedBox(width: 14),
                  Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: display(19))),
                ]),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: SizedBox(height: 1, child: CustomPaint(painter: _DashPainter())),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 16), child: body),
          ]),
        ),
      ),
    );
  }
}

class _TicketClipper extends CustomClipper<Path> {
  final double notchY;
  const _TicketClipper(this.notchY);

  @override
  Path getClip(Size s) {
    final card = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(22)));
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, notchY + .5), radius: 11))
      ..addOval(Rect.fromCircle(center: Offset(s.width, notchY + .5), radius: 11));
    return Path.combine(PathOperation.difference, card, holes);
  }

  @override
  bool shouldReclip(_TicketClipper old) => old.notchY != notchY;
}

class _DashPainter extends CustomPainter {
  const _DashPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.4;
    for (double x = 0; x < size.width; x += 11) {
      canvas.drawLine(Offset(x, 0), Offset(x + 6, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class DayBadge extends StatelessWidget {
  final String number;
  const DayBadge(this.number, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(gradient: C.sunset, borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Day', style: body(10, w: FontWeight.w700, color: C.ink, h: 1)),
          Text(number, style: display(19, w: FontWeight.w700, color: C.ink)),
        ]),
      );
}

class IconBadge extends StatelessWidget {
  final IconData icon;
  const IconBadge(this.icon, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: C.lagoon.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.lagoon.withValues(alpha: 0.45)),
        ),
        child: Icon(icon, color: C.lagoon, size: 22),
      );
}

class TypingDots extends StatelessWidget {
  const TypingDots({super.key});
  @override
  Widget build(BuildContext context) {
    const colors = [C.coral, C.amber, C.lagoon];
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 3; i++)
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(.6, .6),
              end: const Offset(1.15, 1.15),
              delay: (i * 160).ms,
              duration: 480.ms,
              curve: Curves.easeInOut,
            ),
    ]);
  }
}
