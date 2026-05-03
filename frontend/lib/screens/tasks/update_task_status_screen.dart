import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/api_error.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../widgets/form_widgets.dart';

class UpdateTaskStatusScreen extends StatefulWidget {
  const UpdateTaskStatusScreen({super.key});

  @override
  State<UpdateTaskStatusScreen> createState() => _UpdateTaskStatusScreenState();
}

class _UpdateTaskStatusScreenState extends State<UpdateTaskStatusScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemIdCtrl = TextEditingController();
  String? _selectedStatus;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _result;

  static const _statuses = ['Todo', 'In Progress', 'Done'];

  @override
  void dispose() {
    _itemIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStatus == null) {
      setState(() => _error = 'Please select a status');
      return;
    }
    setState(() { _isLoading = true; _error = null; _result = null; });
    try {
      final ctx = context.read<ContextNotifier>().state.context;
      final api = context.read<ApiService>();
      final result = await api.updateTaskStatus(
        itemId: _itemIdCtrl.text.trim(),
        status: _selectedStatus!,
        projectNumber: ctx.selectedProjectNumber,
        owner: ctx.selectedOwner,
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
    _itemIdCtrl.clear(); _selectedStatus = null;
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
              child: const Icon(Icons.sync_alt_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Update Status'),
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
      title: 'Status updated!',
      subtitle: r['status_updated'] as String?,
      details: [
        SuccessDetailRow(
          icon: Icons.flag_rounded,
          label: 'New status',
          value: r['status_updated'] as String? ?? _selectedStatus ?? '',
          valueColor: _colorFor(_selectedStatus),
        ),
      ],
      onBack: () => context.pop(),
      onCreateAnother: _reset,
      createAnotherLabel: 'Update another',
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
            text: 'Get the item ID (PVTI_…) from the Tasks screen by tapping on a task.',
            icon: Icons.fingerprint_rounded,
            colors: AppTheme.projectGradient,
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            FormErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          FormSectionCard(
            title: 'Item',
            children: [
              TextFormField(
                controller: _itemIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Item ID *',
                  prefixIcon: Icon(Icons.fingerprint_rounded, size: 18),
                  hintText: 'PVTI_lADOBqfXXs4A…',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.trim().startsWith('PVTI_')) return 'Must start with PVTI_';
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          FormSectionCard(
            title: 'Status',
            children: [
              _StatusPicker(
                selected: _selectedStatus,
                statuses: _statuses,
                onSelected: (s) => setState(() { _selectedStatus = s; _error = null; }),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Update Status',
            icon: Icons.sync_alt_rounded,
            isLoading: _isLoading,
            onPressed: _submit,
            colors: AppTheme.projectGradient,
          ),
        ],
      ),
    );
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((s) => _chip(s)).toList(),
    );
  }

  Widget _chip(String value) {
    final isSelected = selected == value;
    final color = _colorFor(value);
    return GestureDetector(
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 14,
              color: isSelected ? color : AppTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: isSelected ? color : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Color _colorFor(String s) {
    switch (s) {
      case 'Done': return const Color(0xFF238636);
      case 'In Progress': return const Color(0xFF1F6FEB);
      case 'Todo': return const Color(0xFFE3B341);
      default: return AppTheme.textMuted;
    }
  }
}
