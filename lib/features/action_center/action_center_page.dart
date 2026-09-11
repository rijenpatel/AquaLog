import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/services/action_generator_service.dart';
import '../../core/widgets/aqua_dropdown.dart';
import '../../app/theme/color_schemes.dart';
import '../../core/widgets/aqua_empty_state.dart';
import 'package:flutter/services.dart';

class ActionCenterPage extends ConsumerStatefulWidget {
  const ActionCenterPage({super.key});

  @override
  ConsumerState<ActionCenterPage> createState() => _ActionCenterPageState();
}

class _ActionCenterPageState extends ConsumerState<ActionCenterPage> {
  String _selectedFilter = 'pending'; // 'pending', 'completed', 'all'
  String _categoryFilter = 'all';
  bool _isScanning = false;

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return AquaColors.statusCritical;
      case 'high':
        return Colors.orange;
      case 'normal':
        return Colors.blue;
      case 'low':
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'water_quality':
        return Icons.water_drop_outlined;
      case 'mortality':
        return Icons.heart_broken_outlined;
      case 'sampling':
        return Icons.scale_outlined;
      case 'feed':
        return Icons.set_meal_outlined;
      case 'inventory':
        return Icons.inventory_2_outlined;
      case 'operation':
        return Icons.swap_vert_circle_outlined;
      default:
        return Icons.task_alt_outlined;
    }
  }

  Future<void> _runDailyScan() async {
    setState(() => _isScanning = true);
    final db = ref.read(databaseProvider);
    final service = ActionGeneratorService(db);

    try {
      final generated = await service.generateDailyTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Farm scan complete: $generated new action tasks generated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating tasks: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _showCreateManualTaskDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String priority = 'normal';
    String category = 'operation';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Manual Action Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description / Instructions',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              AquaDropdownFormField<String>(
                value: category,
                labelText: 'Category',
                prefixIcon: const Icon(Icons.category_outlined, size: 20),
                items: ['water_quality', 'mortality', 'sampling', 'feed', 'inventory', 'operation', 'other']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase())))
                    .toList(),
                onChanged: (val) {
                  if (val != null) category = val;
                },
              ),
              const SizedBox(height: 12),
              AquaDropdownFormField<String>(
                value: priority,
                labelText: 'Priority',
                prefixIcon: const Icon(Icons.flag_outlined, size: 20),
                items: ['critical', 'high', 'normal', 'low']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase())))
                    .toList(),
                onChanged: (val) {
                  if (val != null) priority = val;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              final db = ref.read(databaseProvider);
              await db.saveFarmActionTask(FarmActionTasksCompanion.insert(
                id: 'task_man_${const Uuid().v4()}',
                title: titleController.text.trim(),
                description: descController.text.trim().isNotEmpty ? Value(descController.text.trim()) : const Value.absent(),
                category: category,
                priority: Value(priority),
                source: const Value('manual'),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create Task'),
          ),
        ],
      ),
    );
  }

  void _completeTask(FarmActionTask task) {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Complete: ${task.title}'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Resolution Notes / Observations',
            hintText: 'e.g. Aeration turned on, sampled 85 pcs...',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await db.updateFarmActionTaskStatus(
                task.id,
                'completed',
                resolutionNotes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Mark Completed'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasksAsync = ref.watch(allFarmTasksStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Action Center"),
        actions: [
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: 'Run Farm Scan',
            onPressed: _isScanning ? null : _runDailyScan,
          ),
          IconButton(
            icon: const Icon(Icons.add_task_rounded),
            tooltip: 'Add Manual Task',
            onPressed: _showCreateManualTaskDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Pending'),
                    selected: _selectedFilter == 'pending',
                    onSelected: (val) {
                      if (val) setState(() => _selectedFilter = 'pending');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Completed'),
                    selected: _selectedFilter == 'completed',
                    onSelected: (val) {
                      if (val) setState(() => _selectedFilter = 'completed');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('All Statuses'),
                    selected: _selectedFilter == 'all',
                    onSelected: (val) {
                      if (val) setState(() => _selectedFilter = 'all');
                    },
                  ),
                  const SizedBox(width: 16),
                  const Text('|', style: TextStyle(color: Colors.grey)),
                  const SizedBox(width: 16),
                  ChoiceChip(
                    label: const Text('All Categories'),
                    selected: _categoryFilter == 'all',
                    onSelected: (val) {
                      if (val) setState(() => _categoryFilter = 'all');
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Water Quality'),
                    selected: _categoryFilter == 'water_quality',
                    onSelected: (val) {
                      if (val) setState(() => _categoryFilter = 'water_quality');
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Mortality'),
                    selected: _categoryFilter == 'mortality',
                    onSelected: (val) {
                      if (val) setState(() => _categoryFilter = 'mortality');
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Sampling'),
                    selected: _categoryFilter == 'sampling',
                    onSelected: (val) {
                      if (val) setState(() => _categoryFilter = 'sampling');
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Feed'),
                    selected: _categoryFilter == 'feed',
                    onSelected: (val) {
                      if (val) setState(() => _categoryFilter = 'feed');
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Inventory'),
                    selected: _categoryFilter == 'inventory',
                    onSelected: (val) {
                      if (val) setState(() => _categoryFilter = 'inventory');
                    },
                  ),
                ],
              ),
            ),
          ),

          // Tasks List
          Expanded(
            child: tasksAsync.when(
              data: (allTasks) {
                var filtered = allTasks;
                if (_selectedFilter != 'all') {
                  filtered = filtered.where((t) => t.status == _selectedFilter).toList();
                }
                if (_categoryFilter != 'all') {
                  filtered = filtered.where((t) => t.category == _categoryFilter).toList();
                }

                if (filtered.isEmpty) {
                  return AquaEmptyState(
                    icon: Icons.task_alt_rounded,
                    title: 'All Farm Actions Clear',
                    message: _selectedFilter == 'pending'
                        ? 'No pending action tasks for today. Run a farm scan to evaluate real-time pond telemetry.'
                        : 'No tasks found for the selected status and category filters.',
                    actionLabel: _selectedFilter == 'pending' ? 'Run Farm Scan' : null,
                    onAction: _selectedFilter == 'pending' ? _runDailyScan : null,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final task = filtered[index];
                    final pColor = _getPriorityColor(task.priority);
                    final isDone = task.status == 'completed';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: task.priority == 'critical'
                              ? pColor
                              : theme.colorScheme.outlineVariant.withOpacity(0.35),
                          width: task.priority == 'critical' ? 1.5 : 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: pColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: pColor.withOpacity(0.25), width: 0.8),
                                  ),
                                  child: Center(
                                    child: Icon(_getCategoryIcon(task.category), size: 20, color: pColor),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          letterSpacing: -0.2,
                                          decoration: isDone ? TextDecoration.lineThrough : null,
                                          color: isDone
                                              ? theme.colorScheme.onSurface.withOpacity(0.5)
                                              : theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: pColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: pColor.withOpacity(0.3), width: 0.8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 5,
                                                  height: 5,
                                                  decoration: BoxDecoration(color: pColor, shape: BoxShape.circle),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  task.priority.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: pColor,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            task.source == 'system' ? 'SYSTEM ADVISORY' : 'MANUAL TASK',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.3,
                                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isDone)
                                  IconButton.filledTonal(
                                    icon: const Icon(Icons.check_rounded, size: 20),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AquaColors.statusOptimal.withOpacity(0.15),
                                      foregroundColor: AquaColors.statusOptimal,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    tooltip: 'Complete Task',
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      _completeTask(task);
                                    },
                                  ),
                              ],
                            ),
                            if (task.description != null && task.description!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                task.description!,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (task.resolutionNotes != null && task.resolutionNotes!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AquaColors.statusOptimal.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AquaColors.statusOptimal.withOpacity(0.2),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  'Resolved: ${task.resolutionNotes!}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading tasks: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
