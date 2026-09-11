import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/weather_service.dart';
import '../../core/calculations/calculations.dart';
import '../../core/widgets/aqua_status_chip.dart';
import '../../core/providers/batch_dashboard_providers.dart';
import '../../app/theme/color_schemes.dart';
import '../sampling/sampling_dialog.dart';
import 'widgets/first_pond_user_guide.dart';
import 'widgets/first_pond_tutorial_page.dart';

class PondCreationPage extends ConsumerStatefulWidget {
  final FarmSite site;

  const PondCreationPage({super.key, required this.site});

  @override
  ConsumerState<PondCreationPage> createState() => _PondCreationPageState();
}

class _PondCreationPageState extends ConsumerState<PondCreationPage> {
  bool _isAddPondExpanded = false;
  bool _hasInitializedExpandedState = false;
  final _formKey = GlobalKey<FormState>();

  final _pondNameController = TextEditingController();
  final _areaController = TextEditingController(text: '1.25');
  final _depthController = TextEditingController(text: '1.50');
  final _aeratorsCountController = TextEditingController(text: '6');
  final _aeratorHpController = TextEditingController(text: '12.0');

  String _areaUnit = 'Acres'; // 'Acres', 'Hectares', 'm²'
  final String _operationalStatus = 'active'; // 'active', 'vacant'
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _areaController.addListener(_onFieldChanged);
    _depthController.addListener(_onFieldChanged);
    _aeratorHpController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _areaController.removeListener(_onFieldChanged);
    _depthController.removeListener(_onFieldChanged);
    _aeratorHpController.removeListener(_onFieldChanged);
    _pondNameController.dispose();
    _areaController.dispose();
    _depthController.dispose();
    _aeratorsCountController.dispose();
    _aeratorHpController.dispose();
    super.dispose();
  }

  double _calculateAreaInSqMeters() {
    final sanitized = _areaController.text.trim().replaceAll(',', '.');
    final val = double.tryParse(sanitized) ?? 0.0;
    switch (_areaUnit) {
      case 'Acres':
        return val * 4046.86;
      case 'Hectares':
        return val * 10000.0;
      case 'm²':
      default:
        return val;
    }
  }

  Future<void> _submitPond() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _pondNameController.text.trim();
    final areaSqMeters = _calculateAreaInSqMeters();
    final depthSanitized = _depthController.text.trim().replaceAll(',', '.');
    final depth = double.tryParse(depthSanitized) ?? 1.5;
    final aeratorCountRaw = int.tryParse(_aeratorsCountController.text.trim()) ?? 0;
    final aeratorCount = aeratorCountRaw < 0 ? 0 : aeratorCountRaw;
    final aeratorHpSanitized = _aeratorHpController.text.trim().replaceAll(',', '.');
    final aeratorHpRaw = double.tryParse(aeratorHpSanitized) ?? 0.0;
    final aeratorHp = aeratorHpRaw < 0.0 ? 0.0 : aeratorHpRaw;

    if (areaSqMeters <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pond surface area must be greater than zero.')),
      );
      return;
    }

    if (depth <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pond water depth must be greater than zero.')),
      );
      return;
    }

    final db = ref.read(appDatabaseProvider);
    final existingPonds = await (db.select(db.ponds)..where((tbl) => tbl.siteId.equals(widget.site.id))).get();
    if (existingPonds.any((p) => p.name.trim().toLowerCase() == name.toLowerCase())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A pond named "$name" already exists under ${widget.site.name}. Please choose a unique identifier.'),
            backgroundColor: AquaColors.statusAlert,
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final newPondId = 'pond_${DateTime.now().millisecondsSinceEpoch}';

      await db.into(db.ponds).insert(
        PondsCompanion(
          id: drift.Value(newPondId),
          siteId: drift.Value(widget.site.id),
          name: drift.Value(name),
          areaSqMeters: drift.Value(areaSqMeters),
          waterDepthMeters: drift.Value(depth),
          aeratorsCount: drift.Value(aeratorCount),
          totalAeratorHp: drift.Value(aeratorHp),
          status: drift.Value(_operationalStatus),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pond "$name" registered successfully under ${widget.site.name}.'),
            backgroundColor: const Color(0xFF006876),
          ),
        );
        setState(() {
          _isSubmitting = false;
          _isAddPondExpanded = false;
          _pondNameController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create pond: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showStockBatchDialog(Pond pond) {
    final countCtrl = TextEditingController(text: '100000');
    final hatcheryCtrl = TextEditingController(text: 'Apex Hatchery');
    final seedCostCtrl = TextEditingController(text: '40000');
    final targetWeightCtrl = TextEditingController(text: '25.0');
    final hapaCountCtrl = TextEditingController(text: '100');
    final targetDocCtrl = TextEditingController(text: '93');
    String species = 'Litopenaeus vannamei';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final count = int.tryParse(countCtrl.text) ?? 0;
          final density = count > 0 ? (count / pond.areaSqMeters).toStringAsFixed(1) : '0';

          return AlertDialog(
            title: Text('Stock Batch in ${pond.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Pond Area: ${pond.areaSqMeters.toInt()} m² · Stocking Density: $density pcs/m²',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: species,
                    decoration: const InputDecoration(labelText: 'Shrimp Species'),
                    items: const [
                      DropdownMenuItem(value: 'Litopenaeus vannamei', child: Text('L. vannamei (Pacific White)')),
                      DropdownMenuItem(value: 'Penaeus monodon', child: Text('P. monodon (Black Tiger)')),
                    ],
                    onChanged: (v) => setDialogState(() => species = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Batch Stocked Shrimp *', suffixText: 'pcs'),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hapaCountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stocked Hapa Count *',
                            suffixText: 'pcs',
                            helperText: 'Default 100 for 10-day check',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: targetDocCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Target DOC *',
                            suffixText: 'days',
                            helperText: 'Planned harvest cycle',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hatcheryCtrl,
                    decoration: const InputDecoration(labelText: 'Hatchery Source'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: seedCostCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Seed Cost (₹)', prefixText: '₹'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: targetWeightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Target Weight', suffixText: 'g'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final shrimpCount = int.tryParse(countCtrl.text) ?? 100000;
                  final hapaCount = int.tryParse(hapaCountCtrl.text) ?? 100;
                  final targetDoc = int.tryParse(targetDocCtrl.text) ?? 93;
                  final seedCost = double.tryParse(seedCostCtrl.text) ?? 0.0;
                  final targetWeight = double.tryParse(targetWeightCtrl.text) ?? 25.0;

                  final db = ref.read(appDatabaseProvider);

                  // 1-Active-Batch-Per-Pond & Period Overlap Check
                  final existingActive = await db.getActiveBatchForPond(pond.id);
                  if (existingActive != null) {
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (alertCtx) => AlertDialog(
                        icon: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
                        title: const Text('Pond Already Active'),
                        content: Text(
                          'Pond "${pond.name}" already has an active batch (#${existingActive.batchNumber}).\n\n'
                          'Please complete or harvest the current active batch before stocking a new one.',
                        ),
                        actions: [
                          FilledButton(onPressed: () => Navigator.of(alertCtx).pop(), child: const Text('OK')),
                        ],
                      ),
                    );
                    return;
                  }

                  final now = DateTime.now();
                  final overlapping = await db.checkBatchOverlap(
                    pondId: pond.id,
                    stockingDate: now,
                  );
                  if (overlapping != null) {
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (alertCtx) => AlertDialog(
                        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
                        title: const Text('Batch Period Overlap'),
                        content: Text(
                          'Cannot stock batch: A batch (#${overlapping.batchNumber}) already occupies pond "${pond.name}" for this date.',
                        ),
                        actions: [
                          FilledButton(onPressed: () => Navigator.of(alertCtx).pop(), child: const Text('OK')),
                        ],
                      ),
                    );
                    return;
                  }

                  final batchId = 'batch_${DateTime.now().millisecondsSinceEpoch}';

                  await db.into(db.batches).insert(
                    BatchesCompanion(
                      id: drift.Value(batchId),
                      pondId: drift.Value(pond.id),
                      batchNumber: const drift.Value(1),
                      species: drift.Value(species),
                      stockingDate: drift.Value(DateTime.now()),
                      shrimpStockedCount: drift.Value(shrimpCount),
                      hapaStockedCount: drift.Value(hapaCount),
                      targetDoc: drift.Value(targetDoc),
                      plStage: const drift.Value('PL-10'),
                      hatcherySource: drift.Value(hatcheryCtrl.text.trim()),
                      seedCost: drift.Value(seedCost),
                      targetHarvestWeightG: drift.Value(targetWeight),
                      status: const drift.Value('active'),
                    ),
                  );

                  if (seedCost > 0) {
                    await db.into(db.expenses).insert(
                      ExpensesCompanion(
                        id: drift.Value('exp_seed_${DateTime.now().millisecondsSinceEpoch}'),
                        batchId: drift.Value(batchId),
                        pondId: drift.Value(pond.id),
                        date: drift.Value(DateTime.now()),
                        category: const drift.Value('seed'),
                        amount: drift.Value(seedCost),
                        description: drift.Value('Seed purchase for ${pond.name}: $shrimpCount PLs'),
                      ),
                    );
                  }

                  ref.invalidate(activeBatchesStreamProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✓ Batch stocked in ${pond.name}: $shrimpCount PLs (Hapa: $hapaCount, Target DOC: $targetDoc)'),
                        backgroundColor: AquaColors.statusOptimal,
                      ),
                    );
                    Navigator.of(ctx).pop();
                  }
                },
                child: const Text('Stock Batch'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSamplingDialog(Batch batch, Pond pond) {
    SamplingDialog.show(context, batch: batch, pond: pond);
  }

  void _showHapaCheckDialog(Batch batch, Pond pond) {
    final stockedHapa = batch.hapaStockedCount > 0 ? batch.hapaStockedCount : 100;
    final aliveCtrl = TextEditingController(text: '$stockedHapa');
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final alive = int.tryParse(aliveCtrl.text.trim()) ?? 0;
          final survivalPct = stockedHapa > 0 ? ((alive / stockedHapa) * 100.0).clamp(0.0, 100.0) : 0.0;
          final estimatedActive = ((batch.shrimpStockedCount * survivalPct) / 100.0).round();

          return AlertDialog(
            title: Text('10-Day Hapa Survival Check: ${pond.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF006876).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Stocked in Hapa:'),
                            Text('$stockedHapa pcs', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Calculated Survival:'),
                            Text(
                              '${survivalPct.toStringAsFixed(1)}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF006876)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Estimated Active Population:'),
                            Text(
                              '$estimatedActive pcs',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AquaColors.statusOptimal),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Original Stocked: ${batch.shrimpStockedCount} pcs (preserved)',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: aliveCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Alive Shrimp in Hapa Net *',
                      suffixText: 'pcs',
                      helperText: 'Count live shrimp remaining in the check net',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'Notes / Observations'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (alive < 0 || alive > stockedHapa * 2) return;

                  try {
                    final db = ref.read(appDatabaseProvider);
                    await db.into(db.hapaChecks).insert(
                      HapaChecksCompanion(
                        id: drift.Value('hapa_${DateTime.now().millisecondsSinceEpoch}'),
                        batchId: drift.Value(batch.id),
                        pondId: drift.Value(pond.id),
                        date: drift.Value(DateTime.now()),
                        hoursElapsed: const drift.Value(240), // 10 days
                        hapaStocked: drift.Value(stockedHapa),
                        hapaAlive: drift.Value(alive),
                        survivalPercentage: drift.Value(survivalPct),
                        estimatedPopulation: drift.Value(estimatedActive),
                        notes: drift.Value(notesCtrl.text.trim()),
                      ),
                    );

                    // Update batch's actualSurvivalPct
                    await (db.update(db.batches)..where((t) => t.id.equals(batch.id))).write(
                      BatchesCompanion(actualSurvivalPct: drift.Value(survivalPct)),
                    );

                    ref.invalidate(activeBatchesStreamProvider);
                    ref.invalidate(batchDashboardDataProvider(batch.id));

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✓ Hapa Check saved: ${survivalPct.toStringAsFixed(1)}% survival. Active population: $estimatedActive pcs.'),
                          backgroundColor: AquaColors.statusOptimal,
                        ),
                      );
                      Navigator.of(ctx).pop();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save Hapa Check: $e'), backgroundColor: AquaColors.statusAlert),
                      );
                    }
                  }
                },
                child: const Text('Save Hapa Check'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showHarvestDialog(Batch batch, Pond pond) {
    final weightCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '380');
    final buyerCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final kg = double.tryParse(weightCtrl.text) ?? 0.0;
          final price = double.tryParse(priceCtrl.text) ?? 0.0;
          final revenue = (kg * price).toStringAsFixed(0);

          return AlertDialog(
            title: Text('Harvest Batch in ${pond.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Target Pond: ${pond.name} · Est. Revenue: ₹$revenue',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Total Harvest Weight (kg) *', suffixText: 'kg'),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Sale Price per kg (₹) *', prefixText: '₹'),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: buyerCtrl,
                    decoration: const InputDecoration(labelText: 'Processor / Buyer Name', hintText: 'e.g. Nekkanti Sea Foods'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (kg <= 0 || price <= 0) return;
                  final db = ref.read(appDatabaseProvider);
                  await db.completeBatchTransaction(
                    batchId: batch.id,
                    pondId: pond.id,
                    harvestDate: DateTime.now(),
                    harvestWeightKg: kg,
                    harvestCount: (kg * 40).toInt(),
                    salePricePerKg: price,
                    totalRevenue: kg * price,
                    actualFcr: 1.30,
                    actualSurvivalPct: 88.0,
                    harvestType: 'full',
                    buyerName: buyerCtrl.text.trim(),
                  );
                  if (mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Confirm Harvest'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final pondsAsync = ref.watch(allPondsStreamProvider);
    final batchesAsync = ref.watch(activeBatchesStreamProvider);
    final weatherAsync = ref.watch(siteWeatherStreamProvider(widget.site.id));

    final allPonds = pondsAsync.valueOrNull ?? [];
    final sitePonds = allPonds.where((p) => p.siteId == widget.site.id).toList();

    if (!_hasInitializedExpandedState && pondsAsync.hasValue) {
      _hasInitializedExpandedState = true;
      if (sitePonds.isEmpty) {
        _isAddPondExpanded = true;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.site.name,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '${(widget.site.waterSource ?? 'coastal').toUpperCase()} · Coastal Facility',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.school_rounded),
            tooltip: 'Step-by-Step Pond Tutorial',
            onPressed: () => FirstPondTutorialPage.show(context, site: widget.site),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Pond Setup Guide & Best Practices',
            onPressed: () => FirstPondGuideDialog.show(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Compact Material 3 Site Card
            _buildSiteCard(theme),
            const SizedBox(height: 12),

            // 2. Site Weather Station Card (Authoritative weather)
            _buildWeatherStationCard(theme, weatherAsync),
            const SizedBox(height: 16),

            // 3. Section Header & Add Pond Trigger
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ponds Under ${widget.site.name}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${sitePonds.length} registered basins',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _isAddPondExpanded = !_isAddPondExpanded;
                    });
                  },
                  icon: Icon(_isAddPondExpanded ? Icons.close_rounded : Icons.add_rounded, size: 18),
                  label: Text(_isAddPondExpanded ? 'Cancel' : 'Add Pond'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 4. Contextual Add Pond Flow Card with Guide & Telemetry
            if (_isAddPondExpanded) ...[
              _buildAddPondForm(theme, sitePonds),
              const SizedBox(height: 16),
            ],

            // 5. List of Ponds under this Site
            if (sitePonds.isEmpty)
              Card(
                color: theme.colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.water_rounded, size: 40, color: theme.colorScheme.primary.withOpacity(0.5)),
                        const SizedBox(height: 8),
                        Text(
                          'No ponds registered under this site.',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'New to pond setup? Take our interactive step-by-step tutorial to configure dimensions, depth, and aeration.',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF006876),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => FirstPondTutorialPage.show(context, site: widget.site),
                          icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                          label: const Text('Start Step-by-Step Tutorial'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              batchesAsync.when(
                  data: (batches) {
                    return Column(
                      children: sitePonds.map((p) {
                        final batch = batches.where((b) => b.pondId == p.id).firstOrNull;
                        DocResult? docRes;
                        if (batch != null) {
                          docRes = DocCalculator.calculate(stockingDate: batch.stockingDate);
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF006876).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.grid_view_rounded, size: 18, color: Color(0xFF006876)),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        p.name,
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  if (docRes != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                      child: Text(
                                        '${docRes.stage.icon} ${docRes.stage.label} · DOC ${docRes.doc}',
                                        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  else
                                    AquaStatusChip(label: settings.tr('vacant'), level: AquaStatusLevel.warning),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Area: ${p.areaSqMeters.toInt()} m² (${(p.areaSqMeters / 4046.86).toStringAsFixed(2)} ac) · Depth: ${p.waterDepthMeters}m · Aeration: ${p.totalAeratorHp} HP (${p.aeratorsCount} aerators)',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                              const Divider(height: 20),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (batch == null)
                                    FilledButton.tonalIcon(
                                      onPressed: () => _showStockBatchDialog(p),
                                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                                      label: Text(settings.tr('stock_batch')),
                                    )
                                  else ...[
                                    OutlinedButton.icon(
                                      onPressed: () => _showSamplingDialog(batch, p),
                                      icon: const Icon(Icons.monitor_weight_outlined, size: 16),
                                      label: Text(settings.tr('cast_net_sample')),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _showHapaCheckDialog(batch, p),
                                      icon: const Icon(Icons.fact_check_outlined, size: 16),
                                      label: const Text('Hapa Check'),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: () => _showHarvestDialog(batch, p),
                                      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                                      label: Text(settings.tr('complete_harvest')),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteCard(ThemeData theme) {
    final fullAddress = [
      widget.site.address,
      widget.site.villageCity,
      widget.site.state,
      widget.site.country,
    ].whereType<String>().where((e) => e.isNotEmpty).join(', ');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF006876).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ID: ${widget.site.id.toUpperCase().replaceAll('SITE_', 'SITE-')}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF006876),
                  ),
                ),
              ),
              if (widget.site.latitude != null && widget.site.longitude != null)
                Text(
                  '${widget.site.latitude!.toStringAsFixed(4)}° N, ${widget.site.longitude!.toStringAsFixed(4)}° E',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.site.name,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          if (fullAddress.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    fullAddress,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeatherStationCard(ThemeData theme, AsyncValue<WeatherObservation?> weatherAsync) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF006876).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sensors_rounded, size: 18, color: Color(0xFF006876)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Site Environmental Weather',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Live Station · Local Cache',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.sync_rounded, size: 18),
                onPressed: () async {
                  if (widget.site.latitude != null && widget.site.longitude != null) {
                    final weatherService = ref.read(weatherServiceProvider);
                    await weatherService.syncSiteWeather(widget.site);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          weatherAsync.when(
            data: (obs) {
              final temp = obs?.temperature ?? 28.5;
              final feelsLike = obs?.feelsLike ?? (temp + 2.5);
              final humidity = obs?.humidity?.toInt() ?? 74;
              final wind = obs?.windSpeed?.toInt() ?? 14;
              final condition = obs?.condition ?? 'Partly Cloudy';

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${temp.toStringAsFixed(1)}°C',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Feels ${feelsLike.toStringAsFixed(0)}°C',
                              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            condition,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(theme, Icons.water_drop_outlined, 'Humidity', '$humidity%', 'Optimal'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricTile(theme, Icons.air_rounded, 'Wind Speed', '$wind km/h', 'Moderate'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricTile(theme, Icons.umbrella_outlined, 'Rain Risk', '10%', 'Low'),
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => const Text('Weather telemetry currently unavailable.'),
          ),
          const SizedBox(height: 10),

          // Authoritative Weather Scope Notice
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 3.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Site weather is authoritative and automatically informs feed ration calculations for all ponds under this site.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(ThemeData theme, IconData icon, String label, String value, String subtext) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
          Text(subtext, style: theme.textTheme.labelSmall?.copyWith(fontSize: 9, color: theme.colorScheme.primary)),
        ],
      ),
    );
  }

  Widget _buildLiveMetricsCard(ThemeData theme) {
    final areaSqMeters = _calculateAreaInSqMeters();
    final depthSanitized = _depthController.text.trim().replaceAll(',', '.');
    final depth = double.tryParse(depthSanitized) ?? 0.0;
    final volumeCubicMeters = areaSqMeters * depth;
    final aeratorHpSanitized = _aeratorHpController.text.trim().replaceAll(',', '.');
    final aeratorHp = double.tryParse(aeratorHpSanitized) ?? 0.0;
    final acres = areaSqMeters / 4046.86;
    final hpPerAcre = acres > 0 ? (aeratorHp / acres) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF006876).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calculate_outlined, size: 16, color: Color(0xFF006876)),
                  const SizedBox(width: 6),
                  Text(
                    'Live Basin Telemetry & Calculations',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF006876),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF006876).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('AUTO-COMPUTED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF006876))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  theme,
                  Icons.square_foot_rounded,
                  'Total Surface',
                  '${areaSqMeters.toInt()} m²',
                  '${acres.toStringAsFixed(2)} Acres',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  theme,
                  Icons.water_rounded,
                  'Water Volume',
                  '${volumeCubicMeters.toInt()} m³',
                  '${(volumeCubicMeters / 1000).toStringAsFixed(2)} ML',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  theme,
                  Icons.air_rounded,
                  'Aeration Ratio',
                  '${hpPerAcre.toStringAsFixed(1)} HP/ac',
                  hpPerAcre >= 6 ? 'Intensive' : (hpPerAcre >= 3 ? 'Moderate' : 'Low'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _applyPreset(PondPreset preset, List<Pond> sitePonds) {
    setState(() {
      _areaController.text = preset.areaValue.toString();
      _areaUnit = preset.areaUnit;
      _depthController.text = preset.depthMeters.toString();
      _aeratorsCountController.text = preset.aeratorUnits.toString();
      _aeratorHpController.text = preset.totalHp.toString();
      if (_pondNameController.text.trim().isEmpty) {
        _pondNameController.text = 'Pond-${(sitePonds.length + 1).toString().padLeft(2, '0')}';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied "${preset.title}" preset parameters.'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF006876),
      ),
    );
  }

  Widget _buildAddPondForm(ThemeData theme, List<Pond> sitePonds) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First-Pond Quick Setup Guide & Presets
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: FirstPondUserGuideCard(
                onStartTutorial: () => FirstPondTutorialPage.show(context, site: widget.site),
                onApplyPreset: (preset) => _applyPreset(preset, sitePonds),
              ),
            ),
            const SizedBox(height: 12),

            // Locked Site Context Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withOpacity(0.7),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_rounded, size: 15, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Parent Site Context: ',
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${widget.site.name} (Locked)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pond Identifier
                  TextFormField(
                    controller: _pondNameController,
                    decoration: InputDecoration(
                      labelText: 'Pond Identifier *',
                      hintText: 'e.g. Pond-01 or Nursery-2',
                      helperText: 'Unique name for water quality & harvest tracing',
                      suffixIcon: const Icon(Icons.tag_rounded, size: 18),
                      suffix: sitePonds.isEmpty && _pondNameController.text.isEmpty
                          ? TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                minimumSize: Size.zero,
                              ),
                              onPressed: () {
                                setState(() {
                                  _pondNameController.text = 'Pond-01';
                                });
                              },
                              child: const Text('Use "Pond-01"', style: TextStyle(fontSize: 11)),
                            )
                          : null,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Pond identifier is required' : null,
                  ),
                  const SizedBox(height: 14),

                  // Surface Area & Water Depth Grid
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _areaController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Surface Area *',
                            helperText: 'Grow-out: 0.5–1.5 ac',
                            suffix: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _areaUnit,
                                isDense: true,
                                items: ['Acres', 'Hectares', 'm²'].map((u) {
                                  return DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)));
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _areaUnit = v);
                                },
                              ),
                            ),
                          ),
                          validator: (v) {
                            final sanitized = v?.trim().replaceAll(',', '.');
                            final n = double.tryParse(sanitized ?? '');
                            if (n == null || n <= 0) return 'Enter area';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _depthController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Depth (m) *',
                            helperText: 'Ideal: 1.2–1.6m',
                            suffixText: 'm',
                          ),
                          validator: (v) {
                            final sanitized = v?.trim().replaceAll(',', '.');
                            final n = double.tryParse(sanitized ?? '');
                            if (n == null || n <= 0) return 'Enter depth';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Installed Aeration Configuration
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _aeratorsCountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Aerator Units',
                            helperText: 'Paddlewheels/long-arms',
                            suffixText: 'pcs',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _aeratorHpController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Total Aeration',
                            helperText: '≥1 HP per 350kg shrimp',
                            suffixText: 'HP',
                          ),
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty) {
                              final sanitized = v.trim().replaceAll(',', '.');
                              final n = double.tryParse(sanitized);
                              if (n == null || n < 0) return 'Invalid HP';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Live Calculated Basin Telemetry Card
                  _buildLiveMetricsCard(theme),
                  const SizedBox(height: 16),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _isAddPondExpanded = false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                        onPressed: _isSubmitting ? null : _submitPond,
                        label: _isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('Save Pond in ${widget.site.name}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
