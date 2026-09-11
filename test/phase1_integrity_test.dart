import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aqualog/core/database/app_database.dart' hide isNull, isNotNull;
import 'package:aqualog/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('PHASE 1 - Bug 1: Silent Medicine/Supplement Inventory Deduction & Rollback', () {
    test('Valid medicine and supplement deduction succeeds and updates stock and creates transactions', () async {
      // Setup master data
      await db.into(db.farmSites).insert(
        FarmSitesCompanion(id: const Value('site_1'), name: const Value('Site 1'), code: const Value('S1')),
      );
      await db.into(db.ponds).insert(
        PondsCompanion(
          id: const Value('pond_1'),
          siteId: const Value('site_1'),
          name: const Value('Pond 1'),
          areaSqMeters: const Value(1000.0),
          waterDepthMeters: const Value(1.5),
        ),
      );
      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const Value('batch_1'),
          pondId: const Value('pond_1'),
          batchNumber: const Value(1),
          species: const Value('Vannamei'),
          stockingDate: Value(DateTime.now()),
          shrimpStockedCount: const Value(50000),
        ),
      );

      // Inventory items
      await db.into(db.inventoryItems).insert(
        InventoryItemsCompanion(
          id: const Value('feed_item_1'),
          siteId: const Value('site_1'),
          category: const Value('feed'),
          name: const Value('Starter Feed'),
          currentStock: const Value(100.0),
          unit: const Value('kg'),
          costPerUnit: const Value(80.0),
        ),
      );
      await db.into(db.inventoryItems).insert(
        InventoryItemsCompanion(
          id: const Value('med_item_1'),
          siteId: const Value('site_1'),
          category: const Value('medicine'),
          name: const Value('Probiotic Med'),
          currentStock: const Value(5.0),
          unit: const Value('L'),
          costPerUnit: const Value(500.0),
        ),
      );
      await db.into(db.inventoryItems).insert(
        InventoryItemsCompanion(
          id: const Value('supp_item_1'),
          siteId: const Value('site_1'),
          category: const Value('supplements'),
          name: const Value('Vitamin C'),
          currentStock: const Value(10.0),
          unit: const Value('kg'),
          costPerUnit: const Value(300.0),
        ),
      );

      // Execute session with feed, medicine, supplement
      await db.logFeedSessionTransaction(
        feedRecord: FeedRecordsCompanion(
          id: const Value('feed_rec_1'),
          batchId: const Value('batch_1'),
          pondId: const Value('pond_1'),
          date: Value(DateTime.now()),
          timeSlot: const Value('7:00 AM'),
          starterG: const Value(20000),
          totalGrams: const Value(20000),
          totalKg: const Value(20.0),
        ),
        feedDeductions: [
          {'itemId': 'feed_item_1', 'qtyKg': 20.0, 'pelletSize': '1.0mm'},
        ],
        medicineDeductions: [
          {'itemId': 'med_item_1', 'qty': 1.0, 'medicineName': 'Probiotic Med'},
        ],
        supplementDeductions: [
          {'itemId': 'supp_item_1', 'qty': 2.0, 'supplementName': 'Vitamin C'},
        ],
      );

      // Verify stock deductions
      final feedItem = await (db.select(db.inventoryItems)..where((t) => t.id.equals('feed_item_1'))).getSingle();
      final medItem = await (db.select(db.inventoryItems)..where((t) => t.id.equals('med_item_1'))).getSingle();
      final suppItem = await (db.select(db.inventoryItems)..where((t) => t.id.equals('supp_item_1'))).getSingle();

      expect(feedItem.currentStock, equals(80.0));
      expect(medItem.currentStock, equals(4.0));
      expect(suppItem.currentStock, equals(8.0));

      final txs = await db.select(db.inventoryTransactions).get();
      expect(txs.length, equals(3));
    });

    test('Invalid medicine inventory ID aborts transaction and rolls back entirely', () async {
      await db.into(db.farmSites).insert(
        FarmSitesCompanion(id: const Value('site_1'), name: const Value('Site 1'), code: const Value('S1')),
      );
      await db.into(db.ponds).insert(
        PondsCompanion(
          id: const Value('pond_1'),
          siteId: const Value('site_1'),
          name: const Value('Pond 1'),
          areaSqMeters: const Value(1000.0),
          waterDepthMeters: const Value(1.5),
        ),
      );
      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const Value('batch_1'),
          pondId: const Value('pond_1'),
          batchNumber: const Value(1),
          species: const Value('Vannamei'),
          stockingDate: Value(DateTime.now()),
          shrimpStockedCount: const Value(50000),
        ),
      );
      await db.into(db.inventoryItems).insert(
        InventoryItemsCompanion(
          id: const Value('feed_item_1'),
          siteId: const Value('site_1'),
          category: const Value('feed'),
          name: const Value('Starter Feed'),
          currentStock: const Value(100.0),
          unit: const Value('kg'),
          costPerUnit: const Value(80.0),
        ),
      );

      // Attempt feed session with NON-EXISTENT medicine item
      expect(
        () async => await db.logFeedSessionTransaction(
          feedRecord: FeedRecordsCompanion(
            id: const Value('feed_rec_fail_1'),
            batchId: const Value('batch_1'),
            pondId: const Value('pond_1'),
            date: Value(DateTime.now()),
            timeSlot: const Value('7:00 AM'),
            starterG: const Value(20000),
            totalGrams: const Value(20000),
            totalKg: const Value(20.0),
          ),
          feedDeductions: [
            {'itemId': 'feed_item_1', 'qtyKg': 20.0, 'pelletSize': '1.0mm'},
          ],
          medicineDeductions: [
            {'itemId': 'non_existent_med_id', 'qty': 1.0, 'medicineName': 'Ghost Med'},
          ],
        ),
        throwsA(isA<InventoryItemNotFoundException>()),
      );

      // Verify ZERO database mutations took place
      final feedItem = await (db.select(db.inventoryItems)..where((t) => t.id.equals('feed_item_1'))).getSingle();
      expect(feedItem.currentStock, equals(100.0)); // Unchanged

      final records = await db.select(db.feedRecords).get();
      expect(records.isEmpty, isTrue); // Feed record not saved

      final txs = await db.select(db.inventoryTransactions).get();
      expect(txs.isEmpty, isTrue); // No partial transactions
    });

    test('Medicine deduction with category mismatch (referencing feed item as medicine) is rejected', () async {
      await db.into(db.farmSites).insert(
        FarmSitesCompanion(id: const Value('site_1'), name: const Value('Site 1'), code: const Value('S1')),
      );
      await db.into(db.ponds).insert(
        PondsCompanion(
          id: const Value('pond_1'),
          siteId: const Value('site_1'),
          name: const Value('Pond 1'),
          areaSqMeters: const Value(1000.0),
          waterDepthMeters: const Value(1.5),
        ),
      );
      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const Value('batch_1'),
          pondId: const Value('pond_1'),
          batchNumber: const Value(1),
          species: const Value('Vannamei'),
          stockingDate: Value(DateTime.now()),
          shrimpStockedCount: const Value(50000),
        ),
      );
      await db.into(db.inventoryItems).insert(
        InventoryItemsCompanion(
          id: const Value('feed_item_1'),
          siteId: const Value('site_1'),
          category: const Value('feed'), // Category is feed, not medicine
          name: const Value('Starter Feed'),
          currentStock: const Value(100.0),
          unit: const Value('kg'),
          costPerUnit: const Value(80.0),
        ),
      );

      expect(
        () async => await db.logFeedSessionTransaction(
          feedRecord: FeedRecordsCompanion(
            id: const Value('feed_rec_fail_cat'),
            batchId: const Value('batch_1'),
            pondId: const Value('pond_1'),
            date: Value(DateTime.now()),
            timeSlot: const Value('7:00 AM'),
            starterG: const Value(20000),
            totalGrams: const Value(20000),
            totalKg: const Value(20.0),
          ),
          feedDeductions: [
            {'itemId': 'feed_item_1', 'qtyKg': 20.0, 'pelletSize': '1.0mm'},
          ],
          medicineDeductions: [
            {'itemId': 'feed_item_1', 'qty': 1.0, 'medicineName': 'Should Fail'},
          ],
        ),
        throwsA(isA<InvalidInventoryCategoryException>()),
      );
    });
  });

  group('PHASE 1 - Bug 2: Complete Master-Data Delete Safety', () {
    test('Unused site can be deleted', () async {
      await db.into(db.farmSites).insert(
        FarmSitesCompanion(id: const Value('empty_site'), name: const Value('Empty Site'), code: const Value('ES')),
      );

      final check = await db.canDeleteSite('empty_site');
      expect(check.canDelete, isTrue);
      expect(check.totalDependencies, equals(0));

      await db.deleteSiteSafely('empty_site');
      final sites = await db.select(db.farmSites).get();
      expect(sites.isEmpty, isTrue);
    });

    test('Site with inventory items cannot be deleted', () async {
      await db.into(db.farmSites).insert(
        FarmSitesCompanion(id: const Value('site_inv'), name: const Value('Site Inv'), code: const Value('SI')),
      );
      await db.into(db.inventoryItems).insert(
        InventoryItemsCompanion(
          id: const Value('inv_1'),
          siteId: const Value('site_inv'),
          category: const Value('feed'),
          name: const Value('Pellets'),
          currentStock: const Value(50.0),
          unit: const Value('kg'),
          costPerUnit: const Value(80.0),
        ),
      );

      final check = await db.canDeleteSite('site_inv');
      expect(check.canDelete, isFalse);
      expect(check.dependencyBreakdown['Inventory Items'], equals(1));

      expect(() => db.deleteSiteSafely('site_inv'), throwsA(isA<DependentRecordsExistException>()));
    });

    test('Pond with batches cannot be deleted', () async {
      await db.into(db.farmSites).insert(
        FarmSitesCompanion(id: const Value('s1'), name: const Value('Site 1'), code: const Value('S1')),
      );
      await db.into(db.ponds).insert(
        PondsCompanion(
          id: const Value('p1'),
          siteId: const Value('s1'),
          name: const Value('Pond 1'),
          areaSqMeters: const Value(1000.0),
          waterDepthMeters: const Value(1.5),
        ),
      );
      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const Value('b1'),
          pondId: const Value('p1'),
          batchNumber: const Value(1),
          species: const Value('Vannamei'),
          stockingDate: Value(DateTime.now()),
          shrimpStockedCount: const Value(10000),
        ),
      );

      final check = await db.canDeletePond('p1');
      expect(check.canDelete, isFalse);
      expect(check.dependencyBreakdown['Batches'], equals(1));

      expect(() => db.deletePondSafely('p1'), throwsA(isA<DependentRecordsExistException>()));
    });

    test('Batch with feed records cannot be deleted', () async {
      await db.into(db.farmSites).insert(
        FarmSitesCompanion(id: const Value('s1'), name: const Value('Site 1'), code: const Value('S1')),
      );
      await db.into(db.ponds).insert(
        PondsCompanion(
          id: const Value('p1'),
          siteId: const Value('s1'),
          name: const Value('Pond 1'),
          areaSqMeters: const Value(1000.0),
          waterDepthMeters: const Value(1.5),
        ),
      );
      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const Value('b1'),
          pondId: const Value('p1'),
          batchNumber: const Value(1),
          species: const Value('Vannamei'),
          stockingDate: Value(DateTime.now()),
          shrimpStockedCount: const Value(10000),
        ),
      );
      await db.into(db.feedRecords).insert(
        FeedRecordsCompanion(
          id: const Value('f1'),
          batchId: const Value('b1'),
          pondId: const Value('p1'),
          date: Value(DateTime.now()),
          timeSlot: const Value('7:00 AM'),
          starterG: const Value(5000),
          totalGrams: const Value(5000),
          totalKg: const Value(5.0),
        ),
      );

      final check = await db.canDeleteBatch('b1');
      expect(check.canDelete, isFalse);
      expect(check.dependencyBreakdown['Feed Records'], equals(1));

      expect(() => db.deleteBatchSafely('b1'), throwsA(isA<DependentRecordsExistException>()));
    });
  });

  group('PHASE 1 - Bug 3: Riverpod Site/Batch Explicit Clear', () {
    test('copyWith allows explicitly setting selectedSiteId and selectedBatchId to null', () {
      const state1 = AppSettingsState(selectedSiteId: 'site_10', selectedBatchId: 'batch_20');
      expect(state1.selectedSiteId, equals('site_10'));
      expect(state1.selectedBatchId, equals('batch_20'));

      // Explicitly clearing selectedBatchId
      final state2 = state1.copyWith(selectedBatchId: null);
      expect(state2.selectedSiteId, equals('site_10'));
      expect(state2.selectedBatchId, isNull);

      // Explicitly clearing selectedSiteId
      final state3 = state2.copyWith(selectedSiteId: null);
      expect(state3.selectedSiteId, isNull);
      expect(state3.selectedBatchId, isNull);
    });

    test('SettingsNotifier clears batch and removes shared_preferences key when clearing context', () async {
      SharedPreferences.setMockInitialValues({
        'al_selected_site': 'site_test',
        'al_selected_batch': 'batch_test',
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = AppSettingsNotifier(prefs);

      expect(notifier.state.selectedSiteId, equals('site_test'));
      expect(notifier.state.selectedBatchId, equals('batch_test'));

      // Clear batch explicitly
      await notifier.setSelectedBatchId(null);
      expect(notifier.state.selectedBatchId, isNull);
      expect(prefs.containsKey('al_selected_batch'), isFalse);

      // Clear site explicitly -> should also clear batch
      await notifier.setSelectedSiteId(null);
      expect(notifier.state.selectedSiteId, isNull);
      expect(notifier.state.selectedBatchId, isNull);
      expect(prefs.containsKey('al_selected_site'), isFalse);
    });
  });

  group('PHASE 1 - Bug 4: Invalid Inventory Purchase Boundary Validation', () {
    test('Negative or zero quantity purchase is rejected and database remains unchanged', () async {
      await db.into(db.farmSites).insert(
        FarmSitesCompanion(id: const Value('site_1'), name: const Value('Site 1'), code: const Value('S1')),
      );
      await db.into(db.inventoryItems).insert(
        InventoryItemsCompanion(
          id: const Value('feed_1'),
          siteId: const Value('site_1'),
          category: const Value('feed'),
          name: const Value('Pellet'),
          currentStock: const Value(50.0),
          unit: const Value('kg'),
          costPerUnit: const Value(80.0),
        ),
      );

      // Zero quantity
      expect(
        () async => await db.purchaseInventoryTransaction(
          itemId: 'feed_1',
          quantity: 0.0,
          unitCost: 80.0,
          totalCost: 0.0,
          date: DateTime.now(),
        ),
        throwsA(isA<InvalidInventoryQuantityException>()),
      );

      // Negative quantity
      expect(
        () async => await db.purchaseInventoryTransaction(
          itemId: 'feed_1',
          quantity: -10.0,
          unitCost: 80.0,
          totalCost: -800.0,
          date: DateTime.now(),
        ),
        throwsA(isA<InvalidInventoryQuantityException>()),
      );

      // Negative unit cost
      expect(
        () async => await db.purchaseInventoryTransaction(
          itemId: 'feed_1',
          quantity: 10.0,
          unitCost: -80.0,
          totalCost: -800.0,
          date: DateTime.now(),
        ),
        throwsA(isA<InvalidInventoryCostException>()),
      );

      // Negative total cost
      expect(
        () async => await db.purchaseInventoryTransaction(
          itemId: 'feed_1',
          quantity: 10.0,
          unitCost: 80.0,
          totalCost: -10.0,
          date: DateTime.now(),
        ),
        throwsA(isA<InvalidInventoryCostException>()),
      );

      // Confirm stock and transactions remain untouched
      final item = await (db.select(db.inventoryItems)..where((t) => t.id.equals('feed_1'))).getSingle();
      expect(item.currentStock, equals(50.0));

      final txs = await db.select(db.inventoryTransactions).get();
      expect(txs.isEmpty, isTrue);

      final exp = await db.select(db.expenses).get();
      expect(exp.isEmpty, isTrue);
    });

    test('Valid purchase succeeds and creates transaction and expense', () async {
      await db.into(db.farmSites).insert(
        FarmSitesCompanion(id: const Value('site_1'), name: const Value('Site 1'), code: const Value('S1')),
      );
      await db.into(db.inventoryItems).insert(
        InventoryItemsCompanion(
          id: const Value('feed_1'),
          siteId: const Value('site_1'),
          category: const Value('feed'),
          name: const Value('Pellet'),
          currentStock: const Value(50.0),
          unit: const Value('kg'),
          costPerUnit: const Value(80.0),
        ),
      );

      await db.purchaseInventoryTransaction(
        itemId: 'feed_1',
        quantity: 25.0,
        unitCost: 80.0,
        totalCost: 2000.0,
        date: DateTime.now(),
        supplier: 'AquaFeed Ltd',
      );

      final item = await (db.select(db.inventoryItems)..where((t) => t.id.equals('feed_1'))).getSingle();
      expect(item.currentStock, equals(75.0));

      final txs = await db.select(db.inventoryTransactions).get();
      expect(txs.length, equals(1));
      expect(txs.first.quantity, equals(25.0));
      expect(txs.first.type, equals('purchase'));

      final expenses = await db.select(db.expenses).get();
      expect(expenses.length, equals(1));
      expect(expenses.first.amount, equals(2000.0));
    });
  });
}
