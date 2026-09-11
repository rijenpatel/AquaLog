import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/calculations/reorder_assistant_engine.dart';
import '../../app/theme/color_schemes.dart';

class ProcurementAssistantCard extends ConsumerWidget {
  final VoidCallback? onAddPurchaseTap;

  const ProcurementAssistantCard({
    super.key,
    this.onAddPurchaseTap,
  });

  Color _getUrgencyColor(ReorderUrgency urgency) {
    switch (urgency) {
      case ReorderUrgency.outOfStock:
      case ReorderUrgency.orderNow:
        return AquaColors.statusCritical;
      case ReorderUrgency.lowStock:
        return Colors.orange;
      case ReorderUrgency.optimal:
        return AquaColors.statusOptimal;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(allInventoryItemsStreamProvider);

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        final db = ref.watch(databaseProvider);

        return FutureBuilder<List<InventoryTransaction>>(
          future: (db.select(db.inventoryTransactions)
                ..where((t) => t.type.equals('consumption')))
              .get(),
          builder: (context, snapshot) {
            final allTx = snapshot.data ?? const [];
            final txByItem = <String, List<InventoryTransaction>>{};
            for (final tx in allTx) {
              txByItem.putIfAbsent(tx.itemId, () => []).add(tx);
            }

            final urgentList = ReorderAssistantEngine.generateProcurementList(items, txByItem);
            if (urgentList.isEmpty) return const SizedBox.shrink();

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AquaColors.statusCritical.withOpacity(0.4), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.deepOrange),
                        const SizedBox(width: 8),
                        Text(
                          "Procurement Assistant",
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AquaColors.statusCritical.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            '${urgentList.length} ITEMS TO ORDER',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AquaColors.statusCritical,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Urgent Items List
                    ...urgentList.take(4).map((forecast) {
                      final uColor = _getUrgencyColor(forecast.urgency);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 36,
                              decoration: BoxDecoration(color: uColor, borderRadius: BorderRadius.circular(3)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    forecast.item.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Stock: ${forecast.currentStock.toStringAsFixed(1)} ${forecast.item.unit} (${forecast.projectedDaysRemaining.toStringAsFixed(1)} days left)',
                                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                  if (forecast.hasExpiryRisk)
                                    const Text(
                                      '⚠️ Expiry warning: Consume soon',
                                      style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '+${forecast.suggestedOrderQty.toStringAsFixed(0)} ${forecast.item.unit}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: uColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    forecast.urgency.label,
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: uColor),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
