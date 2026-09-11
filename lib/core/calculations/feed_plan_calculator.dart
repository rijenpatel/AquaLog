class FeedPlanRation {
  final double baseFeedKg;
  final double trayAdjustmentKg;
  final double weatherAdjustmentKg;
  final double wqAdjustmentKg;
  final double mortalityAdjustmentKg;
  final double recommendedFeedKg;
  final double feedingRatePct;
  final List<String> adjustmentReasons;

  const FeedPlanRation({
    required this.baseFeedKg,
    required this.trayAdjustmentKg,
    required this.weatherAdjustmentKg,
    required this.wqAdjustmentKg,
    required this.mortalityAdjustmentKg,
    required this.recommendedFeedKg,
    required this.feedingRatePct,
    required this.adjustmentReasons,
  });
}

class PlanVsActualVariance {
  final double plannedKg;
  final double actualKg;
  final double varianceKg;
  final double variancePct;
  final String complianceStatus; // 'Adherent', 'Overfed', 'Underfed'

  const PlanVsActualVariance({
    required this.plannedKg,
    required this.actualKg,
    required this.varianceKg,
    required this.variancePct,
    required this.complianceStatus,
  });
}

class FeedPlanCalculator {
  /// Computes recommended daily feeding rate percentage based on ABW
  static double getRecommendedFeedingRatePct(double abwGrams) {
    if (abwGrams < 3.0) return 7.5;
    if (abwGrams < 6.0) return 6.0;
    if (abwGrams < 10.0) return 4.8;
    if (abwGrams < 15.0) return 3.8;
    if (abwGrams < 20.0) return 3.0;
    return 2.4; // 20g+
  }

  /// Generates the daily feed plan ration with transparent adjustments
  static FeedPlanRation calculateDailyPlan({
    required double biomassKg,
    required double abwGrams,
    int? trayLeftoverPct,
    double? latestDO,
    double? latestAmmonia,
    bool isRaining = false,
    bool extremeHeat = false,
    bool mortalitySpike = false,
  }) {
    final ratePct = getRecommendedFeedingRatePct(abwGrams);
    final baseKg = double.parse(((biomassKg * ratePct) / 100.0).toStringAsFixed(1));

    double trayAdj = 0.0;
    double weatherAdj = 0.0;
    double wqAdj = 0.0;
    double mortAdj = 0.0;
    final reasons = <String>[];

    // 1. Check-tray feedback
    if (trayLeftoverPct != null) {
      if (trayLeftoverPct > 25) {
        trayAdj = -double.parse((baseKg * 0.25).toStringAsFixed(1));
        reasons.add('Trays had surplus leftover ($trayLeftoverPct%): -25%');
      } else if (trayLeftoverPct > 10) {
        trayAdj = -double.parse((baseKg * 0.12).toStringAsFixed(1));
        reasons.add('Trays had moderate leftover ($trayLeftoverPct%): -12%');
      } else if (trayLeftoverPct == 0) {
        trayAdj = double.parse((baseKg * 0.03).toStringAsFixed(1));
        reasons.add('Clean check-trays (100% consumed): +3%');
      }
    }

    // 2. Weather adjustments
    if (isRaining) {
      weatherAdj -= double.parse((baseKg * 0.15).toStringAsFixed(1));
      reasons.add('Rain / atmospheric pressure drop: -15%');
    }
    if (extremeHeat) {
      weatherAdj -= double.parse((baseKg * 0.10).toStringAsFixed(1));
      reasons.add('Extreme midday heat stress: -10%');
    }

    // 3. Water Quality adjustments
    if (latestDO != null) {
      if (latestDO < 3.0) {
        wqAdj -= double.parse((baseKg * 0.50).toStringAsFixed(1));
        reasons.add('Critical DO deficit (<3.0 mg/L): -50% ration cut');
      } else if (latestDO < 4.0) {
        wqAdj -= double.parse((baseKg * 0.20).toStringAsFixed(1));
        reasons.add('Sub-optimal DO (<4.0 mg/L): -20% ration cut');
      }
    }
    if (latestAmmonia != null && latestAmmonia >= 0.2) {
      wqAdj -= double.parse((baseKg * 0.15).toStringAsFixed(1));
      reasons.add('Elevated ammonia (${latestAmmonia.toStringAsFixed(2)} mg/L): -15% to limit waste');
    }

    // 4. Mortality adjustment
    if (mortalitySpike) {
      mortAdj -= double.parse((baseKg * 0.20).toStringAsFixed(1));
      reasons.add('Elevated mortality detected: -20% precautionary reduction');
    }

    final totalAdj = trayAdj + weatherAdj + wqAdj + mortAdj;
    final recommended = double.parse((baseKg + totalAdj).clamp(baseKg * 0.3, baseKg * 1.2).toStringAsFixed(1));

    if (reasons.isEmpty) {
      reasons.add('Standard baseline ration (optimal conditions).');
    }

    return FeedPlanRation(
      baseFeedKg: baseKg,
      trayAdjustmentKg: trayAdj,
      weatherAdjustmentKg: weatherAdj,
      wqAdjustmentKg: wqAdj,
      mortalityAdjustmentKg: mortAdj,
      recommendedFeedKg: recommended,
      feedingRatePct: ratePct,
      adjustmentReasons: reasons,
    );
  }

  /// Analyzes adherence between planned feed and actual logged feed
  static PlanVsActualVariance calculateVariance({
    required double plannedKg,
    required double actualKg,
  }) {
    final diff = double.parse((actualKg - plannedKg).toStringAsFixed(2));
    final pct = plannedKg > 0
        ? double.parse(((diff / plannedKg) * 100.0).toStringAsFixed(1))
        : 0.0;

    String status = 'Adherent';
    if (pct > 7.0) {
      status = 'Overfed';
    } else if (pct < -7.0) {
      status = 'Underfed';
    }

    return PlanVsActualVariance(
      plannedKg: plannedKg,
      actualKg: actualKg,
      varianceKg: diff,
      variancePct: pct,
      complianceStatus: status,
    );
  }
}
