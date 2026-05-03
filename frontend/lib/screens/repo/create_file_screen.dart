import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/api_error.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../widgets/form_widgets.dart';

class CreateFileScreen extends StatefulWidget {
  const CreateFileScreen({super.key});

  @override
  State<CreateFileScreen> createState() => _CreateFileScreenState();
}

class _CreateFileScreenState extends State<CreateFileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pathCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _pathCtrl.dispose();
    _contentCtrl.dispose();
    _messageCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; _result = null; });
    try {
      final ctx = context.read<ContextNotifier>().state.context;
      final api = context.read<ApiService>();
      final result = await api.createFile(
        path: _pathCtrl.text.trim(),
        content: _contentCtrl.text,
        message: _messageCtrl.text.trim(),
        branch: _branchCtrl.text.trim().isEmpty ? null : _branchCtrl.text.trim(),
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

  void _reset() => setState(() { _result = null; _error = null; _pathCtrl.clear(); _contentCtrl.clear(); _messageCtrl.clear(); _branchCtrl.clear(); });

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
              child: const Icon(Icons.upload_file_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Commit File'),
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
    final sha = (r['commit_sha'] as String?) ?? '';
    return FormSuccessCard(
      title: 'File committed!',
      subtitle: r['path'] as String?,
      details: [
        SuccessDetailRow(icon: Icons.insert_drive_file_outlined, label: 'Path', value: r['path'] as String),
        SuccessDetailRow(icon: Icons.commit_rounded, label: 'SHA', value: sha.isNotEmpty ? sha.substring(0, 7) : '–', valueColor: AppTheme.accentLight),
      ],
      onBack: () => context.pop(),
      onCreateAnother: _reset,
      createAnotherLabel: 'Commit another',
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
            text: 'Create or update a file in the repository. Content is committed directly to the branch.',
            icon: Icons.upload_file_rounded,
            colors: AppTheme.repoGradient,
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            FormErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          FormSectionCard(
            title: 'Commit details',
            children: [
              TextFormField(
                controller: _pathCtrl,
                decoration: const InputDecoration(
                  labelText: 'File path *',
                  prefixIcon: Icon(Icons.insert_drive_file_outlined, size: 18),
                  hintText: 'src/hello.py',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Commit message *',
                  prefixIcon: Icon(Icons.commit_rounded, size: 18),
                  hintText: 'Add hello.py',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _branchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Branch (optional — defaults to main)',
                  prefixIcon: Icon(Icons.account_tree_outlined, size: 18),
                  hintText: 'main',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FormSectionCard(
            title: 'File content',
            padding: EdgeInsets.zero,
            children: [
              TextFormField(
                controller: _contentCtrl,
                decoration: InputDecoration(
                  hintText: '# Write your file content here…',
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  fillColor: AppTheme.bg,
                  filled: true,
                ),
                maxLines: 14,
                minLines: 6,
                style: GoogleFonts.jetBrainsMono(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Commit File',
            icon: Icons.upload_file_rounded,
            isLoading: _isLoading,
            onPressed: _submit,
            colors: AppTheme.repoGradient,
          ),
        ],
      ),
    );
  }
}
