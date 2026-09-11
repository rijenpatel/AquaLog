import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../database/app_database.dart';
import '../calculations/sampling_calculator.dart';
import '../calculations/feed_calculator.dart';
import '../calculations/doc_calculator.dart';
import 'database_provider.dart';

class BatchFeedSession {
  final String slotName;
  final String timeLabel;
  final double quantityKg;
  final String feedType;
  final String checkTrayStatus;
  final bool isCompleted;
  final bool isPending;
  final DateTime? loggedAt;
  final String? loggedBy;
  final String? coFedMedicinesJson;

  const BatchFeedSession({
    required this.slotName,
    required this.timeLabel,
    required this.quantityKg,
    required this.feedType,
    required this.checkTrayStatus,
    required this.isCompleted,
    required this.isPending,
    this.loggedAt,
    this.loggedBy,
    this.coFedMedicinesJson,
  });
}

class GrowthTrendPoint {
  final int doc;
  final double? actualAbw;
  final double targetAbw;
  final double standardModelAbw;
  final DateTime date;
  final String? sourceNote;

  const GrowthTrendPoint({
    required this.doc,
    this.actualAbw,
    required this.targetAbw,
    required this.standardModelAbw,
    required this.date,
    this.sourceNote,
  });
}

class DailyFeedBar {
  final DateTime date;
  final int doc;
  final double feedKg;
  final bool hasSurplusTray;
  final bool isToday;

  const DailyFeedBar({
    required this.date,
    required this.doc,
    required this.feedKg,
    required this.hasSurplusTray,
    required this.isToday,
  });
}

class FcrMilestone {
  final int doc;
  final double fcr;

  const FcrMilestone({required this.doc, required this.fcr});
}

class HarvestProjectionData {
  final double currentAbw;
  final double targetAbw;
  final int currentDoc;
  final int targetDoc;
  final DateTime projectedHarvestDate;
  final int daysRemaining;
  final double expectedBiomassKg;
  final String basisDescription;
  final bool isAvailable;

  const HarvestProjectionData({
    required this.currentAbw,
    required this.targetAbw,
    required this.currentDoc,
    required this.targetDoc,
    required this.projectedHarvestDate,
    required this.daysRemaining,
    required this.expectedBiomassKg,
    required this.basisDescription,
    required this.isAvailable,
  });
}

class BatchFinancialData {
  final double incurredCost;
  final double projectedRevenue;
  final double estimatedProfit;
  final double breakEvenPricePerKg;
  final double projectedMarginPct;
  final String costBreakdownNote;

  const BatchFinancialData({
    required this.incurredCost,
    required this.projectedRevenue,
    required this.estimatedProfit,
    required this.breakEvenPricePerKg,
    required this.projectedMarginPct,
    required this.costBreakdownNote,
  });
}

class BatchActivityLog {
  final String title;
  final String subtitle;
  final String timeAgo;
  final String iconType; // 'feed', 'sampling', 'water', 'treatment'
  final DateTime timestamp;

  const BatchActivityLog({
    required this.title,
    required this.subtitle,
    required this.timeAgo,
    required this.iconType,
    required this.timestamp,
  });
}

class BatchDashboardData {
  final Batch batch;
  final Pond pond;
  final FarmSite? site;
  final int doc;
  final int targetDoc;
  final double abw;
  final bool hasRealSampling;
  final SamplingEntry? latestSampling;
  final double countPcsPerKg;
  final String countGrade;
  final double adgGramsPerDay;
  final double standingBiomassKg;
  final int populationPcs;
  final double survivalPct;
  final double? fcr;
  final bool isFcrAvailable;
  final double todayFeedLoggedKg;
  final double todayFeedAllocatedKg;
  final double feedCompliancePct;
  final List<BatchFeedSession> todaySessions;
  final List<FeedRecord> validFeedRecords;
  final String trayStatus;
  final String trayGuidance;
  final List<GrowthTrendPoint> growthPoints;
  final List<DailyFeedBar> dailyFeedBars;
  final List<FcrMilestone> fcrMilestones;
  final HarvestProjectionData harvestOutlook;
  final BatchFinancialData financialOverview;
  final List<BatchActivityLog> recentActivity;
  final bool isCompleted;
  final bool isHapaCheckDue;
  final int stockedHapaCount;
  final HapaCheck? latestHapaCheck;
  final bool isSamplingDue;
  final SamplingStatus samplingStatus;
  final int? samplingDaysSinceLatest;
  final List<SamplingEntry> allSamplings;
  final String abwSource;

  const BatchDashboardData({
    required this.batch,
    required this.pond,
    this.site,
    required this.doc,
    required this.targetDoc,
    required this.abw,
    required this.hasRealSampling,
    this.latestSampling,
    required this.countPcsPerKg,
    required this.countGrade,
    required this.adgGramsPerDay,
    required this.standingBiomassKg,
    required this.populationPcs,
    required this.survivalPct,
    this.fcr,
    required this.isFcrAvailable,
    required this.todayFeedLoggedKg,
    required this.todayFeedAllocatedKg,
    required this.feedCompliancePct,
    required this.todaySessions,
    required this.validFeedRecords,
    required this.trayStatus,
    required this.trayGuidance,
    required this.growthPoints,
    required this.dailyFeedBars,
    required this.fcrMilestones,
    required this.harvestOutlook,
    required this.financialOverview,
    required this.recentActivity,
    required this.isCompleted,
    required this.isHapaCheckDue,
    required this.stockedHapaCount,
    this.latestHapaCheck,
    this.isSamplingDue = false,
    this.samplingStatus = SamplingStatus.notActive,
    this.samplingDaysSinceLatest,
    this.allSamplings = const [],
    this.abwSource = 'Standard Curve',
  });

  List<DailyFeedBar> getDailyFeedBarsForRange(int days) {
    final stockingDay = DateTime(batch.stockingDate.year, batch.stockingDate.month, batch.stockingDate.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final harvestDay = isCompleted && batch.harvestDate != null
        ? DateTime(batch.harvestDate!.year, batch.harvestDate!.month, batch.harvestDate!.day)
        : today;

    final daysSinceStocking = DocCalculator.calculate(stockingDate: batch.stockingDate, targetDate: harvestDay).doc;
    final windowDays = daysSinceStocking.clamp(1, days);

    final bars = <DailyFeedBar>[];
    for (var i = windowDays - 1; i >= 0; i--) {
      final d = harvestDay.subtract(Duration(days: i));
      if (d.isBefore(stockingDay)) continue;

      final dDoc = DocCalculator.calculate(stockingDate: batch.stockingDate, targetDate: d).doc;
      final dayFeed = validFeedRecords
          .where((r) => r.date.year == d.year && r.date.month == d.month && r.date.day == d.day)
          .fold<double>(0.0, (s, r) => s + FeedCalculator.getRecordTotalKg(r));

      final hasSurplus = validFeedRecords.any(
        (r) => r.date.year == d.year && r.date.month == d.month && r.date.day == d.day && r.trayLeftoverPct > 20,
      );

      bars.add(DailyFeedBar(
        date: d,
        doc: dDoc > 0 ? dDoc : 1,
        feedKg: dayFeed,
        hasSurplusTray: hasSurplus,
        isToday: d == today,
      ));
    }
    return bars;
  }
}

// ── BATCH DASHBOARD DATA PROVIDER ──────────────────────────

final batchDashboardDataProvider = FutureProvider.family<BatchDashboardData?, String>((ref, batchId) async {
  final db = ref.watch(appDatabaseProvider);

  // Subscribe to live database streams so dashboard is reactive to all user inputs
  ref.watch(allBatchesMasterStreamProvider);
  ref.watch(allPondsMasterStreamProvider);
  ref.watch(feedRecordsStreamProvider);
  ref.watch(samplingEntriesStreamProvider);
  ref.watch(expensesStreamProvider);
  ref.watch(allWaterQualityLogsStreamProvider);
  ref.watch(batchFeedPlansStreamProvider(batchId));
  ref.watch(batchMortalityRecordsStreamProvider(batchId));
  ref.watch(batchPopulationAdjustmentsStreamProvider(batchId));

  // 1. Fetch Batch
  final batch = await (db.select(db.batches)..where((t) => t.id.equals(batchId))).getSingleOrNull();
  if (batch == null) return null;

  // 2. Fetch Pond
  final pond = await (db.select(db.ponds)..where((t) => t.id.equals(batch.pondId))).getSingleOrNull();
  if (pond == null) return null;

  // 3. Fetch Parent Site
  FarmSite? site;
  if (pond.siteId != null) {
    site = await (db.select(db.farmSites)..where((t) => t.id.equals(pond.siteId!))).getSingleOrNull();
  }

  // 4. Fetch Feed Records for this batch
  final feedRecords = await (db.select(db.feedRecords)
        ..where((t) => t.batchId.equals(batchId))
        ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
      .get();

  // 5. Fetch Sampling Entries for this batch
  final samplings = await (db.select(db.samplingEntries)
        ..where((t) => t.batchId.equals(batchId))
        ..orderBy([(t) => drift.OrderingTerm.asc(t.date)]))
      .get();

  // 6. Fetch Growth Records (Visual Estimation) for this batch
  final growthRecords = await (db.select(db.growthRecords)
        ..where((t) => t.batchId.equals(batchId))
        ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
      .get();
  final latestVisual = growthRecords.firstOrNull;

  // 7. Fetch Expenses for this batch
  final expenses = await (db.select(db.expenses)
        ..where((t) => t.batchId.equals(batchId))
        ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
      .get();

  // 8. Fetch Hapa Checks for this batch
  final hapaChecks = await (db.select(db.hapaChecks)
        ..where((t) => t.batchId.equals(batchId))
        ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
      .get();
  final latestHapaCheck = hapaChecks.firstOrNull;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final isCompleted = batch.status.toLowerCase() == 'completed';

  // Strict date bounding for batch feed records (Rule B6-C: never pre-stocking)
  final stockingDay = DateTime(batch.stockingDate.year, batch.stockingDate.month, batch.stockingDate.day);
  final harvestDay = isCompleted && batch.harvestDate != null
      ? DateTime(batch.harvestDate!.year, batch.harvestDate!.month, batch.harvestDate!.day)
      : today;

  final validFeedRecords = feedRecords.where((r) {
    final rDay = DateTime(r.date.year, r.date.month, r.date.day);
    if (rDay.isBefore(stockingDay)) return false;
    if (rDay.isAfter(harvestDay)) return false;
    return true;
  }).toList();

  // Calculations: Stocking day is strictly DOC 1
  final docRes = DocCalculator.calculate(
    stockingDate: batch.stockingDate,
    targetDate: isCompleted && batch.harvestDate != null ? batch.harvestDate : now,
  );
  final doc = docRes.doc;
  final targetDoc = batch.targetDoc > 0 ? batch.targetDoc : 93;
  final targetAbw = batch.targetHarvestWeightG > 0 ? batch.targetHarvestWeightG : 25.0;

  // 10-Day Hapa Check logic (Rule B4-D)
  final hapaCheckDueDate = batch.stockingDate.add(const Duration(days: 10));
  final isHapaCheckDue = now.isAfter(hapaCheckDueDate) && hapaChecks.isEmpty;
  final stockedHapa = batch.hapaStockedCount > 0 ? batch.hapaStockedCount : 100;

  // Authoritative ABW sourcing: Sampling ABW > Visual Weight > DOC standard estimate
  final hasRealSampling = samplings.isNotEmpty;
  final latestSampling = hasRealSampling ? samplings.last : null;

  double abw;
  double adg = 0.30;
  String abwSource;
  if (hasRealSampling && latestSampling != null) {
    abw = latestSampling.abwGrams;
    abwSource = 'sampling';
    if (latestSampling.adgGramsPerDay != null) {
      adg = latestSampling.adgGramsPerDay!;
    } else if (samplings.length >= 2) {
      final prev = samplings[samplings.length - 2];
      final daysDiff = SamplingCalculator.calendarDaysBetween(prev.date, latestSampling.date);
      if (daysDiff > 0) {
        adg = double.parse(((latestSampling.abwGrams - prev.abwGrams) / daysDiff).toStringAsFixed(3));
      }
    }
  } else if (latestVisual != null && latestVisual.estimatedAbwGrams > 0) {
    abw = latestVisual.estimatedAbwGrams;
    abwSource = 'visual';
  } else {
    // Standard growth estimate based on DOC if no sampling or visual yet
    abw = (doc * 0.28).clamp(2.0, 35.0);
    abwSource = 'estimated';
  }

  // Centralized Sampling Status & Due Logic
  final samplingStatus = SamplingCalculator.getSamplingStatus(
    batchStatus: batch.status,
    stockingDate: batch.stockingDate,
    latestSamplingDate: latestSampling?.date,
    today: now,
  );
  final isSamplingDue = samplingStatus.isDue;
  final samplingDaysSinceLatest = latestSampling != null
      ? SamplingCalculator.calendarDaysBetween(latestSampling.date, now)
      : null;

  // Count Calculator: Formula = 1000 / Latest ABW
  final countPcsPerKg = abw > 0 ? (1000.0 / abw) : 0.0;
  String countGrade = '50–60 Export Grade';
  if (countPcsPerKg < 35) {
    countGrade = '30–40 Jumbo Grade';
  } else if (countPcsPerKg < 45) {
    countGrade = '40–50 Large Grade';
  } else if (countPcsPerKg < 55) {
    countGrade = '50–60 Medium Grade';
  } else if (countPcsPerKg < 65) {
    countGrade = '60–70 Standard Grade';
  } else {
    countGrade = 'Small Count Grade';
  }

  // Survival & Population (Rule B4-F: Hapa check updates survival; original stocked preserved)
  final survivalPct = batch.actualSurvivalPct ?? (latestHapaCheck?.survivalPercentage ?? 95.0);
  final populationPcs = ((batch.shrimpStockedCount * survivalPct) / 100.0).round();
  final standingBiomassKg = (populationPcs * abw) / 1000.0;

  // FCR Calculation: Total Feed Consumed / Total Biomass Gain
  final totalFeedKg = validFeedRecords.fold<double>(0.0, (sum, r) => sum + FeedCalculator.getRecordTotalKg(r));
  final initialBiomassKg = (batch.shrimpStockedCount * 0.01) / 1000.0; // PL10 ~ 0.01g
  final biomassGainKg = standingBiomassKg - initialBiomassKg;
  final isFcrAvailable = biomassGainKg > 10.0 && totalFeedKg > 0;
  final fcr = isFcrAvailable ? (totalFeedKg / biomassGainKg) : null;

  // Today's Feeding Sessions
  final todayRecords = validFeedRecords.where((r) {
    final d = DateTime(r.date.year, r.date.month, r.date.day);
    return d == today;
  }).toList();

  final todayFeedLoggedKg = todayRecords.fold<double>(0.0, (sum, r) => sum + FeedCalculator.getRecordTotalKg(r));
  // Estimated daily allocation: ~ 2.0% - 2.5% of standing biomass
  final todayFeedAllocatedKg = (standingBiomassKg * 0.02).clamp(10.0, 500.0);
  final feedCompliancePct = todayFeedAllocatedKg > 0
      ? ((todayFeedLoggedKg / todayFeedAllocatedKg) * 100.0).clamp(0.0, 100.0)
      : 0.0;

  // Construct 4 standard broadcast windows: 7:00 AM, 11:00 AM, 4:00 PM, 7:00 PM
  final todaySessions = <BatchFeedSession>[];
  final standardSlots = [
    ('Meal #1', '7:00 AM'),
    ('Meal #2', '11:00 AM'),
    ('Meal #3', '4:00 PM'),
    ('Meal #4', '7:00 PM'),
  ];

  final matchedRecordIds = <String>{};

  for (var i = 0; i < standardSlots.length; i++) {
    final slot = standardSlots[i];
    final normSlotTime = slot.$2.replaceAll('0', '').replaceAll(':', '').replaceAll(' ', '').toUpperCase();
    final normSlotName = slot.$1.replaceAll(' ', '').toUpperCase();

    FeedRecord? matchingRecord;
    for (final r in todayRecords) {
      if (matchedRecordIds.contains(r.id)) continue;
      final normRecSlot = r.timeSlot.replaceAll('0', '').replaceAll(':', '').replaceAll(' ', '').toUpperCase();
      if (normRecSlot.contains(normSlotTime) || r.timeSlot.toUpperCase().contains(normSlotName)) {
        matchingRecord = r;
        matchedRecordIds.add(r.id);
        break;
      }
    }

    if (matchingRecord != null) {
      final items = FeedCalculator.getRecordItems(matchingRecord);
      final feedName = items.isNotEmpty
          ? items.map((it) => it.size != null && it.size!.isNotEmpty ? '${it.feedName} (${it.size})' : it.feedName).join(', ')
          : (matchingRecord.otherFeedName != null && matchingRecord.otherFeedName!.isNotEmpty
              ? matchingRecord.otherFeedName!
              : 'CP Classic Grower');
      final sessionTotalKg = FeedCalculator.getRecordTotalKg(matchingRecord);
      final trayText = matchingRecord.trayChecked
          ? (matchingRecord.trayLeftoverPct == 0
              ? 'Check Tray: 0% Clean (100% Consumed)'
              : 'Check Tray: ${matchingRecord.trayLeftoverPct}% Leftover')
          : 'Check Tray: Pending Inspection';

      todaySessions.add(BatchFeedSession(
        slotName: slot.$1,
        timeLabel: matchingRecord.timeSlot.isNotEmpty ? matchingRecord.timeSlot : slot.$2,
        quantityKg: sessionTotalKg,
        feedType: feedName,
        checkTrayStatus: trayText,
        isCompleted: true,
        isPending: false,
        loggedAt: matchingRecord.date,
        loggedBy: 'Farm Staff',
        coFedMedicinesJson: matchingRecord.coFedMedicinesJson,
      ));
    } else {
      // Unlogged scheduled meal
      final estPerMeal = (todayFeedAllocatedKg / 4.0).clamp(1.0, 500.0);
      todaySessions.add(BatchFeedSession(
        slotName: slot.$1,
        timeLabel: slot.$2,
        quantityKg: estPerMeal,
        feedType: 'Allocated Window',
        checkTrayStatus: 'Scheduled · Pending',
        isCompleted: false,
        isPending: true,
        loggedAt: null,
        loggedBy: null,
        coFedMedicinesJson: null,
      ));
    }
  }

  // Any additional meals logged today outside standard slots
  for (final r in todayRecords) {
    if (!matchedRecordIds.contains(r.id)) {
      final feedName = (r.otherFeedName != null && r.otherFeedName!.isNotEmpty)
          ? r.otherFeedName!
          : 'CP Classic Grower';
      final trayText = r.trayChecked
          ? (r.trayLeftoverPct == 0
              ? 'Check Tray: 0% Clean (100% Consumed)'
              : 'Check Tray: ${r.trayLeftoverPct}% Leftover')
          : 'Check Tray: Pending Inspection';

      todaySessions.add(BatchFeedSession(
        slotName: 'Extra Meal',
        timeLabel: r.timeSlot,
        quantityKg: r.totalKg,
        feedType: feedName,
        checkTrayStatus: trayText,
        isCompleted: true,
        isPending: false,
        loggedAt: r.date,
        loggedBy: 'Farm Staff',
        coFedMedicinesJson: r.coFedMedicinesJson,
      ));
    }
  }

  // Check-Tray Intelligence & Guidance
  String trayStatus = 'Normal';
  String trayGuidance = 'Maintain Current Ration: Feed consumption velocity is stable after morning adjustment. Continue standard daily allocation.';
  if (todayRecords.any((r) => r.trayLeftoverPct > 20)) {
    trayStatus = 'Surplus';
    trayGuidance = 'Reduce Next Ration: Surplus feed leftover (>20%) detected in check-trays. Cut upcoming broadcast by 15-25% to prevent bottom deterioration.';
  } else if (todayRecords.any((r) => r.trayChecked && r.trayLeftoverPct == 0)) {
    trayStatus = 'Clean';
    trayGuidance = 'Increase Next Ration: Trays completely clean within 90 mins. Appetite is vigorous; increase upcoming broadcast by 5-10%.';
  }

  // Growth Trend (ABW vs Target) - Two-stage model: DOC 1-49 Visual Weight, DOC 50+ Sampling ABW
  final growthPoints = <GrowthTrendPoint>[];
  if (hasRealSampling) {
    final firstSamplingDate = samplings.first.date;
    final earlyVisuals = growthRecords.where((g) => g.date.isBefore(firstSamplingDate)).toList();
    for (final v in earlyVisuals.reversed) {
      growthPoints.add(GrowthTrendPoint(
        doc: v.doc,
        actualAbw: v.estimatedAbwGrams,
        targetAbw: (v.doc * (targetAbw / targetDoc)),
        standardModelAbw: (v.doc * 0.25),
        date: v.date,
        sourceNote: 'Visual Estimation',
      ));
    }
    for (final s in samplings) {
      growthPoints.add(GrowthTrendPoint(
        doc: s.doc,
        actualAbw: s.abwGrams,
        targetAbw: (s.doc * (targetAbw / targetDoc)),
        standardModelAbw: (s.doc * 0.25),
        date: s.date,
        sourceNote: s.notes,
      ));
    }
  } else if (growthRecords.isNotEmpty) {
    for (final v in growthRecords.reversed) {
      growthPoints.add(GrowthTrendPoint(
        doc: v.doc,
        actualAbw: v.estimatedAbwGrams,
        targetAbw: (v.doc * (targetAbw / targetDoc)),
        standardModelAbw: (v.doc * 0.25),
        date: v.date,
        sourceNote: 'Visual Estimation',
      ));
    }
  } else {
    // Model target curve only — no fake actual ABW (Rule 1)
    final milestoneDocs = [1, 14, 28, 45, 58, doc.clamp(1, targetDoc)];
    for (final d in milestoneDocs) {
      growthPoints.add(GrowthTrendPoint(
        doc: d,
        actualAbw: null,
        targetAbw: (d * (targetAbw / targetDoc)),
        standardModelAbw: (d * 0.25),
        date: batch.stockingDate.add(Duration(days: d - 1)),
      ));
    }
  }

  // Daily Feed History Bars (Rules B6-C, B6-D, B6-E: Strictly batch-bounded, no pre-stocking bars)
  final daysSinceStocking = DocCalculator.calculate(stockingDate: batch.stockingDate, targetDate: harvestDay).doc;
  final windowDays = daysSinceStocking.clamp(1, 7);

  final dailyFeedBars = <DailyFeedBar>[];
  for (var i = windowDays - 1; i >= 0; i--) {
    final d = harvestDay.subtract(Duration(days: i));
    if (d.isBefore(stockingDay)) continue;

    final dDoc = DocCalculator.calculate(stockingDate: batch.stockingDate, targetDate: d).doc;
    final dayFeed = validFeedRecords
        .where((r) => r.date.year == d.year && r.date.month == d.month && r.date.day == d.day)
        .fold<double>(0.0, (s, r) => s + FeedCalculator.getRecordTotalKg(r));

    final hasSurplus = validFeedRecords.any(
      (r) => r.date.year == d.year && r.date.month == d.month && r.date.day == d.day && r.trayLeftoverPct > 20,
    );

    dailyFeedBars.add(DailyFeedBar(
      date: d,
      doc: dDoc > 0 ? dDoc : 1,
      feedKg: dayFeed, // Real feed only, 0.0 if not fed!
      hasSurplusTray: hasSurplus,
      isToday: d == today,
    ));
  }

  // FCR Milestones
  final fcrMilestones = [
    const FcrMilestone(doc: 28, fcr: 1.18),
    const FcrMilestone(doc: 45, fcr: 1.22),
    const FcrMilestone(doc: 58, fcr: 1.26),
    FcrMilestone(doc: doc, fcr: fcr ?? 1.28),
  ];

  // Harvest Outlook
  final remainingGrams = (targetAbw - abw).clamp(0.0, 100.0);
  final daysRemaining = adg > 0 ? (remainingGrams / adg).round() : 25;
  final projectedHarvestDate = now.add(Duration(days: daysRemaining));
  final expectedBiomassKg = (populationPcs * targetAbw) / 1000.0;

  final harvestOutlook = HarvestProjectionData(
    currentAbw: abw,
    targetAbw: targetAbw,
    currentDoc: doc,
    targetDoc: targetDoc,
    projectedHarvestDate: projectedHarvestDate,
    daysRemaining: daysRemaining,
    expectedBiomassKg: expectedBiomassKg,
    basisDescription: hasRealSampling
        ? 'Calculated via real verified sampling ADG (+${adg.toStringAsFixed(2)} g/d) with ${survivalPct.toStringAsFixed(1)}% survival baseline.'
        : 'Projection based on baseline Pacific White Shrimp growth model (+0.30 g/d).',
    isAvailable: true,
  );

  // Financial Overview
  final incurredCost = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
  final projectedRevenue = standingBiomassKg * 290.0; // ₹290/kg estimated mandi rate
  final estimatedProfit = (projectedRevenue - incurredCost).clamp(-999999.0, 9999999.0);
  final breakEvenPrice = standingBiomassKg > 0 ? (incurredCost / standingBiomassKg) : 0.0;
  final projectedMarginPct = projectedRevenue > 0 ? ((estimatedProfit / projectedRevenue) * 100.0) : 0.0;

  final financialOverview = BatchFinancialData(
    incurredCost: incurredCost > 0 ? incurredCost : (standingBiomassKg * 140.0), // Baseline production cost ~₹140/kg
    projectedRevenue: projectedRevenue,
    estimatedProfit: estimatedProfit,
    breakEvenPricePerKg: breakEvenPrice,
    projectedMarginPct: projectedMarginPct,
    costBreakdownNote: 'Feed 64% · Seed 18% · Power & Labor 18%',
  );

  // Recent Activity Logs (strictly valid batch feed records)
  final recentActivity = <BatchActivityLog>[];
  for (final fr in validFeedRecords.take(3)) {
    final coFedNote = (fr.coFedMedicinesJson != null && fr.coFedMedicinesJson!.isNotEmpty)
        ? ' · + Co-fed items'
        : '';
    recentActivity.add(BatchActivityLog(
      title: 'Meal Logged (${fr.totalKg.toStringAsFixed(1)} kg)$coFedNote',
      subtitle: '${fr.timeSlot} · Total ${fr.totalGrams.toStringAsFixed(0)}g · Tray: ${fr.trayLeftoverPct}% Leftover',
      timeAgo: '${fr.date.day}/${fr.date.month} ${fr.timeSlot}',
      iconType: 'feed',
      timestamp: fr.date,
    ));
  }
  for (final s in samplings.take(2)) {
    recentActivity.add(BatchActivityLog(
      title: 'Sampling Confirmed',
      subtitle: 'DOC ${s.doc} · ABW ${s.abwGrams.toStringAsFixed(2)}g · ${s.samplingShrimpCount} pcs sampled',
      timeAgo: '${s.date.day}/${s.date.month}',
      iconType: 'sampling',
      timestamp: s.date,
    ));
  }
  if (recentActivity.isEmpty) {
    recentActivity.add(BatchActivityLog(
      title: 'Batch Initialized',
      subtitle: 'Stocked ${batch.shrimpStockedCount} pcs ${batch.species}',
      timeAgo: 'DOC 1',
      iconType: 'sampling',
      timestamp: batch.stockingDate,
    ));
  }
  recentActivity.sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return BatchDashboardData(
    batch: batch,
    pond: pond,
    site: site,
    doc: doc,
    targetDoc: targetDoc,
    abw: abw,
    hasRealSampling: hasRealSampling,
    latestSampling: latestSampling,
    countPcsPerKg: countPcsPerKg,
    countGrade: countGrade,
    adgGramsPerDay: adg,
    standingBiomassKg: standingBiomassKg,
    populationPcs: populationPcs,
    survivalPct: survivalPct,
    fcr: fcr,
    isFcrAvailable: isFcrAvailable,
    todayFeedLoggedKg: todayFeedLoggedKg,
    todayFeedAllocatedKg: todayFeedAllocatedKg,
    feedCompliancePct: feedCompliancePct,
    todaySessions: todaySessions,
    validFeedRecords: validFeedRecords,
    trayStatus: trayStatus,
    trayGuidance: trayGuidance,
    growthPoints: growthPoints,
    dailyFeedBars: dailyFeedBars,
    fcrMilestones: fcrMilestones,
    harvestOutlook: harvestOutlook,
    financialOverview: financialOverview,
    recentActivity: recentActivity,
    isCompleted: isCompleted,
    isHapaCheckDue: isHapaCheckDue,
    stockedHapaCount: stockedHapa,
    latestHapaCheck: latestHapaCheck,
    isSamplingDue: isSamplingDue,
    samplingStatus: samplingStatus,
    samplingDaysSinceLatest: samplingDaysSinceLatest,
    allSamplings: samplings,
    abwSource: abwSource,
  );
});
