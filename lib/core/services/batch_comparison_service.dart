import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/batch_comparison_models.dart';
import '../calculations/calculations.dart';
import '../calculations/feed_calculator.dart';

class BatchComparisonService {
  final AppDatabase db;

  const BatchComparisonService(this.db);

  static const List<Color> batchPalette = [
    Color(0xFF006876), // Deep Teal
    Color(0xFF6C3483), // Royal Amethyst
    Color(0xFFD35400), // Rich Rust / Amber
    Color(0xFF1E8449), // Emerald Forest
  ];

  Future<BatchComparisonResult> compareBatches({
    required List<String> batchIds,
    ComparisonMode mode = ComparisonMode.sameDoc,
  }) async {
    if (batchIds.length < 2) {
      throw ArgumentError('At least 2 batches must be provided for comparison.');
    }

    final uniqueBatchIds = batchIds.toSet().toList();

    // 1. Fetch Batches
    final batches = await (db.select(db.batches)
          ..where((t) => t.id.isIn(uniqueBatchIds)))
        .get();

    if (batches.length < 2) {
      throw ArgumentError('Selected batches could not be found in database.');
    }

    // Preserve original selection order
    batches.sort((a, b) => uniqueBatchIds.indexOf(a.id).compareTo(uniqueBatchIds.indexOf(b.id)));

    // 2. Fetch Ponds and Sites
    final pondIds = batches.map((b) => b.pondId).toSet().toList();
    final ponds = await (db.select(db.ponds)..where((t) => t.id.isIn(pondIds))).get();
    final pondMap = {for (final p in ponds) p.id: p};

    final siteIds = ponds.map((p) => p.siteId).whereType<String>().toSet().toList();
    final sites = siteIds.isNotEmpty
        ? await (db.select(db.farmSites)..where((t) => t.id.isIn(siteIds))).get()
        : <FarmSite>[];
    final siteMap = {for (final s in sites) s.id: s};

    // 3. Fetch Scoped Dependent Data
    final allFeedRecords = await (db.select(db.feedRecords)
          ..where((t) => t.batchId.isIn(uniqueBatchIds)))
        .get();

    final allSamplings = await (db.select(db.samplingEntries)
          ..where((t) => t.batchId.isIn(uniqueBatchIds)))
        .get();

    final allExpenses = await (db.select(db.expenses)
          ..where((t) => t.batchId.isIn(uniqueBatchIds)))
        .get();

    final allRevenues = await (db.select(db.revenues)
          ..where((t) => t.batchId.isIn(uniqueBatchIds)))
        .get();

    final allHapa = await (db.select(db.hapaChecks)
          ..where((t) => t.batchId.isIn(uniqueBatchIds)))
        .get();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 4. Build BatchMetaItems
    final metaList = <BatchMetaItem>[];
    for (int i = 0; i < batches.length; i++) {
      final b = batches[i];
      final pond = pondMap[b.pondId];
      final site = pond != null && pond.siteId != null ? siteMap[pond.siteId] : null;

      final sDate = DateTime(b.stockingDate.year, b.stockingDate.month, b.stockingDate.day);
      final effectiveEnd = b.status == 'completed' && b.harvestDate != null
          ? DateTime(b.harvestDate!.year, b.harvestDate!.month, b.harvestDate!.day)
          : today;
      final doc = effectiveEnd.difference(sDate).inDays + 1;

      metaList.add(BatchMetaItem(
        batchId: b.id,
        batchNumber: b.batchNumber,
        pondId: b.pondId,
        pondName: pond?.name ?? 'Pond',
        siteId: site?.id,
        siteName: site?.name ?? 'Farm Site',
        species: b.species,
        status: b.status,
        stockingDate: b.stockingDate,
        harvestDate: b.harvestDate,
        currentOrHarvestDoc: doc.clamp(1, 999),
        shrimpStockedCount: b.shrimpStockedCount,
        color: batchPalette[i % batchPalette.length],
      ));
    }

    // 5. Aggregate metrics per batch
    final Map<String, double> abwMap = {};
    final Map<String, double> countMap = {};
    final Map<String, double> survivalMap = {};
    final Map<String, double> biomassKgMap = {};
    final Map<String, int> populationMap = {};
    final Map<String, double> totalFeedKgMap = {};
    final Map<String, double?> fcrMap = {};
    final Map<String, double> costMap = {};
    final Map<String, double> revenueMap = {};
    final Map<String, double> profitMap = {};

    final List<GrowthComparisonPoint> growthPoints = [];
    final List<FeedComparisonPoint> feedPoints = [];
    final List<FcrComparisonPoint> fcrPoints = [];
    final List<HarvestComparisonItem> harvestList = [];
    final List<FinancialComparisonItem> financialList = [];

    for (final meta in metaList) {
      final b = batches.firstWhere((item) => item.id == meta.batchId);
      final sDate = DateTime(b.stockingDate.year, b.stockingDate.month, b.stockingDate.day);
      final hDate = b.harvestDate != null
          ? DateTime(b.harvestDate!.year, b.harvestDate!.month, b.harvestDate!.day)
          : null;

      // Filter feeds strictly within batch lifecycle (no pre-stocking feeds)
      final batchFeeds = allFeedRecords.where((r) {
        if (r.batchId != b.id) return false;
        final rDate = DateTime(r.date.year, r.date.month, r.date.day);
        if (rDate.isBefore(sDate)) return false;
        if (hDate != null && rDate.isAfter(hDate)) return false;
        return true;
      }).toList();

      final totalFeedKg = batchFeeds.fold<double>(
        0.0,
        (sum, r) => sum + FeedCalculator.getRecordTotalKg(r),
      );
      totalFeedKgMap[b.id] = totalFeedKg;

      // Daily Feed Points
      final Map<DateTime, double> feedByDate = {};
      for (final r in batchFeeds) {
        final d = DateTime(r.date.year, r.date.month, r.date.day);
        feedByDate[d] = (feedByDate[d] ?? 0.0) + FeedCalculator.getRecordTotalKg(r);
      }
      for (final entry in feedByDate.entries) {
        final doc = entry.key.difference(sDate).inDays + 1;
        feedPoints.add(FeedComparisonPoint(
          batchId: b.id,
          doc: doc,
          date: entry.key,
          feedKg: entry.value,
        ));
      }

      // Filter samplings strictly for this batch
      final batchSamplings = allSamplings.where((s) => s.batchId == b.id).toList();
      batchSamplings.sort((a, b) => a.date.compareTo(b.date));

      double currentAbw;
      if (batchSamplings.isNotEmpty) {
        currentAbw = batchSamplings.last.abwGrams;
      } else if (b.harvestWeightKg != null && b.harvestCount != null && b.harvestCount! > 0) {
        currentAbw = (b.harvestWeightKg! * 1000.0) / b.harvestCount!;
      } else {
        final targetDoc = b.targetDoc > 0 ? b.targetDoc : 100;
        final targetWeight = b.targetHarvestWeightG;
        final progress = (meta.currentOrHarvestDoc / targetDoc).clamp(0.05, 1.2);
        currentAbw = targetWeight * progress;
      }
      abwMap[b.id] = currentAbw;

      // Growth points from samplings
      for (final s in batchSamplings) {
        growthPoints.add(GrowthComparisonPoint(
          batchId: b.id,
          doc: s.doc,
          date: s.date,
          abwGrams: s.abwGrams,
          adgGramsPerDay: s.adgGramsPerDay,
          source: 'Sampling',
        ));
      }

      // Count pcs/kg = 1000 / abw
      final countPcs = currentAbw > 0 ? (1000.0 / currentAbw) : 0.0;
      countMap[b.id] = countPcs;

      // Survival %
      double survivalPct;
      final batchHapa = allHapa.where((h) => h.batchId == b.id).toList();
      if (b.actualSurvivalPct != null) {
        survivalPct = b.actualSurvivalPct!;
      } else if (batchHapa.isNotEmpty) {
        survivalPct = batchHapa.last.survivalPercentage;
      } else {
        // Fallback default biological survival curve ~ 85%
        survivalPct = 85.0;
      }
      survivalMap[b.id] = survivalPct;

      final population = (b.shrimpStockedCount * (survivalPct / 100.0)).round();
      populationMap[b.id] = population;

      // Biomass (kg)
      double biomassKg;
      if (b.harvestWeightKg != null && b.status == 'completed') {
        biomassKg = b.harvestWeightKg!;
      } else {
        biomassKg = (population * currentAbw) / 1000.0;
      }
      biomassKgMap[b.id] = biomassKg;

      // FCR: Total feed / (Standing Biomass - Initial Seed Biomass)
      double? calcFcr;
      if (b.actualFcr != null) {
        calcFcr = b.actualFcr;
      } else {
        final initialWeightG = 0.01; // typical PL weight
        final initialBiomassKg = (b.shrimpStockedCount * initialWeightG) / 1000.0;
        final gainKg = biomassKg - initialBiomassKg;
        if (gainKg > 10.0 && totalFeedKg > 0) {
          calcFcr = double.parse((totalFeedKg / gainKg).toStringAsFixed(2));
        }
      }
      fcrMap[b.id] = calcFcr;

      // Cumulative FCR milestones over sampling points
      if (batchSamplings.isNotEmpty) {
        for (final s in batchSamplings) {
          final upToDate = DateTime(s.date.year, s.date.month, s.date.day);
          final feedUpToSample = batchFeeds.where((r) {
            final rd = DateTime(r.date.year, r.date.month, r.date.day);
            return !rd.isAfter(upToDate);
          }).fold<double>(0.0, (sum, r) => sum + FeedCalculator.getRecordTotalKg(r));

          final estBio = (population * s.abwGrams) / 1000.0;
          if (estBio > 0 && feedUpToSample > 0) {
            final progressiveFcr = feedUpToSample / estBio;
            fcrPoints.add(FcrComparisonPoint(
              batchId: b.id,
              doc: s.doc,
              date: s.date,
              fcr: double.parse(progressiveFcr.toStringAsFixed(2)),
            ));
          }
        }
      }

      // Harvest data if completed
      if (b.status == 'completed' || b.harvestDate != null) {
        harvestList.add(HarvestComparisonItem(
          batchId: b.id,
          harvestDoc: meta.currentOrHarvestDoc,
          finalAbwGrams: currentAbw,
          harvestWeightKg: b.harvestWeightKg ?? biomassKg,
          harvestCount: b.harvestCount,
          survivalPct: survivalPct,
          actualFcr: b.actualFcr ?? (calcFcr ?? 1.30),
          salePricePerKg: b.salePricePerKg,
          buyerName: b.buyerName,
        ));
      }

      // Financials
      final batchExpenses = allExpenses.where((e) => e.batchId == b.id).toList();
      final totalCost = batchExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
      costMap[b.id] = totalCost;

      final batchRevenues = allRevenues.where((r) => r.batchId == b.id).toList();
      final totalRev = batchRevenues.fold<double>(0.0, (sum, r) => sum + r.totalAmount);
      revenueMap[b.id] = totalRev;

      final profit = totalRev - totalCost;
      profitMap[b.id] = profit;

      final margin = totalRev > 0 ? (profit / totalRev) * 100.0 : 0.0;
      final costPerKg = biomassKg > 0 ? (totalCost / biomassKg) : null;
      final breakEven = biomassKg > 0 ? (totalCost / biomassKg) : null;

      financialList.add(FinancialComparisonItem(
        batchId: b.id,
        totalCost: totalCost,
        totalRevenue: totalRev,
        netProfit: profit,
        marginPct: margin,
        costPerKg: costPerKg,
        breakEvenPricePerKg: breakEven,
      ));
    }

    // 6. Build High-Value Comparison Metrics with Directional Evaluation
    final List<ComparisonMetricItem> metricItems = [];

    // Helper to evaluate winner
    String? findWinner(Map<String, double?> values, MetricDirection direction) {
      if (direction == MetricDirection.neutral) return null;
      String? bestId;
      double? bestVal;

      for (final entry in values.entries) {
        if (entry.value == null) continue;
        if (bestVal == null) {
          bestVal = entry.value;
          bestId = entry.key;
        } else if (direction == MetricDirection.higherIsBetter && entry.value! > bestVal) {
          bestVal = entry.value;
          bestId = entry.key;
        } else if (direction == MetricDirection.lowerIsBetter && entry.value! < bestVal) {
          bestVal = entry.value;
          bestId = entry.key;
        }
      }
      return bestId;
    }

    // A. DOC
    metricItems.add(ComparisonMetricItem(
      key: 'doc',
      label: 'Culture Age (DOC)',
      unit: 'days',
      direction: MetricDirection.neutral,
      rawValues: {for (final m in metaList) m.batchId: m.currentOrHarvestDoc.toDouble()},
      displayStrings: {for (final m in metaList) m.batchId: 'DOC ${m.currentOrHarvestDoc}'},
    ));

    // B. ABW (Higher is better)
    final abwWinner = findWinner(abwMap, MetricDirection.higherIsBetter);
    metricItems.add(ComparisonMetricItem(
      key: 'abw',
      label: 'Average Body Weight (ABW)',
      unit: 'g',
      direction: MetricDirection.higherIsBetter,
      rawValues: abwMap,
      displayStrings: {for (final e in abwMap.entries) e.key: '${e.value.toStringAsFixed(2)} g'},
      bestBatchId: abwWinner,
    ));

    // C. Count (Lower is better = larger shrimp)
    final countWinner = findWinner(countMap, MetricDirection.lowerIsBetter);
    metricItems.add(ComparisonMetricItem(
      key: 'count',
      label: 'Count (Pcs / kg)',
      unit: 'pcs/kg',
      direction: MetricDirection.lowerIsBetter,
      rawValues: countMap,
      displayStrings: {for (final e in countMap.entries) e.key: '${e.value.toStringAsFixed(1)} pcs'},
      bestBatchId: countWinner,
      clarificationNote: 'Lower Count = Larger Shrimp Size',
    ));

    // D. Biomass
    final bioWinner = findWinner(biomassKgMap, MetricDirection.higherIsBetter);
    metricItems.add(ComparisonMetricItem(
      key: 'biomass',
      label: 'Biomass',
      unit: 'kg',
      direction: MetricDirection.higherIsBetter,
      rawValues: biomassKgMap,
      displayStrings: {
        for (final e in biomassKgMap.entries)
          e.key: e.value >= 1000 ? '${(e.value / 1000).toStringAsFixed(2)} MT' : '${e.value.toStringAsFixed(0)} kg'
      },
      bestBatchId: bioWinner,
    ));

    // E. Survival %
    final survWinner = findWinner(survivalMap, MetricDirection.higherIsBetter);
    metricItems.add(ComparisonMetricItem(
      key: 'survival',
      label: 'Survival Rate',
      unit: '%',
      direction: MetricDirection.higherIsBetter,
      rawValues: survivalMap,
      displayStrings: {for (final e in survivalMap.entries) e.key: '${e.value.toStringAsFixed(1)}%'},
      bestBatchId: survWinner,
    ));

    // F. Feed Conversion Ratio (FCR - Lower is better)
    final fcrWinner = findWinner(fcrMap, MetricDirection.lowerIsBetter);
    metricItems.add(ComparisonMetricItem(
      key: 'fcr',
      label: 'Feed Conversion Ratio (FCR)',
      unit: '',
      direction: MetricDirection.lowerIsBetter,
      rawValues: fcrMap,
      displayStrings: {for (final e in fcrMap.entries) e.key: e.value != null ? e.value!.toStringAsFixed(2) : 'N/A'},
      bestBatchId: fcrWinner,
      clarificationNote: 'Lower FCR indicates higher feed efficiency',
    ));

    // G. Total Feed Consumed
    metricItems.add(ComparisonMetricItem(
      key: 'total_feed',
      label: 'Total Feed Consumed',
      unit: 'kg',
      direction: MetricDirection.neutral,
      rawValues: totalFeedKgMap,
      displayStrings: {
        for (final e in totalFeedKgMap.entries)
          e.key: e.value >= 1000 ? '${(e.value / 1000).toStringAsFixed(2)} MT' : '${e.value.toStringAsFixed(0)} kg'
      },
    ));

    // H. Financial Profit / Incurred Costs
    final hasFinances = costMap.values.any((c) => c > 0) || revenueMap.values.any((r) => r > 0);
    if (hasFinances) {
      final profitWinner = findWinner(profitMap, MetricDirection.higherIsBetter);
      metricItems.add(ComparisonMetricItem(
        key: 'profit',
        label: 'Net Crop Profit',
        unit: '₹',
        direction: MetricDirection.higherIsBetter,
        rawValues: profitMap,
        displayStrings: {
          for (final e in profitMap.entries)
            e.key: e.value >= 100000
                ? '₹${(e.value / 100000).toStringAsFixed(2)} L'
                : '₹${e.value.toStringAsFixed(0)}'
        },
        bestBatchId: profitWinner,
      ));
    }

    // 7. Transparent Category Performance Summary
    final Map<String, String> summary = {};
    if (abwWinner != null) {
      final b = metaList.firstWhere((m) => m.batchId == abwWinner);
      summary['Growth (ABW)'] = '${b.displayName} reached largest shrimp size (${abwMap[abwWinner]!.toStringAsFixed(2)}g).';
    }
    if (fcrWinner != null && fcrMap[fcrWinner] != null) {
      final b = metaList.firstWhere((m) => m.batchId == fcrWinner);
      summary['Feed Efficiency (FCR)'] = '${b.displayName} achieved the most optimal FCR (${fcrMap[fcrWinner]!.toStringAsFixed(2)}).';
    }
    if (survWinner != null) {
      final b = metaList.firstWhere((m) => m.batchId == survWinner);
      summary['Survival'] = '${b.displayName} demonstrated the highest survival rate (${survivalMap[survWinner]!.toStringAsFixed(1)}%).';
    }
    if (bioWinner != null) {
      final b = metaList.firstWhere((m) => m.batchId == bioWinner);
      final bio = biomassKgMap[bioWinner]!;
      final bioFormatted = bio >= 1000 ? '${(bio / 1000).toStringAsFixed(2)} MT' : '${bio.toStringAsFixed(0)} kg';
      summary['Biomass Yield'] = '${b.displayName} yielded the highest standing biomass ($bioFormatted).';
    }

    return BatchComparisonResult(
      batches: metaList,
      mode: mode,
      metrics: metricItems,
      growthPoints: growthPoints,
      feedPoints: feedPoints,
      fcrPoints: fcrPoints,
      harvestData: harvestList,
      financialData: financialList,
      performanceSummary: summary,
    );
  }
}
