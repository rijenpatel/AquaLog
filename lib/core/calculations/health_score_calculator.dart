import 'package:flutter/foundation.dart';

@immutable
class HealthScoreBreakdown {
  final int consistencyScore; // Max 35
  final int activityScore;    // Max 20
  final int growthScore;      // Max 25
  final int survivalScore;    // Max 20
  final int totalScore;       // 0 - 100
  final String grade;
  final String status;

  const HealthScoreBreakdown({
    required this.consistencyScore,
    required this.activityScore,
    required this.growthScore,
    required this.survivalScore,
    required this.totalScore,
    required this.grade,
    required this.status,
  });

  @override
  String toString() => 'HealthScoreBreakdown($totalScore/100, Grade $grade - $status)';
}

class HealthScoreCalculator {
  const HealthScoreCalculator();

  /// Computes the 4-Pillar Pond Health Score (0 - 100) as specified in Chapter 9:
  /// Total = Consistency (35) + Activity (20) + Growth (25) + Survival (20)
  static HealthScoreBreakdown calculate({
    required int sessionsLoggedLast7Days, // Max target: 28 sessions (4 feeds/day * 7)
    required bool loggedToday,
    required bool loggedYesterday,
    required bool loggedTwoDaysAgo,
    required double? latestAdg,          // grams/day
    required double? hapaSurvivalPct,    // e.g. 94.5%
  }) {
    // 1. Feed Logging Consistency (Max 35 pts)
    final consistencyRate = (sessionsLoggedLast7Days / 28.0) * 100.0;
    int consistencyScore;
    if (consistencyRate >= 90.0) {
      consistencyScore = 35;
    } else if (consistencyRate >= 75.0) {
      consistencyScore = 25;
    } else if (consistencyRate >= 50.0) {
      consistencyScore = 15;
    } else {
      consistencyScore = 5;
    }

    // 2. Recent Activity (Max 20 pts)
    int activityScore = 0;
    if (loggedToday) activityScore += 10;
    if (loggedYesterday) activityScore += 6;
    if (loggedTwoDaysAgo) activityScore += 4;

    // 3. Growth Performance (Max 25 pts)
    int growthScore = 0;
    if (latestAdg != null) {
      if (latestAdg >= 0.28) {
        growthScore = 25;
      } else if (latestAdg >= 0.20) {
        growthScore = 18;
      } else if (latestAdg >= 0.12) {
        growthScore = 10;
      } else {
        growthScore = 0;
      }
    } else {
      growthScore = 15; // Baseline neutral if sampling not yet due (DOC < 25)
    }

    // 4. Historical Survival (Max 20 pts)
    int survivalScore = 0;
    if (hapaSurvivalPct != null) {
      if (hapaSurvivalPct >= 92.0) {
        survivalScore = 20;
      } else if (hapaSurvivalPct >= 85.0) {
        survivalScore = 14;
      } else if (hapaSurvivalPct >= 75.0) {
        survivalScore = 8;
      } else {
        survivalScore = 2;
      }
    } else {
      survivalScore = 15; // Baseline assumed 88% if hapa net not logged
    }

    final totalScore = (consistencyScore + activityScore + growthScore + survivalScore).clamp(0, 100);

    String grade;
    String status;
    if (totalScore >= 85) {
      grade = 'A+';
      status = 'Optimal Pond Condition';
    } else if (totalScore >= 70) {
      grade = 'A';
      status = 'Good Operating Health';
    } else if (totalScore >= 55) {
      grade = 'B';
      status = 'Moderate / Attention Required';
    } else {
      grade = 'C';
      status = 'Critical Attention Needed';
    }

    return HealthScoreBreakdown(
      consistencyScore: consistencyScore,
      activityScore: activityScore,
      growthScore: growthScore,
      survivalScore: survivalScore,
      totalScore: totalScore,
      grade: grade,
      status: status,
    );
  }

  /// Calculates the holistic 6-pillar operational Pond Health and Risk score (0 - 100)
  static ComprehensivePondHealth calculateComprehensive({
    required int doc,
    double? latestDo,
    double? latestPh,
    double? latestTemp,
    double? latestAmmonia,
    double? latestNitrite,
    double? latestAdg,
    double? survivalPct,
    int? trayLeftoverPct,
    int? daysSinceLastSampling,
    int? todayMortalityCount,
    double? mortalityPctOfStock,
    bool doDeclining = false,
    bool feedIntakeDeclining = false,
  }) {
    // 1. Water Quality (Max 25 pts)
    int wqScore = 20; // Default baseline if unrecorded
    final concerns = <String>[];
    final recommendations = <String>[];
    final timeline = <RiskTimelineEvent>[];
    final correlations = <String>[];

    if (latestDo != null) {
      if (latestDo < 3.0) {
        wqScore = 4;
        concerns.add('Critical DO deficit (${latestDo.toStringAsFixed(1)} mg/L)');
        recommendations.add('Run full paddlewheel aeration immediately and suspend daytime feeding.');
        timeline.add(RiskTimelineEvent(
          level: RiskLevel.red,
          title: 'Critical DO Deficit',
          description: 'DO at ${latestDo.toStringAsFixed(1)} mg/L is critically below 3.0 mg/L minimum.',
          timestamp: DateTime.now(),
        ));
      } else if (latestDo < 4.0) {
        wqScore = 12;
        concerns.add('Sub-optimal DO (${latestDo.toStringAsFixed(1)} mg/L)');
        recommendations.add('Inspect aerators and trim feeding ration.');
        timeline.add(RiskTimelineEvent(
          level: RiskLevel.yellow,
          title: 'Low DO Warning',
          description: 'DO at ${latestDo.toStringAsFixed(1)} mg/L requires aeration support.',
          timestamp: DateTime.now(),
        ));
      } else {
        wqScore = 25;
      }
    }

    if (latestAmmonia != null && latestAmmonia >= 0.25) {
      wqScore = (wqScore - 8).clamp(0, 25);
      concerns.add('Elevated toxic ammonia (${latestAmmonia.toStringAsFixed(2)} mg/L)');
      recommendations.add('Plan 10-15% water exchange or apply probiotics to metabolize ammonia.');
      timeline.add(RiskTimelineEvent(
        level: RiskLevel.orange,
        title: 'Ammonia Spike',
        description: 'Ammonia reached ${latestAmmonia.toStringAsFixed(2)} mg/L.',
        timestamp: DateTime.now(),
      ));
    }

    if (doDeclining) {
      wqScore = (wqScore - 4).clamp(0, 25);
      concerns.add('DO has been consistently declining over recent readings');
    }

    // 2. Growth & ADG (Max 20 pts)
    int growthScore;
    if (latestAdg != null) {
      if (latestAdg >= 0.28) {
        growthScore = 20;
      } else if (latestAdg >= 0.20) {
        growthScore = 16;
      } else if (latestAdg >= 0.12) {
        growthScore = 10;
        concerns.add('Decelerating growth rate (ADG ${latestAdg.toStringAsFixed(2)} g/day)');
      } else {
        growthScore = 4;
        concerns.add('Severely stalled growth (ADG ${latestAdg.toStringAsFixed(2)} g/day)');
        recommendations.add('Check feed quality, check-tray leftovers, and gut health.');
      }
    } else {
      growthScore = doc < 25 ? 16 : 10; // Neutral baseline for early DOC
    }

    // 3. Survival Rate (Max 20 pts)
    int survScore;
    final surv = survivalPct ?? 88.0;
    if (surv >= 90.0) {
      survScore = 20;
    } else if (surv >= 80.0) {
      survScore = 16;
    } else if (surv >= 70.0) {
      survScore = 10;
      concerns.add('Moderate survival reduction (${surv.toStringAsFixed(1)}%)');
    } else {
      survScore = 4;
      concerns.add('Critical low survival rate (${surv.toStringAsFixed(1)}%)');
      recommendations.add('Audit stocking vs mortality and verify cast-net population density.');
    }

    // 4. Feed Performance & Tray Intake (Max 15 pts)
    int feedScore = 15;
    if (trayLeftoverPct != null) {
      if (trayLeftoverPct > 25) {
        feedScore = 4;
        concerns.add('Surplus feed refusal in check-trays ($trayLeftoverPct% leftover)');
        recommendations.add('Reduce upcoming feed broadcast by 25-30% immediately.');
      } else if (trayLeftoverPct > 10) {
        feedScore = 9;
        concerns.add('Moderate feed leftover in check-trays ($trayLeftoverPct%)');
        recommendations.add('Reduce next feeding session by 10-15%.');
      }
    }
    if (feedIntakeDeclining) {
      feedScore = (feedScore - 4).clamp(0, 15);
      concerns.add('Downward feed intake trend noticed over consecutive sessions');
    }

    // 5. Sampling Recency (Max 10 pts)
    int samplingScore;
    if (daysSinceLastSampling == null) {
      samplingScore = doc > 30 ? 2 : 8;
      if (doc > 30) {
        concerns.add('No sampling recorded yet for DOC $doc');
        recommendations.add('Conduct cast-net sampling to calibrate ABW and biomass.');
      }
    } else if (daysSinceLastSampling <= 7) {
      samplingScore = 10;
    } else if (daysSinceLastSampling <= 14) {
      samplingScore = 6;
      concerns.add('Sampling due ($daysSinceLastSampling days since last test)');
    } else {
      samplingScore = 2;
      concerns.add('Sampling overdue ($daysSinceLastSampling days since last test)');
      recommendations.add('Perform cast-net sampling to recalibrate FCR and feed tables.');
    }

    // 6. Mortality Rate (Max 10 pts)
    int mortScore = 10;
    if (mortalityPctOfStock != null && mortalityPctOfStock > 0.4) {
      mortScore = 0;
      concerns.add('Acute daily mortality spike (${(todayMortalityCount ?? 0)} dead)');
      recommendations.add('Perform health inspection: gill fouling, gut condition, bottom sludge.');
    } else if (todayMortalityCount != null && todayMortalityCount > 50) {
      mortScore = 4;
      concerns.add('Elevated mortality recorded today ($todayMortalityCount count)');
    }

    // 7. Multi-factor Correlations
    if (doDeclining && feedIntakeDeclining && (todayMortalityCount ?? 0) > 20) {
      correlations.add('Feed Intake Drop + DO Decline + Mortality Rise (Synergistic Hypoxia Distress)');
    } else if (latestAmmonia != null && latestAmmonia >= 0.2 && (trayLeftoverPct ?? 0) > 15) {
      correlations.add('High Ammonia + Feed Leftover (Waste Accumulation Feedback Loop)');
    }

    final total = (wqScore + growthScore + survScore + feedScore + samplingScore + mortScore).clamp(0, 100);

    RiskLevel level;
    if (total >= 80) {
      level = RiskLevel.green;
    } else if (total >= 65) {
      level = RiskLevel.yellow;
    } else if (total >= 50) {
      level = RiskLevel.orange;
    } else {
      level = RiskLevel.red;
    }

    if (concerns.isEmpty) {
      concerns.add('All parameters operating within optimal biological boundaries.');
    }
    if (recommendations.isEmpty) {
      recommendations.add('Maintain current feeding rations and aerator schedule.');
    }

    return ComprehensivePondHealth(
      totalScore: total,
      riskLevel: level,
      waterQualityScore: wqScore,
      growthScore: growthScore,
      survivalScore: survScore,
      feedPerformanceScore: feedScore,
      samplingRecencyScore: samplingScore,
      mortalityScore: mortScore,
      topConcerns: concerns,
      recommendations: recommendations,
      timelineEvents: timeline,
      correlations: correlations,
    );
  }
}

enum RiskLevel {
  green,
  yellow,
  orange,
  red;

  String get label {
    switch (this) {
      case RiskLevel.green:
        return 'Healthy / Stable';
      case RiskLevel.yellow:
        return 'Needs Attention';
      case RiskLevel.orange:
        return 'High Risk';
      case RiskLevel.red:
        return 'Critical';
    }
  }
}

class RiskTimelineEvent {
  final RiskLevel level;
  final String title;
  final String description;
  final DateTime timestamp;

  const RiskTimelineEvent({
    required this.level,
    required this.title,
    required this.description,
    required this.timestamp,
  });
}

class ComprehensivePondHealth {
  final int totalScore; // 0 - 100
  final RiskLevel riskLevel;
  final int waterQualityScore;     // Max 25
  final int growthScore;           // Max 20
  final int survivalScore;         // Max 20
  final int feedPerformanceScore;  // Max 15
  final int samplingRecencyScore;  // Max 10
  final int mortalityScore;        // Max 10
  final List<String> topConcerns;
  final List<String> recommendations;
  final List<RiskTimelineEvent> timelineEvents;
  final List<String> correlations;

  const ComprehensivePondHealth({
    required this.totalScore,
    required this.riskLevel,
    required this.waterQualityScore,
    required this.growthScore,
    required this.survivalScore,
    required this.feedPerformanceScore,
    required this.samplingRecencyScore,
    required this.mortalityScore,
    required this.topConcerns,
    required this.recommendations,
    required this.timelineEvents,
    required this.correlations,
  });
}
