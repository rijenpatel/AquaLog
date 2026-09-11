import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/calculations/calculations.dart';

class FuelDetailPage extends ConsumerStatefulWidget {
  const FuelDetailPage({super.key});

  @override
  ConsumerState<FuelDetailPage> createState() => _FuelDetailPageState();
}

class _FuelDetailPageState extends ConsumerState<FuelDetailPage> {
  void _showLogRuntimeDialog(InventoryItem dieselItem) {
    final hoursCtrl = TextEditingController(text: '8.0');
    final burnRateCtrl = TextEditingController(text: '7.5');
    String machineName = 'DG Set 1 (62.5 kVA)';
    String reason = 'Grid Power Outage';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final hours = double.tryParse(hoursCtrl.text) ?? 0.0;
          final rate = double.tryParse(burnRateCtrl.text) ?? 7.5;
          final litersBurned = (hours * rate).toStringAsFixed(1);

          return AlertDialog(
            title: const Text('Log Generator Runtime'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: machineName,
                    decoration: const InputDecoration(labelText: 'Machine *'),
                    items: const [
                      DropdownMenuItem(value: 'DG Set 1 (62.5 kVA)', child: Text('DG Set 1 (62.5 kVA)')),
                      DropdownMenuItem(value: 'DG Set 2 (30 kVA)', child: Text('DG Set 2 (30 kVA)')),
                      DropdownMenuItem(value: 'Tractor Pump A', child: Text('Tractor Pump A')),
                    ],
                    onChanged: (v) => setDialogState(() => machineName = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: reason,
                    decoration: const InputDecoration(labelText: 'Operation Reason'),
                    items: const [
                      DropdownMenuItem(value: 'Grid Power Outage', child: Text('Grid Power Outage')),
                      DropdownMenuItem(value: 'Pre-dawn DO boost', child: Text('Pre-dawn DO boost')),
                      DropdownMenuItem(value: 'Pond Water Exchange', child: Text('Pond Water Exchange')),
                    ],
                    onChanged: (v) => setDialogState(() => reason = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hoursCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Runtime Hours *', suffixText: 'hours'),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: burnRateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Fuel Burn Rate (L/hr)', suffixText: 'L/hr'),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Fuel Burned:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('$litersBurned Liters', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final h = double.tryParse(hoursCtrl.text) ?? 0.0;
                  final r = double.tryParse(burnRateCtrl.text) ?? 7.5;
                  if (h <= 0 || r <= 0) return;

                  final liters = h * r;
                  final db = ref.read(appDatabaseProvider);

                  // 1. Insert machine run record
                  await db.into(db.machineRuns).insert(
                    MachineRunsCompanion(
                      id: drift.Value('run_${DateTime.now().millisecondsSinceEpoch}'),
                      machineName: drift.Value(machineName),
                      fuelItemId: drift.Value(dieselItem.id),
                      date: drift.Value(DateTime.now()),
                      runtimeHours: drift.Value(h),
                      fuelBurnRateLPerHr: drift.Value(r),
                      fuelConsumedLiters: drift.Value(liters),
                      reason: drift.Value(reason),
                    ),
                  );

                  // 2. Decrement diesel inventory
                  final newStock = (dieselItem.currentStock - liters).clamp(0.0, 999999.0);
                  await (db.update(db.inventoryItems)..where((t) => t.id.equals(dieselItem.id))).write(
                    InventoryItemsCompanion(currentStock: drift.Value(newStock)),
                  );

                  // 3. Record consumption transaction
                  await db.into(db.inventoryTransactions).insert(
                    InventoryTransactionsCompanion(
                      id: drift.Value('tx_run_${DateTime.now().millisecondsSinceEpoch}'),
                      itemId: drift.Value(dieselItem.id),
                      type: const drift.Value('consumption'),
                      quantity: drift.Value(-liters),
                      unitPrice: drift.Value(dieselItem.costPerUnit),
                      totalCost: drift.Value(liters * dieselItem.costPerUnit),
                      date: drift.Value(DateTime.now()),
                      notes: drift.Value('Generator runtime: $machineName ($h hrs)'),
                    ),
                  );

                  if (mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Save Runtime Log'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(allInventoryItemsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fuel & Energy Reserves')),
      body: itemsAsync.when(
        data: (items) {
          final fuelItems = items.where((i) => i.category == 'fuel').toList();
          final diesel = fuelItems.where((i) => i.fuelType == 'Diesel' || i.name.contains('Diesel')).firstOrNull ??
              (fuelItems.isNotEmpty ? fuelItems.first : null);

          final backupRes = diesel != null
              ? FuelEfficiencyCalculator.calculateBackupHours(
                  currentReserveLiters: diesel.currentStock,
                  burnRateLPerHr: 7.5,
                )
              : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (diesel != null && backupRes != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: backupRes.isLowFuelWarning
                        ? Colors.amber.withOpacity(0.15)
                        : theme.colorScheme.primaryContainer.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: backupRes.isLowFuelWarning ? Colors.amber : theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.bolt_rounded, color: Colors.amber, size: 24),
                              SizedBox(width: 8),
                              Text('Emergency Backup Capacity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          Text(
                            '${diesel.currentStock.toStringAsFixed(0)} L Reserve',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        backupRes.formatted,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: backupRes.isLowFuelWarning ? Colors.amber : theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Based on 7.5 L/hr average burn rate for 62.5 kVA generator running essential pond aerators.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => _showLogRuntimeDialog(diesel),
                        icon: const Icon(Icons.timer_outlined, size: 16),
                        label: const Text('Log Machine Run-Hours'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Text('Fuel Supplies Inventory', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...fuelItems.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Stock: ${item.currentStock} ${item.unit} · ₹${item.costPerUnit}/${item.unit}'),
                      ],
                    ),
                    Text('Value: ₹${(item.currentStock * item.costPerUnit).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
            ],
          );
        },
        loading: () => const LinearProgressIndicator(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}
