import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/api_error.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../widgets/form_widgets.dart';

class SetTaskFieldsScreen extends StatefulWidget {
  const SetTaskFieldsScreen({super.key});

  @override
  State<SetTaskFieldsScreen> createState() => _SetTaskFieldsScreenState();
}

class _FieldEntry {
  final nameCtrl = TextEditingController();
  final valueCtrl = TextEditingController();
  void dispose() {
    nameCtrl.dispose();
    valueCtrl.dispose();
  }
}

class _SetTaskFieldsScreenState extends State<SetTaskFieldsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemIdCtrl = TextEditingController();
  final List<_FieldEntry> _entries = [_FieldEntry()];
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _itemIdCtrl.dispose();
    for (final e in _entries) { e.dispose(); }
    super.dispose();
  }

  void _addEntry() => setState(() => _entries.add(_FieldEntry()));

  void _removeEntry(int i) {
    if (_entries.length == 1) return;
    setState(() {
      _entries[i].dispose();
      _entries.removeAt(i);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; _result = null; });
    try {
      final ctx = context.read<ContextNotifier>().state.context;
      final api = context.read<ApiService>();
      final fields = <String, dynamic>{
        for (final e in _entries)
          if (e.nameCtrl.text.trim().isNotEmpty)
            e.nameCtrl.text.trim(): e.valueCtrl.text.trim(),
      };
      final result = await api.setTaskFields(
        itemId: _itemIdCtrl.text.trim(),
        fields: fields,
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

  void _reset() {
    for (final e in _entries) { e.dispose(); }
    setState(() {
      _result = null; _error = null;
      _itemIdCtrl.clear();
      _entries.clear();
      _entries.add(_FieldEntry());
    });
  }

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
              child: const Icon(Icons.edit_note_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Set Task Fields'),
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
    final updated = (_result!['updated_fields'] as List<dynamic>?)?.join(', ') ?? '';
    return FormSuccessCard(
      title: 'Fields updated!',
      subtitle: updated.isNotEmpty ? updated : null,
      details: [
        SuccessDetailRow(
          icon: Icons.check_circle_outline_rounded,
          label: 'Updated',
          value: updated.isNotEmpty ? updated : '–',
          valueColor: AppTheme.accentLight,
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
            text: 'Set custom field values on a project task. Get the PVTI_ item ID from the Tasks screen.',
            icon: Icons.edit_note_rounded,
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
            title: 'Fields',
            children: [
              ...List.generate(_entries.length, (i) => _buildFieldRow(i)),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _addEntry,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add field'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8E24AA),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Set Fields',
            icon: Icons.edit_note_rounded,
            isLoading: _isLoading,
            onPressed: _submit,
            colors: AppTheme.projectGradient,
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow(int i) {
    final e = _entries[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 14, right: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: e.nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Field name',
                hintText: 'Story Points',
                isDense: true,
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: e.valueCtrl,
              decoration: const InputDecoration(
                labelText: 'Value',
                hintText: '8',
                isDense: true,
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
          ),
          if (_entries.length > 1)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppTheme.error),
              onPressed: () => _removeEntry(i),
              padding: const EdgeInsets.only(top: 10, left: 6),
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
