import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _assigneeCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();

  String? _selectedStatus;
  static const _statuses = ['Todo', 'In Progress', 'Done'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _assigneeCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ctx = context.read<ContextNotifier>().state.context;

    final ok = await context.read<TasksNotifier>().create(
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
          status: _selectedStatus,
          owner: ctx.selectedOwner,
          repo: ctx.selectedRepo,
          projectNumber: ctx.selectedProjectNumber,
          assignee: _assigneeCtrl.text.trim().isEmpty
              ? null
              : _assigneeCtrl.text.trim(),
          label: _labelCtrl.text.trim().isEmpty
              ? null
              : _labelCtrl.text.trim(),
        );

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created!')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TasksNotifier>().state;

    return Scaffold(
      appBar: AppBar(title: const Text('New Task')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.createError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.error),
                ),
                child: Text(state.createError!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13)),
              ),

            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _bodyCtrl,
              decoration:
                  const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 4,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration:
                  const InputDecoration(labelText: 'Status (optional)'),
              items: _statuses
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedStatus = v),
              dropdownColor: Theme.of(context).colorScheme.surface,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _assigneeCtrl,
              decoration: const InputDecoration(
                labelText: 'Assignee (optional)',
                hintText: 'GitHub username',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
                hintText: 'e.g. bug, enhancement',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: state.isCreating ? null : _submit,
              child: state.isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Create Task'),
            ),
          ],
        ),
      ),
    );
  }
}
