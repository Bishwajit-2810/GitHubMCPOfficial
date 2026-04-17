import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../widgets/app_loading.dart';

class AskCodebaseScreen extends StatefulWidget {
  const AskCodebaseScreen({super.key});

  @override
  State<AskCodebaseScreen> createState() => _AskCodebaseScreenState();
}

class _AskCodebaseScreenState extends State<AskCodebaseScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _ask() {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    final ctx = context.read<ContextNotifier>().state.context;
    context.read<RagNotifier>().ask(
          q,
          owner: ctx.selectedOwner,
          repo: ctx.selectedRepo,
        );
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RagNotifier>().state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask Codebase'),
        actions: [
          if (state.answer != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Clear',
              onPressed: () {
                _ctrl.clear();
                context.read<RagNotifier>().reset();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Builder(builder: (_) {
              if (state.isLoading) {
                return const AppLoading(message: 'Thinking…');
              }
              if (state.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                            size: 40),
                        const SizedBox(height: 12),
                        Text(state.error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                    ),
                  ),
                );
              }
              if (state.answer != null) {
                return SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Theme.of(context).colorScheme.outline),
                        ),
                        child: SelectableText(
                          state.answer!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      if (state.sources.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Sources',
                            style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: state.sources
                              .map((s) => Chip(
                                    label: Text(s),
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 56,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('Ask anything about the codebase',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                        'e.g. "How does auth work?" or "What env vars are required?"',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Ask a question…',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _ask(),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send_rounded),
                    onPressed: state.isLoading ? null : _ask,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
