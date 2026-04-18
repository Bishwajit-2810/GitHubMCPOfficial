import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/api_error.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';

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

  @override
  void dispose() {
    _branchCtrl.dispose();
    _sourceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final ctx = context.read<ContextNotifier>().state.context;
      final api = context.read<ApiService>();
      final result = await api.createBranch(
        branch: _branchCtrl.text.trim(),
        sourceBranch: _sourceCtrl.text.trim().isEmpty ? null : _sourceCtrl.text.trim(),
        owner: ctx.selectedOwner,
        repo: ctx.selectedRepo,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Branch "${result['branch']}" created from "${result['source']}"')),
        );
        context.pop();
      }
    } on ApiError catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Branch')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
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
                controller: _branchCtrl,
                decoration: const InputDecoration(
                  labelText: 'New branch name *',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                  hintText: 'feature/my-feature',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sourceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Source branch (leave empty for default)',
                  prefixIcon: Icon(Icons.merge_type),
                  hintText: 'main',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add),
                label: const Text('Create Branch'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
