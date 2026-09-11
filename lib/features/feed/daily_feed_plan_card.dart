import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/calculations/feed_plan_calculator.dart';
import '../../app/theme/color_schemes.dart';

class DailyFeedPlanCard extends ConsumerStatefulWidget {
  final String pondId;
  final String batchId;
  final double biomassKg;
  final double abwGrams;
  final int? trayLeftoverPct;
  final double? latestDO;
  final double? latestAmmonia;
  final bool isRaining;
  final bool extremeHeat;
  final bool mortalitySpike;

  const DailyFeedPlanCard({
    super.key,
    required this.pondId,
    required this.batchId,
    required this.biomassKg,
    required this.abwGrams,
    this.trayLeftoverPct,
    this.latestDO,
    this.latestAmmonia,
    this.isRaining = false,
    this.extremeHeat = false,
    this.mortalitySpike = false,
  });

  @override
  ConsumerState<DailyFeedPlanCard> createState() => _DailyFeedPlanCardState();
}

class _DailyFeedPlanCardState extends ConsumerState<DailyFeedPlanCard> {
  bool _isSaving = false;

  void _showModifyDialog(DailyFeedPlan plan) {
    final qtyController = TextEditingController(text: plan.actualPlannedKg.toStringAsFixed(1));
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modify Feed Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'System Recommended: ${plan.recommendedFeedKg.toStringAsFixed(1)} kg',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Farmer Planned Feed (kg)',
                suffixText: 'kg',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Modification',
                hintText: 'e.g. Higher activity observed on pond bottom...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final qty = double.tryParse(qtyController.text.trim());
              if (qty == null || qty <= 0) return;
              final db = ref.read(databaseProvider);
              await db.updateDailyFeedPlanStatus(
                plan.id,
                'modified',
                actualPlannedKg: qty,
                reason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : 'Farmer override',
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Modification'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = ref.watch(databaseProvider);
    final today = DateTime.now();

    return FutureBuilder<DailyFeedPlan?>(
      future: db.getDailyFeedPlanForDate(widget.pondId, today),
      builder: (context, snapshot) {
        final existingPlan = snapshot.data;

        final calculated = FeedPlanCalculator.calculateDailyPlan(
          biomassKg: widget.biomassKg,
          abwGrams: widget.abwGrams,
          trayLeftoverPct: widget.trayLeftoverPct,
          latestDO: widget.latestDO,
          latestAmmonia: widget.latestAmmonia,
          isRaining: widget.isRaining,
          extremeHeat: widget.extremeHeat,
          mortalitySpike: widget.mortalitySpike,
        );

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
                // Title Row
                Row(
                  children: [
                    const Icon(Icons.psychology_outlined, color: Colors.teal),
                    const SizedBox(width: 8),
                    Text(
                      'Daily Feed Intelligence Plan',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: existingPlan != null && existingPlan.status == 'accepted'
                            ? AquaColors.statusOptimal.withOpacity(0.15)
                            : (existingPlan != null && existingPlan.status == 'modified'
                                ? Colors.orange.withOpacity(0.15)
                                : Colors.blue.withOpacity(0.15)),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        (existingPlan?.status ?? 'Suggested').toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: existingPlan != null && existingPlan.status == 'accepted'
                              ? AquaColors.statusOptimal
                              : (existingPlan != null && existingPlan.status == 'modified'
                                  ? Colors.orange
                                  : Colors.blue),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Numbers Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Base Ration', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                        Text(
                          '${calculated.baseFeedKg.toStringAsFixed(1)} kg',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${calculated.feedingRatePct}% of Biomass',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Recommended Ration', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                        Text(
                          '${calculated.recommendedFeedKg.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (existingPlan != null && existingPlan.status == 'modified')
                          Text(
                            'Planned: ${existingPlan.actualPlannedKg.toStringAsFixed(1)} kg',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Adjustment Reasons
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: calculated.adjustmentReasons
                        .map((r) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1.5),
                              child: Text('• $r', style: const TextStyle(fontSize: 11)),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // Actions: Accept, Modify, Skip
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: existingPlan != null
                            ? () => _showModifyDialog(existingPlan)
                            : null,
                        child: const Text('Modify'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                setState(() => _isSaving = true);
                                try {
                                  final planId = existingPlan?.id ?? 'fp_${widget.pondId}_${today.millisecondsSinceEpoch}';
                                  await db.saveDailyFeedPlan(DailyFeedPlansCompanion.insert(
                                    id: planId,
                                    pondId: widget.pondId,
                                    batchId: widget.batchId,
                                    date: today,
                                    baseFeedKg: calculated.baseFeedKg,
                                    trayAdjustmentKg: Value(calculated.trayAdjustmentKg),
                                    weatherAdjustmentKg: Value(calculated.weatherAdjustmentKg),
                                    wqAdjustmentKg: Value(calculated.wqAdjustmentKg),
                                    mortalityAdjustmentKg: Value(calculated.mortalityAdjustmentKg),
                                    recommendedFeedKg: calculated.recommendedFeedKg,
                                    actualPlannedKg: calculated.recommendedFeedKg,
                                    status: const Value('accepted'),
                                  ));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Feed plan accepted!')),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _isSaving = false);
                                }
                              },
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: Text(existingPlan?.status == 'accepted' ? 'Accepted' : 'Accept Plan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
