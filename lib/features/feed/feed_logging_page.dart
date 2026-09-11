import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/batch_dashboard_providers.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/calculations/calculations.dart';
import '../../core/widgets/aqua_tray_badge.dart';
import '../inventory/inventory_hub_page.dart';

/// Form state representation for a single feed item in the session
class _FeedEntryItem {
  String? inventoryFeedId;
  final TextEditingController quantityController;
  String unit; // 'kg', 'grams', 'bags'
  double? bagWeightKg;

  _FeedEntryItem({
    this.inventoryFeedId,
    required String initialQty,
    this.unit = 'kg',
    this.bagWeightKg,
  }) : quantityController = TextEditingController(text: initialQty);

  double get enteredQty => double.tryParse(quantityController.text.trim()) ?? 0.0;

  double get quantityKg {
    return FeedCalculator.normalizeFeedQuantityToKg(enteredQty, unit, bagWeightKg: bagWeightKg);
  }

  void dispose() {
    quantityController.dispose();
  }
}

class FeedLoggingPage extends ConsumerStatefulWidget {
  final VoidCallback? onFeedLogged;
  final FeedRecord? editRecord;

  const FeedLoggingPage({
    super.key,
    this.onFeedLogged,
    this.editRecord,
  });

  @override
  ConsumerState<FeedLoggingPage> createState() => _FeedLoggingPageState();
}

class _FeedLoggingPageState extends ConsumerState<FeedLoggingPage> {
  late DateTime _selectedDate;
  late String _selectedSlot;
  String? _selectedSiteId;
  String? _selectedPondId;
  String? _selectedBatchId;
  Batch? _resolvedBatch;

  // Dynamic Feed Items List
  final List<_FeedEntryItem> _feedEntries = [];

  // Check Tray Leftover %
  int _trayLeftoverPct = 0;
  bool _trayChecked = true;

  // Optional Additions
  bool _addMedicine = false;
  String? _selectedMedicineItemId;
  final _medicineQtyController = TextEditingController();

  bool _addSupplement = false;
  String? _selectedSupplementItemId;
  final _supplementQtyController = TextEditingController();

  // Two-Tap Safety Gate
  DateTime? _firstTapTime;
  bool _duplicateWarning = false;
  bool _isSaving = false;

  bool get _isEditMode => widget.editRecord != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final rec = widget.editRecord!;
      _selectedDate = rec.date;
      _selectedSlot = rec.timeSlot;
      _selectedPondId = rec.pondId;
      _selectedBatchId = rec.batchId;
      _trayChecked = rec.trayChecked;
      _trayLeftoverPct = rec.trayLeftoverPct;

      final existingItems = FeedCalculator.getRecordItems(rec);
      if (existingItems.isNotEmpty) {
        for (final it in existingItems) {
          _feedEntries.add(_FeedEntryItem(
            inventoryFeedId: it.inventoryFeedId,
            initialQty: it.quantity.toString(),
            unit: it.unit,
            bagWeightKg: it.bagWeightKg,
          ));
        }
      } else {
        _feedEntries.add(_FeedEntryItem(initialQty: '15.0'));
      }
    } else {
      _selectedDate = DateTime.now();
      _selectedSlot = '7:00 AM';
      _autoDetectTimeSlot();
      _feedEntries.add(_FeedEntryItem(initialQty: '15.0'));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedPondId != null) {
        _resolveBatchForPondAndDate(_selectedPondId!, _selectedDate);
      }
    });
  }

  Future<void> _resolveBatchForPondAndDate(String pondId, DateTime date) async {
    final db = ref.read(appDatabaseProvider);
    final b = await db.getBatchForPondOnDate(pondId, date);
    if (mounted) {
      setState(() {
        _resolvedBatch = b;
        _selectedBatchId = b?.id;
      });
    }
  }

  @override
  void dispose() {
    for (final entry in _feedEntries) {
      entry.dispose();
    }
    _medicineQtyController.dispose();
    _supplementQtyController.dispose();
    super.dispose();
  }

  void _autoDetectTimeSlot() {
    final now = DateTime.now();
    final timeNum = now.hour * 60 + now.minute;
    if (timeNum >= 300 && timeNum <= 570) {
      _selectedSlot = '7:00 AM';
    } else if (timeNum > 570 && timeNum <= 810) {
      _selectedSlot = '11:00 AM';
    } else if (timeNum > 810 && timeNum <= 1050) {
      _selectedSlot = '4:00 PM';
    } else if (timeNum > 1050 && timeNum <= 1320) {
      _selectedSlot = '7:00 PM';
    } else {
      _selectedSlot = '7:00 AM';
    }
  }

  double get _totalEnteredKg {
    return _feedEntries.fold(0.0, (sum, entry) => sum + entry.quantityKg);
  }

  void _addNewFeedEntry(List<InventoryItem> availableFeeds) {
    // Pick first available feed not already added, or the first available
    final usedIds = _feedEntries.map((e) => e.inventoryFeedId).toSet();
    final unused = availableFeeds.firstWhere(
      (f) => !usedIds.contains(f.id),
      orElse: () => availableFeeds.first,
    );
    setState(() {
      _feedEntries.add(_FeedEntryItem(
        inventoryFeedId: unused.id,
        initialQty: '5.0',
        unit: 'kg',
      ));
    });
  }

  void _removeFeedEntry(int index) {
    if (_feedEntries.length <= 1) return;
    setState(() {
      final removed = _feedEntries.removeAt(index);
      removed.dispose();
    });
  }

  void _showMultiFeedPicker(List<InventoryItem> selectableFeedItems) {
    final currentlySelectedIds = _feedEntries.map((e) => e.inventoryFeedId).whereType<String>().toSet();
    final tempSelectedIds = Set<String>.from(currentlySelectedIds);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPickerState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.checklist_rounded, color: Color(0xFF006876)),
              SizedBox(width: 8),
              Text('Select Multiple Feeds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select all feed products to record in this feeding session:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: selectableFeedItems.map((feed) {
                        final isSelected = tempSelectedIds.contains(feed.id);
                        final isOutOfStock = feed.currentStock <= 0;
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) {
                            setPickerState(() {
                              if (val == true) {
                                tempSelectedIds.add(feed.id);
                              } else {
                                tempSelectedIds.remove(feed.id);
                              }
                            });
                          },
                          title: Text(feed.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(
                            '${feed.brand ?? "Standard"} · ${feed.pelletSize ?? "Pellet"} · In Stock: ${feed.currentStock.toStringAsFixed(1)} kg',
                            style: TextStyle(
                              fontSize: 12,
                              color: isOutOfStock ? Colors.red : Colors.grey[600],
                              fontWeight: isOutOfStock ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          secondary: isOutOfStock
                              ? const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20)
                              : const Icon(Icons.inventory_2_outlined, color: Color(0xFF006876), size: 20),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.check_rounded, size: 16),
              label: Text('Apply (${tempSelectedIds.length} Feeds)'),
              onPressed: () {
                Navigator.of(ctx).pop();
                if (tempSelectedIds.isEmpty) return;

                setState(() {
                  // Keep entries that are still selected
                  final retained = _feedEntries.where((e) => tempSelectedIds.contains(e.inventoryFeedId)).toList();
                  final existingIds = retained.map((e) => e.inventoryFeedId).toSet();

                  // Add newly checked items
                  for (final id in tempSelectedIds) {
                    if (!existingIds.contains(id)) {
                      retained.add(_FeedEntryItem(
                        inventoryFeedId: id,
                        initialQty: '10.0',
                        unit: 'kg',
                      ));
                    }
                  }

                  // Dispose removed controllers
                  for (final old in _feedEntries) {
                    if (!retained.contains(old)) {
                      old.dispose();
                    }
                  }

                  _feedEntries.clear();
                  _feedEntries.addAll(retained);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFeedStockSheet(BuildContext context, String? siteId) {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController(text: 'CP Aqua');
    final pelletCtrl = TextEditingController(text: '2.0mm');
    final qtyCtrl = TextEditingController(text: '100');
    final costCtrl = TextEditingController(text: '92.0');
    final supplierCtrl = TextEditingController(text: 'Coastal Feeds');
    final lotCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          top: 24,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Feed Stock to Inventory',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Feed Product Name *',
                  hintText: 'e.g. CP Classic Grower 2.0',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: brandCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Brand / Manufacturer',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: pelletCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Pellet Size',
                        hintText: 'e.g. 1.5mm, 2.0mm',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Initial Quantity (kg) *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Cost per kg (₹) *',
                        border: OutlineInputBorder(),
                      ),
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
                      decoration: const InputDecoration(
                        labelText: 'Supplier',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: lotCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Batch / Lot #',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                    final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;

                    if (name.isEmpty || qty <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter valid feed name and quantity.')),
                      );
                      return;
                    }

                    final db = ref.read(appDatabaseProvider);
                    final itemId = 'feed_${DateTime.now().millisecondsSinceEpoch}';

                    await db.into(db.inventoryItems).insert(
                      InventoryItemsCompanion(
                        id: drift.Value(itemId),
                        siteId: drift.Value(siteId ?? 'site_1'),
                        category: const drift.Value('feed'),
                        name: drift.Value(name),
                        brand: drift.Value(brandCtrl.text.trim()),
                        pelletSize: drift.Value(pelletCtrl.text.trim()),
                        currentStock: drift.Value(qty),
                        unit: const drift.Value('kg'),
                        costPerUnit: drift.Value(cost),
                        lowStockThreshold: const drift.Value(20.0),
                        supplier: drift.Value(supplierCtrl.text.trim()),
                        batchLotNumber: drift.Value(lotCtrl.text.trim()),
                      ),
                    );

                    // Insert purchase transaction
                    await db.into(db.inventoryTransactions).insert(
                      InventoryTransactionsCompanion(
                        id: drift.Value('tx_${DateTime.now().millisecondsSinceEpoch}'),
                        itemId: drift.Value(itemId),
                        siteId: drift.Value(siteId ?? 'site_1'),
                        type: const drift.Value('purchase'),
                        quantity: drift.Value(qty),
                        unitPrice: drift.Value(cost),
                        totalCost: drift.Value(qty * cost),
                        date: drift.Value(DateTime.now()),
                        referenceType: const drift.Value('initial_stock'),
                        notes: drift.Value('Initial stock added from feed log screen'),
                      ),
                    );

                    ref.invalidate(allInventoryItemsStreamProvider);

                    if (mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✓ Feed stock "$name" ($qty kg) added to Inventory.')),
                      );
                    }
                  },
                  child: const Text('Save Stock to Inventory', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInsufficientStockDialog(String itemName, double available, double requested) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
        title: const Text('Insufficient Feed Stock', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cannot log feeding exceeding physical inventory.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Available in stock:'),
                      Text('${available.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Requested feed:'),
                      Text('${requested.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Please adjust the feed quantity or receive inward stock in Inventory before recording.', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InventoryHubPage()),
              );
            },
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
            label: const Text('Add Stock'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitFeedLog(List<InventoryItem> allInventory) async {
    if (_selectedPondId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a cultivation pond.')),
      );
      return;
    }

    if (_feedEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one feed product.')),
      );
      return;
    }

    // Prepare feed items
    final feedItemsToSave = <FeedItem>[];
    final feedDeductions = <Map<String, dynamic>>[];

    for (final entry in _feedEntries) {
      if (entry.inventoryFeedId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a feed stock for all items.')),
        );
        return;
      }

      final reqKg = entry.quantityKg;
      if (reqKg <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All feed quantities must be greater than 0.')),
        );
        return;
      }

      final invItem = allInventory.firstWhere(
        (i) => i.id == entry.inventoryFeedId,
        orElse: () => InventoryItem(
          id: entry.inventoryFeedId!,
          siteId: 'site_1',
          category: 'feed',
          name: 'Feed Product',
          currentStock: 0,
          unit: 'kg',
          costPerUnit: 0,
          lowStockThreshold: 10.0,
          bagWeightKg: 25.0,
          createdAt: DateTime.now(),
        ),
      );

      feedItemsToSave.add(FeedItem(
        inventoryFeedId: invItem.id,
        feedName: invItem.name,
        brand: invItem.brand,
        size: invItem.pelletSize,
        quantity: entry.enteredQty,
        unit: entry.unit,
        bagWeightKg: invItem.bagWeightKg,
      ));

      feedDeductions.add({
        'itemId': invItem.id,
        'qtyKg': reqKg,
        'pelletSize': invItem.pelletSize ?? '2.0mm',
      });
    }

    // Stock availability validation
    final stockMap = <String, double>{
      for (final it in allInventory) it.id: it.currentStock,
    };

    // If editing, existing stock deduction will be reversed in the database transaction,
    // so available stock includes what was previously deducted for this record
    if (_isEditMode) {
      final oldItems = FeedCalculator.getRecordItems(widget.editRecord!);
      for (final oldIt in oldItems) {
        if (oldIt.inventoryFeedId != null) {
          stockMap[oldIt.inventoryFeedId!] =
              (stockMap[oldIt.inventoryFeedId!] ?? 0.0) + oldIt.quantityKg;
        }
      }
    }

    final stockValidation = FeedCalculator.validateFeedInventoryAvailability(
      requestedItems: feedItemsToSave,
      availableStockByInventoryId: stockMap,
      feedNamesById: {for (final it in allInventory) it.id: it.name},
    );

    if (!stockValidation.isValid) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
          title: const Text('Insufficient Stock', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The following items exceed available physical inventory:'),
              const SizedBox(height: 8),
              ...stockValidation.errors.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('• $e', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
              )),
              const SizedBox(height: 12),
              const Text('Please adjust quantities or add inward stock in Inventory.', style: TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Co-feeding Optional Additions Validation
    final medicineDeductions = <Map<String, dynamic>>[];
    final supplementDeductions = <Map<String, dynamic>>[];
    final coFedList = <Map<String, dynamic>>[];

    if (_addMedicine && _selectedMedicineItemId != null) {
      final medItem = allInventory.where((i) => i.id == _selectedMedicineItemId).firstOrNull;
      final medQty = double.tryParse(_medicineQtyController.text.trim()) ?? 0.0;
      if (medItem != null && medQty > 0) {
        if (medQty > medItem.currentStock) {
          _showInsufficientStockDialog(medItem.name, medItem.currentStock, medQty);
          return;
        }
        medicineDeductions.add({'itemId': medItem.id, 'qty': medQty, 'unit': medItem.unit});
        coFedList.add({'name': medItem.name, 'qty': medQty, 'unit': medItem.unit, 'type': 'medicine'});
      }
    }

    if (_addSupplement && _selectedSupplementItemId != null) {
      final supItem = allInventory.where((i) => i.id == _selectedSupplementItemId).firstOrNull;
      final supQty = double.tryParse(_supplementQtyController.text.trim()) ?? 0.0;
      if (supItem != null && supQty > 0) {
        if (supQty > supItem.currentStock) {
          _showInsufficientStockDialog(supItem.name, supItem.currentStock, supQty);
          return;
        }
        supplementDeductions.add({'itemId': supItem.id, 'qty': supQty, 'unit': supItem.unit});
        coFedList.add({'name': supItem.name, 'qty': supQty, 'unit': supItem.unit, 'type': 'supplement'});
      }
    }

    final coFedJson = coFedList.isNotEmpty ? jsonEncode(coFedList) : null;
    final feedItemsJson = jsonEncode(feedItemsToSave.map((i) => i.toJson()).toList());
    final totalSessionKg = _totalEnteredKg;

    // Two-tap safety protection for new records
    final now = DateTime.now();
    if (!_isEditMode && (_firstTapTime == null || now.difference(_firstTapTime!).inSeconds > 5)) {
      final db = ref.read(appDatabaseProvider);
      final existing = await (db.select(db.feedRecords)
            ..where((t) =>
                t.pondId.equals(_selectedPondId!) &
                t.timeSlot.equals(_selectedSlot) &
                t.date.equals(_selectedDate)))
          .get();

      if (existing.isNotEmpty) {
        setState(() {
          _duplicateWarning = true;
          _firstTapTime = now;
        });
        return;
      }
    }

    setState(() => _isSaving = true);
    final db = ref.read(appDatabaseProvider);

    try {
      final batch = await (db.select(db.batches)
            ..where((t) => t.pondId.equals(_selectedPondId!) & t.status.equals('active')))
          .getSingleOrNull();

      final batchId = _selectedBatchId ?? (_isEditMode ? widget.editRecord!.batchId : (batch?.id ?? 'batch_default'));
      final recordId = _isEditMode ? widget.editRecord!.id : 'feed_${DateTime.now().millisecondsSinceEpoch}';

      final primaryItem = feedItemsToSave.first;
      final feedNotes = feedItemsToSave.length == 1
          ? 'Feed: ${primaryItem.feedName} (${primaryItem.size ?? ""})'
          : 'Multi-Feed (${feedItemsToSave.length} types): ${feedItemsToSave.map((i) => "${i.feedName} ${i.quantityKg.toStringAsFixed(1)}kg").join(", ")}';

      final feedCompanion = FeedRecordsCompanion(
        id: drift.Value(recordId),
        batchId: drift.Value(batchId),
        pondId: drift.Value(_selectedPondId!),
        date: drift.Value(_selectedDate),
        timeSlot: drift.Value(_selectedSlot),
        starterG: const drift.Value(0.0),
        grower1G: const drift.Value(0.0),
        grower2G: const drift.Value(0.0),
        finisher1G: const drift.Value(0.0),
        finisher2G: const drift.Value(0.0),
        otherFeedName: drift.Value(primaryItem.feedName),
        otherFeedG: drift.Value(totalSessionKg * 1000.0),
        totalGrams: drift.Value(totalSessionKg * 1000.0),
        totalKg: drift.Value(totalSessionKg),
        trayChecked: drift.Value(_trayChecked),
        trayLeftoverPct: drift.Value(_trayLeftoverPct),
        coFedMedicinesJson: drift.Value(coFedJson),
        feedItemsJson: drift.Value(feedItemsJson),
        notes: drift.Value(feedNotes),
      );

      if (_isEditMode) {
        await db.updateFeedSessionTransaction(
          feedRecord: feedCompanion,
          feedDeductions: feedDeductions,
          medicineDeductions: medicineDeductions.isNotEmpty ? medicineDeductions : null,
          supplementDeductions: supplementDeductions.isNotEmpty ? supplementDeductions : null,
        );
      } else {
        await db.logFeedSessionTransaction(
          feedRecord: feedCompanion,
          feedDeductions: feedDeductions,
          medicineDeductions: medicineDeductions.isNotEmpty ? medicineDeductions : null,
          supplementDeductions: supplementDeductions.isNotEmpty ? supplementDeductions : null,
        );
      }

      // Reactive state refresh
      ref.invalidate(feedRecordsStreamProvider);
      ref.invalidate(batchDashboardDataProvider(batchId));
      ref.invalidate(allInventoryItemsStreamProvider);

      if (mounted) {
        setState(() {
          _isSaving = false;
          _duplicateWarning = false;
          _medicineQtyController.clear();
          _supplementQtyController.clear();
          _addMedicine = false;
          _addSupplement = false;
        });

        final actionWord = _isEditMode ? 'Updated' : 'Recorded';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ $actionWord: ${totalSessionKg.toStringAsFixed(1)} kg (${feedItemsToSave.length} feed item${feedItemsToSave.length > 1 ? "s" : ""}) for $_selectedSlot',
            ),
            backgroundColor: const Color(0xFF006876),
          ),
        );

        widget.onFeedLogged?.call();
        if (_isEditMode) {
          Navigator.of(context).pop();
        }
      }
    } on InsufficientStockException catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showInsufficientStockDialog(e.itemName, e.availableStock, e.requestedQuantity);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Feed record failed: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final sitesAsync = ref.watch(allSitesStreamProvider);
    final pondsAsync = ref.watch(allPondsStreamProvider);
    final batchesAsync = ref.watch(allBatchesMasterStreamProvider);
    final inventoryAsync = ref.watch(allInventoryItemsStreamProvider);
    final feedRecordsAsync = ref.watch(feedRecordsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditMode ? 'Edit Feed Session' : settings.tr('feed_logging_title'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Feed Inventory Master · Dynamic Allocation',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: sitesAsync.when(
        data: (allSites) {
          return pondsAsync.when(
            data: (ponds) {
              final allBatches = batchesAsync.valueOrNull ?? [];

              if (ponds.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.water_rounded, size: 48, color: theme.colorScheme.primary.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'No Ponds Registered',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Create a pond under your farm site before recording feeding.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (_selectedPondId == null && ponds.isNotEmpty) {
                _selectedPondId = ponds.first.id;
              }

              final selectedPond = ponds.firstWhere(
                (p) => p.id == _selectedPondId,
                orElse: () => ponds.first,
              );

              if (_selectedSiteId == null && selectedPond.siteId != null) {
                _selectedSiteId = selectedPond.siteId;
              }

          return inventoryAsync.when(
            data: (allInventory) {
              // Master Rule: Feed items in Feed Inventory are selectable for feed logs
              final activeFeedItems = allInventory
                  .where((i) => i.category.toLowerCase() == 'feed')
                  .toList();

              // In edit mode, allow the item even if discontinued to preserve history
              final selectableFeedItems = List<InventoryItem>.from(activeFeedItems);
              if (_isEditMode) {
                for (final entry in _feedEntries) {
                  if (entry.inventoryFeedId != null &&
                      !selectableFeedItems.any((i) => i.id == entry.inventoryFeedId)) {
                    final found = allInventory.where((i) => i.id == entry.inventoryFeedId).firstOrNull;
                    if (found != null) {
                      selectableFeedItems.add(found);
                    }
                  }
                }
              }

              if (selectableFeedItems.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.inventory_2_outlined, size: 48, color: theme.colorScheme.error),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Active Feed in Inventory',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AquaLog requires feed items to be defined in Feed Inventory. Add a feed product to start logging.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => _showAddFeedStockSheet(context, selectedPond.siteId),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Feed to Inventory'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Ensure every entry has a valid inventory ID
              for (final entry in _feedEntries) {
                if (entry.inventoryFeedId == null ||
                    !selectableFeedItems.any((i) => i.id == entry.inventoryFeedId)) {
                  entry.inventoryFeedId = selectableFeedItems.first.id;
                }
              }

              final allFeedRecords = feedRecordsAsync.valueOrNull ?? [];
              // Find previous feed session for previous feed comparison
              final prevSession = FeedCalculator.getPreviousFeedSession(
                records: allFeedRecords,
                batchId: widget.editRecord?.batchId ?? 'batch_default',
                pondId: _selectedPondId,
                currentDate: _selectedDate,
                currentTimeSlot: _selectedSlot,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date & Time Slot Selector
                    _buildSessionBar(theme),
                    const SizedBox(height: 14),

                    // Cascading Site -> Pond -> Batch Selector
                    _buildCascadingSelector(
                      theme: theme,
                      sites: allSites,
                      ponds: ponds,
                      batches: allBatches,
                    ),
                    const SizedBox(height: 16),

                    // Section 3: Dynamic Feed Items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Feed Items (${_feedEntries.length})',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Wrap(
                          spacing: 4,
                          children: [
                            TextButton.icon(
                              onPressed: () => _showAddFeedStockSheet(context, selectedPond.siteId),
                              icon: const Icon(Icons.inventory_2_outlined, size: 15),
                              label: const Text('Stock In'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => _showMultiFeedPicker(selectableFeedItems),
                              icon: const Icon(Icons.checklist_rounded, size: 16),
                              label: const Text('Select Feeds'),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => _addNewFeedEntry(selectableFeedItems),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('+ Row'),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // List of Feed Items
                    ..._feedEntries.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final itemEntry = entry.value;
                      final selectedInvItem = selectableFeedItems.firstWhere(
                        (i) => i.id == itemEntry.inventoryFeedId,
                        orElse: () => selectableFeedItems.first,
                      );

                      // Previous session comparison for this item
                      final currentFeedItem = FeedItem(
                        inventoryFeedId: selectedInvItem.id,
                        feedName: selectedInvItem.name,
                        size: selectedInvItem.pelletSize,
                        quantity: itemEntry.enteredQty,
                        unit: itemEntry.unit,
                      );

                      final changeData = FeedCalculator.getItemQuantityChange(
                        currentItem: currentFeedItem,
                        previousRecord: prevSession,
                      );

                      return _buildFeedEntryCard(
                        theme: theme,
                        index: idx,
                        entry: itemEntry,
                        selectedInvItem: selectedInvItem,
                        availableFeeds: selectableFeedItems,
                        changeData: changeData,
                      );
                    }),
                    const SizedBox(height: 12),

                    // Total Feed Summary Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF006876).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF006876).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL FEED SESSION',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF006876),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_feedEntries.length} feed product${_feedEntries.length > 1 ? "s" : ""} selected',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          Text(
                            '${_totalEnteredKg.toStringAsFixed(2)} kg',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF006876),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Optional Additions Section (Medicine / Supplement)
                    _buildOptionalAdditionsSection(theme, allInventory),
                    const SizedBox(height: 14),

                    // Check Tray Feedback Section
                    _buildCheckTraySection(theme),
                    const SizedBox(height: 18),

                    // Duplicate Warning Banner if applicable
                    if (_duplicateWarning)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Warning: Feed has already been logged for this time slot. Tap again to confirm duplicate log.',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _isSaving ? null : () => _submitFeedLog(allInventory),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF006876),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : Text(
                                _duplicateWarning
                                    ? 'Confirm Duplicate Log'
                                    : _isEditMode
                                        ? 'Update Feed Session (${_totalEnteredKg.toStringAsFixed(1)} kg)'
                                        : 'Save Feed (${_totalEnteredKg.toStringAsFixed(1)} kg)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading inventory: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading ponds: $e')),
      );
    },
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => Center(child: Text('Error loading sites: $e')),
  ),
);
  }

  Widget _buildFeedEntryCard({
    required ThemeData theme,
    required int index,
    required _FeedEntryItem entry,
    required InventoryItem selectedInvItem,
    required List<InventoryItem> availableFeeds,
    required Map<String, dynamic> changeData,
  }) {
    final isOutOfStock = selectedInvItem.currentStock <= 0;
    final isLowStock = selectedInvItem.currentStock <= selectedInvItem.lowStockThreshold && !isOutOfStock;
    final prevQtyKg = (changeData['previousQtyKg'] as num?)?.toDouble() ?? 0.0;
    final diffKg = (changeData['diffKg'] as num?)?.toDouble() ?? 0.0;
    final changeStatus = changeData['status'] as String? ?? 'new';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF006876).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Feed #${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF006876)),
                ),
              ),
              const Spacer(),
              if (_feedEntries.length > 1)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.red),
                  onPressed: () => _removeFeedEntry(index),
                  tooltip: 'Remove Feed Item',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Feed Product Dropdown (from Feed Inventory)
          DropdownButtonFormField<String>(
            value: entry.inventoryFeedId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select Feed from Inventory *',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: availableFeeds.map((feed) {
              return DropdownMenuItem<String>(
                value: feed.id,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${feed.name}${feed.pelletSize != null ? " (${feed.pelletSize})" : ""}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: feed.currentStock <= 0 ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    Text(
                      'Stock: ${feed.currentStock.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontSize: 11,
                        color: feed.currentStock <= 0 ? Colors.red : Colors.green[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (newId) {
              if (newId != null) {
                setState(() => entry.inventoryFeedId = newId);
              }
            },
          ),
          const SizedBox(height: 10),

          // Quantity Input and Unit
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: entry.quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Quantity *',
                    hintText: 'Enter quantity',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: entry.unit,
                        items: [
                          const DropdownMenuItem(value: 'kg', child: Text('kg')),
                          const DropdownMenuItem(value: 'grams', child: Text('grams')),
                          DropdownMenuItem(
                            value: 'bags',
                            child: Text('bags (${selectedInvItem.bagWeightKg.toStringAsFixed(0)}kg)'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              entry.unit = v;
                              entry.bagWeightKg = selectedInvItem.bagWeightKg;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              // Available stock indicator
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isOutOfStock
                        ? Colors.red.withOpacity(0.1)
                        : isLowStock
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isOutOfStock
                          ? Colors.red.withOpacity(0.3)
                          : isLowStock
                              ? Colors.orange.withOpacity(0.3)
                              : Colors.green.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'In Stock',
                        style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        '${selectedInvItem.currentStock.toStringAsFixed(1)} kg',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isOutOfStock
                              ? Colors.red
                              : isLowStock
                                  ? Colors.orange[800]
                                  : Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Previous Feeding Reference & Change Indicator (Rule 25 & 26)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      changeStatus == 'new'
                          ? 'Previous: No prior record'
                          : 'Previous: ${prevQtyKg.toStringAsFixed(1)} kg',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                _buildQuantityChangeBadge(changeStatus, diffKg),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityChangeBadge(String status, double diffKg) {
    if (status == 'increase') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_upward_rounded, size: 12, color: Colors.orange),
            const SizedBox(width: 2),
            Text('+${diffKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
          ],
        ),
      );
    } else if (status == 'decrease') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_downward_rounded, size: 12, color: Colors.blue),
            const SizedBox(width: 2),
            Text('${diffKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
          ],
        ),
      );
    } else if (status == 'same') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 12, color: Colors.green),
            SizedBox(width: 2),
            Text('Same', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF006876).withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('New item', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF006876))),
      );
    }
  }

  Widget _buildSessionBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 90)),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                if (_selectedPondId != null) {
                  _resolveBatchForPondAndDate(_selectedPondId!, picked);
                }
              }
            },
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF006876)),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd MMM yyyy').format(_selectedDate),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSlot,
              items: ['7:00 AM', '11:00 AM', '4:00 PM', '7:00 PM', 'Other'].map((s) {
                return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)));
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedSlot = v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCascadingSelector({
    required ThemeData theme,
    required List<FarmSite> sites,
    required List<Pond> ponds,
    required List<Batch> batches,
  }) {
    final siteMap = {for (final s in sites) s.id: s};
    final sitePonds = sites.isNotEmpty && _selectedSiteId != null
        ? ponds.where((p) => p.siteId == _selectedSiteId).toList()
        : ponds;

    final activeBatch = _resolvedBatch ??
        batches.where((b) => b.pondId == _selectedPondId && b.status == 'active').firstOrNull;

    DocResult? docRes;
    if (activeBatch != null) {
      docRes = DocCalculator.calculate(stockingDate: activeBatch.stockingDate, targetDate: _selectedDate);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Site Selector (if more than 1 site exists)
          if (sites.length > 1) ...[
            Text(
              'Farm Site',
              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedSiteId,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                prefixIcon: Icon(Icons.business_rounded, size: 18),
              ),
              items: sites.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedSiteId = v;
                    final newPonds = ponds.where((p) => p.siteId == v).toList();
                    if (newPonds.isNotEmpty) {
                      _selectedPondId = newPonds.first.id;
                      _resolveBatchForPondAndDate(_selectedPondId!, _selectedDate);
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 12),
          ],

          // 2. Pond Selector
          Text(
            'Cultivation Pond',
            style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedPondId,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon: Icon(Icons.water_rounded, size: 18),
            ),
            items: (sitePonds.isNotEmpty ? sitePonds : ponds).map((p) {
              final sName = p.siteId != null && siteMap.containsKey(p.siteId!) ? ' · ${siteMap[p.siteId!]!.name}' : '';
              return DropdownMenuItem(
                value: p.id,
                child: Text('${p.name} (${p.areaSqMeters.toInt()} m²$sName)'),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _selectedPondId = v);
                _resolveBatchForPondAndDate(v, _selectedDate);
              }
            },
          ),
          const SizedBox(height: 12),

          // 3. Auto-Resolved Batch Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: activeBatch != null
                  ? const Color(0xFF006876).withOpacity(0.08)
                  : Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: activeBatch != null
                    ? const Color(0xFF006876).withOpacity(0.25)
                    : Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  activeBatch != null ? Icons.verified_rounded : Icons.info_outline_rounded,
                  size: 20,
                  color: activeBatch != null ? const Color(0xFF006876) : Colors.orange[800],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: activeBatch != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Batch #${activeBatch.batchNumber} · ${activeBatch.species}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF006876)),
                                ),
                                if (docRes != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF006876),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'DOC ${docRes.doc}',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Stocked: ${DateFormat("dd MMM yyyy").format(activeBatch.stockingDate)} · ${activeBatch.shrimpStockedCount} PLs · Target DOC: ${activeBatch.targetDoc}',
                              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                            ),
                          ],
                        )
                      : Text(
                          'No active batch registered for this pond on ${DateFormat("dd MMM").format(_selectedDate)}. Feeding will be recorded under standard default cycle.',
                          style: TextStyle(fontSize: 12, color: Colors.orange[900]),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckTraySection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Check Tray Inspection (2.5h Post-Feed)',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Switch(
                value: _trayChecked,
                onChanged: (v) => setState(() => _trayChecked = v),
              ),
            ],
          ),
          if (_trayChecked) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTrayButton(0, 'Clean (0%)', Icons.check_circle_outline, Colors.green),
                _buildTrayButton(25, 'Normal (25%)', Icons.radio_button_checked, Colors.blue),
                _buildTrayButton(50, 'Surplus (50%+)', Icons.warning_amber_rounded, Colors.orange),
              ],
            ),
            const SizedBox(height: 10),
            AquaTrayBadge(
              leftoverPct: _trayLeftoverPct,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrayButton(int pct, String label, IconData icon, Color color) {
    final isSelected = _trayLeftoverPct == pct;
    return InkWell(
      onTap: () => setState(() => _trayLeftoverPct = pct),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionalAdditionsSection(ThemeData theme, List<InventoryItem> allInventory) {
    final medicineItems = allInventory.where((i) => i.category.toLowerCase() == 'medicine' && i.currentStock > 0).toList();
    final supplementItems = allInventory.where((i) => i.category.toLowerCase() == 'supplement' && i.currentStock > 0).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Optional Additions (Co-Feeding)',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Optional',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Chips to toggle optional medicine / supplement
          Row(
            children: [
              FilterChip(
                selected: _addMedicine,
                avatar: const Icon(Icons.medication_rounded, size: 16),
                label: const Text('+ Medicine'),
                onSelected: (val) {
                  setState(() {
                    _addMedicine = val;
                    if (val && _selectedMedicineItemId == null && medicineItems.isNotEmpty) {
                      _selectedMedicineItemId = medicineItems.first.id;
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: _addSupplement,
                avatar: const Icon(Icons.science_rounded, size: 16),
                label: const Text('+ Supplement'),
                onSelected: (val) {
                  setState(() {
                    _addSupplement = val;
                    if (val && _selectedSupplementItemId == null && supplementItems.isNotEmpty) {
                      _selectedSupplementItemId = supplementItems.first.id;
                    }
                  });
                },
              ),
            ],
          ),

          // Medicine Configuration Card
          if (_addMedicine) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Medicine Addition', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.red[800])),
                  const SizedBox(height: 8),
                  if (medicineItems.isEmpty)
                    const Text('No medicine stock available in inventory. Add medicine in Inventory first.', style: TextStyle(fontSize: 12, color: Colors.red))
                  else ...[
                    DropdownButtonFormField<String>(
                      value: medicineItems.any((i) => i.id == _selectedMedicineItemId)
                          ? _selectedMedicineItemId
                          : medicineItems.first.id,
                      decoration: const InputDecoration(labelText: 'Select Medicine Product', isDense: true),
                      items: medicineItems.map((item) {
                        return DropdownMenuItem<String>(
                          value: item.id,
                          child: Text('${item.name} (Avail: ${item.currentStock.toStringAsFixed(1)} ${item.unit})'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedMedicineItemId = val),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _medicineQtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Dosage Quantity *',
                        suffixText: 'g / ml',
                        isDense: true,
                        helperText: 'Deducted directly from physical medicine inventory',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Supplement Configuration Card
          if (_addSupplement) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Supplement Addition', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.brown[800])),
                  const SizedBox(height: 8),
                  if (supplementItems.isEmpty)
                    const Text('No supplement stock available in inventory. Add supplement in Inventory first.', style: TextStyle(fontSize: 12, color: Colors.brown))
                  else ...[
                    DropdownButtonFormField<String>(
                      value: supplementItems.any((i) => i.id == _selectedSupplementItemId)
                          ? _selectedSupplementItemId
                          : supplementItems.first.id,
                      decoration: const InputDecoration(labelText: 'Select Supplement Product', isDense: true),
                      items: supplementItems.map((item) {
                        return DropdownMenuItem<String>(
                          value: item.id,
                          child: Text('${item.name} (Avail: ${item.currentStock.toStringAsFixed(1)} ${item.unit})'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedSupplementItemId = val),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _supplementQtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Supplement Quantity *',
                        suffixText: 'g / ml',
                        isDense: true,
                        helperText: 'Deducted directly from physical supplement inventory',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
