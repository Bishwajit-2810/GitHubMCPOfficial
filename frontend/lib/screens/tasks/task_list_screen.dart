import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../widgets/app_error_widget.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/empty_state.dart';

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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/tasks/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
      body: Builder(builder: (_) {
        if (state.isLoading) return const AppLoading(message: 'Loading tasks…');
        if (state.error != null) {
          return AppErrorWidget(message: state.error!, onRetry: _load);
        }
        if (state.tasks.isEmpty) {
          return EmptyState(
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
        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.tasks.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final task = state.tasks[i];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: _StatusDot(status: task.status),
                title: Text(task.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Row(children: [
                  if (task.number != null)
                    Text('#${task.number}  ',
                        style: Theme.of(context).textTheme.bodySmall),
                  if (task.status != null)
                    _StatusChip(status: task.status!),
                ]),
                trailing: task.assignees.isNotEmpty
                    ? Text(
                        '@${task.assignees.first}',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : null,
                onTap: task.url != null
                    ? () => _showTaskDetail(context, task)
                    : null,
              );
            },
          ),
        );
      }),
    );
  }

  void _showTaskDetail(BuildContext context, dynamic task) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(task.title,
                style: Theme.of(context).textTheme.titleMedium),
            if (task.status != null) ...[
              const SizedBox(height: 8),
              _StatusChip(status: task.status),
            ],
            if (task.assignees.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Assignees: ${task.assignees.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (task.url != null) ...[
              const SizedBox(height: 12),
              Text(task.url!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String? status;
  const _StatusDot({this.status});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Color _colorFor(String? s) {
    switch (s?.toLowerCase()) {
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

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status,
          style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
    );
  }
}
