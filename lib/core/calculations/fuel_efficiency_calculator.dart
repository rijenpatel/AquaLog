import 'package:flutter/foundation.dart';

@immutable
class MachineFuelConsumptionResult {
  final double hoursRun;
  final double fuelConsumedLiters;
  final double burnRateLPerHr;
  final String formattedHours;
  final String formattedFuel;

  const MachineFuelConsumptionResult({
    required this.hoursRun,
    required this.fuelConsumedLiters,
    required this.burnRateLPerHr,
    required this.formattedHours,
    required this.formattedFuel,
  });

  @override
  String toString() => 'MachineFuelConsumptionResult($formattedFuel consumed over $formattedHours)';
}

@immutable
class BackupHoursResult {
  final int backupHoursRemaining;
  final double currentReserveLiters;
  final double burnRateLPerHr;
  final bool isLowFuelWarning;
  final String formatted;

  const BackupHoursResult({
    required this.backupHoursRemaining,
    required this.currentReserveLiters,
    required this.burnRateLPerHr,
    required this.isLowFuelWarning,
    required this.formatted,
  });

  @override
  String toString() => 'BackupHoursResult($formatted, Low Warning: $isLowFuelWarning)';
}

class FuelEfficiencyCalculator {
  const FuelEfficiencyCalculator();

  /// Calculates fuel burned from machine run-hours:
  /// Fuel Burned (L) = Hours Run * Burn Rate (L/hr)
  static MachineFuelConsumptionResult calculateConsumption({
    required double hoursRun,
    required double burnRateLPerHr,
  }) {
    if (hoursRun <= 0) {
      throw ArgumentError('Hours run must be greater than zero.');
    }
    if (burnRateLPerHr <= 0) {
      throw ArgumentError('Fuel burn rate must be greater than zero.');
    }

    final liters = hoursRun * burnRateLPerHr;
    final roundedLiters = double.parse(liters.toStringAsFixed(1));

    return MachineFuelConsumptionResult(
      hoursRun: hoursRun,
      fuelConsumedLiters: roundedLiters,
      burnRateLPerHr: burnRateLPerHr,
      formattedHours: '${hoursRun.toStringAsFixed(1)} hrs',
      formattedFuel: '${roundedLiters.toStringAsFixed(1)} L',
    );
  }

  /// Forecasts remaining backup emergency hours from fuel reserves:
  /// Backup Hours = Floor(Reserve Liters / Burn Rate (L/hr))
  /// Low Warning if < 24 hours.
  static BackupHoursResult calculateBackupHours({
    required double currentReserveLiters,
    required double burnRateLPerHr,
  }) {
    if (burnRateLPerHr <= 0) {
      throw ArgumentError('Burn rate must be greater than zero.');
    }

    final hours = (currentReserveLiters / burnRateLPerHr).floor();
    final isLow = hours < 24;

    return BackupHoursResult(
      backupHoursRemaining: hours,
      currentReserveLiters: currentReserveLiters,
      burnRateLPerHr: burnRateLPerHr,
      isLowFuelWarning: isLow,
      formatted: '~$hours hours backup remaining',
    );
  }

  /// Apportions total farm energy cost (diesel + electricity) across ponds
  /// based on each pond's aerator horsepower-hours:
  /// Pond Cost = Total Farm Energy Cost * (Pond Aerator HP / Total Farm Aerator HP)
  static double allocatePondEnergyCost({
    required double totalFarmEnergyExpense,
    required double pondAeratorHp,
    required double totalFarmAeratorHp,
  }) {
    if (totalFarmAeratorHp <= 0) return 0.0;
    final allocated = totalFarmEnergyExpense * (pondAeratorHp / totalFarmAeratorHp);
    return double.parse(allocated.toStringAsFixed(2));
  }
}
