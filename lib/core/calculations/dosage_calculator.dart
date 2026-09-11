import 'package:flutter/foundation.dart';

@immutable
class ChemicalDosageResult {
  final double requiredProductKg;
  final double requiredProductLiters;
  final double volumeM3;
  final double dosageRate;
  final bool isPpmBased;
  final String formatted;

  const ChemicalDosageResult({
    required this.requiredProductKg,
    required this.requiredProductLiters,
    required this.volumeM3,
    required this.dosageRate,
    required this.isPpmBased,
    required this.formatted,
  });

  @override
  String toString() => 'ChemicalDosageResult($formatted for $volumeM3 m³)';
}

class DosageCalculator {
  const DosageCalculator();

  /// Calculates required chemical treatment product from Parts-Per-Million (PPM):
  /// 1 ppm = 1 g/m³ = 1 mg/L
  /// Required Product (kg) = (Volume (m³) * Dosage Rate (ppm)) / 1,000.0
  static ChemicalDosageResult calculateFromPpm({
    required double volumeM3,
    required double dosageRatePpm,
  }) {
    if (volumeM3 <= 0) {
      throw ArgumentError('Water volume must be greater than zero.');
    }
    if (dosageRatePpm <= 0) {
      throw ArgumentError('Dosage rate (PPM) must be greater than zero.');
    }

    final requiredKg = (volumeM3 * dosageRatePpm) / 1000.0;
    final roundedKg = double.parse(requiredKg.toStringAsFixed(2));

    return ChemicalDosageResult(
      requiredProductKg: roundedKg,
      requiredProductLiters: roundedKg, // 1 kg ~ 1 L for standard liquid treatments
      volumeM3: volumeM3,
      dosageRate: dosageRatePpm,
      isPpmBased: true,
      formatted: '$roundedKg kg (or L)',
    );
  }

  /// Calculates required product from Area Rate (kg/ha):
  /// Required Product (kg) = Area (ha) * Rate (kg/ha)
  static ChemicalDosageResult calculateFromAreaRate({
    required double areaHectares,
    required double rateKgPerHa,
    double volumeM3 = 0.0,
  }) {
    if (areaHectares <= 0) {
      throw ArgumentError('Pond area (ha) must be greater than zero.');
    }
    if (rateKgPerHa <= 0) {
      throw ArgumentError('Application rate (kg/ha) must be greater than zero.');
    }

    final requiredKg = areaHectares * rateKgPerHa;
    final roundedKg = double.parse(requiredKg.toStringAsFixed(2));

    return ChemicalDosageResult(
      requiredProductKg: roundedKg,
      requiredProductLiters: roundedKg,
      volumeM3: volumeM3,
      dosageRate: rateKgPerHa,
      isPpmBased: false,
      formatted: '$roundedKg kg',
    );
  }
}
