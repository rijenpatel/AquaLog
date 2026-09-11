import '../database/app_database.dart';

enum PopulationVarianceStatus {
  normal,
  moderate,
  significant;

  String get label {
    switch (this) {
      case PopulationVarianceStatus.normal:
        return 'Balanced';
      case PopulationVarianceStatus.moderate:
        return 'Moderate Variance';
      case PopulationVarianceStatus.significant:
        return 'High Variance';
    }
  }
}

class PopulationSummary {
  final int stockedCount;
  final int cumulativeObservedMortality;
  final int cumulativeEstimatedMortality;
  final int totalMortality;
  final int cumulativeHarvestedCount;
  final int netAdjustments;
  final int estimatedRemainingPopulation;
  final int? samplingEstimatedPopulation;
  final int? reconciliationDifference;
  final double? reconciliationVariancePct;
  final PopulationVarianceStatus varianceStatus;
  final double observedSurvivalPct;
  final double reconciledSurvivalPct;
  final double? sampleDerivedSurvivalPct;

  const PopulationSummary({
    required this.stockedCount,
    required this.cumulativeObservedMortality,
    required this.cumulativeEstimatedMortality,
    required this.totalMortality,
    required this.cumulativeHarvestedCount,
    required this.netAdjustments,
    required this.estimatedRemainingPopulation,
    this.samplingEstimatedPopulation,
    this.reconciliationDifference,
    this.reconciliationVariancePct,
    required this.varianceStatus,
    required this.observedSurvivalPct,
    required this.reconciledSurvivalPct,
    this.sampleDerivedSurvivalPct,
  });
}

class MortalityAlert {
  final String title;
  final String message;
  final String why;
  final String recommendation;
  final String severity; // 'warning', 'critical'
  final DateTime date;

  const MortalityAlert({
    required this.title,
    required this.message,
    required this.why,
    required this.recommendation,
    required this.severity,
    required this.date,
  });
}

class PopulationEngine {
  /// Computes the complete population accounting balance and reconciliation
  static PopulationSummary calculatePopulationSummary({
    required Batch batch,
    required List<MortalityRecord> mortalityRecords,
    required List<PopulationAdjustment> adjustments,
    int? harvestCountOverride,
    double? latestBiomassKg,
    double? latestAbwGrams,
  }) {
    final stocked = batch.shrimpStockedCount;
    int observedMort = 0;
    int estimatedMort = 0;

    for (final r in mortalityRecords) {
      observedMort += r.countObserved;
      estimatedMort += r.countEstimated;
    }
    final totalMort = observedMort + estimatedMort;

    int harvestCount = harvestCountOverride ?? batch.harvestCount ?? 0;

    int netAdj = 0;
    for (final a in adjustments) {
      netAdj += a.differenceCount;
    }

    final estimatedRemaining = (stocked + netAdj - totalMort - harvestCount).clamp(0, stocked * 2);

    int? samplingEst;
    if (latestBiomassKg != null && latestAbwGrams != null && latestAbwGrams > 0) {
      samplingEst = ((latestBiomassKg * 1000.0) / latestAbwGrams).round();
    }

    int? diff;
    double? variancePct;
    var varianceStatus = PopulationVarianceStatus.normal;

    if (samplingEst != null && estimatedRemaining > 0) {
      diff = estimatedRemaining - samplingEst;
      variancePct = double.parse(((diff.abs() / estimatedRemaining) * 100.0).toStringAsFixed(1));

      if (variancePct > 12.0) {
        varianceStatus = PopulationVarianceStatus.significant;
      } else if (variancePct > 5.0) {
        varianceStatus = PopulationVarianceStatus.moderate;
      }
    }

    final double observedSurvival = stocked > 0
        ? double.parse((((stocked - observedMort) / stocked) * 100.0).clamp(0.0, 100.0).toStringAsFixed(1))
        : 0.0;

    final double reconciledSurvival = stocked > 0
        ? double.parse(((estimatedRemaining / stocked) * 100.0).clamp(0.0, 100.0).toStringAsFixed(1))
        : 0.0;

    final double? sampleDerivedSurvival = (samplingEst != null && stocked > 0)
        ? double.parse(((samplingEst / stocked) * 100.0).clamp(0.0, 100.0).toStringAsFixed(1))
        : null;

    return PopulationSummary(
      stockedCount: stocked,
      cumulativeObservedMortality: observedMort,
      cumulativeEstimatedMortality: estimatedMort,
      totalMortality: totalMort,
      cumulativeHarvestedCount: harvestCount,
      netAdjustments: netAdj,
      estimatedRemainingPopulation: estimatedRemaining,
      samplingEstimatedPopulation: samplingEst,
      reconciliationDifference: diff,
      reconciliationVariancePct: variancePct,
      varianceStatus: varianceStatus,
      observedSurvivalPct: observedSurvival,
      reconciledSurvivalPct: reconciledSurvival,
      sampleDerivedSurvivalPct: sampleDerivedSurvival,
    );
  }

  /// Detects abnormal mortality patterns and triggers advisory alerts
  static List<MortalityAlert> detectMortalityAlerts({
    required List<MortalityRecord> mortalityRecords,
    required int currentPopulation,
    double? latestDO,
  }) {
    final alerts = <MortalityAlert>[];
    if (mortalityRecords.isEmpty) return alerts;

    final sorted = List<MortalityRecord>.from(mortalityRecords)..sort((a, b) => b.date.compareTo(a.date));
    final latest = sorted.first;
    final latestTotal = latest.countObserved + latest.countEstimated;

    // 1. Absolute daily mortality spike (> 0.3% of population in a single day)
    if (currentPopulation > 0) {
      final dailyPct = (latestTotal / currentPopulation) * 100.0;
      if (dailyPct >= 0.5) {
        alerts.add(MortalityAlert(
          title: 'Critical Mortality Spike',
          message: 'Observed/estimated ${latestTotal.toString()} dead shrimp (${dailyPct.toStringAsFixed(2)}% of stock) today.',
          why: 'Loss rate exceeds 0.5% in 24 hours, indicating an acute environmental or pathogen distress event.',
          recommendation: 'Perform immediate pond check: check bottom DO, inspect net samples for gill fouling or soft shells, reduce feed by 50%.',
          severity: 'critical',
          date: latest.date,
        ));
      } else if (dailyPct >= 0.2) {
        alerts.add(MortalityAlert(
          title: 'Elevated Daily Mortality',
          message: 'Loss of ${latestTotal.toString()} shrimp (${dailyPct.toStringAsFixed(2)}% of stock) recorded.',
          why: 'Loss rate is noticeably above normal baseline mortality.',
          recommendation: 'Monitor check-trays closely, re-test water parameters, and inspect shrimp gut fullness.',
          severity: 'warning',
          date: latest.date,
        ));
      }
    }

    // 2. Trend Spike vs 3-day average
    if (sorted.length >= 4) {
      final prev3 = sorted.sublist(1, 4);
      final avg3 = prev3.fold<int>(0, (sum, r) => sum + r.countObserved + r.countEstimated) / 3.0;

      if (avg3 > 5 && latestTotal >= (avg3 * 1.8)) {
        alerts.add(MortalityAlert(
          title: 'Mortality Surge Above Baseline',
          message: "Today's mortality ($latestTotal) is 80%+ higher than the previous 3-day average (${avg3.toStringAsFixed(0)}/day).",
          why: 'A sharp escalation indicates deteriorating bottom conditions or molting stress.',
          recommendation: 'Inspect pond bottom cleanliness and siphon waste; verify paddlewheel aeration.',
          severity: 'warning',
          date: latest.date,
        ));
      }
    }

    // 3. Mortality + Sub-optimal DO Correlation
    if (latestTotal > 20 && latestDO != null && latestDO < 4.0) {
      alerts.add(MortalityAlert(
        title: 'Mortality Linked to Low Dissolved Oxygen',
        message: 'Elevated mortality coinciding with sub-optimal DO (${latestDO.toStringAsFixed(1)} mg/L).',
        why: 'Hypoxia precipitates shrimp exhaustion and secondary bacterial vulnerability.',
        recommendation: 'Maximize aeration output immediately and halt nighttime broadcasting until DO recovers above 5.0 mg/L.',
        severity: 'critical',
        date: latest.date,
      ));
    }

    return alerts;
  }
}
