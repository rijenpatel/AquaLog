import '../database/app_database.dart';

enum WqStatus {
  optimal,
  acceptable,
  warning,
  critical;

  String get label {
    switch (this) {
      case WqStatus.optimal:
        return 'Optimal';
      case WqStatus.acceptable:
        return 'Acceptable';
      case WqStatus.warning:
        return 'Warning';
      case WqStatus.critical:
        return 'Critical';
    }
  }
}

class WqParameterThreshold {
  final String name;
  final String unit;
  final double optimalMin;
  final double optimalMax;
  final double acceptableMin;
  final double acceptableMax;
  final double warningMin;
  final double warningMax;

  const WqParameterThreshold({
    required this.name,
    required this.unit,
    required this.optimalMin,
    required this.optimalMax,
    required this.acceptableMin,
    required this.acceptableMax,
    required this.warningMin,
    required this.warningMax,
  });

  WqStatus evaluate(double? value) {
    if (value == null) return WqStatus.acceptable;
    if (value >= optimalMin && value <= optimalMax) return WqStatus.optimal;
    if (value >= acceptableMin && value <= acceptableMax) return WqStatus.acceptable;
    if (value >= warningMin && value <= warningMax) return WqStatus.warning;
    return WqStatus.critical;
  }
}

class WqTrendSummary {
  final String parameter;
  final String unit;
  final double? latestValue;
  final double? previousValue;
  final double? change;
  final double? min7d;
  final double? max7d;
  final double? avg7d;
  final double? avg14d;
  final WqStatus status;
  final String direction; // 'rising', 'declining', 'stable'
  final int abnormalEventCount;

  const WqTrendSummary({
    required this.parameter,
    required this.unit,
    this.latestValue,
    this.previousValue,
    this.change,
    this.min7d,
    this.max7d,
    this.avg7d,
    this.avg14d,
    required this.status,
    required this.direction,
    required this.abnormalEventCount,
  });
}

class WqRiskAlert {
  final String title;
  final String message;
  final String why;
  final String recommendation;
  final WqStatus severity;
  final DateTime date;

  const WqRiskAlert({
    required this.title,
    required this.message,
    required this.why,
    required this.recommendation,
    required this.severity,
    required this.date,
  });
}

class WaterQualityEngine {
  // Configurable default thresholds
  static const Map<String, WqParameterThreshold> defaultThresholds = {
    'dissolvedOxygen': WqParameterThreshold(
      name: 'Dissolved Oxygen',
      unit: 'mg/L',
      optimalMin: 5.0,
      optimalMax: 12.0,
      acceptableMin: 4.0,
      acceptableMax: 14.0,
      warningMin: 3.0,
      warningMax: 16.0,
    ),
    'ph': WqParameterThreshold(
      name: 'pH',
      unit: '',
      optimalMin: 7.5,
      optimalMax: 8.5,
      acceptableMin: 7.0,
      acceptableMax: 9.0,
      warningMin: 6.5,
      warningMax: 9.5,
    ),
    'temperature': WqParameterThreshold(
      name: 'Temperature',
      unit: '°C',
      optimalMin: 28.0,
      optimalMax: 32.0,
      acceptableMin: 26.0,
      acceptableMax: 34.0,
      warningMin: 24.0,
      warningMax: 36.0,
    ),
    'salinity': WqParameterThreshold(
      name: 'Salinity',
      unit: 'ppt',
      optimalMin: 10.0,
      optimalMax: 25.0,
      acceptableMin: 5.0,
      acceptableMax: 35.0,
      warningMin: 2.0,
      warningMax: 40.0,
    ),
    'ammonia': WqParameterThreshold(
      name: 'Ammonia (NH3-N)',
      unit: 'mg/L',
      optimalMin: 0.0,
      optimalMax: 0.05,
      acceptableMin: 0.0,
      acceptableMax: 0.1,
      warningMin: 0.0,
      warningMax: 0.5,
    ),
    'nitrite': WqParameterThreshold(
      name: 'Nitrite (NO2-N)',
      unit: 'mg/L',
      optimalMin: 0.0,
      optimalMax: 0.1,
      acceptableMin: 0.0,
      acceptableMax: 0.25,
      warningMin: 0.0,
      warningMax: 0.5,
    ),
    'alkalinity': WqParameterThreshold(
      name: 'Alkalinity',
      unit: 'mg/L',
      optimalMin: 120.0,
      optimalMax: 180.0,
      acceptableMin: 100.0,
      acceptableMax: 200.0,
      warningMin: 80.0,
      warningMax: 250.0,
    ),
    'transparencyCm': WqParameterThreshold(
      name: 'Transparency',
      unit: 'cm',
      optimalMin: 30.0,
      optimalMax: 40.0,
      acceptableMin: 25.0,
      acceptableMax: 45.0,
      warningMin: 20.0,
      warningMax: 50.0,
    ),
  };

  /// Evaluates a single water quality log and returns overall status
  static WqStatus evaluateLog(WaterQualityLog log, {Map<String, WqParameterThreshold>? customThresholds}) {
    final thresholds = customThresholds ?? defaultThresholds;
    var worst = WqStatus.optimal;

    void check(String param, double? val) {
      if (val == null) return;
      final t = thresholds[param];
      if (t == null) return;
      final status = t.evaluate(val);
      if (status.index > worst.index) {
        worst = status;
      }
    }

    check('dissolvedOxygen', log.dissolvedOxygen);
    check('ph', log.ph);
    check('temperature', log.temperature);
    check('ammonia', log.ammonia);
    check('nitrite', log.nitrite);
    check('alkalinity', log.alkalinity);
    check('salinity', log.salinity);
    check('transparencyCm', log.transparencyCm);

    return worst;
  }

  /// Generates trend summaries for all parameters from historical logs (sorted newest first)
  static Map<String, WqTrendSummary> analyzeTrends(
    List<WaterQualityLog> logs, {
    Map<String, WqParameterThreshold>? customThresholds,
  }) {
    final thresholds = customThresholds ?? defaultThresholds;
    final summaries = <String, WqTrendSummary>{};

    if (logs.isEmpty) {
      for (final entry in thresholds.entries) {
        summaries[entry.key] = WqTrendSummary(
          parameter: entry.value.name,
          unit: entry.value.unit,
          status: WqStatus.optimal,
          direction: 'stable',
          abnormalEventCount: 0,
        );
      }
      return summaries;
    }

    final sorted = List<WaterQualityLog>.from(logs)..sort((a, b) => b.date.compareTo(a.date));
    final now = sorted.first.date;
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));

    for (final entry in thresholds.entries) {
      final key = entry.key;
      final threshold = entry.value;

      double? extract(WaterQualityLog l) {
        switch (key) {
          case 'dissolvedOxygen':
            return l.dissolvedOxygen;
          case 'ph':
            return l.ph;
          case 'temperature':
            return l.temperature;
          case 'salinity':
            return l.salinity;
          case 'ammonia':
            return l.ammonia;
          case 'nitrite':
            return l.nitrite;
          case 'alkalinity':
            return l.alkalinity;
          case 'transparencyCm':
            return l.transparencyCm;
          default:
            return null;
        }
      }

      final nonNullLogs = sorted.where((l) => extract(l) != null).toList();
      if (nonNullLogs.isEmpty) {
        summaries[key] = WqTrendSummary(
          parameter: threshold.name,
          unit: threshold.unit,
          status: WqStatus.optimal,
          direction: 'stable',
          abnormalEventCount: 0,
        );
        continue;
      }

      final latest = extract(nonNullLogs.first)!;
      final previous = nonNullLogs.length > 1 ? extract(nonNullLogs[1]) : null;
      final change = previous != null ? double.parse((latest - previous).toStringAsFixed(2)) : null;

      String direction = 'stable';
      if (change != null) {
        if (change > 0.1) direction = 'rising';
        if (change < -0.1) direction = 'declining';
      }

      final logs7d = nonNullLogs.where((l) => !l.date.isBefore(sevenDaysAgo)).map((l) => extract(l)!).toList();
      final logs14d = nonNullLogs.where((l) => !l.date.isBefore(fourteenDaysAgo)).map((l) => extract(l)!).toList();

      double? min7d, max7d, avg7d, avg14d;
      if (logs7d.isNotEmpty) {
        min7d = logs7d.reduce((a, b) => a < b ? a : b);
        max7d = logs7d.reduce((a, b) => a > b ? a : b);
        avg7d = double.parse((logs7d.reduce((a, b) => a + b) / logs7d.length).toStringAsFixed(2));
      }
      if (logs14d.isNotEmpty) {
        avg14d = double.parse((logs14d.reduce((a, b) => a + b) / logs14d.length).toStringAsFixed(2));
      }

      int abnormalCount = 0;
      for (final l in nonNullLogs) {
        final val = extract(l);
        if (val != null) {
          final s = threshold.evaluate(val);
          if (s == WqStatus.warning || s == WqStatus.critical) {
            abnormalCount++;
          }
        }
      }

      summaries[key] = WqTrendSummary(
        parameter: threshold.name,
        unit: threshold.unit,
        latestValue: latest,
        previousValue: previous,
        change: change,
        min7d: min7d,
        max7d: max7d,
        avg7d: avg7d,
        avg14d: avg14d,
        status: threshold.evaluate(latest),
        direction: direction,
        abnormalEventCount: abnormalCount,
      );
    }

    return summaries;
  }

  /// Analyzes correlations and detects operational risk events
  static List<WqRiskAlert> detectRiskAlerts(
    List<WaterQualityLog> logs, {
    double? currentBiomassKg,
  }) {
    final alerts = <WqRiskAlert>[];
    if (logs.isEmpty) return alerts;

    final sorted = List<WaterQualityLog>.from(logs)..sort((a, b) => b.date.compareTo(a.date));
    final latest = sorted.first;

    // 1. Critical DO Alert
    if (latest.dissolvedOxygen != null) {
      if (latest.dissolvedOxygen! < 3.0) {
        alerts.add(WqRiskAlert(
          title: 'Critical Dissolved Oxygen Deficit',
          message: 'DO measured at ${latest.dissolvedOxygen} mg/L, below critical threshold (3.0 mg/L).',
          why: 'Severe oxygen deficit impairs respiration and can cause acute mortality within hours.',
          recommendation: 'Activate all pond aerators immediately and halt feeding until DO > 4.5 mg/L.',
          severity: WqStatus.critical,
          date: latest.date,
        ));
      } else if (latest.dissolvedOxygen! < 4.0) {
        alerts.add(WqRiskAlert(
          title: 'Low DO Warning',
          message: 'DO measured at ${latest.dissolvedOxygen} mg/L, in warning range.',
          why: 'Marginal oxygen suppresses feeding intake and induces stress.',
          recommendation: 'Inspect paddlewheel aerators and reduce upcoming feed ration by 20%.',
          severity: WqStatus.warning,
          date: latest.date,
        ));
      }
    }

    // 2. Rapid DO drop detection
    if (sorted.length >= 2 && latest.dissolvedOxygen != null && sorted[1].dissolvedOxygen != null) {
      final prevDO = sorted[1].dissolvedOxygen!;
      final delta = latest.dissolvedOxygen! - prevDO;
      if (delta <= -1.2) {
        alerts.add(WqRiskAlert(
          title: 'Rapid DO Depletion',
          message: 'DO dropped by ${delta.abs().toStringAsFixed(1)} mg/L since previous reading.',
          why: 'Rapid oxygen plunge indicates plankton die-off or elevated biological oxygen demand.',
          recommendation: 'Re-test in 2 hours, operate aerators at full capacity, and check water clarity.',
          severity: WqStatus.warning,
          date: latest.date,
        ));
      }
    }

    // 3. Ammonia + pH Elevated Risk Combination
    if (latest.ammonia != null && latest.ph != null) {
      if (latest.ammonia! >= 0.1 && latest.ph! >= 8.5) {
        alerts.add(WqRiskAlert(
          title: 'Elevated Ammonia Toxicity Risk',
          message: 'Ammonia at ${latest.ammonia} mg/L coupled with high pH (${latest.ph}).',
          why: 'Un-ionized toxic ammonia (NH3) exponentially increases as pH rises above 8.2.',
          recommendation: 'Consider a 10-15% water exchange or apply probiotics to metabolize ammonia. Avoid alkaline lime.',
          severity: WqStatus.critical,
          date: latest.date,
        ));
      } else if (latest.ammonia! >= 0.25) {
        alerts.add(WqRiskAlert(
          title: 'High Ammonia Alert',
          message: 'Ammonia is ${latest.ammonia} mg/L (warning threshold 0.1 mg/L).',
          why: 'Persistent ammonia damages gills and weakens shrimp immunity.',
          recommendation: 'Initiate partial water top-up or water exchange, reduce feeding rations.',
          severity: WqStatus.warning,
          date: latest.date,
        ));
      }
    }

    // 4. Low DO + High Temperature Stress Combination
    if (latest.dissolvedOxygen != null && latest.temperature != null) {
      if (latest.dissolvedOxygen! < 4.2 && latest.temperature! >= 32.5) {
        alerts.add(WqRiskAlert(
          title: 'Thermal & Oxygen Stress Co-occurrence',
          message: 'High water temperature (${latest.temperature} °C) coupled with sub-optimal DO (${latest.dissolvedOxygen} mg/L).',
          why: 'Shrimp metabolic rate surges at elevated temperatures while oxygen solubility decreases.',
          recommendation: 'Operate all aeration and postpone feeding to avoid post-prandial oxygen collapse.',
          severity: WqStatus.critical,
          date: latest.date,
        ));
      }
    }

    // 5. Nitrite Toxicity Alert
    if (latest.nitrite != null && latest.nitrite! >= 0.25) {
      alerts.add(WqRiskAlert(
        title: 'Elevated Nitrite Level',
        message: 'Nitrite at ${latest.nitrite} mg/L exceeds safe target (0.1 mg/L).',
        why: 'Nitrite oxidizes shrimp hemocyanin, impairing blood oxygen-carrying capability.',
        recommendation: 'Check pond chloride/salinity levels to counteract nitrite toxicity; plan water exchange.',
        severity: latest.nitrite! >= 0.5 ? WqStatus.critical : WqStatus.warning,
        date: latest.date,
      ));
    }

    // 6. Alkalinity Warning
    if (latest.alkalinity != null) {
      if (latest.alkalinity! < 100.0) {
        alerts.add(WqRiskAlert(
          title: 'Low Water Alkalinity',
          message: 'Alkalinity at ${latest.alkalinity} mg/L is below recommended buffer minimum (100 mg/L).',
          why: 'Low alkalinity destabilizes pH swings between dawn and dusk, hindering shrimp shell hardening.',
          recommendation: 'Apply agricultural limestone or sodium bicarbonate to raise alkalinity to 120-150 mg/L.',
          severity: WqStatus.warning,
          date: latest.date,
        ));
      }
    }

    return alerts;
  }
}
