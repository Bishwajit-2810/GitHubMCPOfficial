import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/api_error.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';

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
      setState(() { _result = result; _isLoading = false; });
    } on ApiError catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Pull Request')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _result != null ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  Widget _buildSuccess() {
    final r = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle_outline, size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text('PR #${r['number']} created!', textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(r['title'] as String, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text('${r['head']} → ${r['base']}', textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back'),
          onPressed: () => context.pop(),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Theme.of(context).colorScheme.error),
              ),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title *',
              prefixIcon: Icon(Icons.title),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _headCtrl,
                decoration: const InputDecoration(
                  labelText: 'Head branch *',
                  prefixIcon: Icon(Icons.call_merge),
                  hintText: 'feature/my-feature',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _baseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Base branch',
                  prefixIcon: Icon(Icons.merge_type),
                  hintText: 'main',
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bodyCtrl,
            decoration: const InputDecoration(
              labelText: 'Description',
              prefixIcon: Icon(Icons.notes),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Draft PR'),
            subtitle: const Text('Mark as work in progress'),
            value: _draft,
            onChanged: (v) => setState(() => _draft = v),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _submit,
            icon: _isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.merge),
            label: const Text('Create Pull Request'),
          ),
        ],
      ),
    );
  }
}
