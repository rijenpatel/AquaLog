import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqualog/core/database/app_database.dart';
import 'package:aqualog/core/services/demo_data_service.dart';
import 'package:aqualog/core/services/backup_service.dart';
import 'package:aqualog/core/services/legacy_import_service.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late BackupService backupService;
  late DemoDataService demoService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    backupService = BackupService(db);
    demoService = DemoDataService(db);

    await demoService.loadDemoData();
  });

  tearDown(() async {
    await db.close();
  });

  test('Exports full database to JSON and restores atomically', () async {
    // 1. Export Demo Data
    final jsonStr = await backupService.exportToJson();
    expect(jsonStr.contains('"application": "AquaLog"'), isTrue);
    expect(jsonStr.contains('Bhimavaram Creek Farm'), isTrue);

    // 2. Open fresh database and restore
    final freshDb = AppDatabase(NativeDatabase.memory());
    final freshBackupService = BackupService(freshDb);

    final summary = await freshBackupService.restoreFromJson(jsonStr);
    expect(summary['ponds'], 6);
    expect(summary['batches'], 5);
    expect(summary['feedRecords']! > 0, isTrue);
    expect(summary['inventoryItems']! > 0, isTrue);

    final restoredPonds = await freshDb.select(freshDb.ponds).get();
    expect(restoredPonds.length, 6);

    await freshDb.close();
  });

  test('Detects and migrates legacy web application JSON export', () async {
    const legacyJson = '''
    {
      "al_ponds": [
        {"id": "p1", "name": "Old Pond 1", "area": 3500, "depth": 1.4, "aerators": 6, "hp": 12}
      ],
      "al_batches": [
        {"id": "b1", "pondId": "p1", "batchNum": 1, "species": "L. vannamei", "stockingDate": "2026-06-01", "count": 90000}
      ],
      "al_records": [
        {"id": "r1", "pondId": "p1", "batchId": "b1", "date": "2026-06-05", "time": "7:00 AM", "feed2": 4500, "total": 4500, "trayLeftover": 0}
      ],
      "al_inventory": [
        {"id": "inv1", "name": "Grower 1.2mm", "category": "feed", "stock": 800, "costPerUnit": 85}
      ]
    }
    ''';

    expect(LegacyImportService.isLegacyFormat(legacyJson), isTrue);

    final importDb = AppDatabase(NativeDatabase.memory());
    final service = LegacyImportService(importDb);

    final result = await service.importLegacyJson(legacyJson);
    expect(result.pondsImported, 1);
    expect(result.batchesImported, 1);
    expect(result.recordsImported, 1);
    expect(result.inventoryImported, 1);
    expect(result.errorsCount, 0);

    final ponds = await importDb.select(importDb.ponds).get();
    expect(ponds.first.name, 'Old Pond 1');
    expect(ponds.first.areaSqMeters, 3500.0);

    await importDb.close();
  });
}
