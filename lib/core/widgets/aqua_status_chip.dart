import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/color_schemes.dart';

enum AquaStatusLevel {
  optimal,
  warning,
  critical,
  info,
}

class AquaStatusChip extends StatelessWidget {
  final String label;
  final AquaStatusLevel level;
  final IconData? icon;
  final VoidCallback? onTap;

  const AquaStatusChip({
    super.key,
    required this.label,
    required this.level,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    IconData defaultIcon;

    switch (level) {
      case AquaStatusLevel.optimal:
        fg = AquaColors.statusOptimal;
        bg = isDark ? fg.withOpacity(0.18) : fg.withOpacity(0.12);
        defaultIcon = Icons.check_circle_rounded;
        break;
      case AquaStatusLevel.warning:
        fg = AquaColors.statusWarning;
        bg = isDark ? fg.withOpacity(0.18) : fg.withOpacity(0.12);
        defaultIcon = Icons.warning_amber_rounded;
        break;
      case AquaStatusLevel.critical:
        fg = AquaColors.statusCritical;
        bg = isDark ? fg.withOpacity(0.18) : fg.withOpacity(0.12);
        defaultIcon = Icons.error_rounded;
        break;
      case AquaStatusLevel.info:
        fg = isDark ? AquaColors.primaryDark : AquaColors.primaryContainerLight;
        bg = isDark ? fg.withOpacity(0.20) : fg.withOpacity(0.12);
        defaultIcon = Icons.info_rounded;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: fg.withOpacity(0.35), width: 0.9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon ?? defaultIcon, size: 13, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
