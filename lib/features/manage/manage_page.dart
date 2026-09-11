import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/calculations/calculations.dart';
import '../../core/widgets/aqua_status_chip.dart';
import '../../core/providers/dashboard_context_provider.dart';
import '../../core/providers/batch_dashboard_providers.dart';
import '../../app/theme/color_schemes.dart';
import '../dashboard/batch_dashboard_view.dart';
import 'site_creation_page.dart';
import 'pond_creation_page.dart';
import 'widgets/first_pond_user_guide.dart';
import 'widgets/first_pond_tutorial_page.dart';
import '../sampling/sampling_dialog.dart';
import '../comparison/batch_comparison_page.dart';

class ManagePage extends ConsumerStatefulWidget {
  const ManagePage({super.key});

  @override
  ConsumerState<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends ConsumerState<ManagePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Site filter state
  String _siteSearch = '';
  String _siteStatusFilter = 'all'; // all, active, inactive

  // Pond filter state
  String? _pondSiteFilter; // null = all sites
  String _pondSearch = '';
  final String _pondStatusFilter = 'all'; // all, active, inactive, archived

  // Batch filter state
  String? _batchSiteFilter; // null = all sites
  String? _batchPondFilter; // null = all ponds
  String _batchStatusFilter = 'all'; // all, active, completed, archived
  String _batchSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SITES MANAGEMENT ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showEditSiteDialog(FarmSite site) {
    final nameCtrl = TextEditingController(text: site.name);
    final codeCtrl = TextEditingController(text: site.code);
    final villageCtrl = TextEditingController(text: site.villageCity ?? '');
    final districtCtrl = TextEditingController(text: site.district ?? '');
    final stateCtrl = TextEditingController(text: site.state ?? '');
    final postalCtrl = TextEditingController(text: site.postalCode ?? '');
    final descCtrl = TextEditingController(text: site.description ?? '');
    String waterSource = site.waterSource ?? 'brackish_estuary';
    String status = site.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit Farm Site: ${site.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Site Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(labelText: 'Site Code *', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: status,
                        decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                        ],
                        onChanged: (v) => setDialogState(() => status = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: villageCtrl,
                        decoration: const InputDecoration(labelText: 'Village / City', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: districtCtrl,
                        decoration: const InputDecoration(labelText: 'District', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: stateCtrl,
                        decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: postalCtrl,
                        decoration: const InputDecoration(labelText: 'Postal Code', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: waterSource,
                  decoration: const InputDecoration(labelText: 'Water Source', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'brackish_estuary', child: Text('Brackish Estuary / Creek')),
                    DropdownMenuItem(value: 'deep_borewell', child: Text('Deep Saline Borewell')),
                    DropdownMenuItem(value: 'sea_water', child: Text('Direct Sea Water Intake')),
                    DropdownMenuItem(value: 'freshwater_canal', child: Text('Freshwater Canal / River')),
                  ],
                  onChanged: (v) => setDialogState(() => waterSource = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description / Notes', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final code = codeCtrl.text.trim();
                if (name.isEmpty || code.isEmpty) return;

                final db = ref.read(appDatabaseProvider);
                await (db.update(db.farmSites)..where((t) => t.id.equals(site.id))).write(
                  FarmSitesCompanion(
                    name: drift.Value(name),
                    code: drift.Value(code),
                    status: drift.Value(status),
                    villageCity: drift.Value(villageCtrl.text.trim()),
                    district: drift.Value(districtCtrl.text.trim()),
                    state: drift.Value(stateCtrl.text.trim()),
                    postalCode: drift.Value(postalCtrl.text.trim()),
                    waterSource: drift.Value(waterSource),
                    description: drift.Value(descCtrl.text.trim()),
                    updatedAt: drift.Value(DateTime.now()),
                  ),
                );

                ref.invalidate(allSitesStreamProvider);
                ref.invalidate(activeSitesStreamProvider);
                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✓ Site "$name" updated successfully!'), backgroundColor: AquaColors.statusOptimal),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeleteSite(FarmSite site) async {
    final db = ref.read(appDatabaseProvider);
    final check = await db.canDeleteSite(site.id);

    if (!check.canDelete) {
      if (!mounted) return;
      final depList = check.dependencyBreakdown.entries
          .map((e) => '• ${e.key}: ${e.value}')
          .join('\n');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
          title: const Text('Cannot Delete Site', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'Cannot delete site "${site.name}" because it contains linked dependencies:\n\n'
            '$depList\n\n'
            'Please delete or reassign all linked records belonging to this site before deleting it.',
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Understood')),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Site "${site.name}"?'),
        content: const Text('Are you sure you want to delete this farm site? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Site'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await db.deleteSiteSafely(site.id);
        ref.invalidate(allSitesStreamProvider);
        ref.invalidate(activeSitesStreamProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✓ Site "${site.name}" deleted.'), backgroundColor: AquaColors.statusOptimal),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete site: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PONDS MANAGEMENT ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showEditPondDialog(Pond pond, List<FarmSite> sites) {
    String siteId = pond.siteId ?? (sites.isNotEmpty ? sites.first.id : 'site_1');
    final nameCtrl = TextEditingController(text: pond.name);
    final areaCtrl = TextEditingController(text: pond.areaSqMeters.toString());
    final depthCtrl = TextEditingController(text: pond.waterDepthMeters.toString());
    final aeratorUnitsCtrl = TextEditingController(text: pond.aeratorsCount.toString());
    final aeratorHpCtrl = TextEditingController(text: pond.totalAeratorHp.toString());
    final descCtrl = TextEditingController(text: pond.description ?? '');
    String status = pond.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit Pond: ${pond.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: siteId,
                  decoration: const InputDecoration(labelText: 'Assigned Farm Site *', border: OutlineInputBorder()),
                  items: sites.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: (v) => setDialogState(() => siteId = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Pond Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: areaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Area (m²) *', border: OutlineInputBorder(), suffixText: 'm²'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: depthCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Depth (m)', border: OutlineInputBorder(), suffixText: 'm'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: aeratorUnitsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Aerator Units', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: aeratorHpCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Total HP', border: OutlineInputBorder(), suffixText: 'HP'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                    DropdownMenuItem(value: 'archived', child: Text('Archived')),
                  ],
                  onChanged: (v) => setDialogState(() => status = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description / Notes', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final area = double.tryParse(areaCtrl.text.trim()) ?? 0.0;
                final depth = double.tryParse(depthCtrl.text.trim()) ?? 1.5;
                final aeratorUnits = int.tryParse(aeratorUnitsCtrl.text.trim()) ?? 4;
                final aeratorHp = double.tryParse(aeratorHpCtrl.text.trim()) ?? 8.0;

                if (name.isEmpty || area <= 0) return;

                final db = ref.read(appDatabaseProvider);
                await (db.update(db.ponds)..where((t) => t.id.equals(pond.id))).write(
                  PondsCompanion(
                    siteId: drift.Value(siteId),
                    name: drift.Value(name),
                    areaSqMeters: drift.Value(area),
                    waterDepthMeters: drift.Value(depth),
                    aeratorsCount: drift.Value(aeratorUnits),
                    totalAeratorHp: drift.Value(aeratorHp),
                    status: drift.Value(status),
                    description: drift.Value(descCtrl.text.trim()),
                    updatedAt: drift.Value(DateTime.now()),
                  ),
                );

                ref.invalidate(allPondsStreamProvider);
                ref.invalidate(allPondsMasterStreamProvider);
                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✓ Pond "$name" updated successfully!'), backgroundColor: AquaColors.statusOptimal),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeletePond(Pond pond) async {
    final db = ref.read(appDatabaseProvider);
    final check = await db.canDeletePond(pond.id);

    if (!check.canDelete) {
      if (!mounted) return;
      final details = check.dependencyBreakdown.entries
          .map((e) => '• ${e.key}: ${e.value}')
          .join('\n');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
          title: const Text('Cannot Delete Pond', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'Cannot delete pond "${pond.name}" because it contains active historical records:\n\n'
            '$details\n\n'
            'To preserve audit history, ponds with logged operational data cannot be deleted. You can set the pond status to "Inactive" or "Archived" instead.',
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Understood')),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Pond "${pond.name}"?'),
        content: const Text('Are you sure you want to permanently delete this pond? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Pond'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await db.deletePondSafely(pond.id);
        ref.invalidate(allPondsStreamProvider);
        ref.invalidate(allPondsMasterStreamProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✓ Pond "${pond.name}" deleted.'), backgroundColor: AquaColors.statusOptimal),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete pond: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BATCH MANAGEMENT ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showStockBatchDialogWithPondPicker(List<Pond> allPonds, List<FarmSite> allSites) async {
    if (allPonds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create a pond before stocking a batch.')),
      );
      return;
    }

    String selectedPondId = allPonds.first.id;
    final countCtrl = TextEditingController(text: '100000');
    final hatcheryCtrl = TextEditingController(text: 'Apex Hatchery');
    final seedCostCtrl = TextEditingController(text: '40000');
    final targetWeightCtrl = TextEditingController(text: '25.0');
    final hapaCountCtrl = TextEditingController(text: '100');
    final targetDocCtrl = TextEditingController(text: '93');
    final notesCtrl = TextEditingController();
    String species = 'Litopenaeus vannamei';
    DateTime stockingDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final pond = allPonds.firstWhere((p) => p.id == selectedPondId, orElse: () => allPonds.first);
          final count = int.tryParse(countCtrl.text) ?? 0;
          final density = count > 0 && pond.areaSqMeters > 0
              ? (count / pond.areaSqMeters).toStringAsFixed(1)
              : '0';

          return AlertDialog(
            title: const Text('Stock New Batch'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedPondId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Target Pond *', border: OutlineInputBorder()),
                    items: allPonds.map((p) {
                      final site = allSites.where((s) => s.id == p.siteId).firstOrNull;
                      return DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          '${p.name} · ${site?.name ?? "Site"}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => selectedPondId = v!),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Pond Area: ${pond.areaSqMeters.toInt()} m² · Stocking Density: $density pcs/m²',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: species,
                          decoration: const InputDecoration(labelText: 'Species', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'Litopenaeus vannamei', child: Text('L. vannamei (Pacific White)')),
                            DropdownMenuItem(value: 'Penaeus monodon', child: Text('P. monodon (Black Tiger)')),
                          ],
                          onChanged: (v) => setDialogState(() => species = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: stockingDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 30)),
                            );
                            if (picked != null) setDialogState(() => stockingDate = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Stocking Date *', border: OutlineInputBorder()),
                            child: Text(DateFormat('dd MMM yyyy').format(stockingDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: countCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Stocked Count *', suffixText: 'pcs', border: OutlineInputBorder()),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hapaCountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Hapa Count *',
                            suffixText: 'pcs',
                            helperText: '10-day survival check net',
                            border: OutlineInputBorder(),
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
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hatcheryCtrl,
                    decoration: const InputDecoration(labelText: 'Hatchery Source', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: seedCostCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Seed Cost (₹)', prefixText: '₹', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: targetWeightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Target Weight', suffixText: 'g', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes / Batch Remarks', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final db = ref.read(appDatabaseProvider);

                  // 1-Active-Batch-Per-Pond & Period Overlap Enforcement Check
                  final existingActive = await db.getActiveBatchForPond(pond.id);
                  if (existingActive != null) {
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (alertCtx) => AlertDialog(
                        icon: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
                        title: const Text('Pond Already Active', style: TextStyle(fontWeight: FontWeight.bold)),
                        content: Text(
                          'Pond "${pond.name}" already has an active batch (#${existingActive.batchNumber} - ${existingActive.species}).\n\n'
                          'Each pond can only run 1 active batch at a time. Please complete or harvest the current active batch before stocking a new one.',
                        ),
                        actions: [
                          FilledButton(onPressed: () => Navigator.of(alertCtx).pop(), child: const Text('OK')),
                        ],
                      ),
                    );
                    return;
                  }

                  // Check lifecycle period overlap
                  final overlapping = await db.checkBatchOverlap(
                    pondId: pond.id,
                    stockingDate: stockingDate,
                  );
                  if (overlapping != null) {
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (alertCtx) => AlertDialog(
                        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
                        title: const Text('Batch Period Overlap', style: TextStyle(fontWeight: FontWeight.bold)),
                        content: Text(
                          'Cannot stock batch: The selected stocking date conflicts with Batch #${overlapping.batchNumber} (${overlapping.species}) in "${pond.name}".\n\n'
                          'Conflicting batch period: ${DateFormat("dd MMM yyyy").format(overlapping.stockingDate)} to '
                          '${overlapping.harvestDate != null ? DateFormat("dd MMM yyyy").format(overlapping.harvestDate!) : "Ongoing"}.',
                        ),
                        actions: [
                          FilledButton(onPressed: () => Navigator.of(alertCtx).pop(), child: const Text('OK')),
                        ],
                      ),
                    );
                    return;
                  }

                  final shrimpCount = int.tryParse(countCtrl.text) ?? 100000;
                  final hapaCount = int.tryParse(hapaCountCtrl.text) ?? 100;
                  final targetDoc = int.tryParse(targetDocCtrl.text) ?? 93;
                  final seedCost = double.tryParse(seedCostCtrl.text) ?? 0.0;
                  final targetWeight = double.tryParse(targetWeightCtrl.text) ?? 25.0;

                  final batchId = 'batch_${DateTime.now().millisecondsSinceEpoch}';

                  // Calculate next batch number for this pond
                  final allPondBatches = await (db.select(db.batches)..where((t) => t.pondId.equals(pond.id))).get();
                  final nextBatchNum = allPondBatches.length + 1;

                  await db.into(db.batches).insert(
                    BatchesCompanion(
                      id: drift.Value(batchId),
                      pondId: drift.Value(pond.id),
                      batchNumber: drift.Value(nextBatchNum),
                      species: drift.Value(species),
                      stockingDate: drift.Value(stockingDate),
                      shrimpStockedCount: drift.Value(shrimpCount),
                      hapaStockedCount: drift.Value(hapaCount),
                      targetDoc: drift.Value(targetDoc),
                      plStage: const drift.Value('PL-10'),
                      hatcherySource: drift.Value(hatcheryCtrl.text.trim()),
                      seedCost: drift.Value(seedCost),
                      targetHarvestWeightG: drift.Value(targetWeight),
                      status: const drift.Value('active'),
                      notes: drift.Value(notesCtrl.text.trim()),
                      updatedAt: drift.Value(DateTime.now()),
                    ),
                  );

                  if (seedCost > 0) {
                    await db.into(db.expenses).insert(
                      ExpensesCompanion(
                        id: drift.Value('exp_seed_${DateTime.now().millisecondsSinceEpoch}'),
                        batchId: drift.Value(batchId),
                        pondId: drift.Value(pond.id),
                        date: drift.Value(stockingDate),
                        category: const drift.Value('seed'),
                        amount: drift.Value(seedCost),
                        description: drift.Value('Seed purchase for ${pond.name} (Batch #$nextBatchNum): $shrimpCount PLs'),
                      ),
                    );
                  }

                  ref.invalidate(activeBatchesStreamProvider);
                  ref.invalidate(allBatchesMasterStreamProvider);
                  if (mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✓ Batch #$nextBatchNum stocked in ${pond.name}: $shrimpCount PLs!'),
                        backgroundColor: AquaColors.statusOptimal,
                      ),
                    );
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

  void _showEditBatchDialog(Batch batch, Pond pond) {
    final countCtrl = TextEditingController(text: batch.shrimpStockedCount.toString());
    final hapaCtrl = TextEditingController(text: batch.hapaStockedCount.toString());
    final targetDocCtrl = TextEditingController(text: batch.targetDoc.toString());
    final targetWeightCtrl = TextEditingController(text: batch.targetHarvestWeightG.toString());
    final hatcheryCtrl = TextEditingController(text: batch.hatcherySource ?? '');
    final seedCostCtrl = TextEditingController(text: batch.seedCost.toString());
    final notesCtrl = TextEditingController(text: batch.notes ?? '');
    String status = batch.status;
    String species = batch.species;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit Batch #${batch.batchNumber} (${pond.name})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Batch Status', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active (Cultivating)')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed (Harvested)')),
                    DropdownMenuItem(value: 'archived', child: Text('Archived')),
                  ],
                  onChanged: (v) => setDialogState(() => status = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: species,
                  decoration: const InputDecoration(labelText: 'Species', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Litopenaeus vannamei', child: Text('L. vannamei (Pacific White)')),
                    DropdownMenuItem(value: 'Penaeus monodon', child: Text('P. monodon (Black Tiger)')),
                  ],
                  onChanged: (v) => setDialogState(() => species = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: countCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Stocked Count', suffixText: 'pcs', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: hapaCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Hapa Count', suffixText: 'pcs', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: targetDocCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Target DOC', suffixText: 'days', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: targetWeightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Target Weight', suffixText: 'g', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hatcheryCtrl,
                  decoration: const InputDecoration(labelText: 'Hatchery Source', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: seedCostCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Seed Cost (₹)', prefixText: '₹', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes / Remarks', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final db = ref.read(appDatabaseProvider);
                final count = int.tryParse(countCtrl.text.trim()) ?? batch.shrimpStockedCount;
                final hapa = int.tryParse(hapaCtrl.text.trim()) ?? batch.hapaStockedCount;
                final targetDoc = int.tryParse(targetDocCtrl.text.trim()) ?? batch.targetDoc;
                final targetWeight = double.tryParse(targetWeightCtrl.text.trim()) ?? 25.0;
                final seedCost = double.tryParse(seedCostCtrl.text.trim()) ?? 0.0;

                await (db.update(db.batches)..where((t) => t.id.equals(batch.id))).write(
                  BatchesCompanion(
                    species: drift.Value(species),
                    status: drift.Value(status),
                    shrimpStockedCount: drift.Value(count),
                    hapaStockedCount: drift.Value(hapa),
                    targetDoc: drift.Value(targetDoc),
                    targetHarvestWeightG: drift.Value(targetWeight),
                    hatcherySource: drift.Value(hatcheryCtrl.text.trim()),
                    seedCost: drift.Value(seedCost),
                    notes: drift.Value(notesCtrl.text.trim()),
                    updatedAt: drift.Value(DateTime.now()),
                  ),
                );

                ref.invalidate(activeBatchesStreamProvider);
                ref.invalidate(allBatchesMasterStreamProvider);
                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✓ Batch #${batch.batchNumber} updated.'), backgroundColor: AquaColors.statusOptimal),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeleteBatch(Batch batch, Pond pond) async {
    final db = ref.read(appDatabaseProvider);
    final check = await db.canDeleteBatch(batch.id);

    if (!check.canDelete) {
      if (!mounted) return;
      final details = check.dependencyBreakdown.entries
          .map((e) => '• ${e.key}: ${e.value}')
          .join('\n');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
          title: const Text('Cannot Delete Batch', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'Cannot delete Batch #${batch.batchNumber} in "${pond.name}" because it contains active linked production records:\n\n'
            '$details\n\n'
            'Deleting this batch would orphan historical audit records. To conclude the batch, please perform a harvest or set its status to "Completed".',
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Understood')),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Batch #${batch.batchNumber}?'),
        content: Text('Are you sure you want to delete Batch #${batch.batchNumber} in ${pond.name}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Batch'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await db.deleteBatchSafely(batch.id);
        ref.invalidate(activeBatchesStreamProvider);
        ref.invalidate(allBatchesMasterStreamProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✓ Batch #${batch.batchNumber} deleted.'), backgroundColor: AquaColors.statusOptimal),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete batch: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
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
                    decoration: const InputDecoration(
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
                    ref.invalidate(allBatchesMasterStreamProvider);
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
            title: Text('Harvest Batch #${batch.batchNumber} (${pond.name})'),
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
                  ref.invalidate(activeBatchesStreamProvider);
                  ref.invalidate(allBatchesMasterStreamProvider);
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

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD TAB VIEWS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final sitesAsync = ref.watch(allSitesStreamProvider);
    final pondsAsync = ref.watch(allPondsMasterStreamProvider);
    final batchesAsync = ref.watch(allBatchesMasterStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.tr('manage_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF006876),
          tabs: const [
            Tab(icon: Icon(Icons.business_rounded), text: 'Sites'),
            Tab(icon: Icon(Icons.water_rounded), text: 'Ponds'),
            Tab(icon: Icon(Icons.waves_rounded), text: 'Batches'),
          ],
        ),
      ),
      body: sitesAsync.when(
        data: (allSites) {
          final allPonds = pondsAsync.valueOrNull ?? [];
          final allBatches = batchesAsync.valueOrNull ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              // ── TAB 1: SITES ─────────────────────────────────────
              _buildSitesTab(allSites, allPonds, theme),

              // ── TAB 2: PONDS ─────────────────────────────────────
              _buildPondsTab(allPonds, allSites, allBatches, theme),

              // ── TAB 3: BATCHES ───────────────────────────────────
              _buildBatchesTab(allBatches, allPonds, allSites, theme),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading sites: $err')),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: SITES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSitesTab(List<FarmSite> sites, List<Pond> ponds, ThemeData theme) {
    var filtered = sites.where((s) {
      final matchesSearch = _siteSearch.isEmpty ||
          s.name.toLowerCase().contains(_siteSearch.toLowerCase()) ||
          (s.code?.toLowerCase().contains(_siteSearch.toLowerCase()) ?? false) ||
          (s.villageCity?.toLowerCase().contains(_siteSearch.toLowerCase()) ?? false);
      final matchesStatus = _siteStatusFilter == 'all' || s.status.toLowerCase() == _siteStatusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    return Column(
      children: [
        // Top Action & Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search farm sites...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (v) => setState(() => _siteSearch = v),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SiteCreationPage()),
                  );
                },
                icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                label: const Text('New Site'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF006876),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),

        // Status Filter Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All Sites'),
                selected: _siteStatusFilter == 'all',
                onSelected: (val) => setState(() => _siteStatusFilter = 'all'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Active'),
                selected: _siteStatusFilter == 'active',
                onSelected: (val) => setState(() => _siteStatusFilter = 'active'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Inactive'),
                selected: _siteStatusFilter == 'inactive',
                onSelected: (val) => setState(() => _siteStatusFilter = 'inactive'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Site Cards List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.business_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('No farm sites found', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SiteCreationPage()),
                          );
                        },
                        child: const Text('Create Farm Site'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final site = filtered[idx];
                    final sitePonds = ponds.where((p) => p.siteId == site.id).toList();
                    final activePonds = sitePonds.where((p) => p.status == 'active').length;
                    final isActive = site.status == 'active';

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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            site.name,
                                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
                                        ),
                                        if (site.code != null && site.code!.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(site.code!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (isActive
                                                    ? const Color(0xFF006876)
                                                    : Colors.grey)
                                                .withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            site.status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isActive ? const Color(0xFF006876) : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${site.villageCity ?? "Village"}, ${site.district ?? ""}, ${site.state ?? "State"}',
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.water_drop_outlined, size: 14, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                '${(site.waterSource ?? "brackish").replaceAll("_", " ").toUpperCase()} · ${sitePonds.length} Ponds ($activePonds active)',
                                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => PondCreationPage(site: site)),
                                  );
                                },
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Add Pond'),
                              ),
                              Row(
                                children: [
                                  IconButton.outlined(
                                    icon: const Icon(Icons.edit_rounded, size: 18),
                                    tooltip: 'Edit Site',
                                    onPressed: () => _showEditSiteDialog(site),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton.outlined(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                    tooltip: 'Delete Site',
                                    onPressed: () => _handleDeleteSite(site),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showNoSitesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_city_rounded, color: Color(0xFF006876)),
            SizedBox(width: 8),
            Text('Farm Site Required'),
          ],
        ),
        content: const Text(
          'Before creating pond basins, you need to register a Farm Site location (coastal, brackish, or freshwater facility). Would you like to create your first site now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Farm Site'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SiteCreationPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: PONDS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPondsTab(List<Pond> ponds, List<FarmSite> sites, List<Batch> batches, ThemeData theme) {
    final siteMap = {for (final s in sites) s.id: s};

    var filtered = ponds.where((p) {
      final matchesSite = _pondSiteFilter == null || p.siteId == _pondSiteFilter;
      final matchesStatus = _pondStatusFilter == 'all' || p.status.toLowerCase() == _pondStatusFilter;
      final matchesSearch = _pondSearch.isEmpty ||
          p.name.toLowerCase().contains(_pondSearch.toLowerCase());
      return matchesSite && matchesStatus && matchesSearch;
    }).toList();

    return Column(
      children: [
        // Top Action & Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search ponds...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (v) => setState(() => _pondSearch = v),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  if (sites.isEmpty) {
                    _showNoSitesDialog(context);
                    return;
                  }
                  final targetSite = _pondSiteFilter != null
                      ? siteMap[_pondSiteFilter] ?? sites.first
                      : sites.first;
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PondCreationPage(site: targetSite)),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Pond'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF006876),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),

        // Site Filter & Status Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Sites'),
                  selected: _pondSiteFilter == null,
                  onSelected: (_) => setState(() => _pondSiteFilter = null),
                ),
                const SizedBox(width: 6),
                ...sites.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(s.name),
                        selected: _pondSiteFilter == s.id,
                        onSelected: (val) => setState(() => _pondSiteFilter = val ? s.id : null),
                      ),
                    )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Ponds List
        Expanded(
          child: filtered.isEmpty
              ? (ponds.isEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FirstPondUserGuideCard(
                            onStartTutorial: () {
                              if (sites.isEmpty) {
                                _showNoSitesDialog(context);
                              } else {
                                FirstPondTutorialPage.show(context, site: sites.first);
                              }
                            },
                            onApplyPreset: (preset) {
                              if (sites.isEmpty) {
                                _showNoSitesDialog(context);
                              } else {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => PondCreationPage(site: sites.first)),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          if (sites.isNotEmpty) ...[
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: const Color(0xFF006876),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                FirstPondTutorialPage.show(context, site: sites.first);
                              },
                              icon: const Icon(Icons.play_circle_fill_rounded),
                              label: Text('Start Step-by-Step Tutorial (${sites.first.name})'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => PondCreationPage(site: sites.first)),
                                );
                              },
                              icon: const Icon(Icons.tune_rounded),
                              label: const Text('Or Use Advanced Manual Form'),
                            ),
                          ] else
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: const Color(0xFF006876),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const SiteCreationPage()),
                                );
                              },
                              icon: const Icon(Icons.add_location_alt_outlined),
                              label: const Text('Create Farm Site First'),
                            ),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.water_outlined, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text('No matching ponds found', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          if (sites.isNotEmpty)
                            FilledButton.tonal(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => PondCreationPage(site: sites.first)),
                                );
                              },
                              child: const Text('Create New Pond'),
                            ),
                        ],
                      ),
                    ))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final pond = filtered[idx];
                    final siteName = pond.siteId != null && siteMap.containsKey(pond.siteId!)
                        ? siteMap[pond.siteId!]!.name
                        : 'Site';
                    final activeBatch = batches.where((b) => b.pondId == pond.id && b.status == 'active').firstOrNull;

                    DocResult? docRes;
                    if (activeBatch != null) {
                      docRes = DocCalculator.calculate(stockingDate: activeBatch.stockingDate);
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      pond.name,
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF006876).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      siteName,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF006876)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (activeBatch != null && docRes != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                      child: Text(
                                        'DOC ${docRes.doc}',
                                        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'VACANT',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${pond.areaSqMeters.toInt()} m² (${(pond.areaSqMeters / 4046.86).toStringAsFixed(2)} ac) · Depth: ${pond.waterDepthMeters}m · Aeration: ${pond.totalAeratorHp} HP (${pond.aeratorsCount} units)',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (activeBatch != null)
                                FilledButton.tonalIcon(
                                  onPressed: () {
                                    ref.read(dashboardContextProvider.notifier).selectBatch(activeBatch.id);
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => Scaffold(
                                          body: SafeArea(
                                            child: BatchDashboardView(batchId: activeBatch.id),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.dashboard_rounded, size: 16),
                                  label: const Text('Open Batch'),
                                )
                              else
                                FilledButton.tonalIcon(
                                  onPressed: () => _showStockBatchDialogWithPondPicker([pond], sites),
                                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                                  label: const Text('Stock Batch'),
                                ),
                              Row(
                                children: [
                                  IconButton.outlined(
                                    icon: const Icon(Icons.edit_rounded, size: 18),
                                    tooltip: 'Edit Pond',
                                    onPressed: () => _showEditPondDialog(pond, sites),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton.outlined(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                    tooltip: 'Delete Pond',
                                    onPressed: () => _handleDeletePond(pond),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: BATCHES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBatchesTab(List<Batch> batches, List<Pond> ponds, List<FarmSite> sites, ThemeData theme) {
    final pondMap = {for (final p in ponds) p.id: p};
    final siteMap = {for (final s in sites) s.id: s};

    var filtered = batches.where((b) {
      final pond = pondMap[b.pondId];
      final matchesSite = _batchSiteFilter == null || pond?.siteId == _batchSiteFilter;
      final matchesPond = _batchPondFilter == null || b.pondId == _batchPondFilter;
      final matchesStatus = _batchStatusFilter == 'all' || b.status.toLowerCase() == _batchStatusFilter;
      final matchesSearch = _batchSearch.isEmpty ||
          b.species.toLowerCase().contains(_batchSearch.toLowerCase()) ||
          (b.hatcherySource?.toLowerCase().contains(_batchSearch.toLowerCase()) ?? false) ||
          (pond?.name.toLowerCase().contains(_batchSearch.toLowerCase()) ?? false);
      return matchesSite && matchesPond && matchesStatus && matchesSearch;
    }).toList();

    return Column(
      children: [
        // Top Action & Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search batches, species, pond...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (v) => setState(() => _batchSearch = v),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BatchComparisonPage()),
                  );
                },
                icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                label: const Text('Compare'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showStockBatchDialogWithPondPicker(ponds, sites),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Stock Batch'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF006876),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),

        // Status Filter Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Batches'),
                  selected: _batchStatusFilter == 'all',
                  onSelected: (_) => setState(() => _batchStatusFilter = 'all'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Active'),
                  selected: _batchStatusFilter == 'active',
                  onSelected: (_) => setState(() => _batchStatusFilter = 'active'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Completed'),
                  selected: _batchStatusFilter == 'completed',
                  onSelected: (_) => setState(() => _batchStatusFilter = 'completed'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Archived'),
                  selected: _batchStatusFilter == 'archived',
                  onSelected: (_) => setState(() => _batchStatusFilter = 'archived'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Batches List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.waves_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('No batches found', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () => _showStockBatchDialogWithPondPicker(ponds, sites),
                        child: const Text('Stock New Batch'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final batch = filtered[idx];
                    final pond = pondMap[batch.pondId] ??
                        Pond(
                          id: batch.pondId,
                          siteId: 'site_1',
                          name: 'Cultivation Pond',
                          areaSqMeters: 5000,
                          waterDepthMeters: 1.5,
                          aeratorsCount: 4,
                          totalAeratorHp: 8,
                          status: 'active',
                          createdAt: DateTime.now(),
                        );
                    final siteName = pond.siteId != null && siteMap.containsKey(pond.siteId!)
                        ? siteMap[pond.siteId!]!.name
                        : 'Site';
                    final isActive = batch.status == 'active';
                    final docRes = DocCalculator.calculate(stockingDate: batch.stockingDate);

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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Batch #${batch.batchNumber} · ${pond.name}',
                                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF006876).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            siteName,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF006876)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${batch.species} · Stocked: ${DateFormat("dd MMM yyyy").format(batch.stockingDate)}',
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              AquaStatusChip(
                                label: batch.status.toUpperCase(),
                                level: isActive ? AquaStatusLevel.optimal : AquaStatusLevel.info,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text('DOC', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                    Text('${docRes.doc} d', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text('Stocked PLs', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                    Text('${batch.shrimpStockedCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text('Survival', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                    Text(
                                      '${(batch.actualSurvivalPct ?? 90.0).toStringAsFixed(1)}%',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006876)),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text('Target Weight', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                    Text('${batch.targetHarvestWeightG.toStringAsFixed(0)} g', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 20),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: () {
                                  ref.read(dashboardContextProvider.notifier).selectBatch(batch.id);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => Scaffold(
                                        body: SafeArea(
                                          child: BatchDashboardView(batchId: batch.id),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                icon: Icon(isActive ? Icons.dashboard_rounded : Icons.analytics_outlined, size: 16),
                                label: Text(isActive ? 'Dashboard' : 'Batch Overview'),
                              ),
                              if (isActive) ...[
                                OutlinedButton.icon(
                                  onPressed: () => SamplingDialog.show(context, batch: batch, pond: pond),
                                  icon: const Icon(Icons.monitor_weight_outlined, size: 16),
                                  label: const Text('Sample'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _showHapaCheckDialog(batch, pond),
                                  icon: const Icon(Icons.fact_check_outlined, size: 16),
                                  label: const Text('Hapa Check'),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: () => _showHarvestDialog(batch, pond),
                                  icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                                  label: const Text('Harvest'),
                                ),
                              ],
                              IconButton.outlined(
                                icon: const Icon(Icons.edit_rounded, size: 18),
                                tooltip: 'Edit Batch',
                                onPressed: () => _showEditBatchDialog(batch, pond),
                              ),
                              IconButton.outlined(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                tooltip: 'Delete Batch',
                                onPressed: () => _handleDeleteBatch(batch, pond),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
