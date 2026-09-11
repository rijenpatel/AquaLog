import 'package:flutter_test/flutter_test.dart';
import 'package:aqualog/core/database/app_database.dart' hide isNull, isNotNull;
import 'package:aqualog/core/services/batch_passport_pdf_service.dart';

void main() {
  group('Phase E: Batch Passport PDF Generation Tests', () {
    test('Generates valid multi-page PDF bytes with complete production data', () async {
      final now = DateTime.now();
      final site = FarmSite(
        id: 'site_1',
        name: 'Delta Estuary Farms',
        waterSource: 'brackish_estuary',
        country: 'India',
        status: 'active',
        createdAt: now,
      );

      final pond = Pond(
        id: 'pond_1',
        name: 'Pond 04',
        areaSqMeters: 5000.0,
        waterDepthMeters: 1.5,
        aeratorsCount: 4,
        totalAeratorHp: 8.0,
        status: 'active',
        createdAt: now,
      );

      final batch = Batch(
        id: 'batch_1',
        pondId: 'pond_1',
        batchNumber: 4,
        species: 'Litopenaeus vannamei',
        stockingDate: now.subtract(const Duration(days: 90)),
        shrimpStockedCount: 150000,
        plStage: 'PL-10',
        hatcherySource: 'Apex Shrimp Hatchery',
        seedCost: 75000.0,
        targetHarvestWeightG: 25.0,
        status: 'completed',
        harvestDate: now,
        harvestWeightKg: 3200.0,
        harvestCount: 132000,
        salePricePerKg: 390.0,
        hapaStockedCount: 100,
        targetDoc: 90,
        buyerName: 'Ocean Catch Exports',
        createdAt: now.subtract(const Duration(days: 90)),
      );

      final samplings = [
        SamplingEntry(
          id: 's_1',
          batchId: 'batch_1',
          pondId: 'pond_1',
          date: now.subtract(const Duration(days: 45)),
          doc: 45,
          samplingTotalWeightG: 1200.0,
          samplingShrimpCount: 100,
          abwGrams: 12.0,
          adgGramsPerDay: 0.27,
          createdAt: now,
        ),
      ];

      final feedRecords = <FeedRecord>[
        FeedRecord(
          id: 'f_1',
          pondId: 'pond_1',
          batchId: 'batch_1',
          date: now.subtract(const Duration(days: 10)),
          timeSlot: '7:00 AM',
          starterG: 0.0,
          grower1G: 45000.0,
          grower2G: 0.0,
          finisher1G: 0.0,
          finisher2G: 0.0,
          otherFeedG: 0.0,
          totalGrams: 45000.0,
          totalKg: 45.0,
          trayChecked: true,
          trayLeftoverPct: 0,
          synced: false,
          createdAt: now,
        ),
      ];

      final wqLogs = [
        WaterQualityLog(
          id: 'wq_1',
          pondId: 'pond_1',
          batchId: 'batch_1',
          date: now.subtract(const Duration(days: 2)),
          timeSlot: 'Morning',
          dissolvedOxygen: 5.4,
          ph: 7.9,
          temperature: 29.5,
          salinity: 18.0,
          ammonia: 0.02,
          nitrite: 0.04,
          createdAt: now,
        ),
      ];

      final operations = [
        PondOperation(
          id: 'op_1',
          pondId: 'pond_1',
          batchId: 'batch_1',
          date: now.subtract(const Duration(days: 15)),
          operationType: 'exchange',
          volumeLiters: 500000.0,
          percentageExchanged: 10.0,
          createdAt: now,
        ),
      ];

      final revenues = [
        Revenue(
          id: 'rev_1',
          batchId: 'batch_1',
          date: now,
          harvestWeightKg: 3200.0,
          pricePerKg: 390.0,
          totalAmount: 1248000.0,
          harvestType: 'full',
          createdAt: now,
        ),
      ];

      final pdfBytes = await BatchPassportPdfService.generatePassportPdfBytes(
        site: site,
        pond: pond,
        batch: batch,
        samplings: samplings,
        feedRecords: feedRecords,
        wqLogs: wqLogs,
        mortalities: const [],
        adjustments: const [],
        operations: operations,
        treatments: const [],
        expenses: const [],
        revenues: revenues,
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      // PDF documents always start with '%PDF-'
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('Handles batches with zero/missing records gracefully without exceptions', () async {
      final now = DateTime.now();
      final site = FarmSite(id: 's', name: 'Site', country: 'India', status: 'active', createdAt: now);
      final pond = Pond(id: 'p', name: 'Pond', areaSqMeters: 4000.0, waterDepthMeters: 1.2, aeratorsCount: 0, totalAeratorHp: 0.0, status: 'active', createdAt: now);
      final batch = Batch(
        id: 'b',
        pondId: 'p',
        batchNumber: 1,
        species: 'Litopenaeus vannamei',
        stockingDate: now,
        shrimpStockedCount: 50000,
        plStage: 'PL-10',
        seedCost: 20000.0,
        targetHarvestWeightG: 25.0,
        status: 'active',
        hapaStockedCount: 100,
        targetDoc: 90,
        createdAt: now,
      );

      final pdfBytes = await BatchPassportPdfService.generatePassportPdfBytes(
        site: site,
        pond: pond,
        batch: batch,
        samplings: const [],
        feedRecords: const [],
        wqLogs: const [],
        mortalities: const [],
        adjustments: const [],
        operations: const [],
        treatments: const [],
        expenses: const [],
        revenues: const [],
      );

      expect(pdfBytes.isNotEmpty, isTrue);
    });
  });
}
