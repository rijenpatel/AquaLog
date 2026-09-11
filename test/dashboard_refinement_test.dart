import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqualog/core/calculations/sampling_calculator.dart';
import 'package:aqualog/core/localization/translations.dart';

void main() {
  group('Dashboard Refinement - Sampling 10-Day Cycle Logic', () {
    test('1. First 7 days after sampling (<7 days elapsed) shows Up To Date', () {
      final sampleDate = DateTime(2026, 9, 1);
      final today = DateTime(2026, 9, 5); // 4 days elapsed

      final schedule = SamplingCalculator.calculateSchedule(
        batchStatus: 'active',
        stockingDate: DateTime(2026, 8, 1),
        latestSamplingDate: sampleDate,
        today: today,
      );

      expect(schedule.state, SamplingScheduleState.upToDate);
      expect(schedule.daysSinceLatestSample, 4);
      expect(schedule.daysUntilNextSample, 6);
      expect(schedule.isWarning, isFalse);
      expect(schedule.statusLabel, 'Sampling Up To Date');
      expect(schedule.detailLabel, 'Sampled 1 Sep');
    });

    test('2. 7 to 9 days after sampling shows "Next sampling coming" with calculated due date', () {
      final sampleDate = DateTime(2026, 9, 1);
      final today = DateTime(2026, 9, 8); // 7 days elapsed -> Next sampling coming

      final schedule = SamplingCalculator.calculateSchedule(
        batchStatus: 'active',
        stockingDate: DateTime(2026, 8, 1),
        latestSamplingDate: sampleDate,
        today: today,
      );

      expect(schedule.state, SamplingScheduleState.approaching);
      expect(schedule.daysSinceLatestSample, 7);
      expect(schedule.daysUntilNextSample, 3);
      expect(schedule.nextSampleDate, DateTime(2026, 9, 11));
      expect(schedule.statusLabel, 'Next sampling coming');
      expect(schedule.detailLabel, 'Due 11 Sep');
      expect(schedule.isWarning, isFalse);
    });

    test('3. Exactly 10 days after sampling shows "Sampling Due Today"', () {
      final sampleDate = DateTime(2026, 9, 1);
      final today = DateTime(2026, 9, 11); // 10 days elapsed -> Due today

      final schedule = SamplingCalculator.calculateSchedule(
        batchStatus: 'active',
        stockingDate: DateTime(2026, 8, 1),
        latestSamplingDate: sampleDate,
        today: today,
      );

      expect(schedule.state, SamplingScheduleState.due);
      expect(schedule.daysSinceLatestSample, 10);
      expect(schedule.daysUntilNextSample, 0);
      expect(schedule.statusLabel, 'Sampling Due Today');
      expect(schedule.detailLabel, 'Due 11 Sep');
      expect(schedule.isWarning, isTrue);
    });

    test('4. More than 10 days after sampling shows "Sampling Overdue"', () {
      final sampleDate = DateTime(2026, 9, 1);
      final today = DateTime(2026, 9, 14); // 13 days elapsed -> 3 days overdue

      final schedule = SamplingCalculator.calculateSchedule(
        batchStatus: 'active',
        stockingDate: DateTime(2026, 8, 1),
        latestSamplingDate: sampleDate,
        today: today,
      );

      expect(schedule.state, SamplingScheduleState.overdue);
      expect(schedule.daysSinceLatestSample, 13);
      expect(schedule.daysUntilNextSample, -3);
      expect(schedule.statusLabel, 'Sampling Overdue');
      expect(schedule.detailLabel, '3d overdue');
      expect(schedule.isWarning, isTrue);
    });

    test('5. Handles month and year boundary correctly', () {
      // 28 Dec 2026 + 10 days = 7 Jan 2027
      final sampleDate = DateTime(2026, 12, 28);
      final today = DateTime(2027, 1, 5); // 8 days elapsed (in new year)

      final schedule = SamplingCalculator.calculateSchedule(
        batchStatus: 'active',
        stockingDate: DateTime(2026, 11, 1),
        latestSamplingDate: sampleDate,
        today: today,
      );

      expect(schedule.state, SamplingScheduleState.approaching);
      expect(schedule.nextSampleDate, DateTime(2027, 1, 7));
      expect(schedule.daysSinceLatestSample, 8);
      expect(schedule.daysUntilNextSample, 2);
      expect(schedule.detailLabel, 'Due 7 Jan');
    });

    test('6. First-time batch without sample logs starts at DOC 50 baseline', () {
      // Stocked 2026-09-01, today is DOC 45 (2026-10-15) -> Approaching
      final stockingDate = DateTime(2026, 9, 1);
      final todayDoc45 = DateTime(2026, 10, 15);

      final schedule = SamplingCalculator.calculateSchedule(
        batchStatus: 'active',
        stockingDate: stockingDate,
        latestSamplingDate: null,
        today: todayDoc45,
      );

      expect(schedule.state, SamplingScheduleState.approaching);
      expect(schedule.statusLabel, 'Next sampling coming');
      expect(schedule.nextSampleDate, DateTime(2026, 10, 20)); // DOC 50
    });
  });

  group('Dashboard Refinement - Localization and Labels', () {
    test('Today total feed label is exact', () {
      expect(AppStrings.get('todays_feed', 'en'), "Today's Total Feed");
      expect(AppStrings.get('todays_feed', 'hi'), "आज का कुल दाना");
    });

    test('KPI and operational translation keys exist', () {
      expect(AppStrings.get('pond_occupancy', 'en'), 'Pond Occupancy');
      expect(AppStrings.get('action_center', 'en'), 'Action Center');
      expect(AppStrings.get('happa_updated', 'en'), 'Happa Updated');
      expect(AppStrings.get('happa_pending', 'en'), 'Happa Check Pending');
      expect(AppStrings.get('next_sampling_coming', 'en'), 'Next sampling coming');
      expect(AppStrings.get('sampling_due_today', 'en'), 'Sampling Due Today');
      expect(AppStrings.get('sampling_overdue', 'en'), 'Sampling Overdue');
    });
  });

  group('Dashboard Refinement - Biomass Calculations', () {
    test('Calculates biomass in kg correctly from stocked count, survival, and ABW', () {
      // 100,000 stocked, 85% survival = 85,000 shrimp
      // ABW 20.0 grams = 85,000 * 20 / 1000 = 1,700 kg
      final biomassKg = SamplingCalculator.calculateBiomass(
        stockedShrimp: 100000,
        hapaSurvivalPct: 85.0,
        abwGrams: 20.0,
      );

      expect(biomassKg, 1700.0);
    });

    test('Returns null when parameters are invalid', () {
      expect(
        SamplingCalculator.calculateBiomass(stockedShrimp: 0, hapaSurvivalPct: 85.0, abwGrams: 20.0),
        isNull,
      );
      expect(
        SamplingCalculator.calculateBiomass(stockedShrimp: 10000, hapaSurvivalPct: 0.0, abwGrams: 20.0),
        isNull,
      );
      expect(
        SamplingCalculator.calculateBiomass(stockedShrimp: 10000, hapaSurvivalPct: 85.0, abwGrams: -1.0),
        isNull,
      );
    });
  });
}
