import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/api_error.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../widgets/form_widgets.dart';

class AssignTaskScreen extends StatefulWidget {
  const AssignTaskScreen({super.key});

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _issueCtrl = TextEditingController();
  final _assigneesCtrl = TextEditingController();
  final _labelsCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _issueCtrl.dispose();
    _assigneesCtrl.dispose();
    _labelsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; _result = null; });
    try {
      final ctx = context.read<ContextNotifier>().state.context;
      final api = context.read<ApiService>();
      final assignees = _assigneesCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final labels = _labelsCtrl.text.trim().isEmpty
          ? null
          : _labelsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final result = await api.assignTask(
        issueNumber: int.parse(_issueCtrl.text.trim()),
        assignees: assignees,
        labels: labels,
        owner: ctx.selectedOwner,
        repo: ctx.selectedRepo,
      );
      if (mounted) setState(() { _result = result; _isLoading = false; });
    } on ApiError catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _reset() => setState(() {
    _result = null; _error = null;
    _issueCtrl.clear(); _assigneesCtrl.clear(); _labelsCtrl.clear();
  });

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Assign Task'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _result != null ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  Widget _buildSuccess() {
    final r = _result!;
    final assignees = (r['assignees'] as List<dynamic>?)?.map((a) => '@$a').join(', ') ?? '';
    return FormSuccessCard(
      title: 'Issue #${r['issue_number']} updated!',
      subtitle: r['title'] as String?,
      details: [
        if (assignees.isNotEmpty)
          SuccessDetailRow(
            icon: Icons.people_outline_rounded,
            label: 'Assigned',
            value: assignees,
            valueColor: AppTheme.accentLight,
          ),
      ],
      onBack: () => context.pop(),
      onCreateAnother: _reset,
      createAnotherLabel: 'Assign another',
      gradientColors: AppTheme.projectGradient,
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormInfoBanner(
            text: 'Assign GitHub usernames to an issue. Separate multiple assignees or labels with commas.',
            icon: Icons.info_outline_rounded,
            colors: AppTheme.projectGradient,
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            FormErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          FormSectionCard(
            title: 'Issue',
            children: [
              TextFormField(
                controller: _issueCtrl,
                decoration: const InputDecoration(
                  labelText: 'Issue number *',
                  prefixIcon: Icon(Icons.tag_rounded, size: 18),
                  hintText: '42',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (int.tryParse(v.trim()) == null) return 'Must be a number';
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          FormSectionCard(
            title: 'Assignments',
            children: [
              TextFormField(
                controller: _assigneesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Assignees *',
                  prefixIcon: Icon(Icons.people_outline_rounded, size: 18),
                  hintText: 'alice, bob',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'At least one assignee is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _labelsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Labels (optional)',
                  prefixIcon: Icon(Icons.label_outline_rounded, size: 18),
                  hintText: 'bug, enhancement',
                ),
              ),
              const SizedBox(height: 8),
              _AssigneesHint(),
            ],
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Assign',
            icon: Icons.person_add_rounded,
            isLoading: _isLoading,
            onPressed: _submit,
            colors: AppTheme.projectGradient,
          ),
        ],
      ),
    );
  }
}

class _AssigneesHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.tips_and_updates_outlined, size: 12, color: AppTheme.textMuted),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'Separate multiple values with commas',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}
