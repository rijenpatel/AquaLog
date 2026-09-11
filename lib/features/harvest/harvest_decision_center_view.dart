import 'package:flutter/material.dart';
import '../../core/calculations/harvest_decision_engine.dart';
import '../../app/theme/color_schemes.dart';

class HarvestDecisionCenterView extends StatelessWidget {
  final HarvestDecisionReport report;
  final VoidCallback? onHarvestNowTap;

  const HarvestDecisionCenterView({
    super.key,
    required this.report,
    this.onHarvestNowTap,
  });

  Widget _buildReadinessBadge(BuildContext context, String label, String value, bool isOptimal) {
    final theme = Theme.of(context);
    final color = isOptimal ? AquaColors.statusOptimal : AquaColors.statusWarning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildScenarioCard(BuildContext context, HarvestScenario s) {
    final theme = Theme.of(context);
    final isRec = s.isRecommended;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRec ? theme.colorScheme.primaryContainer.withOpacity(0.35) : theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRec ? theme.colorScheme.primary : Colors.transparent,
            width: isRec ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isRec) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'BEST CHOICE',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              s.label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isRec ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${s.projectedAbwGrams.toStringAsFixed(1)}g',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              '${s.projectedCountPerKg.toStringAsFixed(0)} count',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const Divider(height: 16),
            Text('${s.projectedBiomassKg.toStringAsFixed(0)} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Text('Biomass', style: TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 6),
            Text('₹${s.projectedMarketPricePerKg.toStringAsFixed(0)}/kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const Text('Grade Price', style: TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              '₹${(s.projectedNetProfit / 1000).toStringAsFixed(1)}k',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: s.projectedNetProfit >= 0 ? AquaColors.statusOptimal : AquaColors.statusCritical,
              ),
            ),
            Text('Net (${s.projectedMarginPct.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title & DOC
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  'Harvest Economic Decision Center',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  'DOC ${report.currentDoc}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Side-by-side 3 Scenarios
            Row(
              children: [
                _buildScenarioCard(context, report.scenarios[0]),
                const SizedBox(width: 8),
                _buildScenarioCard(context, report.scenarios[1]),
                const SizedBox(width: 8),
                _buildScenarioCard(context, report.scenarios[2]),
              ],
            ),
            const SizedBox(height: 14),

            // Decision Summary Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        'Recommendation: ${report.scenarios[report.bestScenarioIndex].label.toUpperCase()}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.decisionExplanation,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Readiness Grid
            const Text(
              'HARVEST READINESS INDICATORS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildReadinessBadge(
                    context,
                    'Biological',
                    report.biologicalReadiness,
                    report.biologicalReadiness == 'Optimal',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildReadinessBadge(
                    context,
                    'Market Price',
                    report.marketReadiness,
                    true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildReadinessBadge(
                    context,
                    'Feed Buffer',
                    report.inventoryReadiness,
                    !report.inventoryReadiness.contains('Low'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildReadinessBadge(
                    context,
                    'Operational',
                    report.operationalReadiness,
                    true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
