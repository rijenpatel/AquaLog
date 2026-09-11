import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:aqualog/core/database/app_database.dart';
import 'package:aqualog/core/calculations/feed_calculator.dart';

void main() {
  group('FeedItem & FeedCalculator Model & Normalization Tests', () {
    test('FeedItem JSON serialization and deserialization', () {
      const item = FeedItem(
        inventoryFeedId: 'inv_123',
        feedName: 'Grower Feed',
        brand: 'CP Aqua',
        size: '1.5 mm',
        quantity: 25.0,
        unit: 'kg',
      );

      final json = item.toJson();
      expect(json['inventoryFeedId'], 'inv_123');
      expect(json['feedName'], 'Grower Feed');
      expect(json['quantity'], 25.0);

      final fromJson = FeedItem.fromJson(json);
      expect(fromJson.inventoryFeedId, 'inv_123');
      expect(fromJson.feedName, 'Grower Feed');
      expect(fromJson.size, '1.5 mm');
      expect(fromJson.quantityKg, 25.0);
    });

    test('Unit normalization to kg', () {
      expect(FeedCalculator.normalizeFeedQuantityToKg(5000, 'g'), 5.0);
      expect(FeedCalculator.normalizeFeedQuantityToKg(2500, 'grams'), 2.5);
      expect(FeedCalculator.normalizeFeedQuantityToKg(20, 'kg'), 20.0);
      expect(FeedCalculator.normalizeFeedQuantityToKg(2, 'bags'), 50.0);
    });

    test('Backward compatibility: legacy fields normalize into FeedItems', () {
      final legacyRecord = FeedRecord(
        id: 'legacy_rec_1',
        pondId: 'p1',
        batchId: 'b1',
        date: DateTime(2026, 9, 8),
        timeSlot: '7:00 AM',
        starterG: 5000.0, // 5 kg
        grower1G: 10000.0, // 10 kg
        grower2G: 0.0,
        finisher1G: 0.0,
        finisher2G: 0.0,
        otherFeedG: 2000.0, // 2 kg
        otherFeedName: 'Special Probiotic Feed',
        totalGrams: 17000.0,
        totalKg: 17.0,
        trayChecked: true,
        trayLeftoverPct: 0,
        synced: false,
        createdAt: DateTime.now(),
      );

      final items = FeedCalculator.getRecordItems(legacyRecord);
      expect(items.length, 3);
      expect(items.any((i) => i.feedName == 'Starter Feed' && i.quantityKg == 5.0), isTrue);
      expect(items.any((i) => i.feedName == 'Grower Feed' && i.quantityKg == 10.0), isTrue);
      expect(items.any((i) => i.feedName == 'Special Probiotic Feed' && i.quantityKg == 2.0), isTrue);
      expect(FeedCalculator.getRecordTotalKg(legacyRecord), 17.0);
    });

    test('Dynamic feedItemsJson takes precedence and calculates total kg', () {
      final dynamicItems = [
        const FeedItem(
          inventoryFeedId: 'inv_feed_1',
          feedName: 'Starter Feed',
          size: '1.0 mm',
          quantity: 12.5,
          unit: 'kg',
        ),
        const FeedItem(
          inventoryFeedId: 'inv_feed_2',
          feedName: 'Grower Feed',
          size: '1.5 mm',
          quantity: 7.5,
          unit: 'kg',
        ),
      ];

      final modernRecord = FeedRecord(
        id: 'modern_rec_1',
        pondId: 'p1',
        batchId: 'b1',
        date: DateTime(2026, 9, 8),
        timeSlot: '11:00 AM',
        starterG: 0.0,
        grower1G: 0.0,
        grower2G: 0.0,
        finisher1G: 0.0,
        finisher2G: 0.0,
        otherFeedG: 0.0,
        totalGrams: 20000.0,
        totalKg: 20.0,
        trayChecked: false,
        trayLeftoverPct: 0,
        feedItemsJson: jsonEncode(dynamicItems.map((i) => i.toJson()).toList()),
        synced: false,
        createdAt: DateTime.now(),
      );

      final items = FeedCalculator.getRecordItems(modernRecord);
      expect(items.length, 2);
      expect(items[0].feedName, 'Starter Feed');
      expect(items[0].quantityKg, 12.5);
      expect(items[1].feedName, 'Grower Feed');
      expect(items[1].quantityKg, 7.5);
      expect(FeedCalculator.getRecordTotalKg(modernRecord), 20.0);
    });

    test('Previous session quantity comparison and change indicators', () {
      final prevItems = [
        const FeedItem(
          inventoryFeedId: 'feed_1',
          feedName: 'Grower Feed',
          size: '1.5 mm',
          quantity: 20.0,
          unit: 'kg',
        ),
      ];

      final prevRecord = FeedRecord(
        id: 'rec_prev',
        pondId: 'p1',
        batchId: 'b1',
        date: DateTime(2026, 9, 8),
        timeSlot: '7:00 AM',
        starterG: 0.0,
        grower1G: 0.0,
        grower2G: 0.0,
        finisher1G: 0.0,
        finisher2G: 0.0,
        otherFeedG: 0.0,
        totalGrams: 20000.0,
        totalKg: 20.0,
        trayChecked: false,
        trayLeftoverPct: 0,
        feedItemsJson: jsonEncode(prevItems.map((i) => i.toJson()).toList()),
        synced: false,
        createdAt: DateTime.now(),
      );

      // Increase test
      final incItem = const FeedItem(
        inventoryFeedId: 'feed_1',
        feedName: 'Grower Feed',
        size: '1.5 mm',
        quantity: 25.0,
        unit: 'kg',
      );
      final incRes = FeedCalculator.getItemQuantityChange(currentItem: incItem, previousRecord: prevRecord);
      expect(incRes['status'], 'increase');
      expect(incRes['diffKg'], 5.0);

      // Decrease test
      final decItem = const FeedItem(
        inventoryFeedId: 'feed_1',
        feedName: 'Grower Feed',
        size: '1.5 mm',
        quantity: 18.0,
        unit: 'kg',
      );
      final decRes = FeedCalculator.getItemQuantityChange(currentItem: decItem, previousRecord: prevRecord);
      expect(decRes['status'], 'decrease');
      expect(decRes['diffKg'], -2.0);

      // Same test
      final sameItem = const FeedItem(
        inventoryFeedId: 'feed_1',
        feedName: 'Grower Feed',
        size: '1.5 mm',
        quantity: 20.0,
        unit: 'kg',
      );
      final sameRes = FeedCalculator.getItemQuantityChange(currentItem: sameItem, previousRecord: prevRecord);
      expect(sameRes['status'], 'same');
      expect(sameRes['diffKg'], 0.0);

      // New item test
      final newItem = const FeedItem(
        inventoryFeedId: 'feed_2',
        feedName: 'Finisher Feed',
        size: '2.5 mm',
        quantity: 10.0,
        unit: 'kg',
      );
      final newRes = FeedCalculator.getItemQuantityChange(currentItem: newItem, previousRecord: prevRecord);
      expect(newRes['status'], 'new');
    });

    test('Feed stock availability check rejects insufficient inventory', () {
      final items = [
        const FeedItem(
          inventoryFeedId: 'feed_a',
          feedName: 'Grower 1.5 mm',
          quantity: 30.0,
          unit: 'kg',
        ),
        const FeedItem(
          inventoryFeedId: 'feed_b',
          feedName: 'Grower 2.0 mm',
          quantity: 15.0,
          unit: 'kg',
        ),
      ];

      // Sufficient stock case
      final valid = FeedCalculator.validateFeedInventoryAvailability(
        requestedItems: items,
        availableStockByInventoryId: {
          'feed_a': 50.0,
          'feed_b': 20.0,
        },
      );
      expect(valid.isValid, isTrue);
      expect(valid.errors, isEmpty);

      // Insufficient stock case on feed_a
      final invalid = FeedCalculator.validateFeedInventoryAvailability(
        requestedItems: items,
        availableStockByInventoryId: {
          'feed_a': 25.0, // Requested 30.0
          'feed_b': 20.0,
        },
      );
      expect(invalid.isValid, isFalse);
      expect(invalid.errors.length, 1);
      expect(invalid.errors.first, contains('Grower 1.5 mm'));
    });

    test('Daily, Weekly, Monthly, and Distribution aggregations', () {
      final records = [
        FeedRecord(
          id: 'r1',
          pondId: 'p1',
          batchId: 'b1',
          date: DateTime(2026, 9, 1),
          timeSlot: '7:00 AM',
          starterG: 0, grower1G: 0, grower2G: 0, finisher1G: 0, finisher2G: 0, otherFeedG: 0,
          totalGrams: 20000, totalKg: 20,
          trayChecked: false, trayLeftoverPct: 0, synced: false, createdAt: DateTime.now(),
          feedItemsJson: jsonEncode([
            const FeedItem(inventoryFeedId: 'f1', feedName: 'Grower 1.5 mm', quantity: 20, unit: 'kg').toJson(),
          ]),
        ),
        FeedRecord(
          id: 'r2',
          pondId: 'p2',
          batchId: 'b1',
          date: DateTime(2026, 9, 1),
          timeSlot: '11:00 AM',
          starterG: 0, grower1G: 0, grower2G: 0, finisher1G: 0, finisher2G: 0, otherFeedG: 0,
          totalGrams: 15000, totalKg: 15,
          trayChecked: false, trayLeftoverPct: 0, synced: false, createdAt: DateTime.now(),
          feedItemsJson: jsonEncode([
            const FeedItem(inventoryFeedId: 'f2', feedName: 'Grower 2.0 mm', quantity: 15, unit: 'kg').toJson(),
          ]),
        ),
      ];

      // Daily
      final daily = FeedCalculator.getDailyFeedTotals(records, DateTime(2026, 9, 1));
      expect(daily['totalKg'], 35.0);
      expect(daily['sessionCount'], 2);
      expect(daily['pondsFedCount'], 2);

      // Distribution by feed
      final byType = FeedCalculator.getFeedDistributionByType(records);
      expect(byType['Grower 1.5 mm'], 20.0);
      expect(byType['Grower 2.0 mm'], 15.0);

      // Distribution by pond
      final byPond = FeedCalculator.getFeedDistributionByPond(records, {'p1': 'Basin 1', 'p2': 'Basin 2'});
      expect(byPond['Basin 1'], 20.0);
      expect(byPond['Basin 2'], 15.0);
    });
  });

  group('Drift In-Memory Database Feed Transactions', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());

      // Seed Site
      await db.into(db.farmSites).insert(
        const FarmSitesCompanion(
          id: drift.Value('site_1'),
          name: drift.Value('Coastal Farm'),
        ),
      );

      // Seed Pond
      await db.into(db.ponds).insert(
        const PondsCompanion(
          id: drift.Value('pond_1'),
          siteId: drift.Value('site_1'),
          name: drift.Value('Basin #1'),
          areaSqMeters: drift.Value(1000.0),
          waterDepthMeters: drift.Value(1.5),
        ),
      );

      // Seed Batch
      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const drift.Value('batch_1'),
          pondId: const drift.Value('pond_1'),
          batchNumber: const drift.Value(1),
          species: const drift.Value('L. vannamei'),
          stockingDate: drift.Value(DateTime(2026, 8, 1)),
          shrimpStockedCount: const drift.Value(100000),
          status: const drift.Value('active'),
          targetDoc: const drift.Value(93),
        ),
      );

      // Seed Feed Inventory Item
      await db.into(db.inventoryItems).insert(
        const InventoryItemsCompanion(
          id: drift.Value('feed_stock_1'),
          siteId: drift.Value('site_1'),
          category: drift.Value('feed'),
          name: drift.Value('CP Classic Grower 1.5mm'),
          currentStock: drift.Value(100.0),
          unit: drift.Value('kg'),
          costPerUnit: drift.Value(90.0),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('logFeedSessionTransaction deducts stock and writes consumption transaction', () async {
      final feedItems = [
        const FeedItem(
          inventoryFeedId: 'feed_stock_1',
          feedName: 'CP Classic Grower 1.5mm',
          quantity: 20.0,
          unit: 'kg',
        ),
      ];

      await db.logFeedSessionTransaction(
        feedRecord: FeedRecordsCompanion(
          id: const drift.Value('feed_rec_test_1'),
          batchId: const drift.Value('batch_1'),
          pondId: const drift.Value('pond_1'),
          date: drift.Value(DateTime(2026, 9, 8)),
          timeSlot: const drift.Value('7:00 AM'),
          totalGrams: const drift.Value(20000.0),
          totalKg: const drift.Value(20.0),
          feedItemsJson: drift.Value(jsonEncode(feedItems.map((i) => i.toJson()).toList())),
        ),
        feedDeductions: [
          {
            'itemId': 'feed_stock_1',
            'qtyKg': 20.0,
            'pelletSize': '1.5mm',
          },
        ],
      );

      // Verify stock deducted from 100 to 80
      final item = await (db.select(db.inventoryItems)..where((t) => t.id.equals('feed_stock_1'))).getSingle();
      expect(item.currentStock, 80.0);

      // Verify transaction recorded
      final txs = await (db.select(db.inventoryTransactions)..where((t) => t.referenceRecordId.equals('feed_rec_test_1'))).get();
      expect(txs.length, 1);
      expect(txs.first.quantity, -20.0);
      expect(txs.first.referenceType, 'feed_log');
    });

    test('InsufficientStockException thrown when requesting more than stock', () async {
      final feedItems = [
        const FeedItem(
          inventoryFeedId: 'feed_stock_1',
          feedName: 'CP Classic Grower 1.5mm',
          quantity: 150.0, // Stock is 100
          unit: 'kg',
        ),
      ];

      expect(
        () async => db.logFeedSessionTransaction(
          feedRecord: FeedRecordsCompanion(
            id: const drift.Value('feed_rec_excess'),
            batchId: const drift.Value('batch_1'),
            pondId: const drift.Value('pond_1'),
            date: drift.Value(DateTime(2026, 9, 8)),
            timeSlot: const drift.Value('7:00 AM'),
            totalGrams: const drift.Value(150000.0),
            totalKg: const drift.Value(150.0),
            feedItemsJson: drift.Value(jsonEncode(feedItems.map((i) => i.toJson()).toList())),
          ),
          feedDeductions: [
            {'itemId': 'feed_stock_1', 'qtyKg': 150.0, 'pelletSize': '1.5mm'},
          ],
        ),
        throwsA(isA<InsufficientStockException>()),
      );

      // Stock remains untouched at 100.0
      final item = await (db.select(db.inventoryItems)..where((t) => t.id.equals('feed_stock_1'))).getSingle();
      expect(item.currentStock, 100.0);
    });

    test('updateFeedSessionTransaction reverses old stock and deducts new stock atomically', () async {
      // 1. Initial 20 kg feed log
      await db.logFeedSessionTransaction(
        feedRecord: FeedRecordsCompanion(
          id: const drift.Value('feed_rec_edit_test'),
          batchId: const drift.Value('batch_1'),
          pondId: const drift.Value('pond_1'),
          date: drift.Value(DateTime(2026, 9, 8)),
          timeSlot: const drift.Value('7:00 AM'),
          totalGrams: const drift.Value(20000.0),
          totalKg: const drift.Value(20.0),
        ),
        feedDeductions: [
          {'itemId': 'feed_stock_1', 'qtyKg': 20.0, 'pelletSize': '1.5mm'},
        ],
      );
      var item = await (db.select(db.inventoryItems)..where((t) => t.id.equals('feed_stock_1'))).getSingle();
      expect(item.currentStock, 80.0);

      // 2. Edit from 20 kg to 30 kg
      await db.updateFeedSessionTransaction(
        feedRecord: FeedRecordsCompanion(
          id: const drift.Value('feed_rec_edit_test'),
          batchId: const drift.Value('batch_1'),
          pondId: const drift.Value('pond_1'),
          date: drift.Value(DateTime(2026, 9, 8)),
          timeSlot: const drift.Value('7:00 AM'),
          totalGrams: const drift.Value(30000.0),
          totalKg: const drift.Value(30.0),
        ),
        feedDeductions: [
          {'itemId': 'feed_stock_1', 'qtyKg': 30.0, 'pelletSize': '1.5mm'},
        ],
      );

      // Final stock should be 100 - 30 = 70 kg, not 80 - 30 = 50 kg!
      item = await (db.select(db.inventoryItems)..where((t) => t.id.equals('feed_stock_1'))).getSingle();
      expect(item.currentStock, 70.0);
    });

    test('deleteFeedRecordWithRollback restores stock and removes transaction', () async {
      // 1. Initial 25 kg feed log
      await db.logFeedSessionTransaction(
        feedRecord: FeedRecordsCompanion(
          id: const drift.Value('feed_rec_del_test'),
          batchId: const drift.Value('batch_1'),
          pondId: const drift.Value('pond_1'),
          date: drift.Value(DateTime(2026, 9, 8)),
          timeSlot: const drift.Value('11:00 AM'),
          totalGrams: const drift.Value(25000.0),
          totalKg: const drift.Value(25.0),
        ),
        feedDeductions: [
          {'itemId': 'feed_stock_1', 'qtyKg': 25.0, 'pelletSize': '1.5mm'},
        ],
      );
      var item = await (db.select(db.inventoryItems)..where((t) => t.id.equals('feed_stock_1'))).getSingle();
      expect(item.currentStock, 75.0);

      // 2. Delete with rollback
      await db.deleteFeedRecordWithRollback('feed_rec_del_test');

      // Stock should be restored to 100.0
      item = await (db.select(db.inventoryItems)..where((t) => t.id.equals('feed_stock_1'))).getSingle();
      expect(item.currentStock, 100.0);

      // Feed record should be deleted
      final rec = await (db.select(db.feedRecords)..where((t) => t.id.equals('feed_rec_del_test'))).getSingleOrNull();
      expect(rec == null, isTrue);
    });
  });
}
