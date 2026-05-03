import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/api_error.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../widgets/form_widgets.dart';

class CreateProjectFieldScreen extends StatefulWidget {
  const CreateProjectFieldScreen({super.key});

  @override
  State<CreateProjectFieldScreen> createState() => _CreateProjectFieldScreenState();
}

class _CreateProjectFieldScreenState extends State<CreateProjectFieldScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _fieldType = 'text';
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _result;

  static const _fieldTypes = [
    _FieldTypeOption('text', Icons.text_fields_rounded, 'Text', 'Free-form text value'),
    _FieldTypeOption('number', Icons.pin_rounded, 'Number', 'Numeric value (e.g. story points)'),
    _FieldTypeOption('date', Icons.calendar_today_rounded, 'Date', 'ISO date value'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; _result = null; });
    try {
      final ctx = context.read<ContextNotifier>().state.context;
      final api = context.read<ApiService>();
      final result = await api.createProjectField(
        fieldName: _nameCtrl.text.trim(),
        fieldType: _fieldType,
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
    _nameCtrl.clear(); _fieldType = 'text';
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
              child: const Icon(Icons.add_chart_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('New Project Field'),
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
    final created = r['created'] as bool? ?? true;
    final fieldTypeOpt = _fieldTypes.firstWhere((t) => t.value == (r['field_type'] ?? _fieldType), orElse: () => _fieldTypes[0]);
    return FormSuccessCard(
      title: created ? 'Field created!' : 'Field already exists',
      subtitle: '"${r['field_name']}"',
      details: [
        SuccessDetailRow(
          icon: fieldTypeOpt.icon,
          label: 'Type',
          value: fieldTypeOpt.label,
          valueColor: AppTheme.accentLight,
        ),
      ],
      onBack: () => context.pop(),
      onCreateAnother: _reset,
      createAnotherLabel: 'New field',
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
            text: 'Add a custom field to your GitHub Project board. Use it with Set Task Fields.',
            icon: Icons.add_chart_rounded,
            colors: AppTheme.projectGradient,
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            FormErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          FormSectionCard(
            title: 'Field name',
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Field name *',
                  prefixIcon: Icon(Icons.text_fields_rounded, size: 18),
                  hintText: 'Story Points',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          FormSectionCard(
            title: 'Field type',
            children: [
              ..._fieldTypes.map((opt) => _TypeTile(
                option: opt,
                isSelected: _fieldType == opt.value,
                onTap: () => setState(() => _fieldType = opt.value),
              )),
            ],
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Create Field',
            icon: Icons.add_chart_rounded,
            isLoading: _isLoading,
            onPressed: _submit,
            colors: AppTheme.projectGradient,
          ),
        ],
      ),
    );
  }
}

class _FieldTypeOption {
  final String value;
  final IconData icon;
  final String label;
  final String description;
  const _FieldTypeOption(this.value, this.icon, this.label, this.description);
}

class _TypeTile extends StatelessWidget {
  final _FieldTypeOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeTile({required this.option, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.projectGradient[0].withValues(alpha: 0.12)
              : AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.projectGradient[0] : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.projectGradient[0].withValues(alpha: 0.2)
                    : AppTheme.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                option.icon,
                size: 18,
                color: isSelected ? AppTheme.projectGradient[0] : AppTheme.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    option.description,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF8E24AA)),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
