import 'package:flutter/foundation.dart';

enum LifecycleStage {
  nursery('Nursery', '🌱', 'DOC 0–25', 0, 25),
  growoutEarly('Growout Early', '🌿', 'DOC 26–60', 26, 60),
  growoutMid('Growout Mid', '🐟', 'DOC 61–90', 61, 90),
  finishing('Finishing', '⚖️', 'DOC 91–120', 91, 120),
  harvestReady('Harvest Ready', '🎯', 'DOC 121+', 121, 9999);

  final String label;
  final String icon;
  final String docRange;
  final int minDoc;
  final int maxDoc;

  const LifecycleStage(
    this.label,
    this.icon,
    this.docRange,
    this.minDoc,
    this.maxDoc,
  );
}

@immutable
class DocResult {
  final int doc;
  final bool isFutureDate;
  final String? warning;
  final LifecycleStage stage;

  const DocResult({
    required this.doc,
    required this.isFutureDate,
    this.warning,
    required this.stage,
  });

  @override
  String toString() => 'DocResult(doc: $doc, stage: ${stage.label}, isFutureDate: $isFutureDate)';
}

class DocCalculator {
  const DocCalculator();

  /// Calculates Days of Culture (DOC) from stocking date to current/target date.
  /// Dates are normalized to start-of-day (midnight).
  /// If stocking date == target date: DOC = 1.
  /// If stocking date is in the future: DOC = 1 with a warning.
  static DocResult calculate({
    required DateTime stockingDate,
    DateTime? targetDate,
  }) {
    final now = targetDate ?? DateTime.now();
    final stockingMidnight = DateTime(stockingDate.year, stockingDate.month, stockingDate.day);
    final targetMidnight = DateTime(now.year, now.month, now.day);

    if (stockingMidnight.isAfter(targetMidnight)) {
      return const DocResult(
        doc: 1,
        isFutureDate: true,
        warning: 'Stocking date is set in the future. DOC initialized to 1.',
        stage: LifecycleStage.nursery,
      );
    }

    final diffMs = targetMidnight.difference(stockingMidnight).inMilliseconds;
    final doc = (diffMs / 86400000).floor() + 1;
    final stage = getLifecycleStage(doc);

    return DocResult(
      doc: doc,
      isFutureDate: false,
      stage: stage,
    );
  }

  static LifecycleStage getLifecycleStage(int doc) {
    if (doc <= 25) return LifecycleStage.nursery;
    if (doc <= 60) return LifecycleStage.growoutEarly;
    if (doc <= 90) return LifecycleStage.growoutMid;
    if (doc <= 120) return LifecycleStage.finishing;
    return LifecycleStage.harvestReady;
  }
}
