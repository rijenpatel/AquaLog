import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import 'inventory_reports_page.dart';
import 'procurement_assistant_card.dart';
import '../../core/widgets/aqua_dropdown.dart';

class InventoryHubPage extends ConsumerStatefulWidget {
  const InventoryHubPage({super.key});

  @override
  ConsumerState<InventoryHubPage> createState() => _InventoryHubPageState();
}

class _InventoryHubPageState extends ConsumerState<InventoryHubPage> {
  String _selectedCategory = 'all'; // 'all', 'feed', 'medicine', 'supplement', 'fuel'
  String _searchQuery = '';
  String? _selectedSiteId;

  void _showInwardStockDialog(BuildContext context, {String defaultCategory = 'feed'}) {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController(text: defaultCategory == 'feed' ? 'CP Aqua' : 'AquaMed');
    final qtyCtrl = TextEditingController(text: '100');
    final costCtrl = TextEditingController(text: '95');
    final supplierCtrl = TextEditingController(text: 'Coastal Agro Supplies');
    final lotCtrl = TextEditingController();
    final pelletCtrl = TextEditingController(text: '2.0mm');
    String category = defaultCategory;
    String unit = defaultCategory == 'feed' ? 'kg' : defaultCategory == 'fuel' ? 'L' : 'units';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Inward Stock / Purchase (${category.toUpperCase()})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AquaDropdownFormField<String>(
                  value: category,
                  labelText: 'Category *',
                  prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
                  items: const [
                    DropdownMenuItem(value: 'feed', child: Text('Pellet Feed')),
                    DropdownMenuItem(value: 'medicine', child: Text('Medicine & Bio')),
                    DropdownMenuItem(value: 'supplement', child: Text('Minerals & Supplement')),
                    DropdownMenuItem(value: 'fuel', child: Text('Diesel & Fuel')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() {
                        category = v;
                        unit = v == 'feed' ? 'kg' : v == 'fuel' ? 'L' : 'units';
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Product Name *',
                    hintText: category == 'feed' ? 'e.g. CP Aqua 40% Grower' : 'e.g. BioGut Probiotic',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: brandCtrl,
                        decoration: const InputDecoration(labelText: 'Brand *'),
                      ),
                    ),
                    if (category == 'feed') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: pelletCtrl,
                          decoration: const InputDecoration(labelText: 'Pellet mm', hintText: '2.0mm'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Quantity ($unit) *', suffixText: unit),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: costCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Price/Unit (₹) *', prefixText: '₹'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: supplierCtrl,
                        decoration: const InputDecoration(labelText: 'Supplier / Dealer'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lotCtrl,
                        decoration: const InputDecoration(labelText: 'Lot / Batch #'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final brand = brandCtrl.text.trim();
                final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;

                if (name.isEmpty || qty <= 0 || cost <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter valid product name, quantity, and unit cost.')),
                  );
                  return;
                }

                final db = ref.read(appDatabaseProvider);
                final itemId = '${category}_${DateTime.now().millisecondsSinceEpoch}';

                await db.createInventoryItemTransaction(
                  item: InventoryItemsCompanion(
                    id: drift.Value(itemId),
                    siteId: _selectedSiteId != null ? drift.Value(_selectedSiteId!) : const drift.Value.absent(),
                    name: drift.Value(name),
                    category: drift.Value(category),
                    brand: drift.Value(brand),
                    pelletSize: category == 'feed' ? drift.Value(pelletCtrl.text.trim()) : const drift.Value.absent(),
                    unit: drift.Value(unit),
                    currentStock: drift.Value(qty),
                    lowStockThreshold: drift.Value(category == 'feed' ? 20.0 : 5.0),
                    costPerUnit: drift.Value(cost),
                    supplier: drift.Value(supplierCtrl.text.trim()),
                    batchLotNumber: drift.Value(lotCtrl.text.trim()),
                  ),
                  initialStock: qty,
                  unitCost: cost,
                  supplier: supplierCtrl.text.trim(),
                );

                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Stocked $qty $unit of $name!'),
                      backgroundColor: const Color(0xFF006876),
                    ),
                  );
                }
              },
              child: const Text('Record Stock'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTopUpDialog(InventoryItem item) {
    final qtyCtrl = TextEditingController(text: item.category == 'feed' ? '100' : '10');
    final costCtrl = TextEditingController(text: item.costPerUnit.toStringAsFixed(0));
    final supplierCtrl = TextEditingController(text: item.supplier ?? 'Supplier');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Top-Up Stock: ${item.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current Stock: ${item.currentStock} ${item.unit}'),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Additional Quantity (${item.unit}) *', suffixText: item.unit),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Purchase Price/Unit (₹) *', prefixText: '₹'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: supplierCtrl,
                decoration: const InputDecoration(labelText: 'Supplier'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
              final cost = double.tryParse(costCtrl.text.trim()) ?? item.costPerUnit;
              if (qty <= 0) return;

              final db = ref.read(appDatabaseProvider);
              await db.purchaseInventoryTransaction(
                itemId: item.id,
                quantity: qty,
                unitCost: cost,
                totalCost: qty * cost,
                date: DateTime.now(),
                supplier: supplierCtrl.text.trim(),
              );

              if (mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added $qty ${item.unit} to ${item.name}!'), backgroundColor: const Color(0xFF006876)),
                );
              }
            },
            child: const Text('Confirm Purchase'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inventoryAsync = ref.watch(allInventoryItemsStreamProvider);
    final sitesAsync = ref.watch(allSitesStreamProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Header Bar (Matching new design 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory & Supplies',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'सामग्री प्रबंधन • Operational Consumables',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.receipt_long_rounded),
                      tooltip: 'Stock Ledger',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const InventoryReportsPage()),
                        );
                      },
                    ),
                    FilledButton.icon(
                      onPressed: () => _showInwardStockDialog(context),
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                      label: const Text('Inward'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Pinned Site Context Selector
            sitesAsync.when(
              data: (sites) {
                if (sites.isEmpty) return const SizedBox.shrink();
                final activeSite = sites.firstWhere(
                  (s) => s.id == _selectedSiteId,
                  orElse: () => sites.first,
                );

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.water_drop_rounded, size: 18, color: Color(0xFF006876)),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ACTIVE FARM ESTATE',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                activeSite.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF006876),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (sites.length > 1)
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: activeSite.id,
                            elevation: 6,
                            borderRadius: BorderRadius.circular(16),
                            dropdownColor: theme.colorScheme.surfaceContainerHigh,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                            items: sites.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedSiteId = v);
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 14),

            // 3. Executive Valuation KPI Grid (Matching new design 1)
            inventoryAsync.when(
              data: (items) {
                final feedItems = items.where((i) => i.category == 'feed').toList();
                final medItems = items.where((i) => i.category == 'medicine').toList();
                final suppItems = items.where((i) => i.category == 'supplement').toList();
                final fuelItems = items.where((i) => i.category == 'fuel').toList();

                final feedValuation = feedItems.fold(0.0, (acc, i) => acc + (i.currentStock * i.costPerUnit));
                final medValuation = medItems.fold(0.0, (acc, i) => acc + (i.currentStock * i.costPerUnit));
                final suppValuation = suppItems.fold(0.0, (acc, i) => acc + (i.currentStock * i.costPerUnit));
                final fuelValuation = fuelItems.fold(0.0, (acc, i) => acc + (i.currentStock * i.costPerUnit));
                final totalValuation = feedValuation + medValuation + suppValuation + fuelValuation;

                final feedKg = feedItems.fold(0.0, (acc, i) => acc + i.currentStock);
                final fuelL = fuelItems.fold(0.0, (acc, i) => acc + i.currentStock);

                // Critical Reorder Warning
                final criticalItems = items.where((i) => i.currentStock <= i.lowStockThreshold).toList();

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Consumable Valuation',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Audit Ready',
                                  style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '₹${totalValuation.toStringAsFixed(0)}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 4-Column Micro Metrics Grid
                          Row(
                            children: [
                              Expanded(
                                child: _buildMicroMetric(
                                  theme,
                                  'Pellet Feed',
                                  '₹${(feedValuation / 1000).toStringAsFixed(1)}k',
                                  '${feedKg.toStringAsFixed(0)} kg in store',
                                  Icons.bubble_chart_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildMicroMetric(
                                  theme,
                                  'Medicine & Bio',
                                  '₹${(medValuation / 1000).toStringAsFixed(1)}k',
                                  '${medItems.length} active SKUs',
                                  Icons.medication_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMicroMetric(
                                  theme,
                                  'Diesel & Fuel',
                                  '₹${(fuelValuation / 1000).toStringAsFixed(1)}k',
                                  '${fuelL.toStringAsFixed(0)} L in tanks',
                                  Icons.local_gas_station_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildMicroMetric(
                                  theme,
                                  'Supplements',
                                  '₹${(suppValuation / 1000).toStringAsFixed(1)}k',
                                  '${suppItems.length} active buffer',
                                  Icons.bolt_rounded,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Operational Alert Banner
                    if (criticalItems.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_rounded, color: theme.colorScheme.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CRITICAL REORDER WARNING',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                  Text(
                                    '${criticalItems.first.name} has only ${criticalItems.first.currentStock} ${criticalItems.first.unit} remaining.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11.5,
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _showTopUpDialog(criticalItems.first),
                              child: const Text('Top Up'),
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
            const SizedBox(height: 16),

            // 3B. Procurement Intelligence & Reorder Assistant
            ProcurementAssistantCard(
              onAddPurchaseTap: () => _showInwardStockDialog(context),
            ),
            const SizedBox(height: 16),

            // 4. Search & Category Filter Chips
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(100),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                decoration: const InputDecoration(
                  icon: Icon(Icons.search_rounded, size: 20),
                  hintText: 'Search product, brand, mm, lot...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(height: 10),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Products'),
                  _buildFilterChip('feed', 'Feed'),
                  _buildFilterChip('medicine', 'Medicine'),
                  _buildFilterChip('supplement', 'Supplements'),
                  _buildFilterChip('fuel', 'Fuel & Diesel'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. Inventory Items List
            inventoryAsync.when(
              data: (items) {
                var filtered = items;
                if (_selectedCategory != 'all') {
                  filtered = filtered.where((i) => i.category == _selectedCategory).toList();
                }
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((i) {
                    return i.name.toLowerCase().contains(_searchQuery) ||
                        (i.brand?.toLowerCase().contains(_searchQuery) ?? false) ||
                        (i.pelletSize?.toLowerCase().contains(_searchQuery) ?? false);
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return Card(
                    color: theme.colorScheme.surfaceContainerLowest,
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 40, color: theme.colorScheme.primary.withOpacity(0.5)),
                            const SizedBox(height: 10),
                            Text(
                              'No inventory items found.',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "Inward" above to register feed, medicine, or fuel stock.',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: filtered.map((item) {
                    final isLow = item.currentStock <= item.lowStockThreshold;
                    final isOut = item.currentStock <= 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: item.category == 'feed'
                                  ? const Color(0xFF006876).withOpacity(0.1)
                                  : item.category == 'medicine'
                                      ? Colors.purple.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              item.category == 'feed'
                                  ? Icons.bubble_chart_rounded
                                  : item.category == 'medicine'
                                      ? Icons.medication_rounded
                                      : item.category == 'fuel'
                                          ? Icons.local_gas_station_rounded
                                          : Icons.bolt_rounded,
                              color: item.category == 'feed' ? const Color(0xFF006876) : Colors.black87,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      item.name,
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    if (item.pelletSize != null) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.pelletSize!,
                                          style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Brand: ${item.brand ?? "Generic"} · ₹${item.costPerUnit.toStringAsFixed(0)}/${item.unit}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${item.currentStock.toStringAsFixed(1)} ${item.unit}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isOut
                                      ? theme.colorScheme.error
                                      : isLow
                                          ? Colors.orange
                                          : null,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                                color: theme.colorScheme.primary,
                                tooltip: 'Top Up Stock',
                                onPressed: () => _showTopUpDialog(item),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicroMetric(ThemeData theme, String label, String value, String subtext, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.labelSmall?.copyWith(fontSize: 10.5, color: theme.colorScheme.onSurfaceVariant)),
              Icon(icon, size: 14, color: theme.colorScheme.primary),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          Text(subtext, style: theme.textTheme.labelSmall?.copyWith(fontSize: 9.5, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String cat, String label) {
    final isSelected = _selectedCategory == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (s) {
          if (s) setState(() => _selectedCategory = cat);
        },
      ),
    );
  }
}
