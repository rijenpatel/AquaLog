import 'dart:math' as math;
import 'package:flutter/material.dart';

/// An exquisite, hand-crafted vector peacock feather (Mor Pankh) medallion
/// designed with embroidered gold accents, emerald, sapphire, and iridescent jewel tones.
class PeacockFeatherBadge extends StatelessWidget {
  final double size;
  final bool showOuterGlow;

  const PeacockFeatherBadge({
    super.key,
    this.size = 56,
    this.showOuterGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: showOuterGlow
            ? [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: const Color(0xFF0077BE).withOpacity(0.25),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _PeacockFeatherPainter(),
      ),
    );
  }
}

class _PeacockFeatherPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = math.min(w, h) / 2;

    // 1. Outer Embroidered Gold Bezel & Beaded Rim
    final outerRingPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFFF6BD),
          Color(0xFFD4AF37),
          Color(0xFF8C6417),
          Color(0xFFF9E89D),
          Color(0xFFA67C1E),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045;
    canvas.drawCircle(center, radius - w * 0.03, outerRingPaint);

    // Subtle dark embroidery background disc
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF162018), // Deep emerald-night
          const Color(0xFF0D1217), // Deep sapphire-midnight
          const Color(0xFF080603), // Velvet dark obsidian
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - w * 0.05, bgPaint);

    // Embroidered micro-bead dots along the inner gold bezel
    final beadPaint = Paint()
      ..color = const Color(0xFFFFE89E).withOpacity(0.85)
      ..style = PaintingStyle.fill;
    final beadRadius = radius - w * 0.07;
    const numBeads = 24;
    for (int i = 0; i < numBeads; i++) {
      final angle = (i * 2 * math.pi) / numBeads;
      final bx = center.dx + beadRadius * math.cos(angle);
      final by = center.dy + beadRadius * math.sin(angle);
      canvas.drawCircle(Offset(bx, by), w * 0.015, beadPaint);
    }

    // 2. Peacock Feather Radiating Barbs (Hairs)
    final barbGold = Paint()
      ..color = const Color(0xFFE2B755).withOpacity(0.7)
      ..strokeWidth = w * 0.016
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final barbGreen = Paint()
      ..color = const Color(0xFF00C897).withOpacity(0.6)
      ..strokeWidth = w * 0.015
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final barbBlue = Paint()
      ..color = const Color(0xFF00A8FF).withOpacity(0.5)
      ..strokeWidth = w * 0.014
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Curved feather stem/rachis path
    final stemStart = Offset(w * 0.38, h * 0.88);
    final stemControl = Offset(w * 0.44, h * 0.55);
    final eyeCenter = Offset(w * 0.52, h * 0.38);

    // Draw realistic angled barbs fanning around the eye
    const fanPoints = 16;
    for (int i = 0; i < fanPoints; i++) {
      final t = i / (fanPoints - 1);
      final angle = -math.pi * 0.85 + (t * math.pi * 1.7);
      final length = w * (0.28 + 0.08 * math.sin(t * math.pi));

      final pStart = Offset(
        eyeCenter.dx + (w * 0.08) * math.cos(angle),
        eyeCenter.dy + (h * 0.09) * math.sin(angle),
      );
      final pEnd = Offset(
        eyeCenter.dx + length * math.cos(angle),
        eyeCenter.dy + length * math.sin(angle),
      );

      final paint = i % 3 == 0 ? barbGold : (i % 3 == 1 ? barbGreen : barbBlue);
      canvas.drawLine(pStart, pEnd, paint);
    }

    // Lower barbs along the lower stem
    for (int j = 1; j <= 6; j++) {
      final yProgress = 0.55 + (j * 0.05);
      final stemPt = Offset(w * 0.42 + (j * 0.005 * w), h * yProgress);
      // Left barb
      canvas.drawLine(stemPt, Offset(stemPt.dx - w * 0.16, stemPt.dy - h * 0.07), barbGreen);
      // Right barb
      canvas.drawLine(stemPt, Offset(stemPt.dx + w * 0.18, stemPt.dy - h * 0.06), barbGold);
    }

    // 3. Golden Central Rachis (Stem)
    final stemPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF5E430B),
          Color(0xFFE5C058),
          Color(0xFFFFF7C4),
          Color(0xFFB58421),
        ],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromPoints(stemStart, eyeCenter))
      ..strokeWidth = w * 0.038
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final stemPath = Path()
      ..moveTo(stemStart.dx, stemStart.dy)
      ..quadraticBezierTo(stemControl.dx, stemControl.dy, eyeCenter.dx, eyeCenter.dy + h * 0.06);
    canvas.drawPath(stemPath, stemPaint);

    // 4. Peacock Feather Eye (Ocellus) - 4 Layered Jewel Gradients
    // Layer A: Golden Bronze Outer Shield
    final outerEyeRect = Rect.fromCenter(
      center: eyeCenter,
      width: w * 0.46,
      height: h * 0.48,
    );
    final outerEyePaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFFFFF0A5),
          Color(0xFFE5B842),
          Color(0xFFA47618),
          Color(0xFF543B06),
        ],
        stops: [0.0, 0.45, 0.85, 1.0],
      ).createShader(outerEyeRect);
    canvas.drawOval(outerEyeRect, outerEyePaint);

    // Layer B: Iridescent Emerald / Turquoise Ring
    final emeraldRect = Rect.fromCenter(
      center: Offset(eyeCenter.dx, eyeCenter.dy + h * 0.01),
      width: w * 0.36,
      height: h * 0.37,
    );
    final emeraldPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFF4EFEBA),
          Color(0xFF00A86B),
          Color(0xFF006D44),
          Color(0xFF003822),
        ],
        stops: [0.0, 0.4, 0.8, 1.0],
      ).createShader(emeraldRect);
    canvas.drawOval(emeraldRect, emeraldPaint);

    // Layer C: Royal Sapphire Blue Iris
    final sapphireRect = Rect.fromCenter(
      center: Offset(eyeCenter.dx, eyeCenter.dy + h * 0.02),
      width: w * 0.25,
      height: h * 0.25,
    );
    final sapphirePaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFF5AB6FF),
          Color(0xFF0066FF),
          Color(0xFF0A2E80),
          Color(0xFF041440),
        ],
        stops: [0.0, 0.35, 0.75, 1.0],
      ).createShader(sapphireRect);
    canvas.drawOval(sapphireRect, sapphirePaint);

    // Layer D: Velvet Indigo / Violet Heart Nucleus with indented top
    final nucleusCenter = Offset(eyeCenter.dx, eyeCenter.dy + h * 0.025);
    final nucleusPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFF2E0854),
          Color(0xFF120024),
          Color(0xFF06000D),
        ],
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: nucleusCenter, radius: w * 0.08));

    // Draw crescent/heart-like peacock eye center
    final heartPath = Path();
    final nw = w * 0.15;
    final nh = h * 0.13;
    heartPath.moveTo(nucleusCenter.dx, nucleusCenter.dy - nh * 0.3);
    heartPath.cubicTo(
      nucleusCenter.dx + nw * 0.5, nucleusCenter.dy - nh * 0.7,
      nucleusCenter.dx + nw * 0.6, nucleusCenter.dy + nh * 0.4,
      nucleusCenter.dx, nucleusCenter.dy + nh * 0.6,
    );
    heartPath.cubicTo(
      nucleusCenter.dx - nw * 0.6, nucleusCenter.dy + nh * 0.4,
      nucleusCenter.dx - nw * 0.5, nucleusCenter.dy - nh * 0.7,
      nucleusCenter.dx, nucleusCenter.dy - nh * 0.3,
    );
    canvas.drawPath(heartPath, nucleusPaint);

    // 5. Specular Jewel Shimmer Highlights
    final glintPaint = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(nucleusCenter.dx - w * 0.035, nucleusCenter.dy - h * 0.03), w * 0.02, glintPaint);

    final subGlintPaint = Paint()
      ..color = const Color(0xFFD6F5FF).withOpacity(0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(nucleusCenter.dx + w * 0.03, nucleusCenter.dy + h * 0.025), w * 0.012, subGlintPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
