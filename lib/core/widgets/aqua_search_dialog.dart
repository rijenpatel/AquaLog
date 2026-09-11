import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';

class AquaSearchDialog extends ConsumerStatefulWidget {
  const AquaSearchDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const AquaSearchDialog(),
    );
  }

  @override
  ConsumerState<AquaSearchDialog> createState() => _AquaSearchDialogState();
}

class _AquaSearchDialogState extends ConsumerState<AquaSearchDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pondsAsync = ref.watch(allPondsStreamProvider);
    final inventoryAsync = ref.watch(allInventoryItemsStreamProvider);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input Bar
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search ponds, batches, supplies, feed...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
                onChanged: (val) => setState(() => _query = val.trim().toLowerCase()),
              ),
              const SizedBox(height: 16),
              if (_query.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'Type to search across farm units & inventory',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    children: [
                      // Matching Ponds
                      pondsAsync.when(
                        data: (ponds) {
                          final matches = ponds.where((p) => p.name.toLowerCase().contains(_query)).toList();
                          if (matches.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PONDS (${matches.length})',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...matches.map((p) => ListTile(
                                leading: const Icon(Icons.water_rounded),
                                title: Text(p.name),
                                subtitle: Text('${p.areaSqMeters.toStringAsFixed(0)} m² · ${p.totalAeratorHp} HP aerators'),
                                onTap: () => Navigator.of(context).pop(),
                              )),
                              const Divider(height: 24),
                            ],
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      // Matching Inventory Items
                      inventoryAsync.when(
                        data: (items) {
                          final matches = items.where((i) =>
                              i.name.toLowerCase().contains(_query) ||
                              (i.brand?.toLowerCase().contains(_query) ?? false) ||
                              (i.supplier?.toLowerCase().contains(_query) ?? false)).toList();
                          if (matches.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'INVENTORY & SUPPLIES (${matches.length})',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...matches.map((i) => ListTile(
                                leading: Icon(
                                  i.category == 'feed'
                                      ? Icons.grain_rounded
                                      : i.category == 'medicine'
                                          ? Icons.medication_rounded
                                          : Icons.local_gas_station_rounded,
                                ),
                                title: Text(i.name),
                                subtitle: Text('Stock: ${i.currentStock} ${i.unit} · ₹${i.costPerUnit}/${i.unit}'),
                                onTap: () => Navigator.of(context).pop(),
                              )),
                            ],
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
