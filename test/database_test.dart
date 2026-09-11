import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqualog/core/database/app_database.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;

  setUp(() {
    // In-memory native SQLite database for fast isolated testing
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('Ponds, Batches, and Sites relational CRUD', () async {
    // 1. Insert Site
    await db.into(db.farmSites).insert(
      FarmSitesCompanion(
        id: const Value('site_1'),
        name: const Value('Bhimavaram Creek Farm'),
        address: const Value('West Godavari, AP'),
        latitude: const Value(16.54),
        longitude: const Value(81.52),
      ),
    );

    final sites = await db.select(db.farmSites).get();
    expect(sites.length, 1);
    expect(sites.first.name, 'Bhimavaram Creek Farm');

    // 2. Insert Pond
    await db.into(db.ponds).insert(
      PondsCompanion(
        id: const Value('pond_1'),
        siteId: const Value('site_1'),
        name: const Value('Pond 1 - North'),
        areaSqMeters: const Value(4000.0),
        waterDepthMeters: const Value(1.5),
        aeratorsCount: const Value(8),
        totalAeratorHp: const Value(16.0),
      ),
    );

    final ponds = await db.select(db.ponds).get();
    expect(ponds.length, 1);
    expect(ponds.first.totalAeratorHp, 16.0);

    // 3. Insert Batch
    final stockingDate = DateTime(2026, 7, 1);
    await db.into(db.batches).insert(
      BatchesCompanion(
        id: const Value('batch_1'),
        pondId: const Value('pond_1'),
        batchNumber: const Value(1),
        species: const Value('Litopenaeus vannamei'),
        stockingDate: Value(stockingDate),
        shrimpStockedCount: const Value(120000),
        plStage: const Value('PL-10'),
        seedCost: const Value(48000.0),
        targetHarvestWeightG: const Value(25.0),
      ),
    );

    final batches = await db.select(db.batches).get();
    expect(batches.length, 1);
    expect(batches.first.shrimpStockedCount, 120000);
  });

  test('Feed logging transaction decrements stock and creates inventory transactions', () async {
    // Create Pond & Batch
    await db.into(db.ponds).insert(
      PondsCompanion(
        id: const Value('pond_1'),
        name: const Value('Pond 1'),
        areaSqMeters: const Value(4000.0),
        waterDepthMeters: const Value(1.5),
      ),
    );
    await db.into(db.batches).insert(
      BatchesCompanion(
        id: const Value('batch_1'),
        pondId: const Value('pond_1'),
        batchNumber: const Value(1),
        stockingDate: Value(DateTime(2026, 7, 1)),
        shrimpStockedCount: const Value(100000),
      ),
    );

    // Create Feed Item (Grower 1.6mm with 1000 kg initial stock)
    await db.into(db.inventoryItems).insert(
      InventoryItemsCompanion(
        id: const Value('inv_feed_grower_16'),
        category: const Value('feed'),
        name: const Value('Grower 1.6mm'),
        pelletSize: const Value('1.6mm'),
        currentStock: const Value(1000.0),
        costPerUnit: const Value(85.0), // Rs 85/kg
      ),
    );

    // Execute Log Feed Session Transaction: broadcast 15 kg of Grower 1.6mm
    final feedDate = DateTime(2026, 9, 7);
    await db.logFeedSessionTransaction(
      feedRecord: FeedRecordsCompanion(
        id: const Value('rec_101'),
        pondId: const Value('pond_1'),
        batchId: const Value('batch_1'),
        date: Value(feedDate),
        timeSlot: const Value('7:00 AM'),
        grower2G: const Value(15000.0),
        totalGrams: const Value(15000.0),
        totalKg: const Value(15.0),
        trayChecked: const Value(true),
        trayLeftoverPct: const Value(0),
      ),
      feedDeductions: [
        {'itemId': 'inv_feed_grower_16', 'qtyKg': 15.0, 'pelletSize': '1.6mm'},
      ],
    );

    // Verify Feed Record inserted
    final records = await db.select(db.feedRecords).get();
    expect(records.length, 1);
    expect(records.first.totalKg, 15.0);

    // Verify Stock decremented from 1000 to 985
    final feedItem = await (db.select(db.inventoryItems)..where((t) => t.id.equals('inv_feed_grower_16'))).getSingle();
    expect(feedItem.currentStock, 985.0);

    // Verify Inventory Transaction recorded
    final txs = await db.select(db.inventoryTransactions).get();
    expect(txs.length, 1);
    expect(txs.first.quantity, -15.0);
    expect(txs.first.type, 'consumption');
    expect(txs.first.totalCost, 15.0 * 85.0);
    expect(txs.first.referenceRecordId, 'rec_101');

    // Test Deletion with Stock Rollback
    await db.deleteFeedRecordWithRollback('rec_101');

    // Verify record and transaction deleted, stock refunded back to 1000
    final recordsAfter = await db.select(db.feedRecords).get();
    expect(recordsAfter.isEmpty, isTrue);

    final feedItemRestored = await (db.select(db.inventoryItems)..where((t) => t.id.equals('inv_feed_grower_16'))).getSingle();
    expect(feedItemRestored.currentStock, 1000.0);
  });

  test('Purchase inventory item transaction updates stock and auto-posts expense to Finance', () async {
    // Create Feed Item with 100 kg initial stock
    await db.into(db.inventoryItems).insert(
      InventoryItemsCompanion(
        id: const Value('inv_feed_starter'),
        category: const Value('feed'),
        name: const Value('Starter 0.8mm'),
        currentStock: const Value(100.0),
        costPerUnit: const Value(90.0),
      ),
    );

    // Execute Purchase: 500 kg @ Rs 95/kg (Total: Rs 47,500)
    await db.purchaseInventoryTransaction(
      itemId: 'inv_feed_starter',
      quantity: 500.0,
      unitCost: 95.0,
      totalCost: 47500.0,
      date: DateTime(2026, 9, 7),
      supplier: 'Coastal Feeds Agency',
      batchLotNumber: 'LOT-9821',
    );

    // Check stock increased to 600 kg
    final item = await (db.select(db.inventoryItems)..where((t) => t.id.equals('inv_feed_starter'))).getSingle();
    expect(item.currentStock, 600.0);
    expect(item.costPerUnit, 95.0);
    expect(item.supplier, 'Coastal Feeds Agency');

    // Check expense was automatically posted in Expenses
    final expenses = await db.select(db.expenses).get();
    expect(expenses.length, 1);
    expect(expenses.first.category, 'feed');
    expect(expenses.first.amount, 47500.0);
  });

  test('Complete Batch / Harvest transaction marks batch completed and creates Revenue', () async {
    await db.into(db.ponds).insert(
      PondsCompanion(
        id: const Value('pond_1'),
        name: const Value('Pond 1'),
        areaSqMeters: const Value(4000.0),
        waterDepthMeters: const Value(1.5),
      ),
    );
    await db.into(db.batches).insert(
      BatchesCompanion(
        id: const Value('batch_1'),
        pondId: const Value('pond_1'),
        batchNumber: const Value(1),
        stockingDate: Value(DateTime(2026, 5, 1)),
        shrimpStockedCount: const Value(120000),
      ),
    );

    // Harvest crop: 2,450 kg @ Rs 420/kg (Total: Rs 1,029,000)
    await db.completeBatchTransaction(
      batchId: 'batch_1',
      pondId: 'pond_1',
      harvestDate: DateTime(2026, 9, 7),
      harvestWeightKg: 2450.0,
      harvestCount: 102000,
      salePricePerKg: 420.0,
      totalRevenue: 1029000.0,
      actualFcr: 1.30,
      actualSurvivalPct: 85.0,
      harvestType: 'full',
      buyerName: 'Nekkanti Sea Foods',
    );

    // Verify batch status is completed
    final batch = await (db.select(db.batches)..where((t) => t.id.equals('batch_1'))).getSingle();
    expect(batch.status, 'completed');
    expect(batch.harvestWeightKg, 2450.0);
    expect(batch.salePricePerKg, 420.0);

    // Verify revenue was created
    final revenues = await db.select(db.revenues).get();
    expect(revenues.length, 1);
    expect(revenues.first.totalAmount, 1029000.0);
    expect(revenues.first.buyerName, 'Nekkanti Sea Foods');
  });
}
