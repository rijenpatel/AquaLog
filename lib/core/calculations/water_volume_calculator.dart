import 'package:flutter/foundation.dart';

@immutable
class WaterVolumeResult {
  final double areaSqMeters;
  final double areaHectares;
  final double waterDepthMeters;
  final double volumeM3;
  final double volumeLiters;
  final double aeratorDensityHpPerHa;
  final bool isAerationAdequate;
  final String? aerationWarning;

  const WaterVolumeResult({
    required this.areaSqMeters,
    required this.areaHectares,
    required this.waterDepthMeters,
    required this.volumeM3,
    required this.volumeLiters,
    required this.aeratorDensityHpPerHa,
    required this.isAerationAdequate,
    this.aerationWarning,
  });

  @override
  String toString() => 'WaterVolumeResult($volumeM3 m³, ${aeratorDensityHpPerHa.toStringAsFixed(1)} HP/ha)';
}

class WaterVolumeCalculator {
  const WaterVolumeCalculator();

  /// Calculates Pond Water Volume and Aerator Density:
  /// Area (ha) = Area (m²) / 10,000
  /// Volume (m³) = Area (m²) * Depth (m)
  /// Volume (L) = Volume (m³) * 1,000
  /// Aerator Density (HP/ha) = Total Aerator HP / Area (ha)
  /// Intensive L. vannamei standard: 25 to 40 HP/ha. Flag if < 20 HP/ha.
  static WaterVolumeResult calculate({
    required double areaSqMeters,
    required double waterDepthMeters,
    double totalAeratorHp = 0.0,
  }) {
    if (areaSqMeters <= 0) {
      throw ArgumentError('Pond surface area must be greater than zero.');
    }
    if (waterDepthMeters <= 0) {
      throw ArgumentError('Water depth must be greater than zero.');
    }

    final areaHa = areaSqMeters / 10000.0;
    final volumeM3 = areaSqMeters * waterDepthMeters;
    final volumeLiters = volumeM3 * 1000.0;

    final aeratorDensity = areaHa > 0 ? totalAeratorHp / areaHa : 0.0;
    final isAdequate = aeratorDensity >= 20.0;

    String? warning;
    if (!isAdequate && totalAeratorHp > 0) {
      warning = 'Aeration density (${aeratorDensity.toStringAsFixed(1)} HP/ha) is below standard 20 HP/ha for intensive crops.';
    }

    return WaterVolumeResult(
      areaSqMeters: areaSqMeters,
      areaHectares: double.parse(areaHa.toStringAsFixed(3)),
      waterDepthMeters: waterDepthMeters,
      volumeM3: double.parse(volumeM3.toStringAsFixed(1)),
      volumeLiters: double.parse(volumeLiters.toStringAsFixed(0)),
      aeratorDensityHpPerHa: double.parse(aeratorDensity.toStringAsFixed(1)),
      isAerationAdequate: isAdequate,
      aerationWarning: warning,
    );
  }
}
