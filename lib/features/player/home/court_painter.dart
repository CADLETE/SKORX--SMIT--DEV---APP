import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A pickleball court seen from behind the baseline, drawn in glowing neon
/// lines. Pure paint, so it stays crisp at every size and costs no assets.
class NeonCourtPainter extends CustomPainter {
  const NeonCourtPainter({required this.lineColor, required this.kitchenColor});

  final Color lineColor;
  final Color kitchenColor;

  @override
  void paint(Canvas canvas, Size size) {
    // The court occupies the lower part of the card, widening towards the viewer.
    final top = size.height * 0.34;
    final bottom = size.height * 1.02;
    final topHalf = size.width * 0.24;
    final bottomHalf = size.width * 0.72;
    final centerX = size.width * 0.62;

    // Depth t in [0, 1] from the far baseline to the near one, eased so far
    // lines bunch up like a real perspective view.
    double yAt(double t) => top + (bottom - top) * (t * t * 0.55 + t * 0.45);
    double halfAt(double t) => topHalf + (bottomHalf - topHalf) * ((yAt(t) - top) / (bottom - top));
    Offset left(double t) => Offset(centerX - halfAt(t), yAt(t));
    Offset right(double t) => Offset(centerX + halfAt(t), yAt(t));

    // Pickleball proportions along the length: kitchen is 7 ft of each 22 ft half.
    const farKitchen = 0.5 - 7 / 44;
    const net = 0.5;
    const nearKitchen = 0.5 + 7 / 44;

    // Kitchen (non-volley zone) tint.
    final kitchen = Path()
      ..moveTo(left(farKitchen).dx, left(farKitchen).dy)
      ..lineTo(right(farKitchen).dx, right(farKitchen).dy)
      ..lineTo(right(nearKitchen).dx, right(nearKitchen).dy)
      ..lineTo(left(nearKitchen).dx, left(nearKitchen).dy)
      ..close();
    canvas.drawPath(kitchen, Paint()..color = kitchenColor);

    final lines = Path()
      ..moveTo(left(0).dx, left(0).dy)
      ..lineTo(right(0).dx, right(0).dy)
      ..lineTo(right(1).dx, right(1).dy)
      ..lineTo(left(1).dx, left(1).dy)
      ..close();
    for (final t in [farKitchen, nearKitchen]) {
      lines
        ..moveTo(left(t).dx, left(t).dy)
        ..lineTo(right(t).dx, right(t).dy);
    }
    // Centre service lines run from each baseline to its kitchen line.
    Offset mid(double t) => Offset(centerX, yAt(t));
    lines
      ..moveTo(mid(0).dx, mid(0).dy)
      ..lineTo(mid(farKitchen).dx, mid(farKitchen).dy)
      ..moveTo(mid(nearKitchen).dx, mid(nearKitchen).dy)
      ..lineTo(mid(1).dx, mid(1).dy);

    // Glow first, then the crisp line on top.
    canvas.drawPath(
      lines,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = lineColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      lines,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = lineColor,
    );

    // The net: brighter and a little thicker, with posts.
    final netPaint = Paint()
      ..strokeWidth = 2.6
      ..shader = ui.Gradient.linear(left(net), right(net), [
        Colors.white.withValues(alpha: 0.15),
        Colors.white.withValues(alpha: 0.9),
        Colors.white.withValues(alpha: 0.15),
      ], [0, 0.5, 1]);
    final netLeft = left(net).translate(-10, 0);
    final netRight = right(net).translate(10, 0);
    canvas.drawLine(netLeft.translate(0, -6), netRight.translate(0, -6), netPaint);
    final post = Paint()
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.6);
    canvas.drawLine(netLeft, netLeft.translate(0, -10), post);
    canvas.drawLine(netRight, netRight.translate(0, -10), post);
  }

  @override
  bool shouldRepaint(NeonCourtPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor || oldDelegate.kitchenColor != kitchenColor;
}

/// A glowing pickleball: lime sphere with holes and a soft halo.
class GlowingBall extends StatelessWidget {
  const GlowingBall({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [Color.lerp(color, Colors.white, 0.55)!, color, Color.lerp(color, Colors.black, 0.35)!],
          stops: const [0, 0.55, 1],
        ),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: size * 0.9, spreadRadius: size * 0.05),
        ],
      ),
      child: CustomPaint(painter: _BallHoles(Color.lerp(color, Colors.black, 0.45)!)),
    );
  }
}

class _BallHoles extends CustomPainter {
  const _BallHoles(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.75);
    final r = size.width * 0.07;
    for (final (x, y) in const [(0.5, 0.2), (0.28, 0.38), (0.72, 0.38), (0.5, 0.52), (0.3, 0.7), (0.7, 0.7), (0.5, 0.86)]) {
      canvas.drawCircle(Offset(size.width * x, size.height * y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_BallHoles oldDelegate) => oldDelegate.color != color;
}
