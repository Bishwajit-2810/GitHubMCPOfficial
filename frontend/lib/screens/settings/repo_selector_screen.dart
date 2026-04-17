import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';

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
          owner: _ownerCtrl.text.trim().isEmpty
              ? null
              : _ownerCtrl.text.trim(),
          repo: _repoCtrl.text.trim().isEmpty ? null : _repoCtrl.text.trim(),
          projectNumber: projectNum,
        );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Context saved!')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctxState = context.watch<ContextNotifier>().state;

    return Scaffold(
      appBar: AppBar(title: const Text('Repo & Project')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Set a default repository and project. These will be used for all task and context operations unless overridden per request.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),

            if (ctxState.error != null)
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
                child: Text(ctxState.error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13)),
              ),

            TextFormField(
              controller: _ownerCtrl,
              decoration: const InputDecoration(
                labelText: 'Owner *',
                hintText: 'GitHub username or org',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Owner is required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _repoCtrl,
              decoration: const InputDecoration(
                labelText: 'Repository *',
                hintText: 'my-repo',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Repository is required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _projectCtrl,
              decoration: const InputDecoration(
                labelText: 'Project number (optional)',
                hintText: 'e.g. 1',
                prefixIcon: Icon(Icons.view_kanban_outlined),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (int.tryParse(v.trim()) == null) return 'Must be a number';
                return null;
              },
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: ctxState.isLoading ? null : _save,
              child: ctxState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
