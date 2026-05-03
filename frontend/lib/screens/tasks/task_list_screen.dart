import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/theme.dart';
import '../../models/task.dart';
import '../../providers/providers.dart';
import '../../widgets/app_error_widget.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/responsive.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final ctx = context.read<ContextNotifier>().state.context;
    context.read<TasksNotifier>().load(
          owner: ctx.selectedOwner,
          projectNumber: ctx.selectedProjectNumber,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TasksNotifier>().state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/tasks/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
      body: Builder(builder: (_) {
        if (state.isLoading) return const _ShimmerTaskList();
        if (state.error != null && state.tasks.isEmpty) {
          return AppErrorWidget(message: state.error!, onRetry: _load);
        }
        if (state.tasks.isEmpty) {
          return EmptyState(
            lottieAsset: 'assets/lottie/empty.json',
            icon: Icons.checklist_rounded,
            title: 'No tasks yet',
            subtitle: 'Create a task or check your repo/project context.',
            action: ElevatedButton.icon(
              onPressed: () => context.push('/tasks/create'),
              icon: const Icon(Icons.add),
              label: const Text('Create Task'),
            ),
          );
        }
        return MaxWidthBox(
          child: RefreshIndicator(
            onRefresh: () async => _load(),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _StatusChart(tasks: state.tasks),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: state.tasks.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) => _TaskCard(
                      task: state.tasks[i],
                      index: i,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ── Status donut chart ────────────────────────────────────────────────────────

class _StatusChart extends StatefulWidget {
  final List<Task> tasks;
  const _StatusChart({required this.tasks});

  @override
  State<_StatusChart> createState() => _StatusChartState();
}

class _StatusChartState extends State<_StatusChart> {
  int _touched = -1;

  static const _palette = [
    Color(0xFF238636), // Done / green
    Color(0xFF1F6FEB), // In Progress / blue
    Color(0xFF8B949E), // No status / grey
    Color(0xFFF0883E), // Other / amber
    Color(0xFFAB47BC), // Extra / purple
    Color(0xFFE64A19), // Extra / orange
  ];

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final t in widget.tasks) {
      final s = t.status ?? 'No Status';
      counts[s] = (counts[s] ?? 0) + 1;
    }
    if (counts.isEmpty) return const SizedBox.shrink();

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = widget.tasks.length;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.donut_large_rounded,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text('$total tasks',
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 420;
            return isWide
                ? Row(
                    children: [
                      SizedBox(
                        width: 130,
                        height: 130,
                        child: _buildPieChart(entries, total),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: _buildLegend(entries, total, context)),
                    ],
                  )
                : Column(
                    children: [
                      SizedBox(
                        height: 130,
                        child: _buildPieChart(entries, total),
                      ),
                      const SizedBox(height: 12),
                      _buildLegend(entries, total, context),
                    ],
                  );
          }),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOut);
  }

  Widget _buildPieChart(
      List<MapEntry<String, int>> entries, int total) {
    return PieChart(
      PieChartData(
        centerSpaceRadius: 38,
        sectionsSpace: 2,
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  response?.touchedSection == null) {
                _touched = -1;
              } else {
                _touched =
                    response!.touchedSection!.touchedSectionIndex;
              }
            });
          },
        ),
        sections: entries.asMap().entries.map((e) {
          final isTouched = e.key == _touched;
          final color = _palette[e.key % _palette.length];
          return PieChartSectionData(
            color: color,
            value: e.value.value.toDouble(),
            title: isTouched ? e.value.value.toString() : '',
            radius: isTouched ? 50 : 42,
            titleStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLegend(List<MapEntry<String, int>> entries, int total,
      BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.asMap().entries.map((e) {
        final color = _palette[e.key % _palette.length];
        final pct = (e.value.value / total * 100).round();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${e.value.key} ($pct%)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ── Task card ─────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final Task task;
  final int index;
  const _TaskCard({required this.task, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: _StatusDot(status: task.status),
        title: Text(
          task.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              if (task.number != null) ...[
                Text('#${task.number}',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 8),
              ],
              if (task.status != null) _StatusPill(status: task.status!),
            ],
          ),
        ),
        trailing: task.assignees.isNotEmpty
            ? _AssigneeChip(login: task.assignees.first)
            : null,
        onTap: task.url != null
            ? () => _showDetail(context, task)
            : null,
      ),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: 50 + index * 30),
            duration: 250.ms)
        .slideX(begin: 0.1, curve: Curves.easeOut);
  }

  void _showDetail(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (task.status != null) _StatusPill(status: task.status!),
            const SizedBox(height: 10),
            Text(task.title,
                style: Theme.of(context).textTheme.titleMedium),
            if (task.assignees.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(task.assignees.join(', '),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
            if (task.url != null) ...[
              const SizedBox(height: 10),
              Text(task.url!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.accentLight)),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final String? status;
  const _StatusDot({this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(shape: BoxShape.circle, color: _color),
    );
  }

  Color get _color {
    switch (status?.toLowerCase()) {
      case 'done':
      case 'closed':
        return const Color(0xFF238636);
      case 'in progress':
        return const Color(0xFF1F6FEB);
      default:
        return const Color(0xFF8B949E);
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _colorFor(String s) {
    switch (s.toLowerCase()) {
      case 'done':
      case 'closed':
        return const Color(0xFF238636);
      case 'in progress':
        return const Color(0xFF1F6FEB);
      default:
        return const Color(0xFF8B949E);
    }
  }
}

class _AssigneeChip extends StatelessWidget {
  final String login;
  const _AssigneeChip({required this.login});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        '@$login',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

// ── Shimmer skeleton ──────────────────────────────────────────────────────────

class _ShimmerTaskList extends StatelessWidget {
  const _ShimmerTaskList();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surface,
      highlightColor: AppTheme.surfaceHigh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Chart skeleton
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            6,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
