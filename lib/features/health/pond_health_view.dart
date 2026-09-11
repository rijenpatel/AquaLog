import 'package:flutter/material.dart';
import '../../core/calculations/health_score_calculator.dart';
import '../../app/theme/color_schemes.dart';

class PondHealthView extends StatelessWidget {
  final ComprehensivePondHealth health;
  final String pondName;
  final int doc;

  const PondHealthView({
    super.key,
    required this.health,
    required this.pondName,
    required this.doc,
  });

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.green:
        return AquaColors.statusOptimal;
      case RiskLevel.yellow:
        return AquaColors.statusWarning;
      case RiskLevel.orange:
        return Colors.orange;
      case RiskLevel.red:
        return AquaColors.statusCritical;
    }
  }

  Widget _buildPillarRow({
    required BuildContext context,
    required String title,
    required int score,
    required int maxScore,
    required IconData icon,
  }) {
    final pct = (score / maxScore).clamp(0.0, 1.0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Icon(icon, size: 14, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '$score / $maxScore',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 0.75
                    ? AquaColors.statusOptimal
                    : (pct >= 0.5 ? AquaColors.statusWarning : AquaColors.statusCritical),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final riskColor = _getRiskColor(health.riskLevel);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: riskColor.withOpacity(isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: riskColor.withOpacity(isDark ? 0.08 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row: Pond Name, DOC, Status Pill
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pondName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'DOC $doc',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: riskColor.withOpacity(0.35), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        health.riskLevel.label.toUpperCase(),
                        style: TextStyle(
                          color: riskColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Score Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(isDark ? 0.12 : 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: riskColor.withOpacity(0.2), width: 0.8),
              ),
              child: Row(
                children: [
                  Text(
                    '${health.totalScore}',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: riskColor,
                      letterSpacing: -1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ' / 100',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Pond Health Index',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        health.riskLevel.label,
                        style: TextStyle(
                          color: riskColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Component Breakdown
            Text(
              'COMPONENT BREAKDOWN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            _buildPillarRow(
              context: context,
              title: 'Water Quality',
              score: health.waterQualityScore,
              maxScore: 25,
              icon: Icons.water_drop_outlined,
            ),
            _buildPillarRow(
              context: context,
              title: 'Growth Performance (ADG)',
              score: health.growthScore,
              maxScore: 20,
              icon: Icons.trending_up_rounded,
            ),
            _buildPillarRow(
              context: context,
              title: 'Survival Rate',
              score: health.survivalScore,
              maxScore: 20,
              icon: Icons.shield_outlined,
            ),
            _buildPillarRow(
              context: context,
              title: 'Feed Performance & Intake',
              score: health.feedPerformanceScore,
              maxScore: 15,
              icon: Icons.set_meal_outlined,
            ),
            _buildPillarRow(
              context: context,
              title: 'Sampling Recency',
              score: health.samplingRecencyScore,
              maxScore: 10,
              icon: Icons.calendar_today_outlined,
            ),
            _buildPillarRow(
              context: context,
              title: 'Mortality Risk Control',
              score: health.mortalityScore,
              maxScore: 10,
              icon: Icons.heart_broken_outlined,
            ),
            const SizedBox(height: 14),

            // Why is the score this way?
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh.withOpacity(isDark ? 0.35 : 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.help_outline_rounded, size: 14, color: Colors.amber),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Why is the score this way?',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: -0.1,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...health.topConcerns.map((c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                c,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (health.recommendations.isNotEmpty) ...[
                    const Divider(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.lightbulb_outline_rounded, size: 14, color: Colors.teal),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Recommended Actions',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: -0.1,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...health.recommendations.map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.arrow_right_rounded, size: 18, color: Colors.teal),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  r,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                  if (health.correlations.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: health.correlations
                          .map((corr) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.link_rounded, size: 12, color: theme.colorScheme.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      corr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
