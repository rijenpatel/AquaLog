import 'package:drift/drift.dart';

class UserProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class FarmSites extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable()();
  TextColumn get waterSource => text().nullable()(); // 'brackish_estuary', 'freshwater', 'marine'
  TextColumn get address => text().nullable()();
  TextColumn get villageCity => text().nullable()();
  TextColumn get district => text().nullable()();
  TextColumn get state => text().nullable()();
  TextColumn get country => text().withDefault(const Constant('India'))();
  TextColumn get postalCode => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // 'active', 'inactive'
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Ponds extends Table {
  TextColumn get id => text()();
  TextColumn get siteId => text().nullable().references(FarmSites, #id)();
  TextColumn get name => text()();
  RealColumn get areaSqMeters => real()();
  RealColumn get waterDepthMeters => real()();
  IntColumn get aeratorsCount => integer().withDefault(const Constant(0))();
  RealColumn get totalAeratorHp => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('active'))(); // 'active', 'inactive', 'archived', 'deleted'
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Batches extends Table {
  TextColumn get id => text()();
  TextColumn get pondId => text().references(Ponds, #id)();
  IntColumn get batchNumber => integer()();
  TextColumn get species => text().withDefault(const Constant('Litopenaeus vannamei'))();
  DateTimeColumn get stockingDate => dateTime()();
  IntColumn get shrimpStockedCount => integer()();
  TextColumn get plStage => text().withDefault(const Constant('PL-10'))();
  TextColumn get hatcherySource => text().nullable()();
  RealColumn get seedCost => real().withDefault(const Constant(0.0))();
  RealColumn get targetHarvestWeightG => real().withDefault(const Constant(25.0))();
  TextColumn get status => text().withDefault(const Constant('active'))(); // 'planned', 'active', 'completed', 'archived'
  DateTimeColumn get harvestDate => dateTime().nullable()();
  RealColumn get harvestWeightKg => real().nullable()();
  IntColumn get harvestCount => integer().nullable()();
  TextColumn get harvestType => text().nullable()(); // 'full', 'partial'
  TextColumn get buyerName => text().nullable()();
  RealColumn get salePricePerKg => real().nullable()();
  RealColumn get actualFcr => real().nullable()();
  RealColumn get actualSurvivalPct => real().nullable()();
  IntColumn get hapaStockedCount => integer().withDefault(const Constant(100))();
  IntColumn get targetDoc => integer().withDefault(const Constant(93))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class FeedRecords extends Table {
  TextColumn get id => text()();
  TextColumn get pondId => text().references(Ponds, #id)();
  TextColumn get batchId => text().references(Batches, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get timeSlot => text()(); // '7:00 AM', '11:00 AM', '4:00 PM', '7:00 PM', 'Other'
  TextColumn get customTime => text().nullable()();
  RealColumn get starterG => real().withDefault(const Constant(0.0))();
  RealColumn get grower1G => real().withDefault(const Constant(0.0))();
  RealColumn get grower2G => real().withDefault(const Constant(0.0))();
  RealColumn get finisher1G => real().withDefault(const Constant(0.0))();
  RealColumn get finisher2G => real().withDefault(const Constant(0.0))();
  TextColumn get otherFeedName => text().nullable()();
  RealColumn get otherFeedG => real().withDefault(const Constant(0.0))();
  RealColumn get totalGrams => real()();
  RealColumn get totalKg => real()();
  BoolColumn get trayChecked => boolean().withDefault(const Constant(false))();
  IntColumn get trayLeftoverPct => integer().withDefault(const Constant(0))();
  TextColumn get coFedMedicinesJson => text().nullable()(); // JSON array of co-fed medicines
  TextColumn get feedItemsJson => text().nullable()(); // JSON array of dynamic feed items [{inventoryFeedId, feedName, brand, size, quantity, unit}]
  TextColumn get notes => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class SamplingEntries extends Table {
  TextColumn get id => text()();
  TextColumn get batchId => text().references(Batches, #id)();
  TextColumn get pondId => text().references(Ponds, #id)();
  DateTimeColumn get date => dateTime()();
  IntColumn get doc => integer()();
  RealColumn get samplingTotalWeightG => real()();
  IntColumn get samplingShrimpCount => integer()();
  RealColumn get abwGrams => real()();
  RealColumn get adgGramsPerDay => real().nullable()();
  RealColumn get weightGainGrams => real().nullable()();
  IntColumn get daysElapsed => integer().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class HapaChecks extends Table {
  TextColumn get id => text()();
  TextColumn get batchId => text().references(Batches, #id)();
  TextColumn get pondId => text().references(Ponds, #id)();
  DateTimeColumn get date => dateTime()();
  IntColumn get hoursElapsed => integer().withDefault(const Constant(24))();
  IntColumn get hapaStocked => integer().withDefault(const Constant(100))();
  IntColumn get hapaAlive => integer()();
  RealColumn get survivalPercentage => real()();
  IntColumn get estimatedPopulation => integer()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class GrowthRecords extends Table {
  TextColumn get id => text()();
  TextColumn get batchId => text().references(Batches, #id)();
  TextColumn get pondId => text().references(Ponds, #id)();
  DateTimeColumn get date => dateTime()();
  IntColumn get doc => integer()();
  RealColumn get estimatedAbwGrams => real()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class BiomassSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get batchId => text().references(Batches, #id)();
  TextColumn get pondId => text().references(Ponds, #id)();
  DateTimeColumn get date => dateTime()();
  RealColumn get biomassKg => real()();
  TextColumn get source => text()(); // 'sampling', 'visual'
  IntColumn get estimatedPopulation => integer()();
  RealColumn get abwGrams => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class InventoryItems extends Table {
  TextColumn get id => text()();
  TextColumn get siteId => text().nullable().references(FarmSites, #id)();
  TextColumn get category => text()(); // 'feed', 'medicine', 'fuel'
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get pelletSize => text().nullable()();
  TextColumn get medicineCategory => text().nullable()();
  TextColumn get fuelType => text().nullable()();
  TextColumn get unit => text().withDefault(const Constant('kg'))(); // 'kg', 'L', 'units', 'bottles', 'packs'
  RealColumn get bagWeightKg => real().withDefault(const Constant(25.0))();
  RealColumn get currentStock => real().withDefault(const Constant(0.0))();
  RealColumn get lowStockThreshold => real().withDefault(const Constant(10.0))();
  RealColumn get costPerUnit => real().withDefault(const Constant(0.0))();
  TextColumn get supplier => text().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  TextColumn get batchLotNumber => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class InventoryTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(InventoryItems, #id)();
  TextColumn get siteId => text().nullable().references(FarmSites, #id)();
  TextColumn get type => text()(); // 'purchase', 'consumption', 'manual_adjustment', 'expired', 'damaged'
  RealColumn get quantity => real()(); // Positive for inward, negative for outward
  RealColumn get unitPrice => real().withDefault(const Constant(0.0))();
  RealColumn get totalCost => real().withDefault(const Constant(0.0))();
  DateTimeColumn get date => dateTime()();
  TextColumn get referenceRecordId => text().nullable()();
  TextColumn get referenceType => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get batchId => text().nullable().references(Batches, #id)();
  TextColumn get siteId => text().nullable().references(FarmSites, #id)();
  TextColumn get pondId => text().nullable().references(Ponds, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get category => text()(); // 'feed', 'seed', 'power', 'labor', 'medicine', 'maintenance', 'rent', 'equipment', 'other'
  RealColumn get amount => real()();
  TextColumn get description => text()();
  TextColumn get inventoryTxId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Revenues extends Table {
  TextColumn get id => text()();
  TextColumn get batchId => text().references(Batches, #id)();
  DateTimeColumn get date => dateTime()();
  RealColumn get harvestWeightKg => real()();
  RealColumn get pricePerKg => real()();
  RealColumn get totalAmount => real()();
  TextColumn get buyerName => text().nullable()();
  TextColumn get harvestType => text().withDefault(const Constant('full'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MarketPrices extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get countCategory => text()(); // '30 count', '40 count', '60 count', '100 count'
  RealColumn get pricePerKg => real()();
  TextColumn get location => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MachineRuns extends Table {
  TextColumn get id => text()();
  TextColumn get siteId => text().nullable().references(FarmSites, #id)();
  TextColumn get machineName => text()();
  TextColumn get fuelItemId => text().nullable().references(InventoryItems, #id)();
  TextColumn get fuelType => text().withDefault(const Constant('Diesel'))();
  DateTimeColumn get date => dateTime()();
  RealColumn get runtimeHours => real()();
  RealColumn get startHourMeter => real().nullable()();
  RealColumn get endHourMeter => real().nullable()();
  RealColumn get fuelBurnRateLPerHr => real().withDefault(const Constant(7.5))();
  RealColumn get fuelConsumedLiters => real()();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class TreatmentRecords extends Table {
  TextColumn get id => text()();
  TextColumn get pondId => text().references(Ponds, #id)();
  TextColumn get batchId => text().references(Batches, #id)();
  TextColumn get itemId => text().references(InventoryItems, #id)();
  TextColumn get productName => text()();
  RealColumn get quantityApplied => real()();
  TextColumn get unit => text().withDefault(const Constant('kg'))();
  RealColumn get dosageRatePpm => real().nullable()();
  TextColumn get treatmentReason => text().nullable()();
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class WeatherObservations extends Table {
  TextColumn get id => text()();
  TextColumn get siteId => text().nullable().references(FarmSites, #id)();
  DateTimeColumn get date => dateTime()();
  RealColumn get temperature => real()();
  RealColumn get feelsLike => real().nullable()();
  RealColumn get humidity => real().nullable()();
  RealColumn get windSpeed => real().nullable()();
  RealColumn get rainProbability => real().nullable()();
  TextColumn get condition => text().nullable()();
  RealColumn get uvIndex => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class WaterQualityLogs extends Table {
  TextColumn get id => text()();
  TextColumn get pondId => text().references(Ponds, #id)();
  TextColumn get batchId => text().nullable().references(Batches, #id)();
  TextColumn get siteId => text().nullable().references(FarmSites, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get timeSlot => text().withDefault(const Constant('Morning'))(); // 'Morning', 'Afternoon', 'Evening', 'Custom'
  RealColumn get temperature => real().nullable()(); // °C
  RealColumn get ph => real().nullable()();
  RealColumn get dissolvedOxygen => real().nullable()(); // mg/L
  RealColumn get salinity => real().nullable()(); // ppt
  RealColumn get ammonia => real().nullable()(); // mg/L
  RealColumn get nitrite => real().nullable()(); // mg/L
  RealColumn get alkalinity => real().nullable()(); // mg/L
  RealColumn get transparencyCm => real().nullable()(); // cm
  RealColumn get waterDepthMeters => real().nullable()(); // meters
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class MortalityRecords extends Table {
  TextColumn get id => text()();
  TextColumn get pondId => text().references(Ponds, #id)();
  TextColumn get batchId => text().references(Batches, #id)();
  DateTimeColumn get date => dateTime()();
  IntColumn get countObserved => integer().withDefault(const Constant(0))();
  IntColumn get countEstimated => integer().withDefault(const Constant(0))();
  TextColumn get reason => text().withDefault(const Constant('normal'))(); // 'normal', 'stress', 'disease_suspected', 'low_do', 'weather', 'handling', 'unknown', 'other'
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class PopulationAdjustments extends Table {
  TextColumn get id => text()();
  TextColumn get batchId => text().references(Batches, #id)();
  TextColumn get pondId => text().nullable().references(Ponds, #id)();
  DateTimeColumn get date => dateTime()();
  IntColumn get adjustedCount => integer()();
  IntColumn get previousCount => integer()();
  IntColumn get differenceCount => integer()();
  TextColumn get reason => text()(); // 'sampling_correction', 'stocking_correction', 'counting_correction', 'data_correction', 'other'
  TextColumn get source => text().withDefault(const Constant('manual'))(); // 'manual', 'sampling_derived', 'system'
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class PondOperations extends Table {
  TextColumn get id => text()();
  TextColumn get pondId => text().references(Ponds, #id)();
  TextColumn get batchId => text().nullable().references(Batches, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get operationType => text()(); // 'exchange', 'addition', 'removal', 'partial_drain', 'full_drain', 'top_up'
  RealColumn get volumeLiters => real()();
  RealColumn get percentageExchanged => real().nullable()();
  TextColumn get source => text().nullable()(); // 'canal', 'borewell', 'reservoir', 'other'
  TextColumn get pumpEquipment => text().nullable()();
  TextColumn get reason => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class FarmActionTasks extends Table {
  TextColumn get id => text()();
  TextColumn get siteId => text().nullable().references(FarmSites, #id)();
  TextColumn get pondId => text().nullable().references(Ponds, #id)();
  TextColumn get batchId => text().nullable().references(Batches, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text()(); // 'water_quality', 'mortality', 'sampling', 'feed', 'inventory', 'harvest', 'operation', 'other'
  TextColumn get priority => text().withDefault(const Constant('normal'))(); // 'critical', 'high', 'normal', 'low'
  TextColumn get status => text().withDefault(const Constant('pending'))(); // 'pending', 'in_progress', 'completed', 'skipped', 'dismissed'
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get source => text().withDefault(const Constant('system'))(); // 'system', 'manual'
  TextColumn get resolutionNotes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class DailyFeedPlans extends Table {
  TextColumn get id => text()();
  TextColumn get pondId => text().references(Ponds, #id)();
  TextColumn get batchId => text().references(Batches, #id)();
  DateTimeColumn get date => dateTime()();
  RealColumn get baseFeedKg => real()();
  RealColumn get trayAdjustmentKg => real().withDefault(const Constant(0.0))();
  RealColumn get weatherAdjustmentKg => real().withDefault(const Constant(0.0))();
  RealColumn get wqAdjustmentKg => real().withDefault(const Constant(0.0))();
  RealColumn get mortalityAdjustmentKg => real().withDefault(const Constant(0.0))();
  RealColumn get recommendedFeedKg => real()();
  RealColumn get actualPlannedKg => real()();
  TextColumn get adjustmentReason => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // 'pending', 'accepted', 'modified', 'skipped'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
