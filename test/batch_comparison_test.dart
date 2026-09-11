import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:aqualog/core/database/app_database.dart' hide isNull, isNotNull;
import 'package:aqualog/core/services/batch_comparison_service.dart';
import 'package:aqualog/core/models/batch_comparison_models.dart';
import 'package:aqualog/core/services/demo_data_service.dart';

void main() {
  late AppDatabase db;
  late BatchComparisonService comparisonService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    comparisonService = BatchComparisonService(db);
    await DemoDataService(db).loadDemoData();
  });

  tearDown(() async {
    await db.close();
  });

  group('Batch Comparison Feature Tests', () {
    test('1. Loads and compares 2 active batches with Same DOC mode', () async {
      // batch_pond_1 (DOC 73) and batch_pond_2 (DOC 46)
      final result = await comparisonService.compareBatches(
        batchIds: ['batch_pond_1', 'batch_pond_2'],
        mode: ComparisonMode.sameDoc,
      );

      expect(result, isNotNull);
      expect(result.batches.length, equals(2));
      expect(result.batches[0].batchNumber, equals(4));
      expect(result.batches[1].batchNumber, equals(2));
      expect(result.batches[0].status, equals('active'));
      expect(result.batches[1].status, equals('active'));

      // Check quick comparison metrics
      expect(result.metrics.isNotEmpty, isTrue);
      final abwMetric = result.metrics.firstWhere((m) => m.key == 'abw');
      expect(abwMetric.direction, equals(MetricDirection.higherIsBetter));
      expect(abwMetric.rawValues.length, equals(2));
      // In batch_pond_1 and batch_pond_2, batch_pond_1 (DOC 73) has higher ABW than batch_pond_2 (DOC 46)
      expect(abwMetric.bestBatchId, equals('batch_pond_1'));

      final fcrMetric = result.metrics.firstWhere((m) => m.key == 'fcr');
      expect(fcrMetric.direction, equals(MetricDirection.lowerIsBetter));
      expect(fcrMetric.bestBatchId, isNotNull);

      final countMetric = result.metrics.firstWhere((m) => m.key == 'count');
      expect(countMetric.direction, equals(MetricDirection.lowerIsBetter));

      // Check growth comparison series
      expect(result.growthPoints.isNotEmpty, isTrue);
      expect(result.growthPoints.any((p) => p.batchId == 'batch_pond_1'), isTrue);
      expect(result.growthPoints.any((p) => p.batchId == 'batch_pond_2'), isTrue);

      // Check feed comparison series
      expect(result.feedPoints.isNotEmpty, isTrue);
      // Check FCR series
      expect(result.fcrPoints.isNotEmpty, isTrue);

      // Verify category performance summary exists without unexplained synthetic overall score
      expect(result.performanceSummary.isNotEmpty, isTrue);
    });

    test('2. Compares 3 batches including Active vs Completed', () async {
      // batch_pond_1 (Active), batch_pond_2 (Active), batch_pond_4_completed (Completed)
      final result = await comparisonService.compareBatches(
        batchIds: ['batch_pond_1', 'batch_pond_2', 'batch_pond_4_completed'],
        mode: ComparisonMode.sameDoc,
      );

      expect(result.batches.length, equals(3));
      expect(result.batches[0].status, equals('active'));
      expect(result.batches[1].status, equals('active'));
      expect(result.batches[2].status, equals('completed'));

      // Completed batch should have final harvest metrics
      expect(result.harvestData.isNotEmpty, isTrue);
      final completedHarvest = result.harvestData.firstWhere((h) => h.batchId == 'batch_pond_4_completed');
      expect(completedHarvest.harvestWeightKg, greaterThan(0));
      expect(completedHarvest.actualFcr, greaterThan(0));

      // Check financial comparison
      expect(result.financialData.length, equals(3));
      for (final fin in result.financialData) {
        expect(fin.totalCost, greaterThan(0));
      }
    });

    test('3. Same Date mode groups feed data by calendar date', () async {
      final result = await comparisonService.compareBatches(
        batchIds: ['batch_pond_1', 'batch_pond_2'],
        mode: ComparisonMode.sameDate,
      );

      expect(result.mode, equals(ComparisonMode.sameDate));
      expect(result.feedPoints.isNotEmpty, isTrue);
      for (final pt in result.feedPoints) {
        expect(pt.date, isNotNull);
        expect(pt.feedKg, greaterThan(0));
      }
    });

    test('4. Excludes pre-stocking feed records from batch comparison', () async {
      // Stocking date of batch_pond_1 is 72 days ago
      final batch1 = await (db.select(db.batches)..where((b) => b.id.equals('batch_pond_1'))).getSingle();
      final preStockingDate = batch1.stockingDate.subtract(const Duration(days: 5));

      // Insert an invalid feed record before stocking date
      await db.into(db.feedRecords).insert(
        FeedRecordsCompanion(
          id: const drift.Value('feed_invalid_prestock'),
          batchId: const drift.Value('batch_pond_1'),
          pondId: drift.Value(batch1.pondId),
          date: drift.Value(preStockingDate),
          timeSlot: const drift.Value('06:00 AM'),
          totalGrams: const drift.Value(50000),
          totalKg: const drift.Value(50.0),
          trayChecked: const drift.Value(false),
          trayLeftoverPct: const drift.Value(0),
          notes: const drift.Value('Invalid pre-stock feed'),
          createdAt: drift.Value(DateTime.now()),
        ),
      );

      final result = await comparisonService.compareBatches(
        batchIds: ['batch_pond_1', 'batch_pond_2'],
        mode: ComparisonMode.sameDoc,
      );

      // Pre-stocking feed points (DOC <= 0) must be excluded from feed comparison points
      for (final pt in result.feedPoints.where((p) => p.batchId == 'batch_pond_1')) {
        expect(pt.doc, greaterThanOrEqualTo(1));
      }
    });

    test('5. Handles missing data gracefully and does not crash', () async {
      // Create a brand new batch with no samplings and no feed
      const emptyBatchId = 'batch_empty_test';
      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const drift.Value(emptyBatchId),
          pondId: const drift.Value('pond_1'),
          batchNumber: const drift.Value(99),
          species: const drift.Value('L. vannamei'),
          status: const drift.Value('active'),
          stockingDate: drift.Value(DateTime.now().subtract(const Duration(days: 5))),
          shrimpStockedCount: const drift.Value(50000),
          hapaStockedCount: const drift.Value(500),
          targetDoc: const drift.Value(100),
          targetHarvestWeightG: const drift.Value(25.0),
          createdAt: drift.Value(DateTime.now()),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );

      final result = await comparisonService.compareBatches(
        batchIds: ['batch_pond_1', emptyBatchId],
        mode: ComparisonMode.sameDoc,
      );

      expect(result.batches.length, equals(2));
      expect(result.performanceSummary, isNotEmpty);
      expect(result.metrics.isNotEmpty, isTrue);
    });

    test('6. Prevents comparing fewer than 2 batches', () async {
      expect(
        () => comparisonService.compareBatches(batchIds: ['batch_pond_1']),
        throwsArgumentError,
      );
    });
  });
}
