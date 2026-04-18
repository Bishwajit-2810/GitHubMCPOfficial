import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final List<String> _pathStack = [''];
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  String get _currentPath => _pathStack.last;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final ctx = context.read<ContextNotifier>().state.context;
      final api = context.read<ApiService>();
      final result = await api.listFiles(
        path: _currentPath,
        owner: ctx.selectedOwner,
        repo: ctx.selectedRepo,
      );
      final items = (result['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      items.sort((a, b) {
        if (a['type'] == b['type']) return (a['name'] as String).compareTo(b['name'] as String);
        return a['type'] == 'dir' ? -1 : 1;
      });
      setState(() { _items = items; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _navigate(String name) {
    final next = _currentPath.isEmpty ? name : '$_currentPath/$name';
    setState(() { _pathStack.add(next); });
    _load();
  }

  void _goUp() {
    if (_pathStack.length > 1) {
      setState(() { _pathStack.removeLast(); });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context.watch<ContextNotifier>().state.context;
    final repo = ctx.selectedRepo ?? '(no repo)';
    final displayPath = _currentPath.isEmpty ? '/' : '/$_currentPath';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Files'),
            Text(repo, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        leading: _pathStack.length > 1
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goUp)
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Create Branch',
            onPressed: () => context.push('/branch/create'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Icon(Icons.folder_open, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayPath,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _load, child: const Text('Retry')),
                            ],
                          ),
                        ),
                      )
                    : _items.isEmpty
                        ? const Center(child: Text('Empty directory'))
                        : ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (context, i) {
                              final item = _items[i];
                              final isDir = item['type'] == 'dir';
                              return ListTile(
                                leading: Icon(
                                  isDir ? Icons.folder_rounded : Icons.insert_drive_file_outlined,
                                  color: isDir
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                title: Text(item['name'] as String),
                                subtitle: isDir
                                    ? null
                                    : Text(_formatSize(item['size'] as int?)),
                                trailing: isDir ? const Icon(Icons.chevron_right) : null,
                                onTap: isDir ? () => _navigate(item['name'] as String) : null,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
