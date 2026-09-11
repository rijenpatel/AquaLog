import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'tables.dart';
import '../calculations/sampling_calculator.dart';

export 'package:drift/drift.dart' hide Column, Table;

part 'app_database.g.dart';

typedef Batch = Batche;

class InsufficientStockException implements Exception {
  final String itemName;
  final double availableStock;
  final double requestedQuantity;
  final String unit;

  InsufficientStockException({
    required this.itemName,
    required this.availableStock,
    required this.requestedQuantity,
    this.unit = 'kg',
  });

  @override
  String toString() =>
      'Insufficient stock for $itemName: Available ${availableStock.toStringAsFixed(1)} $unit, requested ${requestedQuantity.toStringAsFixed(1)} $unit.';
}

class InventoryItemNotFoundException implements Exception {
  final String itemId;
  final String? itemType;

  InventoryItemNotFoundException({required this.itemId, this.itemType});

  @override
  String toString() =>
      'Inventory ${itemType ?? 'item'} with ID "$itemId" does not exist.';
}

class InvalidInventoryCategoryException implements Exception {
  final String itemId;
  final String expectedCategory;
  final String actualCategory;

  InvalidInventoryCategoryException({
    required this.itemId,
    required this.expectedCategory,
    required this.actualCategory,
  });

  @override
  String toString() =>
      'Inventory item "$itemId" is of category "$actualCategory", expected "$expectedCategory".';
}

class InvalidInventoryQuantityException implements Exception {
  final double quantity;
  final String message;

  InvalidInventoryQuantityException(this.quantity, [this.message = 'Inventory transaction quantity must be positive.']);

  @override
  String toString() => '$message (Provided: $quantity)';
}

class InvalidInventoryCostException implements Exception {
  final double cost;
  final String message;

  InvalidInventoryCostException(this.cost, [this.message = 'Inventory cost cannot be negative.']);

  @override
  String toString() => '$message (Provided: $cost)';
}

class DependentRecordsExistException implements Exception {
  final String entityType;
  final String entityId;
  final String details;

  DependentRecordsExistException({
    required this.entityType,
    required this.entityId,
    required this.details,
  });

  @override
  String toString() =>
      'Cannot delete $entityType "$entityId" because dependent records exist: $details';
}

class BatchPeriodOverlapException implements Exception {
  final String pondId;
  final int conflictingBatchNumber;
  final String conflictingBatchId;
  final String message;

  BatchPeriodOverlapException({
    required this.pondId,
    required this.conflictingBatchNumber,
    required this.conflictingBatchId,
    required this.message,
  });

  @override
  String toString() => message;
}

class DeleteSafetyCheck {
  final bool canDelete;
  final int linkedPonds;
  final int linkedBatches;
  final int linkedFeedRecords;
  final int linkedSamplings;
  final int linkedWaterLogs;
  final int linkedHarvests;
  final int linkedExpenses;
  final int linkedInventory;
  final int linkedTransactions;
  final int linkedMachineRuns;
  final int linkedWeather;
  final int linkedHapaChecks;
  final int linkedGrowthRecords;
  final int linkedBiomassSnapshots;
  final int linkedTreatments;
  final int linkedMortalities;
  final int linkedOperations;
  final int linkedActionTasks;
  final int linkedFeedPlans;
  final Map<String, int> dependencyBreakdown;

  const DeleteSafetyCheck({
    required this.canDelete,
    this.linkedPonds = 0,
    this.linkedBatches = 0,
    this.linkedFeedRecords = 0,
    this.linkedSamplings = 0,
    this.linkedWaterLogs = 0,
    this.linkedHarvests = 0,
    this.linkedExpenses = 0,
    this.linkedInventory = 0,
    this.linkedTransactions = 0,
    this.linkedMachineRuns = 0,
    this.linkedWeather = 0,
    this.linkedHapaChecks = 0,
    this.linkedGrowthRecords = 0,
    this.linkedBiomassSnapshots = 0,
    this.linkedTreatments = 0,
    this.linkedMortalities = 0,
    this.linkedOperations = 0,
    this.linkedActionTasks = 0,
    this.linkedFeedPlans = 0,
    this.dependencyBreakdown = const {},
  });

  int get totalDependencies => dependencyBreakdown.values.fold<int>(0, (sum, count) => sum + count);
}

@DriftDatabase(tables: [
  UserProfiles,
  FarmSites,
  Ponds,
  Batches,
  FeedRecords,
  SamplingEntries,
  HapaChecks,
  GrowthRecords,
  BiomassSnapshots,
  InventoryItems,
  InventoryTransactions,
  Expenses,
  Revenues,
  MarketPrices,
  MachineRuns,
  TreatmentRecords,
  WeatherObservations,
  WaterQualityLogs,
  MortalityRecords,
  PopulationAdjustments,
  PondOperations,
  FarmActionTasks,
  DailyFeedPlans,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(userProfiles);
            await m.addColumn(farmSites, farmSites.code);
            await m.addColumn(farmSites, farmSites.waterSource);
            await m.addColumn(farmSites, farmSites.villageCity);
            await m.addColumn(farmSites, farmSites.district);
            await m.addColumn(farmSites, farmSites.state);
            await m.addColumn(farmSites, farmSites.country);
            await m.addColumn(farmSites, farmSites.postalCode);
            await m.addColumn(weatherObservations, weatherObservations.feelsLike);
            await m.addColumn(weatherObservations, weatherObservations.windSpeed);
            await m.addColumn(weatherObservations, weatherObservations.uvIndex);
          }
          if (from < 3) {
            await m.addColumn(batches, batches.hapaStockedCount);
            await m.addColumn(batches, batches.targetDoc);
          }
          if (from < 4) {
            await m.createTable(waterQualityLogs);
            await m.createTable(mortalityRecords);
            await m.createTable(populationAdjustments);
            await m.createTable(pondOperations);
            await m.createTable(farmActionTasks);
            await m.createTable(dailyFeedPlans);
          }
        },
      );

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'aqualog_farm.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }

  // ── ATOMIC TRANSACTIONS ──────────────────────────────────────────

  /// Log Feed Session Transaction:
  /// 1. Insert FeedRecord
  /// 2. Deduct Feed Stock from InventoryItems (for each pellet size fed)
  /// 3. Record InventoryTransactions (consumption)
  /// 4. Deduct co-fed medicines if selected
  /// 5. Deduct co-fed supplements if selected
  Future<void> logFeedSessionTransaction({
    required FeedRecordsCompanion feedRecord,
    required List<Map<String, dynamic>> feedDeductions, // [{itemId, qtyKg, pelletSize}]
    List<Map<String, dynamic>>? medicineDeductions, // [{itemId, qty, unit}]
    List<Map<String, dynamic>>? supplementDeductions, // [{itemId, qty, unit}]
  }) async {
    return transaction(() async {
      // 1. Insert Feed Record
      await into(feedRecords).insert(feedRecord);

      // 2. Deduct Feed Items from Inventory
      for (final deduction in feedDeductions) {
        final itemId = deduction['itemId'] as String;
        final qtyKg = (deduction['qtyKg'] as num).toDouble();
        if (qtyKg <= 0) continue;

        final item = await (select(inventoryItems)..where((t) => t.id.equals(itemId))).getSingleOrNull();
        if (item == null) {
          throw InventoryItemNotFoundException(itemId: itemId, itemType: 'feed');
        }
        if (item.category.toLowerCase() != 'feed') {
          throw InvalidInventoryCategoryException(
            itemId: itemId,
            expectedCategory: 'feed',
            actualCategory: item.category,
          );
        }

        if (item.currentStock < qtyKg) {
          throw InsufficientStockException(
            itemName: item.name,
            availableStock: item.currentStock,
            requestedQuantity: qtyKg,
            unit: item.unit,
          );
        }

        final newStock = item.currentStock - qtyKg;
        await (update(inventoryItems)..where((t) => t.id.equals(itemId))).write(
          InventoryItemsCompanion(currentStock: Value(newStock)),
        );

        await into(inventoryTransactions).insert(
          InventoryTransactionsCompanion(
            id: Value('tx_${const Uuid().v4()}'),
            itemId: Value(item.id),
            siteId: Value(item.siteId),
            type: const Value('consumption'),
            quantity: Value(-qtyKg),
            unitPrice: Value(item.costPerUnit),
            totalCost: Value(qtyKg * item.costPerUnit),
            date: Value(feedRecord.date.value),
            referenceRecordId: Value(feedRecord.id.value),
            referenceType: const Value('feed_log'),
            notes: Value('Feed log: ${feedRecord.timeSlot.value}'),
          ),
        );
      }

      // 3. Deduct Co-Fed Medicines
      if (medicineDeductions != null) {
        for (final med in medicineDeductions) {
          final itemId = med['itemId'] as String;
          final qty = (med['qty'] as num).toDouble();
          if (qty <= 0) continue;

          final item = await (select(inventoryItems)..where((t) => t.id.equals(itemId))).getSingleOrNull();
          if (item == null) {
            throw InventoryItemNotFoundException(itemId: itemId, itemType: 'medicine');
          }
          if (item.category.toLowerCase() != 'medicine') {
            throw InvalidInventoryCategoryException(
              itemId: itemId,
              expectedCategory: 'medicine',
              actualCategory: item.category,
            );
          }

          if (item.currentStock < qty) {
            throw InsufficientStockException(
              itemName: item.name,
              availableStock: item.currentStock,
              requestedQuantity: qty,
              unit: item.unit,
            );
          }

          final newStock = item.currentStock - qty;
          await (update(inventoryItems)..where((t) => t.id.equals(itemId))).write(
            InventoryItemsCompanion(currentStock: Value(newStock)),
          );

          await into(inventoryTransactions).insert(
            InventoryTransactionsCompanion(
              id: Value('tx_med_${const Uuid().v4()}'),
              itemId: Value(item.id),
              siteId: Value(item.siteId),
              type: const Value('consumption'),
              quantity: Value(-qty),
              unitPrice: Value(item.costPerUnit),
              totalCost: Value(qty * item.costPerUnit),
              date: Value(feedRecord.date.value),
              referenceRecordId: Value(feedRecord.id.value),
              referenceType: const Value('co_feed_medicine'),
              notes: Value('Co-fed with ${feedRecord.timeSlot.value} feed'),
            ),
          );
        }
      }

      // 4. Deduct Co-Fed Supplements
      if (supplementDeductions != null) {
        for (final sup in supplementDeductions) {
          final itemId = sup['itemId'] as String;
          final qty = (sup['qty'] as num).toDouble();
          if (qty <= 0) continue;

          final item = await (select(inventoryItems)..where((t) => t.id.equals(itemId))).getSingleOrNull();
          if (item == null) {
            throw InventoryItemNotFoundException(itemId: itemId, itemType: 'supplement');
          }
          final cat = item.category.toLowerCase();
          if (cat != 'supplement' && cat != 'supplements' && cat != 'medicine') {
            throw InvalidInventoryCategoryException(
              itemId: itemId,
              expectedCategory: 'supplement',
              actualCategory: item.category,
            );
          }

          if (item.currentStock < qty) {
            throw InsufficientStockException(
              itemName: item.name,
              availableStock: item.currentStock,
              requestedQuantity: qty,
              unit: item.unit,
            );
          }

          final newStock = item.currentStock - qty;
          await (update(inventoryItems)..where((t) => t.id.equals(itemId))).write(
            InventoryItemsCompanion(currentStock: Value(newStock)),
          );

          await into(inventoryTransactions).insert(
            InventoryTransactionsCompanion(
              id: Value('tx_sup_${const Uuid().v4()}'),
              itemId: Value(item.id),
              siteId: Value(item.siteId),
              type: const Value('consumption'),
              quantity: Value(-qty),
              unitPrice: Value(item.costPerUnit),
              totalCost: Value(qty * item.costPerUnit),
              date: Value(feedRecord.date.value),
              referenceRecordId: Value(feedRecord.id.value),
              referenceType: const Value('co_feed_supplement'),
              notes: Value('Co-fed with ${feedRecord.timeSlot.value} feed'),
            ),
          );
        }
      }
    });
  }

  /// Update an existing Feed Session:
  /// 1. Reverses/restores stock from previous consumption transactions linked to this feed record
  /// 2. Deletes old transactions
  /// 3. Validates and deducts new feed stock
  /// 4. Inserts new consumption transactions
  /// 5. Updates the FeedRecord row
  Future<void> updateFeedSessionTransaction({
    required FeedRecordsCompanion feedRecord,
    required List<Map<String, dynamic>> feedDeductions, // [{itemId, qtyKg, pelletSize}]
    List<Map<String, dynamic>>? medicineDeductions,
    List<Map<String, dynamic>>? supplementDeductions,
  }) async {
    return transaction(() async {
      final recordId = feedRecord.id.value;

      // 1. Restore stock from previous transactions
      final oldTxs = await (select(inventoryTransactions)..where((t) => t.referenceRecordId.equals(recordId))).get();
      for (final tx in oldTxs) {
        final item = await (select(inventoryItems)..where((t) => t.id.equals(tx.itemId))).getSingleOrNull();
        if (item != null) {
          final restoredStock = item.currentStock - tx.quantity; // tx.quantity is negative
          await (update(inventoryItems)..where((t) => t.id.equals(item.id))).write(
            InventoryItemsCompanion(currentStock: Value(restoredStock)),
          );
        }
      }
      await (delete(inventoryTransactions)..where((t) => t.referenceRecordId.equals(recordId))).go();

      // 2. Validate and deduct new feed items
      for (final deduction in feedDeductions) {
        final itemId = deduction['itemId'] as String;
        final qtyKg = (deduction['qtyKg'] as num).toDouble();
        if (qtyKg <= 0) continue;

        final item = await (select(inventoryItems)..where((t) => t.id.equals(itemId))).getSingleOrNull();
        if (item == null) {
          throw InventoryItemNotFoundException(itemId: itemId, itemType: 'feed');
        }
        if (item.category.toLowerCase() != 'feed') {
          throw InvalidInventoryCategoryException(
            itemId: itemId,
            expectedCategory: 'feed',
            actualCategory: item.category,
          );
        }

        if (item.currentStock < qtyKg) {
          throw InsufficientStockException(
            itemName: item.name,
            availableStock: item.currentStock,
            requestedQuantity: qtyKg,
            unit: item.unit,
          );
        }

        final newStock = item.currentStock - qtyKg;
        await (update(inventoryItems)..where((t) => t.id.equals(itemId))).write(
          InventoryItemsCompanion(currentStock: Value(newStock)),
        );

        await into(inventoryTransactions).insert(
          InventoryTransactionsCompanion(
            id: Value('tx_${const Uuid().v4()}'),
            itemId: Value(item.id),
            siteId: Value(item.siteId),
            type: const Value('consumption'),
            quantity: Value(-qtyKg),
            unitPrice: Value(item.costPerUnit),
            totalCost: Value(qtyKg * item.costPerUnit),
            date: Value(feedRecord.date.value),
            referenceRecordId: Value(recordId),
            referenceType: const Value('feed_log'),
            notes: Value('Feed log edit: ${feedRecord.timeSlot.value}'),
          ),
        );
      }

      // 3. Deduct Co-Fed Medicines
      if (medicineDeductions != null) {
        for (final med in medicineDeductions) {
          final itemId = med['itemId'] as String;
          final qty = (med['qty'] as num).toDouble();
          if (qty <= 0) continue;

          final item = await (select(inventoryItems)..where((t) => t.id.equals(itemId))).getSingleOrNull();
          if (item == null) {
            throw InventoryItemNotFoundException(itemId: itemId, itemType: 'medicine');
          }
          if (item.category.toLowerCase() != 'medicine') {
            throw InvalidInventoryCategoryException(
              itemId: itemId,
              expectedCategory: 'medicine',
              actualCategory: item.category,
            );
          }

          if (item.currentStock < qty) {
            throw InsufficientStockException(
              itemName: item.name,
              availableStock: item.currentStock,
              requestedQuantity: qty,
              unit: item.unit,
            );
          }

          final newStock = item.currentStock - qty;
          await (update(inventoryItems)..where((t) => t.id.equals(itemId))).write(
            InventoryItemsCompanion(currentStock: Value(newStock)),
          );

          await into(inventoryTransactions).insert(
            InventoryTransactionsCompanion(
              id: Value('tx_med_${const Uuid().v4()}'),
              itemId: Value(item.id),
              siteId: Value(item.siteId),
              type: const Value('consumption'),
              quantity: Value(-qty),
              unitPrice: Value(item.costPerUnit),
              totalCost: Value(qty * item.costPerUnit),
              date: Value(feedRecord.date.value),
              referenceRecordId: Value(recordId),
              referenceType: const Value('co_feed_medicine'),
              notes: Value('Co-fed with ${feedRecord.timeSlot.value} feed edit'),
            ),
          );
        }
      }

      // 4. Deduct Co-Fed Supplements
      if (supplementDeductions != null) {
        for (final sup in supplementDeductions) {
          final itemId = sup['itemId'] as String;
          final qty = (sup['qty'] as num).toDouble();
          if (qty <= 0) continue;

          final item = await (select(inventoryItems)..where((t) => t.id.equals(itemId))).getSingleOrNull();
          if (item == null) {
            throw InventoryItemNotFoundException(itemId: itemId, itemType: 'supplement');
          }
          final cat = item.category.toLowerCase();
          if (cat != 'supplement' && cat != 'supplements' && cat != 'medicine') {
            throw InvalidInventoryCategoryException(
              itemId: itemId,
              expectedCategory: 'supplement',
              actualCategory: item.category,
            );
          }

          if (item.currentStock < qty) {
            throw InsufficientStockException(
              itemName: item.name,
              availableStock: item.currentStock,
              requestedQuantity: qty,
              unit: item.unit,
            );
          }

          final newStock = item.currentStock - qty;
          await (update(inventoryItems)..where((t) => t.id.equals(itemId))).write(
            InventoryItemsCompanion(currentStock: Value(newStock)),
          );

          await into(inventoryTransactions).insert(
            InventoryTransactionsCompanion(
              id: Value('tx_sup_${const Uuid().v4()}'),
              itemId: Value(item.id),
              siteId: Value(item.siteId),
              type: const Value('consumption'),
              quantity: Value(-qty),
              unitPrice: Value(item.costPerUnit),
              totalCost: Value(qty * item.costPerUnit),
              date: Value(feedRecord.date.value),
              referenceRecordId: Value(recordId),
              referenceType: const Value('co_feed_supplement'),
              notes: Value('Co-fed with ${feedRecord.timeSlot.value} feed edit'),
            ),
          );
        }
      }

      // 5. Update Feed Record
      await (update(feedRecords)..where((t) => t.id.equals(recordId))).write(feedRecord);
    });
  }

  /// Purchase Inventory Item Transaction:
  /// 1. Increase stock in InventoryItem
  /// 2. Record inward transaction (purchase)
  /// 3. Auto-insert expense record in Expenses table (category: feed, medicine, or fuel)
  Future<void> purchaseInventoryTransaction({
    required String itemId,
    required double quantity,
    required double unitCost,
    required double totalCost,
    required DateTime date,
    String? supplier,
    String? batchLotNumber,
    String? notes,
  }) async {
    // Database boundary validation for purchase inputs
    if (quantity <= 0) {
      throw InvalidInventoryQuantityException(quantity, 'Purchase quantity must be greater than 0.');
    }
    if (unitCost < 0) {
      throw InvalidInventoryCostException(unitCost, 'Purchase unit cost cannot be negative.');
    }
    if (totalCost < 0) {
      throw InvalidInventoryCostException(totalCost, 'Purchase total cost cannot be negative.');
    }
    final expectedTotal = quantity * unitCost;
    if (unitCost > 0 && (totalCost - expectedTotal).abs() > 0.05) {
      throw InvalidInventoryCostException(
        totalCost,
        'Purchase total cost ($totalCost) does not match quantity ($quantity) * unit price ($unitCost) = $expectedTotal.',
      );
    }

    return transaction(() async {
      final item = await (select(inventoryItems)..where((t) => t.id.equals(itemId))).getSingleOrNull();
      if (item == null) {
        throw InventoryItemNotFoundException(itemId: itemId);
      }
      final newStock = item.currentStock + quantity;

      await (update(inventoryItems)..where((t) => t.id.equals(itemId))).write(
        InventoryItemsCompanion(
          currentStock: Value(newStock),
          costPerUnit: Value(unitCost),
          supplier: supplier != null ? Value(supplier) : item.supplier != null ? Value(item.supplier) : const Value.absent(),
          batchLotNumber: batchLotNumber != null ? Value(batchLotNumber) : const Value.absent(),
        ),
      );

      final txId = 'tx_pur_${const Uuid().v4()}';
      await into(inventoryTransactions).insert(
        InventoryTransactionsCompanion(
          id: Value(txId),
          itemId: Value(item.id),
          siteId: Value(item.siteId),
          type: const Value('purchase'),
          quantity: Value(quantity),
          unitPrice: Value(unitCost),
          totalCost: Value(totalCost),
          date: Value(date),
          referenceType: const Value('purchase_invoice'),
          notes: Value(notes ?? 'Purchased from ${supplier ?? "supplier"}'),
        ),
      );

      // Auto-post expense to Finance
      if (totalCost > 0) {
        await into(expenses).insert(
          ExpensesCompanion(
            id: Value('exp_${const Uuid().v4()}'),
            siteId: Value(item.siteId),
            date: Value(date),
            category: Value(item.category), // 'feed', 'medicine', 'fuel'
            amount: Value(totalCost),
            description: Value('Purchase: ${item.name} ($quantity ${item.unit} @ ₹$unitCost)'),
            inventoryTxId: Value(txId),
          ),
        );
      }
    });
  }

  /// Create Inventory Item with optional initial stock onboarding
  Future<void> createInventoryItemTransaction({
    required InventoryItemsCompanion item,
    required double initialStock,
    required double unitCost,
    String? supplier,
    String? notes,
  }) async {
    if (initialStock < 0) {
      throw InvalidInventoryQuantityException(initialStock, 'Initial stock cannot be negative.');
    }
    if (unitCost < 0) {
      throw InvalidInventoryCostException(unitCost, 'Unit cost cannot be negative.');
    }
    return transaction(() async {
      await into(inventoryItems).insert(item);
      if (initialStock > 0) {
        final txId = 'tx_init_${const Uuid().v4()}';
        await into(inventoryTransactions).insert(
          InventoryTransactionsCompanion(
            id: Value(txId),
            itemId: item.id,
            siteId: item.siteId,
            type: const Value('purchase'),
            quantity: Value(initialStock),
            unitPrice: Value(unitCost),
            totalCost: Value(initialStock * unitCost),
            date: Value(DateTime.now()),
            referenceType: const Value('initial_stock'),
            notes: Value(notes ?? 'Initial stock onboarding'),
          ),
        );

        if (unitCost > 0) {
          await into(expenses).insert(
            ExpensesCompanion(
              id: Value('exp_${const Uuid().v4()}'),
              siteId: item.siteId,
              date: Value(DateTime.now()),
              category: item.category,
              amount: Value(initialStock * unitCost),
              description: Value('Initial Stock: ${item.name.value} ($initialStock ${item.unit.value} @ ₹$unitCost)'),
              inventoryTxId: Value(txId),
            ),
          );
        }
      }
    });
  }

  /// Complete Batch / Harvest Reconciliation Transaction:
  /// 1. Update Batch: status = 'completed', harvest metrics
  /// 2. Auto-insert revenue entry in Revenues
  /// 3. Free parent Pond status back to active vacant
  Future<void> completeBatchTransaction({
    required String batchId,
    required String pondId,
    required DateTime harvestDate,
    required double harvestWeightKg,
    required int harvestCount,
    required double salePricePerKg,
    required double totalRevenue,
    required double actualFcr,
    required double actualSurvivalPct,
    required String harvestType,
    String? buyerName,
    String? notes,
  }) async {
    return transaction(() async {
      // 1. Update Batch
      await (update(batches)..where((t) => t.id.equals(batchId))).write(
        BatchesCompanion(
          status: const Value('completed'),
          harvestDate: Value(harvestDate),
          harvestWeightKg: Value(harvestWeightKg),
          harvestCount: Value(harvestCount),
          salePricePerKg: Value(salePricePerKg),
          actualFcr: Value(actualFcr),
          actualSurvivalPct: Value(actualSurvivalPct),
          harvestType: Value(harvestType),
          buyerName: Value(buyerName),
        ),
      );

      // 2. Insert Revenue
      await into(revenues).insert(
        RevenuesCompanion(
          id: Value('rev_${DateTime.now().millisecondsSinceEpoch}'),
          batchId: Value(batchId),
          date: Value(harvestDate),
          harvestWeightKg: Value(harvestWeightKg),
          pricePerKg: Value(salePricePerKg),
          totalAmount: Value(totalRevenue),
          buyerName: Value(buyerName),
          harvestType: Value(harvestType),
          notes: Value(notes),
        ),
      );
    });
  }

  /// Rollback stock when a FeedRecord is deleted:
  /// Reverses all associated consumption transactions
  Future<void> deleteFeedRecordWithRollback(String recordId) async {
    return transaction(() async {
      final txs = await (select(inventoryTransactions)..where((t) => t.referenceRecordId.equals(recordId))).get();
      for (final tx in txs) {
        final item = await (select(inventoryItems)..where((t) => t.id.equals(tx.itemId))).getSingleOrNull();
        if (item != null) {
          // tx.quantity is negative; subtracting it adds it back to stock
          final restoredStock = item.currentStock - tx.quantity;
          await (update(inventoryItems)..where((t) => t.id.equals(item.id))).write(
            InventoryItemsCompanion(currentStock: Value(restoredStock)),
          );
        }
      }
      // Delete the linked transactions and the feed record
      await (delete(inventoryTransactions)..where((t) => t.referenceRecordId.equals(recordId))).go();
      await (delete(feedRecords)..where((t) => t.id.equals(recordId))).go();
    });
  }

  // ── USER PROFILE ──────────────────────────────────────────

  Future<UserProfile?> getUserProfile() async {
    return select(userProfiles).getSingleOrNull();
  }

  Future<void> saveUserProfile(String name) async {
    final existing = await getUserProfile();
    final now = DateTime.now();
    if (existing == null) {
      await into(userProfiles).insert(
        UserProfilesCompanion(
          id: const Value('user_main'),
          name: Value(name),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    } else {
      await (update(userProfiles)..where((t) => t.id.equals(existing.id))).write(
        UserProfilesCompanion(
          name: Value(name),
          updatedAt: Value(now),
        ),
      );
    }
  }

  // ── WEATHER CACHING ───────────────────────────────────────

  Future<WeatherObservation?> getLatestWeatherObservation(String siteId) async {
    return (select(weatherObservations)
          ..where((t) => t.siteId.equals(siteId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> cacheWeatherObservation(WeatherObservationsCompanion observation) async {
    await into(weatherObservations).insertOnConflictUpdate(observation);
  }

  Future<void> clearWeatherCache(String siteId) async {
    await (delete(weatherObservations)..where((t) => t.siteId.equals(siteId))).go();
  }

  // ── SAMPLING ENGINE ───────────────────────────────────────

  Future<List<SamplingEntry>> getSamplingsForBatch(String batchId) async {
    return (select(samplingEntries)
          ..where((t) => t.batchId.equals(batchId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.date),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
  }

  Future<SamplingEntry?> getLatestSamplingForBatch(String batchId) async {
    return (select(samplingEntries)
          ..where((t) => t.batchId.equals(batchId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Recalculates the complete chronological sampling growth chain for a batch.
  /// 1. First record: growth = null, daysElapsed = null, adg = null.
  /// 2. Subsequent records: growth = abw - prev.abw, days = date - prev.date, adg = growth / days.
  Future<void> recalcSamplingGrowthForBatch(String batchId) async {
    final entries = await getSamplingsForBatch(batchId);
    if (entries.isEmpty) return;

    await transaction(() async {
      for (int i = 0; i < entries.length; i++) {
        final current = entries[i];
        if (i == 0) {
          await (update(samplingEntries)..where((t) => t.id.equals(current.id))).write(
            const SamplingEntriesCompanion(
              weightGainGrams: Value(null),
              daysElapsed: Value(null),
              adgGramsPerDay: Value(null),
            ),
          );
        } else {
          final prev = entries[i - 1];
          final growth = double.parse((current.abwGrams - prev.abwGrams).toStringAsFixed(3));
          final days = SamplingCalculator.calendarDaysBetween(prev.date, current.date);
          final adg = days > 0 ? double.parse((growth / days).toStringAsFixed(3)) : null;

          await (update(samplingEntries)..where((t) => t.id.equals(current.id))).write(
            SamplingEntriesCompanion(
              weightGainGrams: Value(growth),
              daysElapsed: Value(days > 0 ? days : null),
              adgGramsPerDay: Value(adg),
            ),
          );
        }
      }
    });
  }

  Future<void> saveSamplingEntry(SamplingEntriesCompanion entry, String batchId) async {
    await into(samplingEntries).insertOnConflictUpdate(entry);
    await recalcSamplingGrowthForBatch(batchId);
  }

  Future<void> deleteSamplingEntry(String samplingId, String batchId) async {
    return transaction(() async {
      await (delete(samplingEntries)..where((t) => t.id.equals(samplingId))).go();
      await recalcSamplingGrowthForBatch(batchId);
    });
  }

  // ── MASTER DATA MANAGEMENT ─────────────────────────────────

  /// Safe deletion checks & dependency detection

  Future<DeleteSafetyCheck> canDeleteSite(String siteId) async {
    final linkedPonds = await (select(ponds)..where((t) => t.siteId.equals(siteId))).get();
    final linkedInventory = await (select(inventoryItems)..where((t) => t.siteId.equals(siteId))).get();
    final linkedTransactions = await (select(inventoryTransactions)..where((t) => t.siteId.equals(siteId))).get();
    final linkedExpenses = await (select(expenses)..where((t) => t.siteId.equals(siteId))).get();
    final linkedMachineRuns = await (select(machineRuns)..where((t) => t.siteId.equals(siteId))).get();
    final linkedWeather = await (select(weatherObservations)..where((t) => t.siteId.equals(siteId))).get();
    final linkedWQ = await (select(waterQualityLogs)..where((t) => t.siteId.equals(siteId))).get();
    final linkedTasks = await (select(farmActionTasks)..where((t) => t.siteId.equals(siteId))).get();

    final breakdown = <String, int>{
      if (linkedPonds.isNotEmpty) 'Ponds': linkedPonds.length,
      if (linkedInventory.isNotEmpty) 'Inventory Items': linkedInventory.length,
      if (linkedTransactions.isNotEmpty) 'Inventory Transactions': linkedTransactions.length,
      if (linkedExpenses.isNotEmpty) 'Expenses': linkedExpenses.length,
      if (linkedMachineRuns.isNotEmpty) 'Machine Runs': linkedMachineRuns.length,
      if (linkedWeather.isNotEmpty) 'Weather Observations': linkedWeather.length,
      if (linkedWQ.isNotEmpty) 'Water Quality Logs': linkedWQ.length,
      if (linkedTasks.isNotEmpty) 'Farm Tasks': linkedTasks.length,
    };

    final canDel = breakdown.isEmpty;
    return DeleteSafetyCheck(
      canDelete: canDel,
      linkedPonds: linkedPonds.length,
      linkedInventory: linkedInventory.length,
      linkedTransactions: linkedTransactions.length,
      linkedExpenses: linkedExpenses.length,
      linkedMachineRuns: linkedMachineRuns.length,
      linkedWeather: linkedWeather.length,
      linkedWaterLogs: linkedWQ.length,
      linkedActionTasks: linkedTasks.length,
      dependencyBreakdown: breakdown,
    );
  }

  Future<void> deleteSiteSafely(String siteId) async {
    return transaction(() async {
      final check = await canDeleteSite(siteId);
      if (!check.canDelete) {
        final details = check.dependencyBreakdown.entries
            .map((e) => '${e.key}: ${e.value}')
            .join(', ');
        throw DependentRecordsExistException(
          entityType: 'Site',
          entityId: siteId,
          details: details,
        );
      }
      await (delete(farmSites)..where((t) => t.id.equals(siteId))).go();
    });
  }

  Future<DeleteSafetyCheck> canDeletePond(String pondId) async {
    final pondBatches = await (select(batches)..where((t) => t.pondId.equals(pondId))).get();
    final feedLogs = await (select(feedRecords)..where((t) => t.pondId.equals(pondId))).get();
    final samplings = await (select(samplingEntries)..where((t) => t.pondId.equals(pondId))).get();
    final hapas = await (select(hapaChecks)..where((t) => t.pondId.equals(pondId))).get();
    final growths = await (select(growthRecords)..where((t) => t.pondId.equals(pondId))).get();
    final biomasses = await (select(biomassSnapshots)..where((t) => t.pondId.equals(pondId))).get();
    final treatments = await (select(treatmentRecords)..where((t) => t.pondId.equals(pondId))).get();
    final pondExpenses = await (select(expenses)..where((t) => t.pondId.equals(pondId))).get();
    final wqLogs = await (select(waterQualityLogs)..where((t) => t.pondId.equals(pondId))).get();
    final mortalities = await (select(mortalityRecords)..where((t) => t.pondId.equals(pondId))).get();
    final operations = await (select(pondOperations)..where((t) => t.pondId.equals(pondId))).get();
    final tasks = await (select(farmActionTasks)..where((t) => t.pondId.equals(pondId))).get();
    final feedPlans = await (select(dailyFeedPlans)..where((t) => t.pondId.equals(pondId))).get();

    final breakdown = <String, int>{
      if (pondBatches.isNotEmpty) 'Batches': pondBatches.length,
      if (feedLogs.isNotEmpty) 'Feed Records': feedLogs.length,
      if (samplings.isNotEmpty) 'Sampling Entries': samplings.length,
      if (hapas.isNotEmpty) 'Hapa Checks': hapas.length,
      if (growths.isNotEmpty) 'Growth Records': growths.length,
      if (biomasses.isNotEmpty) 'Biomass Snapshots': biomasses.length,
      if (treatments.isNotEmpty) 'Treatment Records': treatments.length,
      if (pondExpenses.isNotEmpty) 'Expenses': pondExpenses.length,
      if (wqLogs.isNotEmpty) 'Water Quality Logs': wqLogs.length,
      if (mortalities.isNotEmpty) 'Mortality Records': mortalities.length,
      if (operations.isNotEmpty) 'Pond Operations': operations.length,
      if (tasks.isNotEmpty) 'Farm Tasks': tasks.length,
      if (feedPlans.isNotEmpty) 'Feed Plans': feedPlans.length,
    };

    final canDel = breakdown.isEmpty;
    return DeleteSafetyCheck(
      canDelete: canDel,
      linkedBatches: pondBatches.length,
      linkedFeedRecords: feedLogs.length,
      linkedSamplings: samplings.length,
      linkedHapaChecks: hapas.length,
      linkedGrowthRecords: growths.length,
      linkedBiomassSnapshots: biomasses.length,
      linkedTreatments: treatments.length,
      linkedExpenses: pondExpenses.length,
      linkedWaterLogs: wqLogs.length,
      linkedMortalities: mortalities.length,
      linkedOperations: operations.length,
      linkedActionTasks: tasks.length,
      linkedFeedPlans: feedPlans.length,
      dependencyBreakdown: breakdown,
    );
  }

  Future<void> deletePondSafely(String pondId) async {
    return transaction(() async {
      final check = await canDeletePond(pondId);
      if (!check.canDelete) {
        final details = check.dependencyBreakdown.entries
            .map((e) => '${e.key}: ${e.value}')
            .join(', ');
        throw DependentRecordsExistException(
          entityType: 'Pond',
          entityId: pondId,
          details: details,
        );
      }
      await (delete(ponds)..where((t) => t.id.equals(pondId))).go();
    });
  }

  Future<DeleteSafetyCheck> canDeleteBatch(String batchId) async {
    final batch = await (select(batches)..where((t) => t.id.equals(batchId))).getSingleOrNull();
    final feedLogs = await (select(feedRecords)..where((t) => t.batchId.equals(batchId))).get();
    final samplings = await (select(samplingEntries)..where((t) => t.batchId.equals(batchId))).get();
    final hapas = await (select(hapaChecks)..where((t) => t.batchId.equals(batchId))).get();
    final growths = await (select(growthRecords)..where((t) => t.batchId.equals(batchId))).get();
    final biomasses = await (select(biomassSnapshots)..where((t) => t.batchId.equals(batchId))).get();
    final treatments = await (select(treatmentRecords)..where((t) => t.batchId.equals(batchId))).get();
    final batchExpenses = await (select(expenses)..where((t) => t.batchId.equals(batchId))).get();
    final batchRevenues = await (select(revenues)..where((t) => t.batchId.equals(batchId))).get();
    final isHarvested = batch != null && (batch.status == 'completed' || batch.harvestDate != null);
    final wqLogs = await (select(waterQualityLogs)..where((t) => t.batchId.equals(batchId))).get();
    final mortalities = await (select(mortalityRecords)..where((t) => t.batchId.equals(batchId))).get();
    final adjustments = await (select(populationAdjustments)..where((t) => t.batchId.equals(batchId))).get();
    final tasks = await (select(farmActionTasks)..where((t) => t.batchId.equals(batchId))).get();
    final feedPlans = await (select(dailyFeedPlans)..where((t) => t.batchId.equals(batchId))).get();

    final breakdown = <String, int>{
      if (feedLogs.isNotEmpty) 'Feed Records': feedLogs.length,
      if (samplings.isNotEmpty) 'Sampling Entries': samplings.length,
      if (hapas.isNotEmpty) 'Hapa Checks': hapas.length,
      if (growths.isNotEmpty) 'Growth Records': growths.length,
      if (biomasses.isNotEmpty) 'Biomass Snapshots': biomasses.length,
      if (treatments.isNotEmpty) 'Treatment Records': treatments.length,
      if (batchExpenses.isNotEmpty) 'Expenses': batchExpenses.length,
      if (batchRevenues.isNotEmpty) 'Revenues': batchRevenues.length,
      if (isHarvested) 'Harvest Records': 1,
      if (wqLogs.isNotEmpty) 'Water Quality Logs': wqLogs.length,
      if (mortalities.isNotEmpty) 'Mortality Records': mortalities.length,
      if (adjustments.isNotEmpty) 'Population Adjustments': adjustments.length,
      if (tasks.isNotEmpty) 'Farm Tasks': tasks.length,
      if (feedPlans.isNotEmpty) 'Feed Plans': feedPlans.length,
    };

    final canDel = breakdown.isEmpty;
    return DeleteSafetyCheck(
      canDelete: canDel,
      linkedFeedRecords: feedLogs.length,
      linkedSamplings: samplings.length,
      linkedHapaChecks: hapas.length,
      linkedGrowthRecords: growths.length,
      linkedBiomassSnapshots: biomasses.length,
      linkedTreatments: treatments.length,
      linkedHarvests: isHarvested ? 1 : 0,
      linkedExpenses: batchExpenses.length + batchRevenues.length,
      linkedWaterLogs: wqLogs.length,
      linkedMortalities: mortalities.length,
      linkedActionTasks: tasks.length,
      linkedFeedPlans: feedPlans.length,
      dependencyBreakdown: breakdown,
    );
  }


  Future<void> deleteBatchSafely(String batchId) async {
    return transaction(() async {
      final check = await canDeleteBatch(batchId);
      if (!check.canDelete) {
        final details = check.dependencyBreakdown.entries
            .map((e) => '${e.key}: ${e.value}')
            .join(', ');
        throw DependentRecordsExistException(
          entityType: 'Batch',
          entityId: batchId,
          details: details,
        );
      }
      await (delete(batches)..where((t) => t.id.equals(batchId))).go();
    });
  }

  /// Checks if any existing batch for [pondId] overlaps with [[stockingDate], [harvestDate]].
  /// If [excludeBatchId] is provided, that batch is ignored (useful when editing an existing batch).
  Future<Batch?> checkBatchOverlap({
    required String pondId,
    required DateTime stockingDate,
    DateTime? harvestDate,
    String? excludeBatchId,
  }) async {
    final pondBatches = await (select(batches)..where((t) => t.pondId.equals(pondId))).get();
    final newStart = DateTime(stockingDate.year, stockingDate.month, stockingDate.day);
    final newEnd = harvestDate != null
        ? DateTime(harvestDate.year, harvestDate.month, harvestDate.day)
        : null;

    for (final b in pondBatches) {
      if (excludeBatchId != null && b.id == excludeBatchId) continue;

      final bStart = DateTime(b.stockingDate.year, b.stockingDate.month, b.stockingDate.day);
      final bEnd = b.harvestDate != null
          ? DateTime(b.harvestDate!.year, b.harvestDate!.month, b.harvestDate!.day)
          : null;

      // Two intervals [S1, E1] and [S2, E2] overlap if:
      // S1 <= E2 (or E2 is null/open) AND S2 <= E1 (or E1 is null/open)
      final start1BeforeEnd2 = bEnd == null || !newStart.isAfter(bEnd);
      final start2BeforeEnd1 = newEnd == null || !bStart.isAfter(newEnd);

      if (start1BeforeEnd2 && start2BeforeEnd1) {
        return b;
      }
    }
    return null;
  }

  /// Date-based batch resolution: returns the batch for [pondId] active on [date].
  Future<Batch?> getBatchForPondOnDate(String pondId, DateTime date) async {
    final pondBatches = await (select(batches)..where((t) => t.pondId.equals(pondId))).get();
    if (pondBatches.isEmpty) return null;

    final targetDate = DateTime(date.year, date.month, date.day);

    // 1. Check if any batch was active across this date
    final matchedBatches = pondBatches.where((b) {
      final sDate = DateTime(b.stockingDate.year, b.stockingDate.month, b.stockingDate.day);
      if (sDate.isAfter(targetDate)) return false;
      if (b.harvestDate != null) {
        final hDate = DateTime(b.harvestDate!.year, b.harvestDate!.month, b.harvestDate!.day);
        if (targetDate.isAfter(hDate)) return false;
      }
      return true;
    }).toList();

    if (matchedBatches.isNotEmpty) {
      matchedBatches.sort((a, b) => b.stockingDate.compareTo(a.stockingDate));
      final activeOne = matchedBatches.where((b) => b.status == 'active').firstOrNull;
      return activeOne ?? matchedBatches.first;
    }

    // 2. Fallback: currently active batch for this pond
    final activeFallback = pondBatches.where((b) => b.status == 'active').firstOrNull;
    if (activeFallback != null) return activeFallback;

    // 3. Fallback: most recent batch
    pondBatches.sort((a, b) => b.stockingDate.compareTo(a.stockingDate));
    return pondBatches.first;
  }

  /// Check if a pond already has an active batch
  Future<Batch?> getActiveBatchForPond(String pondId) async {
    return (select(batches)..where((t) => t.pondId.equals(pondId) & t.status.equals('active'))).getSingleOrNull();
  }

  // ── WATER QUALITY LOGS ─────────────────────────────────────

  Stream<List<WaterQualityLog>> watchWaterQualityLogsForPond(String pondId) {
    return (select(waterQualityLogs)
          ..where((t) => t.pondId.equals(pondId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  Future<List<WaterQualityLog>> getWaterQualityLogsForPond(String pondId, {int? limit}) async {
    final query = select(waterQualityLogs)
      ..where((t) => t.pondId.equals(pondId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.createdAt),
      ]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Future<List<WaterQualityLog>> getWaterQualityLogsForBatch(String batchId, {int? limit}) async {
    final query = select(waterQualityLogs)
      ..where((t) => t.batchId.equals(batchId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.createdAt),
      ]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Future<WaterQualityLog?> getLatestWaterQualityLog(String pondId) async {
    return (select(waterQualityLogs)
          ..where((t) => t.pondId.equals(pondId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> saveWaterQualityLog(WaterQualityLogsCompanion log) async {
    await into(waterQualityLogs).insertOnConflictUpdate(log);
  }

  Future<void> deleteWaterQualityLog(String id) async {
    await (delete(waterQualityLogs)..where((t) => t.id.equals(id))).go();
  }

  // ── MORTALITY & POPULATION ────────────────────────────────

  Stream<List<MortalityRecord>> watchMortalityRecordsForBatch(String batchId) {
    return (select(mortalityRecords)
          ..where((t) => t.batchId.equals(batchId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  Future<List<MortalityRecord>> getMortalityRecordsForBatch(String batchId) async {
    return (select(mortalityRecords)
          ..where((t) => t.batchId.equals(batchId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.date),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
  }

  Future<int> getCumulativeMortalityForBatch(String batchId) async {
    final records = await getMortalityRecordsForBatch(batchId);
    return records.fold<int>(0, (sum, r) => sum + r.countObserved + r.countEstimated);
  }

  Future<void> saveMortalityRecord(MortalityRecordsCompanion record) async {
    await into(mortalityRecords).insertOnConflictUpdate(record);
  }

  Future<void> deleteMortalityRecord(String id) async {
    await (delete(mortalityRecords)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<PopulationAdjustment>> watchPopulationAdjustmentsForBatch(String batchId) {
    return (select(populationAdjustments)
          ..where((t) => t.batchId.equals(batchId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  Future<List<PopulationAdjustment>> getPopulationAdjustmentsForBatch(String batchId) async {
    return (select(populationAdjustments)
          ..where((t) => t.batchId.equals(batchId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.date),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
  }

  Future<void> savePopulationAdjustment(PopulationAdjustmentsCompanion adjustment) async {
    await into(populationAdjustments).insertOnConflictUpdate(adjustment);
  }

  // ── POND OPERATIONS ────────────────────────────────────────

  Stream<List<PondOperation>> watchPondOperations(String pondId) {
    return (select(pondOperations)
          ..where((t) => t.pondId.equals(pondId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  Future<List<PondOperation>> getPondOperationsForPond(String pondId, {int? limit}) async {
    final query = select(pondOperations)
      ..where((t) => t.pondId.equals(pondId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.createdAt),
      ]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Future<List<PondOperation>> getPondOperationsForBatch(String batchId) async {
    return (select(pondOperations)
          ..where((t) => t.batchId.equals(batchId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .get();
  }

  Future<void> savePondOperation(PondOperationsCompanion operation) async {
    await into(pondOperations).insertOnConflictUpdate(operation);
  }

  Future<void> deletePondOperation(String id) async {
    await (delete(pondOperations)..where((t) => t.id.equals(id))).go();
  }

  // ── FARM ACTION TASKS ──────────────────────────────────────

  Stream<List<FarmActionTask>> watchActionTasks({String? siteId, String? pondId, String? status}) {
    final query = select(farmActionTasks);
    if (siteId != null) query.where((t) => t.siteId.equals(siteId));
    if (pondId != null) query.where((t) => t.pondId.equals(pondId));
    if (status != null) query.where((t) => t.status.equals(status));
    query.orderBy([
      (t) => OrderingTerm.desc(t.createdAt),
    ]);
    return query.watch();
  }

  Future<List<FarmActionTask>> getActionTasks({String? siteId, String? pondId, String? status}) async {
    final query = select(farmActionTasks);
    if (siteId != null) query.where((t) => t.siteId.equals(siteId));
    if (pondId != null) query.where((t) => t.pondId.equals(pondId));
    if (status != null) query.where((t) => t.status.equals(status));
    query.orderBy([
      (t) => OrderingTerm.desc(t.createdAt),
    ]);
    return query.get();
  }

  Future<void> saveFarmActionTask(FarmActionTasksCompanion task) async {
    await into(farmActionTasks).insertOnConflictUpdate(task);
  }

  Future<void> updateFarmActionTaskStatus(String taskId, String status, {String? resolutionNotes}) async {
    await (update(farmActionTasks)..where((t) => t.id.equals(taskId))).write(
      FarmActionTasksCompanion(
        status: Value(status),
        completedAt: status == 'completed' ? Value(DateTime.now()) : const Value.absent(),
        resolutionNotes: resolutionNotes != null ? Value(resolutionNotes) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteFarmActionTask(String taskId) async {
    await (delete(farmActionTasks)..where((t) => t.id.equals(taskId))).go();
  }

  // ── DAILY FEED PLANS ───────────────────────────────────────

  Stream<DailyFeedPlan?> watchDailyFeedPlanForDate(String pondId, DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(dailyFeedPlans)
          ..where((t) => t.pondId.equals(pondId) & t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<DailyFeedPlan?> getDailyFeedPlanForDate(String pondId, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(dailyFeedPlans)
          ..where((t) => t.pondId.equals(pondId) & t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<DailyFeedPlan>> getDailyFeedPlansForBatch(String batchId) async {
    return (select(dailyFeedPlans)
          ..where((t) => t.batchId.equals(batchId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.date),
          ]))
        .get();
  }

  Future<void> saveDailyFeedPlan(DailyFeedPlansCompanion plan) async {
    await into(dailyFeedPlans).insertOnConflictUpdate(plan);
  }

  Future<void> updateDailyFeedPlanStatus(
    String id,
    String status, {
    double? actualPlannedKg,
    String? reason,
  }) async {
    await (update(dailyFeedPlans)..where((t) => t.id.equals(id))).write(
      DailyFeedPlansCompanion(
        status: Value(status),
        actualPlannedKg: actualPlannedKg != null ? Value(actualPlannedKg) : const Value.absent(),
        adjustmentReason: reason != null ? Value(reason) : const Value.absent(),
      ),
    );
  }
}
