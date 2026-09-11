import 'package:flutter/foundation.dart';

enum AdgEvaluation {
  excellent('Excellent Growth', '🌱+', 'High-velocity growth; feed assimilation optimal.'),
  normal('Normal Growth', '🌿', 'Standard commercial growth velocity.'),
  subOptimal('Sub-Optimal Growth', '⚠️', 'Sluggish growth; inspect water quality and check-trays.'),
  stallingAlert('Growth Stalling Alert!', '🔴', 'Stalled or negative growth; immediate health test required.');

  final String title;
  final String badge;
  final String recommendation;

  const AdgEvaluation(this.title, this.badge, this.recommendation);
}

@immutable
class AdgResult {
  final double adgGramsPerDay;
  final double weightGainGrams;
  final int daysElapsed;
  final AdgEvaluation evaluation;
  final String formatted;

  const AdgResult({
    required this.adgGramsPerDay,
    required this.weightGainGrams,
    required this.daysElapsed,
    required this.evaluation,
    required this.formatted,
  });

  @override
  String toString() => 'AdgResult($formatted g/day, ${evaluation.title})';
}

class AdgCalculator {
  const AdgCalculator();

  /// Calculates Average Daily Growth (ADG) between two consecutive sampling events.
  /// ΔWeight = Current ABW - Previous ABW
  /// ΔDays = Floor((Current Date - Previous Date) / 86400000)
  /// ADG = ΔWeight / ΔDays (g/day)
  static AdgResult calculate({
    required double currentAbwGrams,
    required double previousAbwGrams,
    required DateTime currentDate,
    required DateTime previousDate,
  }) {
    final curMidnight = DateTime(currentDate.year, currentDate.month, currentDate.day);
    final prevMidnight = DateTime(previousDate.year, previousDate.month, previousDate.day);

    final daysElapsed = curMidnight.difference(prevMidnight).inDays;
    if (daysElapsed <= 0) {
      throw ArgumentError('Days elapsed between sampling events must be at least 1 day.');
    }

    final weightGain = currentAbwGrams - previousAbwGrams;
    final rawAdg = weightGain / daysElapsed;
    final roundedAdg = double.parse(rawAdg.toStringAsFixed(3));

    AdgEvaluation evaluation;
    if (roundedAdg >= 0.30) {
      evaluation = AdgEvaluation.excellent;
    } else if (roundedAdg >= 0.20) {
      evaluation = AdgEvaluation.normal;
    } else if (roundedAdg >= 0.10) {
      evaluation = AdgEvaluation.subOptimal;
    } else {
      evaluation = AdgEvaluation.stallingAlert;
    }

    return AdgResult(
      adgGramsPerDay: roundedAdg,
      weightGainGrams: double.parse(weightGain.toStringAsFixed(2)),
      daysElapsed: daysElapsed,
      evaluation: evaluation,
      formatted: roundedAdg.toStringAsFixed(2),
    );
  }
}
