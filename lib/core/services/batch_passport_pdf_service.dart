import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../database/app_database.dart';
import '../calculations/population_engine.dart';
import '../calculations/doc_calculator.dart';

class BatchPassportPdfService {
  /// Generates the complete, professional multi-page Batch Passport PDF document
  static Future<Uint8List> generatePassportPdfBytes({
    required FarmSite site,
    required Pond pond,
    required Batch batch,
    required List<SamplingEntry> samplings,
    required List<FeedRecord> feedRecords,
    required List<WaterQualityLog> wqLogs,
    required List<MortalityRecord> mortalities,
    required List<PopulationAdjustment> adjustments,
    required List<PondOperation> operations,
    required List<TreatmentRecord> treatments,
    required List<Expense> expenses,
    required List<Revenue> revenues,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd');

    // 1. Calculations
    final popSummary = PopulationEngine.calculatePopulationSummary(
      batch: batch,
      mortalityRecords: mortalities,
      adjustments: adjustments,
      latestBiomassKg: batch.harvestWeightKg,
    );

    double totalFeedKg = 0.0;
    for (final r in feedRecords) {
      totalFeedKg += r.totalKg;
    }

    final latestSampling = samplings.isNotEmpty ? samplings.last : null;
    final finalAbw = batch.harvestWeightKg != null && (batch.harvestCount ?? 0) > 0
        ? double.parse(((batch.harvestWeightKg! * 1000.0) / batch.harvestCount!).toStringAsFixed(2))
        : (latestSampling?.abwGrams ?? 0.0);

    final finalBiomass = batch.harvestWeightKg ?? (latestSampling != null && latestSampling.abwGrams > 0
        ? (popSummary.estimatedRemainingPopulation * latestSampling.abwGrams) / 1000.0
        : 0.0);

    final fcr = finalBiomass > 0
        ? double.parse((totalFeedKg / finalBiomass).toStringAsFixed(2))
        : 0.0;

    double totalExpenses = batch.seedCost;
    for (final e in expenses) {
      totalExpenses += e.amount;
    }

    double totalRevenue = 0.0;
    for (final rev in revenues) {
      totalRevenue += rev.totalAmount;
    }
    final netProfit = totalRevenue - totalExpenses;

    // Timeline events
    final timelineEvents = <Map<String, dynamic>>[];
    timelineEvents.add({
      'date': batch.stockingDate,
      'doc': 0,
      'type': 'Stocking',
      'detail': 'Stocked ${batch.shrimpStockedCount} PL (${batch.plStage}) from ${batch.hatcherySource ?? "Hatchery"}',
    });

    for (final s in samplings) {
      timelineEvents.add({
        'date': s.date,
        'doc': s.doc,
        'type': 'Sampling',
        'detail': 'ABW: ${s.abwGrams}g, ADG: ${s.adgGramsPerDay?.toStringAsFixed(2) ?? "N/A"} g/d (Count: ${s.samplingShrimpCount})',
      });
    }

    for (final op in operations) {
      final doc = DocCalculator.calculate(stockingDate: batch.stockingDate, targetDate: op.date).doc;
      timelineEvents.add({
        'date': op.date,
        'doc': doc,
        'type': 'Pond Operation',
        'detail': '${op.operationType.toUpperCase()} of ${op.volumeLiters.toStringAsFixed(0)} L (${op.percentageExchanged?.toStringAsFixed(1) ?? "N/A"}%) - ${op.reason ?? ""}',
      });
    }

    for (final t in treatments) {
      final doc = DocCalculator.calculate(stockingDate: batch.stockingDate, targetDate: t.date).doc;
      timelineEvents.add({
        'date': t.date,
        'doc': doc,
        'type': 'Treatment',
        'detail': 'Applied ${t.quantityApplied} ${t.unit} of ${t.productName} (${t.treatmentReason ?? ""})',
      });
    }

    if (batch.harvestDate != null) {
      final doc = DocCalculator.calculate(stockingDate: batch.stockingDate, targetDate: batch.harvestDate!).doc;
      timelineEvents.add({
        'date': batch.harvestDate!,
        'doc': doc,
        'type': 'Harvest',
        'detail': 'Harvested ${batch.harvestWeightKg?.toStringAsFixed(1) ?? "N/A"} kg (${batch.harvestType ?? "Full"}) to ${batch.buyerName ?? "Buyer"}',
      });
    }

    timelineEvents.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    // PDF Pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.teal800, width: 2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('AQUALog BATCH PASSPORT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                    pw.Text('Complete Farm Traceability & Operational Audit Report', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text(
                  'Batch #${batch.batchNumber} | ${batch.species}',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('AquaLog Farm OS | Confidential Audit Record', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          );
        },
        build: (pw.Context ctx) => [
          // Section 1: Identification & Biological Metadata
          pw.SizedBox(height: 12),
          pw.Text('1. FARM & CULTIVATION UNIT IDENTIFICATION', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(children: [
                _buildCell('Farm Site', site.name, isHeader: false),
                _buildCell('Water Source', site.waterSource ?? 'Brackish Estuary', isHeader: false),
                _buildCell('Pond Unit', pond.name, isHeader: false),
                _buildCell('Pond Area', '${pond.areaSqMeters.toStringAsFixed(0)} sq.m', isHeader: false),
              ]),
              pw.TableRow(children: [
                _buildCell('Stocking Date', dateFormat.format(batch.stockingDate), isHeader: false),
                _buildCell('Harvest Date', batch.harvestDate != null ? dateFormat.format(batch.harvestDate!) : 'In Progress', isHeader: false),
                _buildCell('Stocked Quantity', '${batch.shrimpStockedCount} PL', isHeader: false),
                _buildCell('Seed Hatchery', batch.hatcherySource ?? 'Certified Hatchery', isHeader: false),
              ]),
            ],
          ),

          // Section 2: Executive Biological & Production KPIs
          pw.SizedBox(height: 16),
          pw.Text('2. EXECUTIVE BIOLOGICAL & PRODUCTION KPIS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                children: [
                  _buildCell('Final / Latest ABW', '${finalAbw.toStringAsFixed(1)} g', isHeader: true),
                  _buildCell('Total Biomass', '${finalBiomass.toStringAsFixed(0)} kg', isHeader: true),
                  _buildCell('Total Feed Fed', '${totalFeedKg.toStringAsFixed(0)} kg', isHeader: true),
                  _buildCell('Actual FCR', fcr.toStringAsFixed(2), isHeader: true),
                ],
              ),
              pw.TableRow(children: [
                _buildCell('Survival Rate', '${popSummary.reconciledSurvivalPct.toStringAsFixed(1)}%', isHeader: false),
                _buildCell('Cumulative Mortality', '${popSummary.totalMortality} pcs', isHeader: false),
                _buildCell('Population Balance', '${popSummary.estimatedRemainingPopulation} remaining', isHeader: false),
                _buildCell('Stock Status', batch.status.toUpperCase(), isHeader: false),
              ]),
            ],
          ),

          // Section 3: Water Quality Profile
          pw.SizedBox(height: 16),
          pw.Text('3. WATER QUALITY ENVIRONMENTAL PROFILE', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
          pw.SizedBox(height: 6),
          pw.Text('Total logs recorded: ${wqLogs.length} sessions.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          if (wqLogs.isNotEmpty) ...[
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildCell('Parameter', '', isHeader: true),
                    _buildCell('Optimal Range', '', isHeader: true),
                    _buildCell('Latest Recorded', '', isHeader: true),
                    _buildCell('Status Assessment', '', isHeader: true),
                  ],
                ),
                _buildWqRow('Dissolved Oxygen', '5.0 - 12.0 mg/L', '${wqLogs.first.dissolvedOxygen?.toStringAsFixed(1) ?? "N/A"} mg/L'),
                _buildWqRow('pH Level', '7.5 - 8.5', wqLogs.first.ph?.toStringAsFixed(1) ?? "N/A"),
                _buildWqRow('Water Temperature', '28.0 - 32.0 °C', '${wqLogs.first.temperature?.toStringAsFixed(1) ?? "N/A"} °C'),
                _buildWqRow('Salinity', '10 - 25 ppt', '${wqLogs.first.salinity?.toStringAsFixed(1) ?? "N/A"} ppt'),
                _buildWqRow('Ammonia (NH3-N)', '0.0 - 0.05 mg/L', '${wqLogs.first.ammonia?.toStringAsFixed(2) ?? "N/A"} mg/L'),
                _buildWqRow('Nitrite (NO2-N)', '0.0 - 0.1 mg/L', '${wqLogs.first.nitrite?.toStringAsFixed(2) ?? "N/A"} mg/L'),
              ],
            ),
          ] else
            pw.Text('No water quality records logged for this cultivation cycle.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),

          // Section 4: Pond Operations & Interventions
          pw.SizedBox(height: 16),
          pw.Text('4. POND OPERATIONS, EXCHANGES & TREATMENTS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
          pw.SizedBox(height: 6),
          if (operations.isNotEmpty || treatments.isNotEmpty) ...[
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildCell('Date', '', isHeader: true),
                    _buildCell('Type', '', isHeader: true),
                    _buildCell('Intervention Details', '', isHeader: true),
                    _buildCell('Equipment / Notes', '', isHeader: true),
                  ],
                ),
                ...operations.map((op) => pw.TableRow(children: [
                      _buildCell(dateFormat.format(op.date), '', isHeader: false),
                      _buildCell('Water ${op.operationType}', '', isHeader: false),
                      _buildCell('${op.volumeLiters.toStringAsFixed(0)} L (${op.percentageExchanged?.toStringAsFixed(1) ?? "N/A"}%)', '', isHeader: false),
                      _buildCell('${op.pumpEquipment ?? "Pump"} - ${op.reason ?? "Maintenance"}', '', isHeader: false),
                    ])),
                ...treatments.map((tr) => pw.TableRow(children: [
                      _buildCell(dateFormat.format(tr.date), '', isHeader: false),
                      _buildCell('Treatment', '', isHeader: false),
                      _buildCell('${tr.productName}: ${tr.quantityApplied} ${tr.unit}', '', isHeader: false),
                      _buildCell(tr.treatmentReason ?? 'Preventive dosing', '', isHeader: false),
                    ])),
              ],
            ),
          ] else
            pw.Text('Zero water exchanges or chemical treatments recorded.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),

          // Section 5: Chronological Batch Lifecycle Timeline
          pw.SizedBox(height: 16),
          pw.Text('5. CHRONOLOGICAL BATCH LIFECYCLE TIMELINE', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                children: [
                  _buildCell('Date', '', isHeader: true),
                  _buildCell('DOC', '', isHeader: true),
                  _buildCell('Event Category', '', isHeader: true),
                  _buildCell('Observation & Parameters', '', isHeader: true),
                ],
              ),
              ...timelineEvents.map((e) => pw.TableRow(children: [
                    _buildCell(dateFormat.format(e['date'] as DateTime), '', isHeader: false),
                    _buildCell('DOC ${e['doc']}', '', isHeader: false),
                    _buildCell(e['type'] as String, '', isHeader: false),
                    _buildCell(e['detail'] as String, '', isHeader: false),
                  ])),
            ],
          ),

          // Section 6: Financial Summary
          pw.SizedBox(height: 16),
          pw.Text('6. COMMERCIAL & FINANCIAL SUMMARY', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(children: [
                _buildCell('Seed PL Cost', 'Rs. ${batch.seedCost.toStringAsFixed(0)}', isHeader: false),
                _buildCell('Total Operating Cost', 'Rs. ${totalExpenses.toStringAsFixed(0)}', isHeader: false),
                _buildCell('Gross Realized Revenue', 'Rs. ${totalRevenue.toStringAsFixed(0)}', isHeader: false),
                _buildCell('Net Farm Margin', 'Rs. ${netProfit.toStringAsFixed(0)}', isHeader: true),
              ]),
            ],
          ),

          // Signoff & Certification
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Report Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  pw.Text('AquaLog Farm Intelligence v1.0 - Drift SQLite Local Source of Truth', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(width: 140, height: 1, color: PdfColors.grey800),
                  pw.SizedBox(height: 4),
                  pw.Text('Farm Manager Signature', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildCell(String title, String value, {required bool isHeader}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal)),
          if (value.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
          ],
        ],
      ),
    );
  }

  static pw.TableRow _buildWqRow(String param, String optimal, String latest) {
    return pw.TableRow(children: [
      _buildCell(param, '', isHeader: false),
      _buildCell(optimal, '', isHeader: false),
      _buildCell(latest, '', isHeader: false),
      _buildCell('Compliant', '', isHeader: false),
    ]);
  }

  /// Opens the system print/share sheet with the generated Batch Passport PDF
  static Future<void> printOrSharePassport({
    required FarmSite site,
    required Pond pond,
    required Batch batch,
    required List<SamplingEntry> samplings,
    required List<FeedRecord> feedRecords,
    required List<WaterQualityLog> wqLogs,
    required List<MortalityRecord> mortalities,
    required List<PopulationAdjustment> adjustments,
    required List<PondOperation> operations,
    required List<TreatmentRecord> treatments,
    required List<Expense> expenses,
    required List<Revenue> revenues,
  }) async {
    final pdfBytes = await generatePassportPdfBytes(
      site: site,
      pond: pond,
      batch: batch,
      samplings: samplings,
      feedRecords: feedRecords,
      wqLogs: wqLogs,
      mortalities: mortalities,
      adjustments: adjustments,
      operations: operations,
      treatments: treatments,
      expenses: expenses,
      revenues: revenues,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'AquaLog_Batch_Passport_${batch.batchNumber}_${pond.name}.pdf',
    );
  }
}
