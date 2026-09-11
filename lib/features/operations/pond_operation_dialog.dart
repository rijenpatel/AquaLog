import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/calculations/pond_operations_engine.dart';
import '../../core/widgets/aqua_dropdown.dart';

class PondOperationDialog extends ConsumerStatefulWidget {
  final Pond pond;
  final String? batchId;
  final VoidCallback? onCompleted;

  const PondOperationDialog({
    super.key,
    required this.pond,
    this.batchId,
    this.onCompleted,
  });

  static Future<void> show(
    BuildContext context, {
    required Pond pond,
    String? batchId,
    VoidCallback? onCompleted,
  }) {
    return showDialog(
      context: context,
      builder: (_) => PondOperationDialog(
        pond: pond,
        batchId: batchId,
        onCompleted: onCompleted,
      ),
    );
  }

  @override
  ConsumerState<PondOperationDialog> createState() => _PondOperationDialogState();
}

class _PondOperationDialogState extends ConsumerState<PondOperationDialog> {
  String _operationType = 'exchange';
  final _volumeController = TextEditingController();
  final _percentageController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  String _waterSource = 'canal';
  bool _isSaving = false;

  final List<Map<String, String>> _types = [
    {'value': 'exchange', 'label': 'Water Exchange (Drain & Refill)'},
    {'value': 'addition', 'label': 'Water Addition / Top-Up'},
    {'value': 'removal', 'label': 'Water Removal / Discharge'},
    {'value': 'partial_drain', 'label': 'Partial Drain'},
    {'value': 'full_drain', 'label': 'Full Pond Drain'},
  ];

  final List<String> _sources = ['canal', 'borewell', 'reservoir', 'estuary', 'other'];

  @override
  void initState() {
    super.initState();
    // Default 10%
    _percentageController.text = '10';
    _updateLitersFromPercentage(10.0);
  }

  void _updateLitersFromPercentage(double pct) {
    final liters = PondOperationsEngine.calculateLitersFromPercentage(widget.pond, pct);
    _volumeController.text = liters.toStringAsFixed(0);
  }

  void _updatePercentageFromLiters(double liters) {
    final pct = PondOperationsEngine.calculatePercentageFromLiters(widget.pond, liters);
    _percentageController.text = pct.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _volumeController.dispose();
    _percentageController.dispose();
    _equipmentController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final volume = double.tryParse(_volumeController.text.trim());
    if (volume == null || volume <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid volume in liters.')),
      );
      return;
    }

    final pct = double.tryParse(_percentageController.text.trim());

    setState(() => _isSaving = true);
    final db = ref.read(databaseProvider);

    try {
      final opId = 'op_${const Uuid().v4()}';
      await db.savePondOperation(PondOperationsCompanion.insert(
        id: opId,
        pondId: widget.pond.id,
        batchId: widget.batchId != null ? Value(widget.batchId) : const Value.absent(),
        date: DateTime.now(),
        operationType: _operationType,
        volumeLiters: volume,
        percentageExchanged: pct != null ? Value(pct) : const Value.absent(),
        source: Value(_waterSource),
        pumpEquipment: _equipmentController.text.trim().isNotEmpty
            ? Value(_equipmentController.text.trim())
            : const Value.absent(),
        reason: _reasonController.text.trim().isNotEmpty
            ? Value(_reasonController.text.trim())
            : const Value.absent(),
        notes: _notesController.text.trim().isNotEmpty
            ? Value(_notesController.text.trim())
            : const Value.absent(),
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pond operation logged successfully.')),
        );
        widget.onCompleted?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log operation: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final capacity = PondOperationsEngine.calculatePondCapacity(widget.pond);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.swap_vert_circle_outlined, color: Colors.blue),
          const SizedBox(width: 8),
          Text('Log Water Operation: ${widget.pond.name}'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Total Pond Volume: ${capacity.totalPondCapacityM3.toStringAsFixed(0)} m³ (${(capacity.totalPondCapacityLiters / 1000000.0).toStringAsFixed(2)}M Liters)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            AquaDropdownFormField<String>(
              value: _operationType,
              labelText: 'Operation Type',
              prefixIcon: const Icon(Icons.swap_vert_circle_outlined, size: 20),
              items: _types
                  .map((t) => DropdownMenuItem(value: t['value'], child: Text(t['label']!)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _operationType = val);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _percentageController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Exchange %',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final p = double.tryParse(val.trim());
                      if (p != null) {
                        final liters = PondOperationsEngine.calculateLitersFromPercentage(widget.pond, p);
                        _volumeController.text = liters.toStringAsFixed(0);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _volumeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Volume (Liters)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final l = double.tryParse(val.trim());
                      if (l != null) {
                        _updatePercentageFromLiters(l);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AquaDropdownFormField<String>(
              value: _waterSource,
              labelText: 'Water Source',
              prefixIcon: const Icon(Icons.source_outlined, size: 20),
              items: _sources
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _waterSource = val);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Operation',
                hintText: 'e.g. Ammonia dilution, salinity adjustment, routine weekly exchange',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _equipmentController,
              decoration: const InputDecoration(
                labelText: 'Pump / Equipment Used',
                hintText: 'e.g. Pump #2 (7.5 HP Diesel)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? const Text('Saving...') : const Text('Log Operation'),
        ),
      ],
    );
  }
}
