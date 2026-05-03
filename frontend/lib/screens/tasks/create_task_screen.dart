import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/form_widgets.dart';

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
  bool _created = false;

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
          assignee: _assigneeCtrl.text.trim().isEmpty ? null : _assigneeCtrl.text.trim(),
          label: _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim(),
        );
    if (ok && mounted) setState(() => _created = true);
  }

  void _reset() => setState(() {
    _created = false;
    _titleCtrl.clear();
    _bodyCtrl.clear();
    _assigneeCtrl.clear();
    _labelCtrl.clear();
    _selectedStatus = null;
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TasksNotifier>().state;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppTheme.projectGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_task_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('New Task'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _created ? _buildSuccess() : _buildForm(state),
      ),
    );
  }

  Widget _buildSuccess() {
    return FormSuccessCard(
      title: 'Task created!',
      subtitle: _titleCtrl.text,
      details: [
        if (_selectedStatus != null)
          SuccessDetailRow(icon: Icons.flag_rounded, label: 'Status', value: _selectedStatus!),
        if (_assigneeCtrl.text.isNotEmpty)
          SuccessDetailRow(icon: Icons.person_outline_rounded, label: 'Assignee', value: '@${_assigneeCtrl.text}'),
      ],
      onBack: () => context.pop(),
      onCreateAnother: _reset,
      createAnotherLabel: 'New task',
      gradientColors: AppTheme.projectGradient,
    );
  }

  Widget _buildForm(TasksState state) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.createError != null) ...[
            FormErrorBanner(message: state.createError!),
            const SizedBox(height: 12),
          ],
          FormSectionCard(
            title: 'Task',
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  prefixIcon: Icon(Icons.title_rounded, size: 18),
                  hintText: 'Fix login redirect on mobile',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.notes_rounded, size: 18),
                  alignLabelWithHint: true,
                  hintText: 'Add context, acceptance criteria…',
                ),
                maxLines: 4,
                minLines: 2,
              ),
            ],
          ),
          const SizedBox(height: 12),
          FormSectionCard(
            title: 'Details',
            children: [
              _StatusPicker(
                selected: _selectedStatus,
                statuses: _statuses,
                onSelected: (s) => setState(() => _selectedStatus = s),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _assigneeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Assignee (optional)',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                  hintText: 'GitHub username',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Label (optional)',
                  prefixIcon: Icon(Icons.label_outline_rounded, size: 18),
                  hintText: 'bug, enhancement, …',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Create Task',
            icon: Icons.add_task_rounded,
            isLoading: state.isCreating,
            onPressed: _submit,
            colors: AppTheme.projectGradient,
          ),
        ],
      ),
    );
  }
}

// ── Status picker ─────────────────────────────────────────────────────────────

class _StatusPicker extends StatelessWidget {
  final String? selected;
  final List<String> statuses;
  final void Function(String?) onSelected;

  const _StatusPicker({
    required this.selected,
    required this.statuses,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Status',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _chip(context, null, 'None'),
            ...statuses.map((s) => _chip(context, s, s)),
          ],
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String? value, String label) {
    final isSelected = selected == value;
    final color = _colorFor(value);
    return GestureDetector(
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Color _colorFor(String? s) {
    switch (s) {
      case 'Done': return const Color(0xFF238636);
      case 'In Progress': return const Color(0xFF1F6FEB);
      case 'Todo': return const Color(0xFFE3B341);
      default: return AppTheme.textMuted;
    }
  }
}
