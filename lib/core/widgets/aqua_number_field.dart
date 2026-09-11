import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AquaNumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String unit;
  final ValueChanged<double>? onChanged;
  final List<double> quickSteps; // e.g. [500, 1000]

  const AquaNumberField({
    super.key,
    required this.label,
    required this.controller,
    this.unit = 'grams',
    this.onChanged,
    this.quickSteps = const [500.0, 1000.0],
  });

  void _adjustValue(double delta) {
    HapticFeedback.lightImpact();
    final current = double.tryParse(controller.text) ?? 0.0;
    final updated = (current + delta).clamp(0.0, 999999.0);
    controller.text = updated % 1 == 0 ? updated.toInt().toString() : updated.toStringAsFixed(1);
    onChanged?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 5,
              child: TextFormField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      widthFactor: 1.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh.withOpacity(isDark ? 0.4 : 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          unit,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null) onChanged?.call(parsed);
                },
              ),
            ),
            const SizedBox(width: 8),
            for (final step in quickSteps) ...[
              SizedBox(
                height: 52,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                  ),
                  onPressed: () => _adjustValue(step),
                  child: Text(
                    step >= 1000 ? '+${(step / 1000).toInt()}kg' : '+${step.toInt()}g',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }
}

