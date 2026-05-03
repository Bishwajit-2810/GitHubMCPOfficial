import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/form_widgets.dart';

class RepoSelectorScreen extends StatefulWidget {
  const RepoSelectorScreen({super.key});

  @override
  State<RepoSelectorScreen> createState() => _RepoSelectorScreenState();
}

class _RepoSelectorScreenState extends State<RepoSelectorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerCtrl = TextEditingController();
  final _repoCtrl = TextEditingController();
  final _projectCtrl = TextEditingController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final ctx = context.read<ContextNotifier>().state.context;
    _ownerCtrl.text = ctx.selectedOwner ?? '';
    _repoCtrl.text = ctx.selectedRepo ?? '';
    _projectCtrl.text = ctx.selectedProjectNumber?.toString() ?? '';
  }

  @override
  void dispose() {
    _ownerCtrl.dispose();
    _repoCtrl.dispose();
    _projectCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final projectNum = int.tryParse(_projectCtrl.text.trim());
    final ok = await context.read<ContextNotifier>().save(
          owner: _ownerCtrl.text.trim().isEmpty ? null : _ownerCtrl.text.trim(),
          repo: _repoCtrl.text.trim().isEmpty ? null : _repoCtrl.text.trim(),
          projectNumber: projectNum,
        );
    if (ok && mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final ctxState = context.watch<ContextNotifier>().state;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F4C81), Color(0xFF1565C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tune_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Repo & Project'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _saved ? _buildSuccess(ctxState) : _buildForm(ctxState),
      ),
    );
  }

  Widget _buildSuccess(dynamic ctxState) {
    final ctx = ctxState.context;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppTheme.greenGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, size: 36, color: Colors.white),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
        ),
        const SizedBox(height: 20),
        const Text(
          'Context saved!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ).animate().fadeIn(delay: 120.ms),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              if (ctx.selectedOwner != null)
                _ContextRow(icon: Icons.person_outline_rounded, label: 'Owner', value: ctx.selectedOwner!),
              if (ctx.selectedRepo != null)
                _ContextRow(icon: Icons.folder_outlined, label: 'Repository', value: ctx.selectedRepo!),
              if (ctx.selectedProjectNumber != null)
                _ContextRow(icon: Icons.view_kanban_outlined, label: 'Project', value: '#${ctx.selectedProjectNumber}'),
            ],
          ),
        ).animate().fadeIn(delay: 240.ms),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: const Text('Back'),
        ).animate().fadeIn(delay: 300.ms),
      ],
    );
  }

  Widget _buildForm(dynamic ctxState) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormInfoBanner(
            text: 'Set a default repository and project used across all task and repo operations.',
            icon: Icons.info_outline_rounded,
            colors: const [Color(0xFF1565C0), Color(0xFF1976D2)],
          ),
          const SizedBox(height: 16),
          if (ctxState.error != null) ...[
            FormErrorBanner(message: ctxState.error!),
            const SizedBox(height: 12),
          ],
          FormSectionCard(
            title: 'Repository',
            children: [
              TextFormField(
                controller: _ownerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Owner *',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                  hintText: 'GitHub username or org',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Owner is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _repoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Repository *',
                  prefixIcon: Icon(Icons.folder_outlined, size: 18),
                  hintText: 'my-repo',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Repository is required' : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          FormSectionCard(
            title: 'Project (optional)',
            children: [
              TextFormField(
                controller: _projectCtrl,
                decoration: const InputDecoration(
                  labelText: 'Project number',
                  prefixIcon: Icon(Icons.view_kanban_outlined, size: 18),
                  hintText: 'e.g. 1',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (int.tryParse(v.trim()) == null) return 'Must be a number';
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Save Context',
            icon: Icons.save_rounded,
            isLoading: ctxState.isLoading,
            onPressed: _save,
            colors: const [Color(0xFF1565C0), Color(0xFF1976D2)],
          ),
        ],
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContextRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
