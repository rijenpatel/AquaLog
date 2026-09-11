import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import 'peacock_feather_badge.dart';

/// A regal, ultra-luxurious commemorative tribute plaque featuring
/// hand-crafted gold embroidery borders, an authentic peacock feather (Mor Pankh)
/// jewel medallion, and deep engraved golden lettering.
class GoldEmbroideryTributeCard extends StatelessWidget {
  const GoldEmbroideryTributeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.22),
            blurRadius: 28,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.65),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CustomPaint(
          painter: _GoldEmbroideryCardPainter(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
            decoration: BoxDecoration(
              // Deep obsidian/midnight backdrop with golden velvet ambient sheen
              gradient: RadialGradient(
                center: const Alignment(0, -0.3),
                radius: 1.1,
                colors: [
                  const Color(0xFF261D0C), // Warm golden velvet center
                  const Color(0xFF161208), // Rich obsidian gold
                  const Color(0xFF0D0B06), // Midnight charcoal
                  const Color(0xFF070603), // Deep velvet black rim
                ],
                stops: const [0.0, 0.45, 0.75, 1.0],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Medallion: Peacock Feather Logo with double gold bezel
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer golden halo burst
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFFEFA7).withOpacity(0.35),
                            const Color(0xFFD4AF37).withOpacity(0.15),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                    const PeacockFeatherBadge(size: 64),
                  ],
                ),
                const SizedBox(height: 14),

                // Top Ribbon Badge: Commemorative Tribute
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGoldEmbroideryKnot(isLeft: true),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'COMMEMORATIVE TRIBUTE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 3.0,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFBE8A6),
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 1.5),
                              blurRadius: 3,
                              color: Colors.black.withOpacity(0.9),
                            ),
                            const Shadow(
                              offset: Offset(0, -0.5),
                              blurRadius: 1,
                              color: Color(0xFFFFFAA0),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildGoldEmbroideryKnot(isLeft: false),
                  ],
                ),
                const SizedBox(height: 10),

                // Decorative Golden Flourish Divider
                _buildGoldFlourishDivider(),
                const SizedBox(height: 12),

                // Engraved Golden Date: 07-09-2026
                ShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      colors: [
                        Color(0xFFFFFAF0), // Bright gold shine
                        Color(0xFFFFDF73), // Luminous rich gold
                        Color(0xFFE5B842), // Solid metallic gold
                        Color(0xFF9E7216), // Deep antique gold
                        Color(0xFFF9E89D), // Secondary specular glint
                        Color(0xFFD4AF37), // Classic gold
                        Color(0xFF6B4E07), // Shadow gold base
                      ],
                      stops: [0.0, 0.20, 0.38, 0.58, 0.72, 0.86, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(bounds);
                  },
                  child: Text(
                    AppConfig.creationDate,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4.5,
                      fontFamily: 'serif',
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 4,
                          color: Color(0xFF000000),
                        ),
                        Shadow(
                          offset: Offset(0, -1),
                          blurRadius: 1,
                          color: Color(0xFFFFF7C2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Bottom Subtitle & Gratitude Inscription
                Text(
                  'In Everlasting Memory & Deep Gratitude',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.5,
                    color: const Color(0xFFE8D09B),
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 1.5),
                        blurRadius: 3,
                        color: Colors.black.withOpacity(0.95),
                      ),
                      const Shadow(
                        offset: Offset(0, -0.5),
                        blurRadius: 1,
                        color: Color(0xFFFFF2BD),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Lower Embroidered Filigree Accent
                _buildLowerGoldAccents(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoldEmbroideryKnot({required bool isLeft}) {
    return Transform.scale(
      scaleX: isLeft ? 1 : -1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 1.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x00D4AF37), Color(0xFFD4AF37)],
              ),
            ),
          ),
          const SizedBox(width: 3),
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE89E),
                border: Border.all(color: const Color(0xFF8C6417), width: 0.8),
                boxShadow: const [
                  BoxShadow(color: Color(0xFFD4AF37), blurRadius: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoldFlourishDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x00D4AF37),
                  Color(0x88D4AF37),
                  Color(0xFFFFEAA7),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEAA7),
                    boxShadow: [
                      BoxShadow(color: Color(0xFFD4AF37), blurRadius: 4),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFFCE6), Color(0xFFD4AF37), Color(0xFF8C6417)],
                  ),
                  border: Border.all(color: const Color(0xFFFFFAA0), width: 1),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFFFFDF73), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEAA7),
                    boxShadow: [
                      BoxShadow(color: Color(0xFFD4AF37), blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            height: 1.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFEAA7),
                  Color(0x88D4AF37),
                  Color(0x00D4AF37),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLowerGoldAccents() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x00D4AF37), Color(0xFFC6982E)],
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.favorite_rounded, size: 12, color: Color(0xFFE5B842)),
        const SizedBox(width: 6),
        Container(
          width: 36,
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFC6982E), Color(0x00D4AF37)],
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter that paints double gold-embroidered borders, corner arabesques,
/// and fine metallic stitch detailing.
class _GoldEmbroideryCardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Outer Embossed Gold Border
    final outerRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1.5, 1.5, w - 3, h - 3),
      const Radius.circular(23),
    );

    final outerBorderPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFFF9D2),
          Color(0xFFD4AF37),
          Color(0xFF7A5408),
          Color(0xFFFBECA6),
          Color(0xFFA87E22),
          Color(0xFF6B4905),
          Color(0xFFFFFAA8),
        ],
        stops: [0.0, 0.18, 0.38, 0.55, 0.72, 0.88, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(outerRRect.outerRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(outerRRect, outerBorderPaint);

    // 2. Inner Embroidered Filigree Border
    const inset = 7.0;
    final innerRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, w - (inset * 2), h - (inset * 2)),
      const Radius.circular(18),
    );

    final innerBorderPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF8A6212),
          Color(0xFFFDE895),
          Color(0xFFD4AF37),
          Color(0xFF6A4705),
          Color(0xFFFFF4B8),
        ],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(innerRRect.outerRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(innerRRect, innerBorderPaint);

    // 3. Four Embroidered Corner Flourishes (Arabesque Lace Brackets)
    _drawCornerEmbroidery(canvas, 14, 14, 1, 1); // Top-Left
    _drawCornerEmbroidery(canvas, w - 14, 14, -1, 1); // Top-Right
    _drawCornerEmbroidery(canvas, 14, h - 14, 1, -1); // Bottom-Left
    _drawCornerEmbroidery(canvas, w - 14, h - 14, -1, -1); // Bottom-Right

    // 4. Subtle Embroidered Gold Stitch Marks along Top & Bottom Edges
    final stitchPaint = Paint()
      ..color = const Color(0xFFFCE182).withOpacity(0.55)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final stitchCount = (w / 14).floor();
    for (int i = 2; i < stitchCount - 2; i++) {
      final x = (i * 14.0);
      // Top stitch
      canvas.drawLine(Offset(x, inset + 2), Offset(x + 5, inset + 2), stitchPaint);
      // Bottom stitch
      canvas.drawLine(Offset(x, h - inset - 2), Offset(x + 5, h - inset - 2), stitchPaint);
    }
  }

  void _drawCornerEmbroidery(Canvas canvas, double cx, double cy, double sx, double sy) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(sx, sy);

    final pGold = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFF7C4), Color(0xFFD4AF37), Color(0xFF875E10)],
      ).createShader(const Rect.fromLTWH(0, 0, 24, 24))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    // Corner bracket arc
    final cornerPath = Path();
    cornerPath.moveTo(0, 22);
    cornerPath.quadraticBezierTo(2, 6, 6, 2);
    cornerPath.lineTo(22, 0);
    canvas.drawPath(cornerPath, pGold);

    // Inner petal / leaf flourish
    final petalPath = Path();
    petalPath.moveTo(4, 16);
    petalPath.cubicTo(6, 10, 10, 6, 16, 4);
    petalPath.cubicTo(11, 7, 7, 11, 4, 16);
    canvas.drawPath(petalPath, pGold);

    // Corner gold stud dot
    final dotPaint = Paint()
      ..color = const Color(0xFFFFEDB0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(3.5, 3.5), 1.6, dotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
