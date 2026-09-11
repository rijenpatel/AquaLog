import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/calculations/sampling_calculator.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/batch_dashboard_providers.dart';
import '../../app/theme/color_schemes.dart';
import 'sampling_dialog.dart';

class SamplingHistorySheet extends ConsumerWidget {
  final Batch batch;
  final Pond pond;

  const SamplingHistorySheet({
    super.key,
    required this.batch,
    required this.pond,
  });

  static Future<void> show(
    BuildContext context, {
    required Batch batch,
    required Pond pond,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SamplingHistorySheet(batch: batch, pond: pond),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, SamplingEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sampling Record?'),
        content: Text(
          'Are you sure you want to remove the sampling record from ${DateFormat("dd MMM yyyy").format(entry.date)} (ABW ${entry.abwGrams.toStringAsFixed(3)}g)?\n\nAll subsequent growth metrics will be automatically recalculated.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AquaColors.statusAlert),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(appDatabaseProvider);
      await db.deleteSamplingEntry(entry.id, batch.id);

      ref.invalidate(samplingEntriesStreamProvider);
      ref.invalidate(batchDashboardDataProvider(batch.id));
      ref.invalidate(activeBatchesStreamProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sampling record deleted and growth history recalculated.'),
            backgroundColor: AquaColors.statusAlert,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final samplingsAsync = ref.watch(samplingEntriesStreamProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Sheet Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sampling History', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          '${pond.name} · Batch #${batch.batchNumber}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AquaColors.primary,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => SamplingDialog.show(context, batch: batch, pond: pond),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Sample'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Sampling List
              Expanded(
                child: samplingsAsync.when(
                  data: (allEntries) {
                    final entries = allEntries.where((s) => s.batchId == batch.id).toList();
                    if (entries.isEmpty) {
                      final doc = SamplingCalculator.calculateSamplingDoc(
                        stockingDate: batch.stockingDate,
                        samplingDate: DateTime.now(),
                      );
                      final emptyMsg = doc < kSamplingStartDoc
                          ? 'Sampling program begins at DOC 50. Currently at DOC $doc.'
                          : 'No cast net samples recorded yet for this batch. Conduct sampling to establish baseline ABW.';

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.scale_rounded, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(emptyMsg, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                              const SizedBox(height: 16),
                              FilledButton.tonalIcon(
                                onPressed: () => SamplingDialog.show(context, batch: batch, pond: pond),
                                icon: const Icon(Icons.add),
                                label: const Text('Record First Sample'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final e = entries[idx];
                        final countPerKg = SamplingCalculator.calculateCountPerKg(e.abwGrams);
                        final countPerKgText = SamplingCalculator.formatCountPerKg(countPerKg);
                        final isLatest = idx == 0;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isLatest ? AquaColors.primary.withOpacity(0.5) : theme.colorScheme.outlineVariant.withOpacity(0.3),
                              width: isLatest ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        DateFormat('dd MMM yyyy').format(e.date),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'DOC ${e.doc}',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (isLatest) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AquaColors.primary.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Latest',
                                            style: TextStyle(color: AquaColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        tooltip: 'Edit Sampling',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => SamplingDialog.show(context, batch: batch, pond: pond, existingEntry: e),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AquaColors.statusAlert),
                                        tooltip: 'Delete Sampling',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _confirmDelete(context, ref, e),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('ABW', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text(
                                          '${e.abwGrams.toStringAsFixed(3)} g',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AquaColors.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Count / kg', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text(
                                          countPerKgText,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Growth', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text(
                                          e.weightGainGrams != null
                                              ? '${e.weightGainGrams! >= 0 ? "+" : ""}${e.weightGainGrams!.toStringAsFixed(3)} g'
                                              : '—',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: e.weightGainGrams != null && e.weightGainGrams! < 0
                                                ? AquaColors.statusAlert
                                                : AquaColors.statusOptimal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Daily Growth', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text(
                                          e.adgGramsPerDay != null
                                              ? '${e.adgGramsPerDay! >= 0 ? "+" : ""}${e.adgGramsPerDay!.toStringAsFixed(3)} g/d'
                                              : '—',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'Sampled: ${e.samplingShrimpCount} prawns (${e.samplingTotalWeightG.toStringAsFixed(1)}g total cast)',
                                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                  if (e.daysElapsed != null) ...[
                                    Text(' · ${e.daysElapsed} days since prior', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ],
                              ),
                              if (e.notes != null && e.notes!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Note: ${e.notes}',
                                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading sampling history: $err')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
