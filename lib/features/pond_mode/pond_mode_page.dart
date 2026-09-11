import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../app/theme/color_schemes.dart';
import '../water_quality/water_quality_entry_page.dart';
import '../mortality/mortality_logging_dialog.dart';
import '../mortality/population_adjustment_dialog.dart';
import '../operations/pond_operation_dialog.dart';
import '../feed/feed_logging_page.dart';
import '../../core/calculations/doc_calculator.dart';

class PondModePage extends ConsumerStatefulWidget {
  final String initialPondId;

  const PondModePage({
    super.key,
    required this.initialPondId,
  });

  static Future<void> show(BuildContext context, {required String pondId}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PondModePage(initialPondId: pondId),
      ),
    );
  }

  @override
  ConsumerState<PondModePage> createState() => _PondModePageState();
}

class _PondModePageState extends ConsumerState<PondModePage> {
  late String _currentPondId;

  @override
  void initState() {
    super.initState();
    _currentPondId = widget.initialPondId;
  }

  Widget _buildFieldActionButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pondsAsync = ref.watch(allPondsStreamProvider);
    final db = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.outdoor_grill_outlined, size: 20),
            SizedBox(width: 8),
            Text('Pond Mode — Field Hub'),
          ],
        ),
        actions: [
          // Offline Status Pill
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AquaColors.statusOptimal.withOpacity(0.15),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.offline_pin_rounded, size: 14, color: AquaColors.statusOptimal),
                SizedBox(width: 4),
                Text(
                  'OFFLINE ACTIVE',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AquaColors.statusOptimal),
                ),
              ],
            ),
          ),
        ],
      ),
      body: pondsAsync.when(
        data: (ponds) {
          if (ponds.isEmpty) {
            return const Center(child: Text('No active ponds.'));
          }

          final currentIndex = ponds.indexWhere((p) => p.id == _currentPondId);
          final safeIndex = currentIndex >= 0 ? currentIndex : 0;
          final currentPond = ponds[safeIndex];

          return FutureBuilder<Batch?>(
            future: db.getActiveBatchForPond(currentPond.id),
            builder: (context, batchSnap) {
              final activeBatch = batchSnap.data;
              final doc = activeBatch != null
                  ? DocCalculator.calculate(stockingDate: activeBatch.stockingDate).doc
                  : 0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pond Selector Carousel Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                            onPressed: safeIndex > 0
                                ? () => setState(() => _currentPondId = ponds[safeIndex - 1].id)
                                : null,
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  currentPond.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                Text(
                                  activeBatch != null ? 'Batch #${activeBatch.batchNumber} • DOC $doc' : 'Vacant Pond',
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                            onPressed: safeIndex < ponds.length - 1
                                ? () => setState(() => _currentPondId = ponds[safeIndex + 1].id)
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Field Actions (Large touch targets)
                    _buildFieldActionButton(
                      context: context,
                      title: 'Log Water Quality',
                      subtitle: 'DO, pH, Temp, Salinity, Ammonia',
                      icon: Icons.water_drop_rounded,
                      color: Colors.blue,
                      onTap: () => WaterQualityEntryPage.show(context, pondId: currentPond.id),
                    ),
                    const SizedBox(height: 10),

                    if (activeBatch != null) ...[
                      _buildFieldActionButton(
                        context: context,
                        title: 'Log Daily Mortality',
                        subtitle: 'Observed & estimated dead count',
                        icon: Icons.remove_circle_outline_rounded,
                        color: Colors.red,
                        onTap: () => MortalityLoggingDialog.show(
                          context,
                          batchId: activeBatch.id,
                          pondId: currentPond.id,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    _buildFieldActionButton(
                      context: context,
                      title: 'Log Water Exchange / Operation',
                      subtitle: 'Drain & refill, top-up, pumps',
                      icon: Icons.swap_vert_circle_rounded,
                      color: Colors.teal,
                      onTap: () => PondOperationDialog.show(
                        context,
                        pond: currentPond,
                        batchId: activeBatch?.id,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (activeBatch != null) ...[
                      _buildFieldActionButton(
                        context: context,
                        title: 'Adjust Population (Audit)',
                        subtitle: 'Cast-net count correction',
                        icon: Icons.tune_rounded,
                        color: Colors.deepPurple,
                        onTap: () => PopulationAdjustmentDialog.show(
                          context,
                          batchId: activeBatch.id,
                          currentEstimatedPopulation: activeBatch.shrimpStockedCount,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    _buildFieldActionButton(
                      context: context,
                      title: 'Feed Session Broadcast',
                      subtitle: 'Log pellets, trays, and co-fed medicines',
                      icon: Icons.set_meal_rounded,
                      color: Colors.amber.shade800,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FeedLoggingPage(
                              onFeedLogged: () => Navigator.pop(context),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading ponds: $err')),
      ),
    );
  }
}
