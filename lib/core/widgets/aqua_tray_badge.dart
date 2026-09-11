import 'package:flutter/material.dart';
import '../calculations/check_tray_engine.dart';
import '../../app/theme/color_schemes.dart';

class AquaTrayBadge extends StatelessWidget {
  final int leftoverPct;
  final bool compact;

  const AquaTrayBadge({
    super.key,
    required this.leftoverPct,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final rec = CheckTrayEngine.evaluate(leftoverPct);

    Color bg;
    Color fg;
    IconData icon;

    switch (rec.status) {
      case CheckTrayStatus.clean:
        bg = AquaColors.trayClean.withOpacity(0.15);
        fg = AquaColors.trayClean;
        icon = Icons.check_circle_rounded;
        break;
      case CheckTrayStatus.normal:
        bg = AquaColors.trayNormal.withOpacity(0.15);
        fg = AquaColors.trayNormal;
        icon = Icons.done_all_rounded;
        break;
      case CheckTrayStatus.moderate:
        bg = AquaColors.trayModerate.withOpacity(0.15);
        fg = AquaColors.trayModerate;
        icon = Icons.warning_amber_rounded;
        break;
      case CheckTrayStatus.surplus:
        bg = AquaColors.traySurplus.withOpacity(0.15);
        fg = AquaColors.traySurplus;
        icon = Icons.error_outline_rounded;
        break;
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: fg.withOpacity(0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: fg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              rec.status.label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 6),
          Text(
            '${rec.status.label} · ${rec.actionSummary}',
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
