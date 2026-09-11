import 'package:flutter/foundation.dart';

@immutable
class PeriodFcrResult {
  final double? fcr;
  final double feedFedKg;
  final double biomassGainKg;
  final bool isUndefined;
  final String? warning;
  final String formatted;

  const PeriodFcrResult({
    required this.fcr,
    required this.feedFedKg,
    required this.biomassGainKg,
    required this.isUndefined,
    this.warning,
    required this.formatted,
  });

  @override
  String toString() => isUndefined ? 'PeriodFcrResult(Undefined: $warning)' : 'PeriodFcrResult(FCR: $formatted)';
}

@immutable
class CumulativeFcrResult {
  final double fcr;
  final double totalFeedKg;
  final double biomassOrHarvestKg;
  final String formatted;

  const CumulativeFcrResult({
    required this.fcr,
    required this.totalFeedKg,
    required this.biomassOrHarvestKg,
    required this.formatted,
  });

  @override
  String toString() => 'CumulativeFcrResult(FCR: $formatted)';
}

class FcrCalculator {
  const FcrCalculator();

  /// Calculates Period-by-Period FCR between two sampling dates.
  /// Formula: Period FCR = Feed Broadcast between Date1 and Date2 (kg) / (Biomass2 - Biomass1) (kg)
  /// Edge Case: If Biomass2 <= Biomass1 (disease mortality or zero gain), FCR is mathematically undefined.
  static PeriodFcrResult calculatePeriodFcr({
    required double feedFedKg,
    required double biomass1Kg,
    required double biomass2Kg,
  }) {
    final biomassGain = biomass2Kg - biomass1Kg;

    if (biomassGain <= 0) {
      return PeriodFcrResult(
        fcr: null,
        feedFedKg: feedFedKg,
        biomassGainKg: biomassGain,
        isUndefined: true,
        warning: 'Biomass gain ≤ 0 kg. Period FCR is undefined.',
        formatted: 'N/A',
      );
    }

    final rawFcr = feedFedKg / biomassGain;
    final roundedFcr = double.parse(rawFcr.toStringAsFixed(2));

    return PeriodFcrResult(
      fcr: roundedFcr,
      feedFedKg: feedFedKg,
      biomassGainKg: biomassGain,
      isUndefined: false,
      formatted: roundedFcr.toStringAsFixed(2),
    );
  }

  /// Calculates Cumulative FCR across the crop cycle to date or at harvest.
  /// Cumulative FCR = Total Feed Fed (kg) / Current Biomass or Harvest Weight (kg)
  static CumulativeFcrResult calculateCumulativeFcr({
    required double totalFeedKg,
    required double biomassOrHarvestKg,
  }) {
    if (biomassOrHarvestKg <= 0) {
      throw ArgumentError('Biomass or harvest weight must be greater than zero.');
    }

    final rawFcr = totalFeedKg / biomassOrHarvestKg;
    final roundedFcr = double.parse(rawFcr.toStringAsFixed(2));

    return CumulativeFcrResult(
      fcr: roundedFcr,
      totalFeedKg: totalFeedKg,
      biomassOrHarvestKg: biomassOrHarvestKg,
      formatted: roundedFcr.toStringAsFixed(2),
    );
  }
}
