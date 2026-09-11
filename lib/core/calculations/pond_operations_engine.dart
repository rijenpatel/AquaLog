import '../database/app_database.dart';

class PondVolumeMetrics {
  final double pondAreaSqMeters;
  final double waterDepthMeters;
  final double totalPondCapacityLiters;
  final double totalPondCapacityM3;

  const PondVolumeMetrics({
    required this.pondAreaSqMeters,
    required this.waterDepthMeters,
    required this.totalPondCapacityLiters,
    required this.totalPondCapacityM3,
  });
}

class OperationImpactAnalysis {
  final PondOperation operation;
  final double? preAmmonia;
  final double? postAmmonia;
  final double? ammoniaReductionPct;
  final double? prePh;
  final double? postPh;
  final double? preDo;
  final double? postDo;
  final String narrative;

  const OperationImpactAnalysis({
    required this.operation,
    this.preAmmonia,
    this.postAmmonia,
    this.ammoniaReductionPct,
    this.prePh,
    this.postPh,
    this.preDo,
    this.postDo,
    required this.narrative,
  });
}

class PondOperationsEngine {
  /// Computes the total physical water volume of the pond based on dimensions
  static PondVolumeMetrics calculatePondCapacity(Pond pond) {
    final area = pond.areaSqMeters;
    final depth = pond.waterDepthMeters > 0 ? pond.waterDepthMeters : 1.2;
    final m3 = area * depth;
    final liters = m3 * 1000.0;

    return PondVolumeMetrics(
      pondAreaSqMeters: area,
      waterDepthMeters: depth,
      totalPondCapacityM3: m3,
      totalPondCapacityLiters: liters,
    );
  }

  /// Calculates volume in liters from a percentage of pond capacity
  static double calculateLitersFromPercentage(Pond pond, double percentage) {
    final metrics = calculatePondCapacity(pond);
    return double.parse(((metrics.totalPondCapacityLiters * percentage) / 100.0).toStringAsFixed(1));
  }

  /// Calculates exchange percentage from volume in liters
  static double calculatePercentageFromLiters(Pond pond, double volumeLiters) {
    final metrics = calculatePondCapacity(pond);
    if (metrics.totalPondCapacityLiters <= 0) return 0.0;
    return double.parse(((volumeLiters / metrics.totalPondCapacityLiters) * 100.0).toStringAsFixed(1));
  }

  /// Evaluates the impact of a water exchange operation against pre/post WQ logs
  static OperationImpactAnalysis analyzeExchangeImpact({
    required PondOperation operation,
    required List<WaterQualityLog> wqLogs,
  }) {
    final sorted = List<WaterQualityLog>.from(wqLogs)..sort((a, b) => a.date.compareTo(b.date));

    WaterQualityLog? preLog;
    WaterQualityLog? postLog;

    for (final l in sorted) {
      if (l.date.isBefore(operation.date)) {
        preLog = l;
      } else if (l.date.isAfter(operation.date) && postLog == null) {
        postLog = l;
      }
    }

    double? preA = preLog?.ammonia;
    double? postA = postLog?.ammonia;
    double? nh3Red;
    if (preA != null && postA != null && preA > 0) {
      nh3Red = double.parse((((preA - postA) / preA) * 100.0).toStringAsFixed(1));
    }

    String narrative = 'Operation recorded: ${operation.operationType} of ${operation.volumeLiters.toStringAsFixed(0)} L (${operation.percentageExchanged?.toStringAsFixed(1) ?? "N/A"}%).';
    if (nh3Red != null) {
      if (nh3Red > 0) {
        narrative += ' Ammonia reduced by $nh3Red% post-exchange (from $preA to $postA mg/L).';
      } else {
        narrative += ' Ammonia changed from $preA to $postA mg/L post-exchange.';
      }
    }

    return OperationImpactAnalysis(
      operation: operation,
      preAmmonia: preA,
      postAmmonia: postA,
      ammoniaReductionPct: nh3Red,
      prePh: preLog?.ph,
      postPh: postLog?.ph,
      preDo: preLog?.dissolvedOxygen,
      postDo: postLog?.dissolvedOxygen,
      narrative: narrative,
    );
  }
}
