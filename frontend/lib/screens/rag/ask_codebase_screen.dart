import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../utils/file_icons.dart';
import '../../widgets/bouncing_dots.dart';

class AskCodebaseScreen extends StatefulWidget {
  const AskCodebaseScreen({super.key});

  @override
  State<AskCodebaseScreen> createState() => _AskCodebaseScreenState();
}

class _AskCodebaseScreenState extends State<AskCodebaseScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _lastQuestion;

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _ask() {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _lastQuestion = q);
    _ctrl.clear();
    final ctx = context.read<ContextNotifier>().state.context;
    context.read<RagNotifier>().ask(
          q,
          owner: ctx.selectedOwner,
          repo: ctx.selectedRepo,
        );
    FocusScope.of(context).unfocus();
  }

  void _reset() {
    _ctrl.clear();
    setState(() => _lastQuestion = null);
    context.read<RagNotifier>().reset();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RagNotifier>().state;

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
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Ask Codebase'),
          ],
        ),
        actions: [
          if (state.answer != null || _lastQuestion != null)
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
          Expanded(child: _buildBody(state)),
          _ChatInputBar(
            ctrl: _ctrl,
            isLoading: state.isLoading,
            onSend: _ask,
            hintText: 'Ask anything about the codebase…',
          ),
        ],
      ),
    );
  }

  Widget _buildBody(RagState state) {
    if (state.isLoading) {
      return _ThinkingView(question: _lastQuestion)
          .animate()
          .fadeIn(duration: 200.ms);
    }
    if (state.error != null) {
      return _ErrorView(error: state.error!);
    }
    if (state.answer != null) {
      return _AnswerView(
        question: _lastQuestion ?? '',
        answer: state.answer!,
        sources: state.sources,
        scrollCtrl: _scrollCtrl,
      );
    }
    return _EmptyHint(onSuggestion: (s) => _ctrl.text = s);
  }
}

// ── Thinking animation ─────────────────────────────────────────────────────────

class _ThinkingView extends StatelessWidget {
  final String? question;

  const _ThinkingView({this.question});

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
              const _AiAvatar(),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const BouncingDots(label: 'Thinking…'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Answer view ────────────────────────────────────────────────────────────────

class _AnswerView extends StatelessWidget {
  final String question;
  final String answer;
  final List<String> sources;
  final ScrollController scrollCtrl;

  const _AnswerView({
    required this.question,
    required this.answer,
    required this.sources,
    required this.scrollCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      em: theme.textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
      tableHead: theme.textTheme.bodySmall
          ?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
      tableBody: theme.textTheme.bodySmall,
      tableBorder: TableBorder.all(color: AppTheme.border),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _AiAvatar(),
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
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.source_rounded,
                          size: 13, color: AppTheme.textMuted),
                      SizedBox(width: 6),
                      Text(
                        'SOURCES',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: sources.map((s) {
                      final fileName = s.split('/').last;
                      final fs = fileStyleFor(fileName, false);
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
                              s,
                              style: TextStyle(
                                  fontSize: 11, color: fs.color),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
          ],
        ],
      ),
    );
  }
}

// ── Empty hint with suggestion chips ─────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final void Function(String) onSuggestion;

  const _EmptyHint({required this.onSuggestion});

  static const _suggestions = [
    'How does authentication work?',
    'What are the main API endpoints?',
    'How is the database structured?',
    'What env vars are required?',
    'How do MCP tools get registered?',
    'Explain the data flow end-to-end',
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
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 34, color: Colors.white),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            const Text(
              'Ask anything about the codebase',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 80.ms),
            const SizedBox(height: 6),
            const Text(
              'Powered by RAG + Groq LLM — answers with source references',
              style:
                  TextStyle(color: AppTheme.textMuted, fontSize: 12),
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
                        const Icon(Icons.lightbulb_outline_rounded,
                            size: 13, color: AppTheme.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          e.value,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
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

class _ErrorView extends StatelessWidget {
  final String error;

  const _ErrorView({required this.error});

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
                style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ).animate().fadeIn(),
    );
  }
}

// ── Chat input bar ─────────────────────────────────────────────────────────────

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
                hintStyle: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 14),
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
                  borderSide: const BorderSide(
                      color: AppTheme.accent, width: 1.5),
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
                    : Icons.send_rounded,
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

// ── Shared bubble widgets ─────────────────────────────────────────────────────

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
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
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

class _AiAvatar extends StatelessWidget {
  const _AiAvatar();

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
      child:
          const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
    );
  }
}
