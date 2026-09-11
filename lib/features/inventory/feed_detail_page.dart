import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/calculations/calculations.dart';
import '../../app/theme/color_schemes.dart';

class FeedDetailPage extends ConsumerStatefulWidget {
  const FeedDetailPage({super.key});

  @override
  ConsumerState<FeedDetailPage> createState() => _FeedDetailPageState();
}

class _FeedDetailPageState extends ConsumerState<FeedDetailPage> {
  void _showAdjustStockDialog(InventoryItem item) {
    final qtyCtrl = TextEditingController(text: '25');
    String adjustType = 'damage';
    final notesCtrl = TextEditingController(text: 'Moisture spoilage');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Adjust Stock: ${item.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: adjustType,
                  decoration: const InputDecoration(labelText: 'Adjustment Reason'),
                  items: const [
                    DropdownMenuItem(value: 'damage', child: Text('Damaged / Torn Bag')),
                    DropdownMenuItem(value: 'spoilage', child: Text('Moisture Spoilage')),
                    DropdownMenuItem(value: 'recount', child: Text('Recount Discrepancy')),
                  ],
                  onChanged: (v) => setDialogState(() => adjustType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Deduct Quantity (kg) *', suffixText: 'kg'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Justification Notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text) ?? 0.0;
                if (qty <= 0) return;

                final db = ref.read(appDatabaseProvider);
                final newStock = (item.currentStock - qty).clamp(0.0, 999999.0);

                await (db.update(db.inventoryItems)..where((t) => t.id.equals(item.id))).write(
                  InventoryItemsCompanion(currentStock: drift.Value(newStock)),
                );

                await db.into(db.inventoryTransactions).insert(
                  InventoryTransactionsCompanion(
                    id: drift.Value('tx_adj_${DateTime.now().millisecondsSinceEpoch}'),
                    itemId: drift.Value(item.id),
                    type: drift.Value(adjustType),
                    quantity: drift.Value(-qty),
                    date: drift.Value(DateTime.now()),
                    notes: drift.Value(notesCtrl.text.trim()),
                  ),
                );

                if (mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Confirm Adjustment'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(allInventoryItemsStreamProvider);
    final recordsAsync = ref.watch(feedRecordsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed Stock & Lots'),
      ),
      body: itemsAsync.when(
        data: (items) {
          final feedItems = items.where((i) => i.category == 'feed').toList();
          if (feedItems.isEmpty) {
            return const Center(child: Text('No feed items found.'));
          }

          return recordsAsync.when(
            data: (records) {
              // Calculate 7-day burn rate
              final totalFeedLast7Days = records.take(28).fold<double>(0.0, (s, r) => s + r.totalKg);
              final dailyBurnRate = InventoryAnalytics.calculateDailyBurnRate(totalFeedLast7Days);

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: feedItems.length,
                itemBuilder: (ctx, idx) {
                  final item = feedItems[idx];
                  final bags = (item.currentStock / item.bagWeightKg).floor();
                  final valuation = item.currentStock * item.costPerUnit;
                  final depletion = InventoryAnalytics.calculateDepletionForecast(
                    currentStock: item.currentStock,
                    dailyBurnRate: dailyBurnRate > 0 ? dailyBurnRate / feedItems.length : 15.0,
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: item.pelletSize == '0.8mm'
                                        ? AquaColors.pelletStarter
                                        : item.pelletSize == '1.2mm'
                                            ? AquaColors.pelletGrower1
                                            : item.pelletSize == '1.6mm'
                                                ? AquaColors.pelletGrower2
                                                : AquaColors.pelletFinisher1,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item.name,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                item.pelletSize ?? 'Pellet',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total In Stock', style: theme.textTheme.labelSmall),
                                Text(
                                  '${item.currentStock.toStringAsFixed(1)} kg',
                                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Bags (@ 25kg)', style: theme.textTheme.labelSmall),
                                Text('$bags bags', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Stock Value', style: theme.textTheme.labelSmall),
                                Text('₹${valuation.toStringAsFixed(0)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: depletion.isCriticalReorder
                                ? Colors.red.withOpacity(0.15)
                                : theme.colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.hourglass_top_rounded,
                                size: 16,
                                color: depletion.isCriticalReorder ? Colors.red : theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '⏳ ${depletion.daysRemaining} days of feed remaining',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: depletion.isCriticalReorder ? Colors.red : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => _showAdjustStockDialog(item),
                              child: const Text('Adjust Spoilage'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          );
        },
        loading: () => const LinearProgressIndicator(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}
