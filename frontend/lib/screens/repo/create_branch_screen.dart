import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/api_error.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../widgets/form_widgets.dart';

class CreateBranchScreen extends StatefulWidget {
  const CreateBranchScreen({super.key});

  @override
  State<CreateBranchScreen> createState() => _CreateBranchScreenState();
}

class _CreateBranchScreenState extends State<CreateBranchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _branchCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _branchCtrl.dispose();
    _sourceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; _result = null; });
    try {
      final ctx = context.read<ContextNotifier>().state.context;
      final api = context.read<ApiService>();
      final result = await api.createBranch(
        branch: _branchCtrl.text.trim(),
        sourceBranch: _sourceCtrl.text.trim().isEmpty
            ? null
            : _sourceCtrl.text.trim(),
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

  void _reset() => setState(() { _result = null; _error = null; _branchCtrl.clear(); _sourceCtrl.clear(); });

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
                gradient: const LinearGradient(colors: AppTheme.repoGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_tree_outlined, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Create Branch'),
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
    return FormSuccessCard(
      title: 'Branch created!',
      subtitle: '"${r['branch']}"',
      details: [
        SuccessDetailRow(icon: Icons.account_tree_outlined, label: 'Branch', value: r['branch'] as String),
        SuccessDetailRow(icon: Icons.merge_type_rounded, label: 'From', value: r['source'] as String),
      ],
      onBack: () => context.pop(),
      onCreateAnother: _reset,
      createAnotherLabel: 'New branch',
      gradientColors: AppTheme.repoGradient,
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormInfoBanner(
            text: 'Creates a new branch in your repository. Leave source empty to branch from the default branch.',
            icon: Icons.info_outline_rounded,
            colors: AppTheme.repoGradient,
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            FormErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          FormSectionCard(
            title: 'Branch details',
            children: [
              TextFormField(
                controller: _branchCtrl,
                decoration: const InputDecoration(
                  labelText: 'New branch name *',
                  prefixIcon: Icon(Icons.account_tree_outlined, size: 18),
                  hintText: 'feature/my-feature',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sourceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Source branch (optional)',
                  prefixIcon: Icon(Icons.merge_type_rounded, size: 18),
                  hintText: 'main',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Create Branch',
            icon: Icons.add_rounded,
            isLoading: _isLoading,
            onPressed: _submit,
            colors: AppTheme.repoGradient,
          ),
        ],
      ),
    );
  }
}
