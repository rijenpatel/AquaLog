import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/widgets/aqua_metric_card.dart';

class FinancePage extends ConsumerStatefulWidget {
  const FinancePage({super.key});

  @override
  ConsumerState<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends ConsumerState<FinancePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddExpenseDialog() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'feed';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Operating Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category *'),
                  items: const [
                    DropdownMenuItem(value: 'feed', child: Text('Feed & Nutrition')),
                    DropdownMenuItem(value: 'seed', child: Text('PL Seed')),
                    DropdownMenuItem(value: 'power', child: Text('Electricity & Diesel')),
                    DropdownMenuItem(value: 'labor', child: Text('Labor & Wages')),
                    DropdownMenuItem(value: 'medicine', child: Text('Medicines & Minerals')),
                    DropdownMenuItem(value: 'maintenance', child: Text('Machinery Maintenance')),
                    DropdownMenuItem(value: 'rent', child: Text('Lease / Rent')),
                    DropdownMenuItem(value: 'other', child: Text('Miscellaneous')),
                  ],
                  onChanged: (v) => setDialogState(() => category = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (₹) *', prefixText: '₹'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description / Invoice Info *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                final desc = descCtrl.text.trim();
                if (amt <= 0 || desc.isEmpty) return;

                final db = ref.read(appDatabaseProvider);
                await db.into(db.expenses).insert(
                  ExpensesCompanion(
                    id: drift.Value('exp_${DateTime.now().millisecondsSinceEpoch}'),
                    category: drift.Value(category),
                    amount: drift.Value(amt),
                    description: drift.Value(desc),
                    date: drift.Value(DateTime.now()),
                  ),
                );
                if (mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Add Expense'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPriceDialog() {
    final priceCtrl = TextEditingController(text: '430');
    String count = '40 count';
    final locationCtrl = TextEditingController(text: 'Bhimavaram Mandi');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Mandi Market Price'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: count,
                  decoration: const InputDecoration(labelText: 'Shrimp Count Size *'),
                  items: const [
                    DropdownMenuItem(value: '30 count', child: Text('30 count (33g - Premium Export)')),
                    DropdownMenuItem(value: '40 count', child: Text('40 count (25g - Standard Harvest)')),
                    DropdownMenuItem(value: '60 count', child: Text('60 count (16.6g - Thinning)')) ,
                    DropdownMenuItem(value: '100 count', child: Text('100 count (10g - Juvenile)')),
                  ],
                  onChanged: (v) => setDialogState(() => count = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price per kg (₹) *', prefixText: '₹'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(labelText: 'Mandi / Location'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final p = double.tryParse(priceCtrl.text) ?? 0.0;
                if (p <= 0) return;

                final db = ref.read(appDatabaseProvider);
                await db.into(db.marketPrices).insert(
                  MarketPricesCompanion(
                    id: drift.Value('price_${DateTime.now().millisecondsSinceEpoch}'),
                    countCategory: drift.Value(count),
                    pricePerKg: drift.Value(p),
                    location: drift.Value(locationCtrl.text.trim()),
                    date: drift.Value(DateTime.now()),
                  ),
                );
                if (mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Record Price'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);
    final revenuesAsync = ref.watch(revenuesStreamProvider);
    final pricesAsync = ref.watch(marketPricesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.tr('finance_title')),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Expenses'),
            Tab(text: 'Revenue'),
            Tab(text: 'Mandi Prices'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Overview Tab
          expensesAsync.when(
            data: (expenses) => revenuesAsync.when(
              data: (revenues) {
                final totalCost = expenses.fold<double>(0.0, (s, e) => s + e.amount);
                final totalRev = revenues.fold<double>(0.0, (s, r) => s + r.totalAmount);
                final netProfit = totalRev - totalCost;
                final margin = totalRev > 0 ? (netProfit / totalRev) * 100 : 0.0;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AquaMetricCard(
                            title: settings.tr('net_profit'),
                            value: '₹${(netProfit / 1000).toStringAsFixed(1)}K',
                            subtitle: 'Margin: ${margin.toStringAsFixed(1)}%',
                            accentColor: netProfit >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AquaMetricCard(
                            title: settings.tr('total_revenue'),
                            value: '₹${(totalRev / 1000).toStringAsFixed(1)}K',
                            subtitle: '${revenues.length} sales',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AquaMetricCard(
                      title: settings.tr('total_costs'),
                      value: '₹${totalCost.toStringAsFixed(0)}',
                      subtitle: 'Aggregated feed, power, seed & operating expenses',
                    ),
                    const SizedBox(height: 16),

                    // Break-Even Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
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
                                settings.tr('break_even_benchmark'),
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const Text('Target 40 Count: ₹430/kg', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Estimated farm break-even sale price is ₹324.30/kg based on incurred standing crop biomass. Negotiate minimum ₹380/kg with buyers.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // 2. Expenses Tab
          expensesAsync.when(
            data: (expenses) => Scaffold(
              floatingActionButton: FloatingActionButton(
                onPressed: _showAddExpenseDialog,
                child: const Icon(Icons.add_rounded),
              ),
              body: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: expenses.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final e = expenses[idx];
                  return ListTile(
                    title: Text(e.description),
                    subtitle: Text('${e.category.toUpperCase()} · ${DateFormat('dd MMM yyyy').format(e.date)}'),
                    trailing: Text(
                      '₹${e.amount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  );
                },
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // 3. Revenue Tab
          revenuesAsync.when(
            data: (revenues) {
              if (revenues.isEmpty) {
                return const Center(child: Text('No harvest sales recorded yet.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: revenues.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final r = revenues[idx];
                  return ListTile(
                    title: Text('Buyer: ${r.buyerName ?? "Processor"}'),
                    subtitle: Text('${r.harvestWeightKg} kg @ ₹${r.pricePerKg}/kg · ${DateFormat('dd MMM yyyy').format(r.date)}'),
                    trailing: Text(
                      '₹${r.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                    ),
                  );
                },
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // 4. Market Prices Tab
          pricesAsync.when(
            data: (prices) => Scaffold(
              floatingActionButton: FloatingActionButton(
                onPressed: _showAddPriceDialog,
                child: const Icon(Icons.add_rounded),
              ),
              body: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: prices.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final p = prices[idx];
                  return ListTile(
                    title: Text('${p.countCategory} (${p.location ?? "Mandi"})'),
                    subtitle: Text(DateFormat('dd MMM yyyy').format(p.date)),
                    trailing: Text(
                      '₹${p.pricePerKg.toStringAsFixed(0)}/kg',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                    ),
                  );
                },
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
