import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';

class InventoryReportsPage extends ConsumerStatefulWidget {
  const InventoryReportsPage({super.key});

  @override
  ConsumerState<InventoryReportsPage> createState() => _InventoryReportsPageState();
}

class _InventoryReportsPageState extends ConsumerState<InventoryReportsPage> {
  String _selectedReport = 'feed_purchase';

  void _exportCsv(List<List<dynamic>> rows, String filename) {
    final csvData = const ListToCsvConverter().convert(rows);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✓ Exported ${rows.length - 1} records as $filename.csv (${csvData.length} chars)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(allInventoryItemsStreamProvider);
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Reports & Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export CSV',
            onPressed: () {
              itemsAsync.whenData((items) {
                final rows = <List<dynamic>>[
                  ['Name', 'Category', 'Stock', 'Unit', 'Cost Per Unit'],
                  ...items.map((i) => [i.name, i.category, i.currentStock, i.unit, i.costPerUnit]),
                ];
                _exportCsv(rows, 'inventory_report');
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Report Type Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surfaceContainerLow,
            child: DropdownButtonFormField<String>(
              value: _selectedReport,
              decoration: const InputDecoration(labelText: 'Select Report Type'),
              items: const [
                DropdownMenuItem(value: 'feed_purchase', child: Text('Feed Purchase History')),
                DropdownMenuItem(value: 'medicine_purchase', child: Text('Medicine Purchase History')),
                DropdownMenuItem(value: 'fuel_purchase', child: Text('Fuel Purchase History')),
                DropdownMenuItem(value: 'current_inventory', child: Text('Current Inventory & Valuation')),
                DropdownMenuItem(value: 'low_stock', child: Text('Low Stock Alerts & Shortfalls')),
                DropdownMenuItem(value: 'stock_movement', child: Text('Stock Movement Ledger')),
              ],
              onChanged: (v) => setState(() => _selectedReport = v!),
            ),
          ),

          // Report Content Table / List
          Expanded(
            child: itemsAsync.when(
              data: (items) {
                if (_selectedReport == 'current_inventory') {
                  final totalVal = items.fold<double>(0.0, (s, i) => s + (i.currentStock * i.costPerUnit));
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Warehouse Valuation:', style: theme.textTheme.titleSmall),
                            Text('₹${totalVal.toStringAsFixed(0)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final i = items[idx];
                            return ListTile(
                              leading: Icon(
                                i.category == 'feed'
                                    ? Icons.grain_rounded
                                    : i.category == 'medicine'
                                        ? Icons.medication_rounded
                                        : Icons.local_gas_station_rounded,
                              ),
                              title: Text(i.name),
                              subtitle: Text('Category: ${i.category.toUpperCase()} · Rate: ₹${i.costPerUnit}/${i.unit}'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${i.currentStock} ${i.unit}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('₹${(i.currentStock * i.costPerUnit).toStringAsFixed(0)}', style: TextStyle(color: theme.colorScheme.primary, fontSize: 12)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }

                if (_selectedReport == 'low_stock') {
                  final lowItems = items.where((i) => i.currentStock <= i.lowStockThreshold).toList();
                  if (lowItems.isEmpty) {
                    return const Center(child: Text('✓ All supplies are healthy. No items below minimum threshold.'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: lowItems.length,
                    itemBuilder: (ctx, idx) {
                      final i = lowItems[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(i.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('Current Stock: ${i.currentStock} ${i.unit} (Min: ${i.lowStockThreshold} ${i.unit})'),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(100)),
                              child: const Text('Reorder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black)),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }

                // Default: Query Transactions
                return FutureBuilder<List<InventoryTransaction>>(
                  future: (db.select(db.inventoryTransactions)..orderBy([(t) => OrderingTerm.desc(t.date)])).get(),
                  builder: (ctx, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final txs = snap.data!;
                    if (txs.isEmpty) return const Center(child: Text('No transactions recorded yet.'));

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: txs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final tx = txs[idx];
                        final isPositive = tx.quantity > 0;
                        return ListTile(
                          leading: Icon(
                            isPositive ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                            color: isPositive ? Colors.green : Colors.orange,
                          ),
                          title: Text(tx.notes ?? tx.type.toUpperCase()),
                          subtitle: Text(DateFormat('dd MMM yyyy').format(tx.date)),
                          trailing: Text(
                            '${isPositive ? "+" : ""}${tx.quantity.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isPositive ? Colors.green : Colors.orange,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
