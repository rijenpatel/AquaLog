class HarvestScenario {
  final int daysFromNow;
  final String label;
  final double projectedAbwGrams;
  final double projectedCountPerKg;
  final int projectedPopulation;
  final double projectedBiomassKg;
  final double additionalFeedKg;
  final double additionalCost;
  final double projectedMarketPricePerKg;
  final double projectedRevenue;
  final double projectedTotalCost;
  final double projectedNetProfit;
  final double projectedMarginPct;
  final bool isRecommended;

  const HarvestScenario({
    required this.daysFromNow,
    required this.label,
    required this.projectedAbwGrams,
    required this.projectedCountPerKg,
    required this.projectedPopulation,
    required this.projectedBiomassKg,
    required this.additionalFeedKg,
    required this.additionalCost,
    required this.projectedMarketPricePerKg,
    required this.projectedRevenue,
    required this.projectedTotalCost,
    required this.projectedNetProfit,
    required this.projectedMarginPct,
    required this.isRecommended,
  });
}

class HarvestDecisionReport {
  final int currentDoc;
  final double currentAbwGrams;
  final double currentBiomassKg;
  final double targetHarvestWeightG;
  final List<HarvestScenario> scenarios;
  final int bestScenarioIndex;
  final String decisionExplanation;
  final String biologicalReadiness;  // 'Optimal', 'Approaching Target', 'Early Stage'
  final String marketReadiness;      // 'Favorable', 'Moderate', 'Soft'
  final String inventoryReadiness;   // 'Sufficient Feed', 'Low Buffer'
  final String operationalReadiness;  // 'Ready', 'Pending Buyer/Net'

  const HarvestDecisionReport({
    required this.currentDoc,
    required this.currentAbwGrams,
    required this.currentBiomassKg,
    required this.targetHarvestWeightG,
    required this.scenarios,
    required this.bestScenarioIndex,
    required this.decisionExplanation,
    required this.biologicalReadiness,
    required this.marketReadiness,
    required this.inventoryReadiness,
    required this.operationalReadiness,
  });
}

class HarvestDecisionEngine {
  /// Estimates shrimp price per kg based on size count per kg:
  /// Standard commercial slab table:
  /// 30 count (~33.3g) -> ~₹460/kg
  /// 40 count (~25.0g) -> ~₹390/kg
  /// 50 count (~20.0g) -> ~₹340/kg
  /// 60 count (~16.6g) -> ~₹290/kg
  /// 80 count (~12.5g) -> ~₹240/kg
  /// 100 count (~10.0g) -> ~₹190/kg
  static double getMarketPriceForAbw(double abwGrams, {double? priceOverride}) {
    if (priceOverride != null && priceOverride > 0) return priceOverride;
    if (abwGrams >= 33.0) return 460.0;
    if (abwGrams >= 28.0) return 420.0;
    if (abwGrams >= 24.0) return 390.0;
    if (abwGrams >= 20.0) return 350.0;
    if (abwGrams >= 16.0) return 295.0;
    if (abwGrams >= 13.0) return 250.0;
    return 200.0;
  }

  /// Evaluates 3 economic harvest scenarios: Harvest Now, +7 Days, +14 Days
  static HarvestDecisionReport evaluateScenarios({
    required int currentDoc,
    required double currentAbwGrams,
    required int currentPopulation,
    required double currentBiomassKg,
    required double historicalExpenses,
    required double targetWeightGrams,
    double? currentAdgGramsPerDay,
    double? feedCostPerKg,
    double? currentMarketPriceOverride,
    double? feedStockRemainingKg,
  }) {
    final adg = (currentAdgGramsPerDay != null && currentAdgGramsPerDay > 0)
        ? currentAdgGramsPerDay
        : 0.22;
    final feedPrice = feedCostPerKg ?? 95.0;
    const assumedFcr = 1.45;
    const dailyMortalityRate = 0.001; // 0.1% daily background mortality

    final daysList = [0, 7, 14];
    final scenarios = <HarvestScenario>[];

    for (final days in daysList) {
      // 1. Projected ABW with slight biological deceleration at higher sizes (>22g)
      double effectiveAdg = adg;
      if (currentAbwGrams > 22.0) {
        effectiveAdg = adg * 0.88; // Growth decelerates as shrimp approach market size
      }
      final projectedAbw = double.parse((currentAbwGrams + (effectiveAdg * days)).toStringAsFixed(2));
      final countPerKg = projectedAbw > 0 ? double.parse((1000.0 / projectedAbw).toStringAsFixed(1)) : 0.0;

      // 2. Projected Population
      final popMultiplier = (1.0 - (dailyMortalityRate * days)).clamp(0.85, 1.0);
      final projectedPop = (currentPopulation * popMultiplier).round();

      // 3. Projected Biomass
      final projectedBiomass = double.parse(((projectedPop * projectedAbw) / 1000.0).toStringAsFixed(1));

      // 4. Additional Feed Required
      final biomassGain = (projectedBiomass - currentBiomassKg).clamp(0.0, 999999.0);
      final addlFeed = double.parse((biomassGain * assumedFcr).toStringAsFixed(1));
      final addlCost = double.parse((addlFeed * feedPrice + (days * 150.0)).toStringAsFixed(2)); // Feed + electricity/labor

      // 5. Market Price & Revenue
      final pricePerKg = getMarketPriceForAbw(projectedAbw, priceOverride: currentMarketPriceOverride);
      final projectedRevenue = double.parse((projectedBiomass * pricePerKg).toStringAsFixed(2));

      // 6. Net Profit & Margin
      final totalCost = double.parse((historicalExpenses + addlCost).toStringAsFixed(2));
      final netProfit = double.parse((projectedRevenue - totalCost).toStringAsFixed(2));
      final marginPct = projectedRevenue > 0
          ? double.parse(((netProfit / projectedRevenue) * 100.0).toStringAsFixed(1))
          : 0.0;

      scenarios.add(HarvestScenario(
        daysFromNow: days,
        label: days == 0 ? 'Harvest Now' : (days == 7 ? '+7 Days' : '+14 Days'),
        projectedAbwGrams: projectedAbw,
        projectedCountPerKg: countPerKg,
        projectedPopulation: projectedPop,
        projectedBiomassKg: projectedBiomass,
        additionalFeedKg: addlFeed,
        additionalCost: addlCost,
        projectedMarketPricePerKg: pricePerKg,
        projectedRevenue: projectedRevenue,
        projectedTotalCost: totalCost,
        projectedNetProfit: netProfit,
        projectedMarginPct: marginPct,
        isRecommended: false,
      ));
    }

    // Determine Best Economic Scenario
    int bestIdx = 0;
    double maxProfit = scenarios.first.projectedNetProfit;

    for (int i = 0; i < scenarios.length; i++) {
      if (scenarios[i].projectedNetProfit > maxProfit) {
        maxProfit = scenarios[i].projectedNetProfit;
        bestIdx = i;
      }
    }

    // Rebuild scenarios with isRecommended set
    final evaluatedScenarios = <HarvestScenario>[];
    for (int i = 0; i < scenarios.length; i++) {
      final s = scenarios[i];
      evaluatedScenarios.add(HarvestScenario(
        daysFromNow: s.daysFromNow,
        label: s.label,
        projectedAbwGrams: s.projectedAbwGrams,
        projectedCountPerKg: s.projectedCountPerKg,
        projectedPopulation: s.projectedPopulation,
        projectedBiomassKg: s.projectedBiomassKg,
        additionalFeedKg: s.additionalFeedKg,
        additionalCost: s.additionalCost,
        projectedMarketPricePerKg: s.projectedMarketPricePerKg,
        projectedRevenue: s.projectedRevenue,
        projectedTotalCost: s.projectedTotalCost,
        projectedNetProfit: s.projectedNetProfit,
        projectedMarginPct: s.projectedMarginPct,
        isRecommended: i == bestIdx,
      ));
    }

    final best = evaluatedScenarios[bestIdx];
    String explanation;
    if (bestIdx == 0) {
      explanation = 'Harvesting now locks in current margins. Growth deceleration or upcoming feed costs outweigh potential price-slab gains.';
    } else if (bestIdx == 1) {
      explanation = 'Harvest in 7 days offers maximum economic efficiency: Projected size jump to ${best.projectedAbwGrams}g (${best.projectedCountPerKg.toStringAsFixed(0)} count) captures a higher market price slab while keeping additional feed costs modest.';
    } else {
      explanation = 'Harvest in 14 days yields peak net margin: Strong ADG continues to generate surplus biomass value faster than feed expenditure.';
    }

    // Readiness
    String bioReady = 'Optimal';
    if (currentAbwGrams < targetWeightGrams * 0.75) {
      bioReady = 'Early Stage';
    } else if (currentAbwGrams < targetWeightGrams) {
      bioReady = 'Approaching Target';
    }

    String invReady = 'Sufficient Feed';
    if (feedStockRemainingKg != null && feedStockRemainingKg < best.additionalFeedKg) {
      invReady = 'Low Buffer (Reorder needed for extension)';
    }

    return HarvestDecisionReport(
      currentDoc: currentDoc,
      currentAbwGrams: currentAbwGrams,
      currentBiomassKg: currentBiomassKg,
      targetHarvestWeightG: targetWeightGrams,
      scenarios: evaluatedScenarios,
      bestScenarioIndex: bestIdx,
      decisionExplanation: explanation,
      biologicalReadiness: bioReady,
      marketReadiness: 'Favorable (Grade Slab Analyzed)',
      inventoryReadiness: invReady,
      operationalReadiness: 'Ready (Check aeration & harvesting nets)',
    );
  }
}
