import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/api_error.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../widgets/form_widgets.dart';

class CreatePRScreen extends StatefulWidget {
  const CreatePRScreen({super.key});

  @override
  State<CreatePRScreen> createState() => _CreatePRScreenState();
}

class _CreatePRScreenState extends State<CreatePRScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _headCtrl = TextEditingController();
  final _baseCtrl = TextEditingController();
  bool _draft = false;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _headCtrl.dispose();
    _baseCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; _result = null; });
    try {
      final ctx = context.read<ContextNotifier>().state.context;
      final api = context.read<ApiService>();
      final result = await api.createPullRequest(
        title: _titleCtrl.text.trim(),
        head: _headCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        base: _baseCtrl.text.trim().isEmpty ? null : _baseCtrl.text.trim(),
        draft: _draft,
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

  void _reset() => setState(() { _result = null; _error = null; _titleCtrl.clear(); _bodyCtrl.clear(); _headCtrl.clear(); _baseCtrl.clear(); _draft = false; });

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
              child: const Icon(Icons.merge_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Create Pull Request'),
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
      title: 'PR #${r['number']} created!',
      subtitle: r['title'] as String?,
      details: [
        SuccessDetailRow(icon: Icons.call_merge_rounded, label: 'Head', value: r['head'] as String, valueColor: AppTheme.accentLight),
        SuccessDetailRow(icon: Icons.merge_type_rounded, label: 'Base', value: r['base'] as String),
        if (r['draft'] == true)
          const SuccessDetailRow(icon: Icons.drafts_rounded, label: 'Status', value: 'Draft PR', valueColor: AppTheme.textSecondary),
      ],
      onBack: () => context.pop(),
      onCreateAnother: _reset,
      createAnotherLabel: 'New PR',
      gradientColors: AppTheme.repoGradient,
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            FormErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          FormSectionCard(
            title: 'Pull request',
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  prefixIcon: Icon(Icons.title_rounded, size: 18),
                  hintText: 'Fix: resolve null pointer in auth handler',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _headCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Head branch *',
                        prefixIcon: Icon(Icons.call_merge_rounded, size: 18),
                        hintText: 'feature/fix',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppTheme.textMuted),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _baseCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Base branch',
                        prefixIcon: Icon(Icons.merge_type_rounded, size: 18),
                        hintText: 'main',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          FormSectionCard(
            title: 'Description',
            children: [
              TextFormField(
                controller: _bodyCtrl,
                decoration: const InputDecoration(
                  hintText: 'Describe your changes…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: 6,
                minLines: 3,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: SwitchListTile(
              title: const Text('Draft pull request',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: const Text('Mark as work in progress',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              secondary: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.drafts_rounded, size: 16, color: AppTheme.textSecondary),
              ),
              value: _draft,
              onChanged: (v) => setState(() => _draft = v),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Open Pull Request',
            icon: Icons.merge_rounded,
            isLoading: _isLoading,
            onPressed: _submit,
            colors: AppTheme.repoGradient,
          ),
        ],
      ),
    );
  }
}
