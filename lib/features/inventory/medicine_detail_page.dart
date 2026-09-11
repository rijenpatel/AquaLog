import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/calculations/calculations.dart';

class MedicineDetailPage extends ConsumerStatefulWidget {
  const MedicineDetailPage({super.key});

  @override
  ConsumerState<MedicineDetailPage> createState() => _MedicineDetailPageState();
}

class _MedicineDetailPageState extends ConsumerState<MedicineDetailPage> {
  // Dosage Calculator state
  double _calcArea = 4000.0;
  double _calcDepth = 1.5;
  double _calcPpm = 2.0;

  void _showLogTreatmentDialog(InventoryItem item, List<Pond> ponds, List<Batch> batches) {
    if (ponds.isEmpty) return;
    String selectedPondId = ponds.first.id;
    final qtyCtrl = TextEditingController(text: '5.0');
    String reason = 'Routine Water Prep';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Apply ${item.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedPondId,
                  decoration: const InputDecoration(labelText: 'Target Pond *'),
                  items: ponds.map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text(p.name),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedPondId = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: reason,
                  decoration: const InputDecoration(labelText: 'Treatment Reason'),
                  items: const [
                    DropdownMenuItem(value: 'Routine Water Prep', child: Text('Routine Water Prep')),
                    DropdownMenuItem(value: 'High Ammonia Spike', child: Text('High Ammonia Spike')),
                    DropdownMenuItem(value: 'Molting Support', child: Text('Molting Support')),
                    DropdownMenuItem(value: 'Vibrio Biosecurity', child: Text('Vibrio Biosecurity')),
                    DropdownMenuItem(value: 'Turbid Water Treatment', child: Text('Turbid Water Treatment')),
                  ],
                  onChanged: (v) => setDialogState(() => reason = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Quantity (${item.unit}) *',
                    suffixText: item.unit,
                    helperText: 'Available stock: ${item.currentStock} ${item.unit}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text) ?? 0.0;
                if (qty <= 0 || qty > item.currentStock) return;

                final db = ref.read(appDatabaseProvider);
                final batch = batches.where((b) => b.pondId == selectedPondId).firstOrNull;
                final batchId = batch?.id ?? 'batch_default';

                // Insert treatment record
                await db.into(db.treatmentRecords).insert(
                  TreatmentRecordsCompanion(
                    id: drift.Value('treat_${DateTime.now().millisecondsSinceEpoch}'),
                    pondId: drift.Value(selectedPondId),
                    batchId: drift.Value(batchId),
                    itemId: drift.Value(item.id),
                    productName: drift.Value(item.name),
                    quantityApplied: drift.Value(qty),
                    unit: drift.Value(item.unit),
                    treatmentReason: drift.Value(reason),
                    date: drift.Value(DateTime.now()),
                  ),
                );

                // Decrement inventory stock & record consumption transaction
                final newStock = item.currentStock - qty;
                await (db.update(db.inventoryItems)..where((t) => t.id.equals(item.id))).write(
                  InventoryItemsCompanion(currentStock: drift.Value(newStock)),
                );

                await db.into(db.inventoryTransactions).insert(
                  InventoryTransactionsCompanion(
                    id: drift.Value('tx_treat_${DateTime.now().millisecondsSinceEpoch}'),
                    itemId: drift.Value(item.id),
                    type: const drift.Value('consumption'),
                    quantity: drift.Value(-qty),
                    unitPrice: drift.Value(item.costPerUnit),
                    totalCost: drift.Value(qty * item.costPerUnit),
                    date: drift.Value(DateTime.now()),
                    notes: drift.Value('Pond treatment: $reason'),
                  ),
                );

                if (mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Apply Treatment'),
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
    final pondsAsync = ref.watch(allPondsStreamProvider);
    final batchesAsync = ref.watch(activeBatchesStreamProvider);

    final waterVol = WaterVolumeCalculator.calculate(areaSqMeters: _calcArea, waterDepthMeters: _calcDepth);
    final doseRes = DosageCalculator.calculateFromPpm(volumeM3: waterVol.volumeM3, dosageRatePpm: _calcPpm);

    return Scaffold(
      appBar: AppBar(title: const Text('Medicine & Biosecurity')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Interactive Pond Volume & Dosage Calculator Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calculate_rounded, color: Color(0xFF006876)),
                        const SizedBox(width: 8),
                        Text(
                          'Pond Volume Dosage Calculator',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'Req: ${doseRes.requiredProductKg.toStringAsFixed(1)} kg',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Volume: ${waterVol.volumeM3.toStringAsFixed(0)} m³ (${(waterVol.volumeLiters / 1000000.0).toStringAsFixed(2)} ML)',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Area: ${_calcArea.toInt()} m²', style: theme.textTheme.labelSmall),
                          Slider(
                            value: _calcArea,
                            min: 1000.0,
                            max: 10000.0,
                            divisions: 18,
                            onChanged: (v) => setState(() => _calcArea = v),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Depth: ${_calcDepth.toStringAsFixed(1)} m', style: theme.textTheme.labelSmall),
                          Slider(
                            value: _calcDepth,
                            min: 1.0,
                            max: 2.5,
                            divisions: 15,
                            onChanged: (v) => setState(() => _calcDepth = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dosage Rate: ${_calcPpm.toStringAsFixed(1)} PPM', style: theme.textTheme.labelSmall),
                          Slider(
                            value: _calcPpm,
                            min: 0.5,
                            max: 10.0,
                            divisions: 19,
                            onChanged: (v) => setState(() => _calcPpm = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Medicine Products List
          itemsAsync.when(
            data: (items) {
              final medItems = items.where((i) => i.category == 'medicine').toList();
              if (medItems.isEmpty) return const Center(child: Text('No medicines configured.'));

              return pondsAsync.when(
                data: (ponds) => batchesAsync.when(
                  data: (batches) => Column(
                    children: medItems.map((item) {
                      final now = DateTime.now();
                      int? daysToExpiry;
                      if (item.expiryDate != null) {
                        daysToExpiry = item.expiryDate!.difference(now).inDays;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
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
                                Text(
                                  item.name,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (daysToExpiry != null && daysToExpiry <= 30)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: daysToExpiry < 0 ? Colors.red.withOpacity(0.15) : Colors.amber.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      daysToExpiry < 0 ? 'Expired' : 'Expires in $daysToExpiry days',
                                      style: TextStyle(
                                        color: daysToExpiry < 0 ? Colors.red : Colors.amber,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Category: ${item.medicineCategory ?? "General"} · Current Stock: ${item.currentStock} ${item.unit} · Valuation: ₹${(item.currentStock * item.costPerUnit).toStringAsFixed(0)}',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: () => _showLogTreatmentDialog(item, ponds, batches),
                                  icon: const Icon(Icons.water_drop_outlined, size: 16),
                                  label: const Text('Apply to Pond'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
