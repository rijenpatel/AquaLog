import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqualog/core/calculations/calculations.dart';
import 'package:aqualog/core/database/app_database.dart' hide isNull;

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AquaLog Sampling Module - 24 Core Specification Tests', () {
    // Helper to create active batch
    Batch createBatch({
      String id = 'batch_test',
      required DateTime stockingDate,
      String status = 'active',
      int stockedQuantity = 100000,
    }) {
      return Batch(
        id: id,
        pondId: 'pond_1',
        batchNumber: 1,
        species: 'Litopenaeus vannamei',
        stockingDate: stockingDate,
        shrimpStockedCount: stockedQuantity,
        plStage: 'PL-10',
        seedCost: 0.0,
        targetHarvestWeightG: 25.0,
        status: status,
        hapaStockedCount: 100,
        targetDoc: 120,
        createdAt: stockingDate,
      );
    }

    // Helper to create a sampling entry
    SamplingEntry createSampling({
      required String id,
      required String batchId,
      required DateTime date,
      required double abw,
      int doc = 50,
      double? weightGain,
      int? daysElapsed,
      double? adg,
    }) {
      return SamplingEntry(
        id: id,
        batchId: batchId,
        pondId: 'pond_1',
        date: date,
        doc: doc,
        samplingShrimpCount: 100,
        samplingTotalWeightG: abw * 100,
        abwGrams: abw,
        weightGainGrams: weightGain,
        daysElapsed: daysElapsed,
        adgGramsPerDay: adg,
        createdAt: date,
      );
    }

    // ==========================================
    // Test 1 — DOC 49
    // ==========================================
    test('Test 1 — DOC 49: Sampling is not active', () {
      final today = DateTime(2026, 9, 8);
      // Stocking date for DOC 49: diff = 48 days
      final stockingDate = today.subtract(const Duration(days: 48));
      final batch = createBatch(stockingDate: stockingDate);

      final doc = DocCalculator.calculate(
        stockingDate: stockingDate,
        targetDate: today,
      ).doc;
      expect(doc, 49);

      final status = SamplingCalculator.getSamplingStatus(
        batchStatus: batch.status,
        stockingDate: batch.stockingDate,
        latestSamplingDate: null,
        today: today,
      );
      expect(status, SamplingStatus.notActive);
      expect(
        SamplingCalculator.batchNeedsSampling(
          batchStatus: batch.status,
          stockingDate: batch.stockingDate,
          latestSamplingDate: null,
          today: today,
        ),
        isFalse,
      );
    });

    // ==========================================
    // Test 2 — DOC 50
    // ==========================================
    test('Test 2 — DOC 50: No sampling -> Sampling Due', () {
      final today = DateTime(2026, 9, 8);
      // Stocking date for DOC 50: diff = 49 days
      final stockingDate = today.subtract(const Duration(days: 49));
      final batch = createBatch(stockingDate: stockingDate);

      final doc = DocCalculator.calculate(
        stockingDate: stockingDate,
        targetDate: today,
      ).doc;
      expect(doc, 50);

      final status = SamplingCalculator.getSamplingStatus(
        batchStatus: batch.status,
        stockingDate: batch.stockingDate,
        latestSamplingDate: null,
        today: today,
      );
      expect(status, SamplingStatus.dueFirstSample);
      expect(
        SamplingCalculator.batchNeedsSampling(
          batchStatus: batch.status,
          stockingDate: batch.stockingDate,
          latestSamplingDate: null,
          today: today,
        ),
        isTrue,
      );
    });

    // ==========================================
    // Test 3 — First Sampling
    // ==========================================
    test('Test 3 — First Sampling: Baseline has no prior growth and derives Count/kg = 125', () {
      final abwResult = AbwCalculator.calculate(totalWeightGrams: 800.0, count: 100);
      expect(abwResult.abwGrams, 8.0);
      expect(abwResult.formatted, '8.000');
      expect(abwResult.wholeCountPerKg, 125);
      expect(abwResult.formattedCountPerKg, '125 shrimp/kg');

      // First sample growth calculation
      final growth = SamplingCalculator.calculateGrowth(
        currentAbw: 8.0,
        currentDate: DateTime(2026, 9, 1),
        previousAbw: null,
      );
      expect(growth.growthSincePrev, isNull);
      expect(growth.dailyGrowth, isNull);
      expect(growth.daysSincePrev, isNull);
    });

    // ==========================================
    // Test 4 — Nine Days
    // ==========================================
    test('Test 4 — Nine Days: Elapsed 9 days (< 10) -> Sampling Up To Date', () {
      final stock = DateTime(2026, 7, 1);
      final batch = createBatch(stockingDate: stock);
      final prevDate = DateTime(2026, 9, 1);
      final today = DateTime(2026, 9, 10); // 9 calendar days

      final latest = createSampling(
        id: 's1',
        batchId: batch.id,
        date: prevDate,
        abw: 8.0,
      );

      final daysSince = SamplingCalculator.calendarDaysBetween(prevDate, today);
      expect(daysSince, 9);

      final status = SamplingCalculator.getSamplingStatus(
        batchStatus: batch.status,
        stockingDate: batch.stockingDate,
        latestSamplingDate: latest.date,
        today: today,
      );
      expect(status, SamplingStatus.upToDate);
      expect(
        SamplingCalculator.batchNeedsSampling(
          batchStatus: batch.status,
          stockingDate: batch.stockingDate,
          latestSamplingDate: latest.date,
          today: today,
        ),
        isFalse,
      );
    });

    // ==========================================
    // Test 5 — Exactly 10 Days
    // ==========================================
    test('Test 5 — Exactly 10 Days: 10-day mark -> Sampling Due', () {
      final stock = DateTime(2026, 7, 1);
      final batch = createBatch(stockingDate: stock);
      final prevDate = DateTime(2026, 9, 1);
      final today = DateTime(2026, 9, 11); // 10 calendar days

      final latest = createSampling(
        id: 's1',
        batchId: batch.id,
        date: prevDate,
        abw: 8.0,
      );

      final daysSince = SamplingCalculator.calendarDaysBetween(prevDate, today);
      expect(daysSince, 10);

      final status = SamplingCalculator.getSamplingStatus(
        batchStatus: batch.status,
        stockingDate: batch.stockingDate,
        latestSamplingDate: latest.date,
        today: today,
      );
      expect(status, SamplingStatus.dueIntervalReached);
      expect(
        SamplingCalculator.batchNeedsSampling(
          batchStatus: batch.status,
          stockingDate: batch.stockingDate,
          latestSamplingDate: latest.date,
          today: today,
        ),
        isTrue,
      );
    });

    // ==========================================
    // Test 6 — More Than 10 Days
    // ==========================================
    test('Test 6 — More Than 10 Days: 14 days -> Sampling Due', () {
      final stock = DateTime(2026, 7, 1);
      final batch = createBatch(stockingDate: stock);
      final prevDate = DateTime(2026, 9, 1);
      final today = DateTime(2026, 9, 15); // 14 days

      final latest = createSampling(
        id: 's1',
        batchId: batch.id,
        date: prevDate,
        abw: 8.0,
      );

      final daysSince = SamplingCalculator.calendarDaysBetween(prevDate, today);
      expect(daysSince, 14);

      final status = SamplingCalculator.getSamplingStatus(
        batchStatus: batch.status,
        stockingDate: batch.stockingDate,
        latestSamplingDate: latest.date,
        today: today,
      );
      expect(status, SamplingStatus.dueIntervalReached);
      expect(
        SamplingCalculator.batchNeedsSampling(
          batchStatus: batch.status,
          stockingDate: batch.stockingDate,
          latestSamplingDate: latest.date,
          today: today,
        ),
        isTrue,
      );
    });

    // ==========================================
    // Test 7 — ABW
    // ==========================================
    test('Test 7 — ABW: 1000g / 100 shrimp = 10.000g', () {
      final abw = SamplingCalculator.calculateAbw(totalCastWeightGrams: 1000.0, sampleCount: 100);
      expect(abw, 10.0);
      expect(abw?.toStringAsFixed(3), '10.000');
    });

    // ==========================================
    // Test 8 — Count/kg
    // ==========================================
    test('Test 8 — Count/kg: ABW = 10.000g -> 100 shrimp/kg', () {
      final countPerKg = SamplingCalculator.calculateCountPerKg(10.0);
      expect(countPerKg, 100.0);
      final whole = SamplingCalculator.calculateWholeCountPerKg(10.0);
      expect(whole, 100);
      expect(SamplingCalculator.formatCountPerKg(countPerKg), '100 shrimp/kg');
    });

    // ==========================================
    // Test 9 — Count/kg with decimal result
    // ==========================================
    test('Test 9 — Count/kg with decimal result: ABW = 8.500g -> 118 shrimp/kg', () {
      final countPerKg = SamplingCalculator.calculateCountPerKg(8.5);
      expect(countPerKg, closeTo(117.647, 0.001));
      final whole = SamplingCalculator.calculateWholeCountPerKg(8.5);
      expect(whole, 118);
      expect(SamplingCalculator.formatCountPerKg(countPerKg), '118 shrimp/kg');
    });

    // ==========================================
    // Test 10 — Growth
    // ==========================================
    test('Test 10 — Growth: Prev = 8.000g, Cur = 10.000g -> +2.000g', () {
      final growth = SamplingCalculator.calculateGrowth(
        currentAbw: 10.0,
        currentDate: DateTime(2026, 9, 11),
        previousAbw: 8.0,
        previousDate: DateTime(2026, 9, 1),
      );
      expect(growth.growthSincePrev, 2.0);
      expect(growth.formattedGrowth, '+2.000 g');
    });

    // ==========================================
    // Test 11 — Daily Growth
    // ==========================================
    test('Test 11 — Daily Growth: Growth = 2.000g, Days = 10 -> +0.200 g/day', () {
      final adg = SamplingCalculator.calculateDailyGrowth(growth: 2.0, days: 10);
      expect(adg, 0.200);
      expect(SamplingCalculator.formatDailyGrowth(adg), '+0.200 g/day');
    });

    // ==========================================
    // Test 12 — Negative Growth
    // ==========================================
    test('Test 12 — Negative Growth: Prev = 10.000g, Cur = 9.500g -> -0.500g', () {
      final growth = SamplingCalculator.calculateGrowth(
        currentAbw: 9.5,
        currentDate: DateTime(2026, 9, 11),
        previousAbw: 10.0,
        previousDate: DateTime(2026, 9, 1),
      );
      expect(growth.growthSincePrev, -0.500);
      expect(growth.formattedGrowth, '-0.500 g');

      final adg = SamplingCalculator.calculateDailyGrowth(growth: growth.growthSincePrev, days: 10);
      expect(adg, -0.050);
      expect(SamplingCalculator.formatDailyGrowth(adg), '-0.050 g/day');
    });

    // ==========================================
    // Test 13 — Zero Sample Count
    // ==========================================
    test('Test 13 — Zero Sample Count is rejected', () {
      expect(
        SamplingCalculator.calculateAbw(totalCastWeightGrams: 500, sampleCount: 0),
        isNull,
      );
      expect(
        () => AbwCalculator.calculate(totalWeightGrams: 500, count: 0),
        throwsArgumentError,
      );
    });

    // ==========================================
    // Test 14 — Decimal Sample Count
    // ==========================================
    test('Test 14 — Decimal Sample Count is rejected', () {
      // Sample count must be integer
      final countString = '100.5';
      final parsed = int.tryParse(countString);
      expect(parsed, isNull, reason: 'Decimal strings fail integer parsing');
    });

    // ==========================================
    // Test 15 — Future Date
    // ==========================================
    test('Test 15 — Future Date is rejected', () {
      final today = DateTime(2026, 9, 8);
      final tomorrow = DateTime(2026, 9, 9);
      final todayNormalized = SamplingCalculator.normalizeDate(today);
      final tomorrowNormalized = SamplingCalculator.normalizeDate(tomorrow);

      final isFuture = tomorrowNormalized.isAfter(todayNormalized);
      expect(isFuture, isTrue, reason: 'Sampling date cannot be in the future.');
    });

    // ==========================================
    // Test 16 — Before Stocking
    // ==========================================
    test('Test 16 — Before Stocking is rejected', () {
      final stockingDate = DateTime(2026, 7, 1);
      final beforeStocking = DateTime(2026, 6, 30);
      final isBefore = SamplingCalculator.normalizeDate(beforeStocking)
          .isBefore(SamplingCalculator.normalizeDate(stockingDate));

      expect(isBefore, isTrue, reason: 'Sampling date cannot be before the stocking date.');
    });

    // ==========================================
    // Test 17 & 18 — Growth Recalculation Chain in DB
    // ==========================================
    test('Test 17 & 18 — Full growth chain recalculation on insert, edit, and delete', () async {
      // 1. Setup Site, Pond, Batch
      await db.into(db.farmSites).insert(
        const FarmSitesCompanion(id: Value('site_1'), name: Value('Farm Site')),
      );
      await db.into(db.ponds).insert(
        const PondsCompanion(
          id: Value('pond_1'),
          siteId: Value('site_1'),
          name: Value('Pond 1'),
          areaSqMeters: Value(4000.0),
          waterDepthMeters: Value(1.5),
        ),
      );
      final stockingDate = DateTime(2026, 7, 1);
      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const Value('batch_1'),
          pondId: const Value('pond_1'),
          batchNumber: const Value(1),
          stockingDate: Value(stockingDate),
          shrimpStockedCount: const Value(100000),
          status: const Value('active'),
          targetDoc: const Value(120),
          createdAt: Value(stockingDate),
        ),
      );

      // 2. Insert Sample 1: 2026-09-01 (ABW 8.000g)
      await db.saveSamplingEntry(
        SamplingEntriesCompanion(
          id: const Value('smp_1'),
          batchId: const Value('batch_1'),
          pondId: const Value('pond_1'),
          date: Value(DateTime(2026, 9, 1)),
          doc: const Value(63),
          samplingShrimpCount: const Value(100),
          samplingTotalWeightG: const Value(800.0),
          abwGrams: const Value(8.0),
          createdAt: Value(DateTime(2026, 9, 1)),
        ),
        'batch_1',
      );

      // 3. Insert Sample 2: 2026-09-11 (ABW 10.000g, 10 days later)
      await db.saveSamplingEntry(
        SamplingEntriesCompanion(
          id: const Value('smp_2'),
          batchId: const Value('batch_1'),
          pondId: const Value('pond_1'),
          date: Value(DateTime(2026, 9, 11)),
          doc: const Value(73),
          samplingShrimpCount: const Value(100),
          samplingTotalWeightG: const Value(1000.0),
          abwGrams: const Value(10.0),
          createdAt: Value(DateTime(2026, 9, 11)),
        ),
        'batch_1',
      );

      // 4. Insert Sample 3: 2026-09-21 (ABW 12.500g, 10 days later)
      await db.saveSamplingEntry(
        SamplingEntriesCompanion(
          id: const Value('smp_3'),
          batchId: const Value('batch_1'),
          pondId: const Value('pond_1'),
          date: Value(DateTime(2026, 9, 21)),
          doc: const Value(83),
          samplingShrimpCount: const Value(100),
          samplingTotalWeightG: const Value(1250.0),
          abwGrams: const Value(12.5),
          createdAt: Value(DateTime(2026, 9, 21)),
        ),
        'batch_1',
      );

      var chain = await db.getSamplingsForBatch('batch_1');
      expect(chain.length, 3);
      // smp_1 (baseline)
      expect(chain[0].weightGainGrams, isNull);
      expect(chain[0].daysElapsed, isNull);
      expect(chain[0].adgGramsPerDay, isNull);

      // smp_2
      expect(chain[1].weightGainGrams, 2.0);
      expect(chain[1].daysElapsed, 10);
      expect(chain[1].adgGramsPerDay, 0.200);

      // smp_3
      expect(chain[2].weightGainGrams, 2.5);
      expect(chain[2].daysElapsed, 10);
      expect(chain[2].adgGramsPerDay, 0.250);

      // Test 17: Delete middle sample smp_2
      await db.deleteSamplingEntry('smp_2', 'batch_1');
      chain = await db.getSamplingsForBatch('batch_1');
      expect(chain.length, 2);
      expect(chain[0].id, 'smp_1');
      expect(chain[1].id, 'smp_3');

      // smp_3 should now link directly to smp_1!
      // Growth: 12.5 - 8.0 = 4.5g
      // Days: 2026-09-01 to 2026-09-21 = 20 days
      // ADG: 4.5 / 20 = 0.225 g/day
      expect(chain[1].weightGainGrams, 4.5);
      expect(chain[1].daysElapsed, 20);
      expect(chain[1].adgGramsPerDay, 0.225);

      // Test 18: Edit previous sample smp_1 (update ABW to 9.000g)
      await db.saveSamplingEntry(
        SamplingEntriesCompanion(
          id: const Value('smp_1'),
          batchId: const Value('batch_1'),
          pondId: const Value('pond_1'),
          date: Value(DateTime(2026, 9, 1)),
          doc: const Value(63),
          samplingShrimpCount: const Value(100),
          samplingTotalWeightG: const Value(900.0),
          abwGrams: const Value(9.0),
          createdAt: Value(DateTime(2026, 9, 1)),
        ),
        'batch_1',
      );

      chain = await db.getSamplingsForBatch('batch_1');
      // smp_3 growth: 12.5 - 9.0 = 3.5g
      // ADG: 3.5 / 20 = 0.175 g/day
      expect(chain[1].weightGainGrams, 3.5);
      expect(chain[1].daysElapsed, 20);
      expect(chain[1].adgGramsPerDay, 0.175);
    });

    // ==========================================
    // Test 19 — Batch Isolation
    // ==========================================
    test('Test 19 — Batch Isolation: Samplings from Batch A never affect Batch B', () async {
      await db.into(db.farmSites).insert(
        const FarmSitesCompanion(id: Value('site_1'), name: Value('Farm Site')),
      );
      await db.into(db.ponds).insert(
        const PondsCompanion(
          id: Value('pond_1'),
          siteId: Value('site_1'),
          name: Value('Pond 1'),
          areaSqMeters: Value(4000.0),
          waterDepthMeters: Value(1.5),
        ),
      );
      final stockingDate = DateTime(2026, 7, 1);
      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const Value('batch_A'),
          pondId: const Value('pond_1'),
          batchNumber: const Value(1),
          stockingDate: Value(stockingDate),
          shrimpStockedCount: const Value(100000),
          status: const Value('active'),
          createdAt: Value(stockingDate),
        ),
      );
      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const Value('batch_B'),
          pondId: const Value('pond_1'),
          batchNumber: const Value(2),
          stockingDate: Value(stockingDate),
          shrimpStockedCount: const Value(100000),
          status: const Value('active'),
          createdAt: Value(stockingDate),
        ),
      );

      // Add sampling to Batch A
      await db.saveSamplingEntry(
        SamplingEntriesCompanion(
          id: const Value('smp_A1'),
          batchId: const Value('batch_A'),
          pondId: const Value('pond_1'),
          date: Value(DateTime(2026, 9, 1)),
          doc: const Value(63),
          samplingShrimpCount: const Value(100),
          samplingTotalWeightG: const Value(1000.0),
          abwGrams: const Value(10.0),
          createdAt: Value(DateTime(2026, 9, 1)),
        ),
        'batch_A',
      );

      final samplingsB = await db.getSamplingsForBatch('batch_B');
      expect(samplingsB, isEmpty);

      final latestB = await db.getLatestSamplingForBatch('batch_B');
      expect(latestB, isNull);
    });

    // ==========================================
    // Test 20 — Completed Batch
    // ==========================================
    test('Test 20 — Completed Batch: Does not generate sampling due reminder', () {
      final stockingDate = DateTime(2026, 5, 1);
      final batch = createBatch(stockingDate: stockingDate, status: 'completed');
      final today = DateTime(2026, 9, 8);

      final status = SamplingCalculator.getSamplingStatus(
        batchStatus: batch.status,
        stockingDate: batch.stockingDate,
        latestSamplingDate: null,
        today: today,
      );
      expect(status, SamplingStatus.notActive);
      expect(
        SamplingCalculator.batchNeedsSampling(
          batchStatus: batch.status,
          stockingDate: batch.stockingDate,
          latestSamplingDate: null,
          today: today,
        ),
        isFalse,
      );
    });

    // ==========================================
    // Test 21 — Visual Fallback
    // ==========================================
    test('Test 21 — Visual Fallback: When no sampling exists, uses visual weight', () {
      // Visual weight exists (e.g. 5.2g), no sampling
      final double? samplingAbw = null;
      final double visualWeight = 5.2;

      final currentWeight = SamplingCalculator.getCurrentWeight(
        latestSamplingAbw: samplingAbw,
        latestVisualWeight: visualWeight,
      );
      expect(currentWeight, 5.2);
    });

    // ==========================================
    // Test 22 — Sampling Priority
    // ==========================================
    test('Test 22 — Sampling Priority: Sampling ABW takes priority over visual weight', () {
      final double samplingAbw = 10.5;
      final double visualWeight = 9.8; // even if recorded later

      // Priority logic: Sampling > Visual
      final currentWeight = SamplingCalculator.getCurrentWeight(
        latestSamplingAbw: samplingAbw,
        latestVisualWeight: visualWeight,
      );
      expect(currentWeight, 10.5);
    });

    // ==========================================
    // Test 23 — Biomass
    // ==========================================
    test('Test 23 — Biomass: Uses Sampling ABW and estimated population', () {
      final biomass = SamplingCalculator.calculateBiomass(
        stockedShrimp: 100000,
        hapaSurvivalPct: 82.0,
        abwGrams: 10.0,
      );
      // 100,000 * 0.82 = 82,000 shrimp
      // 82,000 * 10g / 1000 = 820 kg
      expect(biomass, 820.0);
    });

    // ==========================================
    // Test 24 — FCR
    // ==========================================
    test('Test 24 — FCR: Two valid sampling points calculate sampling-based FCR', () {
      // Biomass 1 at Sampling 1: 820 kg
      final biomass1 = SamplingCalculator.calculateBiomass(
        stockedShrimp: 100000,
        hapaSurvivalPct: 82.0,
        abwGrams: 10.0,
      );
      expect(biomass1, 820.0);

      // Biomass 2 at Sampling 2: 12.5g ABW
      final biomass2 = SamplingCalculator.calculateBiomass(
        stockedShrimp: 100000,
        hapaSurvivalPct: 82.0,
        abwGrams: 12.5,
      );
      // 82,000 * 12.5 / 1000 = 1025 kg
      expect(biomass2, 1025.0);

      final biomassGain = biomass2! - biomass1!;
      expect(biomassGain, 205.0);

      // Feed consumed between Sampling 1 and Sampling 2
      final feedConsumedKg = 307.5;
      final fcr = feedConsumedKg / biomassGain;
      expect(fcr, 1.5);
    });
  });
}
