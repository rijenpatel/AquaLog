import 'package:flutter/foundation.dart';

enum BiomassSource {
  sampling('Sampling ABW', false),
  visual('Visual Estimation', true),
  missing('Missing Data', false);

  final String label;
  final bool isEstimateOnly;

  const BiomassSource(this.label, this.isEstimateOnly);
}

@immutable
class BiomassResult {
  final double biomassKg;
  final int estimatedPopulation;
  final double abwGrams;
  final BiomassSource source;
  final String formatted;
  final String? warning;

  const BiomassResult({
    required this.biomassKg,
    required this.estimatedPopulation,
    required this.abwGrams,
    required this.source,
    required this.formatted,
    this.warning,
  });

  @override
  String toString() => 'BiomassResult($formatted kg from ${source.label})';
}

class BiomassCalculator {
  const BiomassCalculator();

  /// Calculates standing Biomass in kg using the strict fallback resolution tree:
  /// 1. Check if estimated population available (via Hapa check or baseline survival).
  /// 2. Sourcing priority for ABW:
  ///    - Sampling ABW (primary accurate source)
  ///    - Visual ABW (fallback with warning flag)
  ///    - If neither available: returns null / throws MissingDataException.
  /// Formula: Biomass (kg) = (N_estimated * ABW (g)) / 1000.0
  /// Formatted to 1 decimal place.
  static BiomassResult? calculate({
    required int? estimatedPopulation,
    required double? samplingAbwGrams,
    required double? visualAbwGrams,
  }) {
    if (estimatedPopulation == null || estimatedPopulation <= 0) {
      return null; // Missing population
    }

    double? selectedAbw;
    BiomassSource source;
    String? warning;

    if (samplingAbwGrams != null && samplingAbwGrams > 0) {
      selectedAbw = samplingAbwGrams;
      source = BiomassSource.sampling;
    } else if (visualAbwGrams != null && visualAbwGrams > 0) {
      selectedAbw = visualAbwGrams;
      source = BiomassSource.visual;
      warning = 'Calculated from visual weight estimation. Conduct cast net sampling for precision.';
    } else {
      return null; // Missing ABW
    }

    final rawBiomass = (estimatedPopulation * selectedAbw) / 1000.0;
    final roundedBiomass = double.parse(rawBiomass.toStringAsFixed(1));

    return BiomassResult(
      biomassKg: roundedBiomass,
      estimatedPopulation: estimatedPopulation,
      abwGrams: selectedAbw,
      source: source,
      formatted: roundedBiomass.toStringAsFixed(1),
      warning: warning,
    );
  }
}
