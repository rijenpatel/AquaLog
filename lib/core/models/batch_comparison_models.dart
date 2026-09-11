import 'package:flutter/material.dart';

enum ComparisonMode {
  sameDoc,
  sameDate,
}

enum MetricDirection {
  higherIsBetter,
  lowerIsBetter,
  neutral,
}

/// Metadata representation for a batch in comparison
class BatchMetaItem {
  final String batchId;
  final int batchNumber;
  final String pondId;
  final String pondName;
  final String? siteId;
  final String siteName;
  final String species;
  final String status; // 'active' or 'completed'
  final DateTime stockingDate;
  final DateTime? harvestDate;
  final int currentOrHarvestDoc;
  final int shrimpStockedCount;
  final Color color;

  const BatchMetaItem({
    required this.batchId,
    required this.batchNumber,
    required this.pondId,
    required this.pondName,
    this.siteId,
    required this.siteName,
    required this.species,
    required this.status,
    required this.stockingDate,
    this.harvestDate,
    required this.currentOrHarvestDoc,
    required this.shrimpStockedCount,
    required this.color,
  });

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  String get displayName => '$pondName — Batch #$batchNumber';
}

/// Single metric row comparing values across batches
class ComparisonMetricItem {
  final String key;
  final String label;
  final String unit;
  final MetricDirection direction;
  final Map<String, double?> rawValues;
  final Map<String, String> displayStrings;
  final String? bestBatchId;
  final String? clarificationNote;

  const ComparisonMetricItem({
    required this.key,
    required this.label,
    required this.unit,
    required this.direction,
    required this.rawValues,
    required this.displayStrings,
    this.bestBatchId,
    this.clarificationNote,
  });

  bool isBest(String batchId) => bestBatchId == batchId;
}

/// Data point for Growth Comparison (ABW vs DOC / Date)
class GrowthComparisonPoint {
  final String batchId;
  final int doc;
  final DateTime date;
  final double abwGrams;
  final double? adgGramsPerDay;
  final String source;

  const GrowthComparisonPoint({
    required this.batchId,
    required this.doc,
    required this.date,
    required this.abwGrams,
    this.adgGramsPerDay,
    required this.source,
  });
}

/// Data point for Feed Consumption Comparison
class FeedComparisonPoint {
  final String batchId;
  final int doc;
  final DateTime date;
  final double feedKg;

  const FeedComparisonPoint({
    required this.batchId,
    required this.doc,
    required this.date,
    required this.feedKg,
  });
}

/// Data point for FCR comparison
class FcrComparisonPoint {
  final String batchId;
  final int doc;
  final DateTime date;
  final double fcr;

  const FcrComparisonPoint({
    required this.batchId,
    required this.doc,
    required this.date,
    required this.fcr,
  });
}

/// Harvest performance comparison for completed/mature batches
class HarvestComparisonItem {
  final String batchId;
  final int harvestDoc;
  final double finalAbwGrams;
  final double harvestWeightKg;
  final int? harvestCount;
  final double survivalPct;
  final double actualFcr;
  final double? salePricePerKg;
  final String? buyerName;

  const HarvestComparisonItem({
    required this.batchId,
    required this.harvestDoc,
    required this.finalAbwGrams,
    required this.harvestWeightKg,
    this.harvestCount,
    required this.survivalPct,
    required this.actualFcr,
    this.salePricePerKg,
    this.buyerName,
  });
}

/// Financial metrics for comparison
class FinancialComparisonItem {
  final String batchId;
  final double totalCost;
  final double totalRevenue;
  final double netProfit;
  final double marginPct;
  final double? costPerKg;
  final double? breakEvenPricePerKg;

  const FinancialComparisonItem({
    required this.batchId,
    required this.totalCost,
    required this.totalRevenue,
    required this.netProfit,
    required this.marginPct,
    this.costPerKg,
    this.breakEvenPricePerKg,
  });
}

/// Complete aggregated comparison result
class BatchComparisonResult {
  final List<BatchMetaItem> batches;
  final ComparisonMode mode;
  final List<ComparisonMetricItem> metrics;
  final List<GrowthComparisonPoint> growthPoints;
  final List<FeedComparisonPoint> feedPoints;
  final List<FcrComparisonPoint> fcrPoints;
  final List<HarvestComparisonItem> harvestData;
  final List<FinancialComparisonItem> financialData;
  final Map<String, String> performanceSummary;

  const BatchComparisonResult({
    required this.batches,
    required this.mode,
    required this.metrics,
    required this.growthPoints,
    required this.feedPoints,
    required this.fcrPoints,
    required this.harvestData,
    required this.financialData,
    required this.performanceSummary,
  });

  BatchMetaItem? getBatch(String batchId) {
    return batches.where((b) => b.batchId == batchId).firstOrNull;
  }
}
