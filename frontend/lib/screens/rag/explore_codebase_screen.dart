import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/api_error.dart';
import '../../services/api_service.dart';
import '../../utils/file_icons.dart';
import '../../widgets/bouncing_dots.dart';

class ExploreCodebaseScreen extends StatefulWidget {
  const ExploreCodebaseScreen({super.key});

  @override
  State<ExploreCodebaseScreen> createState() =>
      _ExploreCodebaseScreenState();
}

class _ExploreCodebaseScreenState extends State<ExploreCodebaseScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _result;
  String? _lastQuestion;

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _explore() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _lastQuestion = q;
      _isLoading = true;
      _error = null;
      _result = null;
    });
    _ctrl.clear();
    FocusScope.of(context).unfocus();
    try {
      final api = context.read<ApiService>();
      final result = await api.exploreCodebase(query: q);
      if (mounted) setState(() { _result = result; _isLoading = false; });
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _reset() {
    _ctrl.clear();
    setState(() {
      _result = null;
      _error = null;
      _lastQuestion = null;
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
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppTheme.aiGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.manage_search_rounded,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Explore Codebase'),
          ],
        ),
        actions: [
          if (_result != null || _lastQuestion != null)
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New'),
              onPressed: _reset,
              style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _ChatInputBar(
            ctrl: _ctrl,
            isLoading: _isLoading,
            onSend: _explore,
            hintText: 'Explore the repository structure…',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _ExploreThinkingView(question: _lastQuestion)
          .animate()
          .fadeIn(duration: 200.ms);
    }
    if (_error != null) {
      return _ExploreErrorView(
          error: _error!, onRetry: _explore);
    }
    if (_result != null) {
      return _ExploreResultView(
        question: _lastQuestion ?? '',
        result: _result!,
        scrollCtrl: _scrollCtrl,
      );
    }
    return _ExploreEmptyHint(
        onSuggestion: (s) => _ctrl.text = s);
  }
}

// ── Thinking view ──────────────────────────────────────────────────────────────

class _ExploreThinkingView extends StatelessWidget {
  final String? question;

  const _ExploreThinkingView({this.question});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (question != null) ...[
            _QuestionBubble(text: question!),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExploreAvatar(),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const BouncingDots(label: 'Exploring…'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Result view ────────────────────────────────────────────────────────────────

class _ExploreResultView extends StatelessWidget {
  final String question;
  final Map<String, dynamic> result;
  final ScrollController scrollCtrl;

  const _ExploreResultView({
    required this.question,
    required this.result,
    required this.scrollCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answer = result['answer'] as String? ?? '';
    final totalFiles = result['total_files'] as int? ?? 0;
    final fileSummary =
        result['file_summary'] as Map<String, dynamic>? ?? {};
    final images = result['images'] as List<dynamic>? ?? [];

    final mdStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(height: 1.65),
      h1: theme.textTheme.titleLarge,
      h2: theme.textTheme.titleMedium,
      h3: theme.textTheme.titleSmall,
      code: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        color: AppTheme.accentLight,
        backgroundColor: AppTheme.bg,
      ),
      codeblockDecoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquoteDecoration: const BoxDecoration(
        color: AppTheme.surfaceHigh,
        border: Border(left: BorderSide(color: AppTheme.accent, width: 3)),
      ),
      blockquotePadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      strong: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
    );

    return SingleChildScrollView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (question.isNotEmpty) ...[
            _QuestionBubble(text: question),
            const SizedBox(height: 16),
          ],

          // Answer bubble
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExploreAvatar(),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: MarkdownBody(
                    data: answer,
                    selectable: true,
                    styleSheet: mdStyle,
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08),

          // Stats cards
          if (totalFiles > 0) ...[
            const SizedBox(height: 14),
            _StatsPanel(
              totalFiles: totalFiles,
              fileSummary: fileSummary,
            ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
          ],

          // Images list
          if (images.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ImagesList(images: images)
                .animate()
                .fadeIn(delay: 250.ms, duration: 300.ms),
          ],
        ],
      ),
    );
  }
}

// ── Stats panel ────────────────────────────────────────────────────────────────

class _StatsPanel extends StatelessWidget {
  final int totalFiles;
  final Map<String, dynamic> fileSummary;

  const _StatsPanel(
      {required this.totalFiles, required this.fileSummary});

  @override
  Widget build(BuildContext context) {
    final sorted = fileSummary.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded,
                  size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                '$totalFiles files indexed',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (sorted.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: sorted.take(12).map((e) {
                final fs = fileStyleFor('file.${e.key}', false);
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: fs.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: fs.color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(fs.icon, size: 12, color: fs.color),
                      const SizedBox(width: 5),
                      Text(
                        '.${e.key}  ×${e.value}',
                        style: TextStyle(
                            fontSize: 11, color: fs.color),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Images list ────────────────────────────────────────────────────────────────

class _ImagesList extends StatelessWidget {
  final List<dynamic> images;

  const _ImagesList({required this.images});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_rounded,
                  size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                'Images (${images.length})',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...images.take(10).map((img) {
            final m = img as Map<String, dynamic>;
            final name = m['filename'] as String? ?? '';
            final folder = m['folder'] as String? ?? '';
            final fs = fileStyleFor(name, false);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(fs.icon, size: 14, color: fs.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    folder,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Empty hint ─────────────────────────────────────────────────────────────────

class _ExploreEmptyHint extends StatelessWidget {
  final void Function(String) onSuggestion;

  const _ExploreEmptyHint({required this.onSuggestion});

  static const _suggestions = [
    'How many Python files are there?',
    'List all image assets',
    'What are the top-level directories?',
    'How many lines of Dart code?',
    'Find all config files',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppTheme.aiGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.manage_search_rounded,
                  size: 36, color: Colors.white),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            const Text(
              'Explore repository structure',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 80.ms),
            const SizedBox(height: 6),
            const Text(
              'Query file counts, types, structure and assets',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 120.ms),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _suggestions.asMap().entries.map((e) {
                return GestureDetector(
                  onTap: () => onSuggestion(e.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_rounded,
                            size: 13, color: AppTheme.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          e.value,
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(
                        delay: Duration(milliseconds: 180 + e.key * 55),
                        duration: 250.ms,
                      ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────────────

class _ExploreErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ExploreErrorView(
      {required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 32, color: AppTheme.error),
            ),
            const SizedBox(height: 16),
            Text(error,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try again'),
            ),
          ],
        ),
      ).animate().fadeIn(),
    );
  }
}

// ── Explore avatar ─────────────────────────────────────────────────────────────

class _ExploreAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppTheme.aiGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.manage_search_rounded,
          size: 16, color: Colors.white),
    );
  }
}

// ── Shared chat widgets (local copies) ────────────────────────────────────────

class _QuestionBubble extends StatelessWidget {
  final String text;
  const _QuestionBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border),
          ),
          child: const Icon(Icons.person_rounded,
              size: 18, color: AppTheme.textSecondary),
        ),
      ],
    ).animate().fadeIn(duration: 250.ms).slideX(begin: 0.08);
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isLoading;
  final VoidCallback onSend;
  final String hintText;

  const _ChatInputBar({
    required this.ctrl,
    required this.isLoading,
    required this.onSend,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle:
                    const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                filled: true,
                fillColor: AppTheme.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: AppTheme.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              maxLines: 4,
              minLines: 1,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLoading
                    ? [AppTheme.surfaceHigh, AppTheme.surfaceHigh]
                    : AppTheme.aiGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: IconButton(
              icon: Icon(
                isLoading
                    ? Icons.hourglass_top_rounded
                    : Icons.search_rounded,
                size: 20,
                color: isLoading ? AppTheme.textMuted : Colors.white,
              ),
              onPressed: isLoading ? null : onSend,
            ),
          ),
        ],
      ),
    );
  }
}
