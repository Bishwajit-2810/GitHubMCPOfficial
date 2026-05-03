import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../utils/file_icons.dart';
import '../../widgets/app_error_widget.dart';

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
  bool _isGrid = false;

  String get _currentPath => _pathStack.last;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final ctx = context.read<ContextNotifier>().state.context;
      final api = context.read<ApiService>();
      final result = await api.listFiles(
        path: _currentPath,
        owner: ctx.selectedOwner,
        repo: ctx.selectedRepo,
      );
      final items =
          (result['items'] as List<dynamic>).cast<Map<String, dynamic>>();
      items.sort((a, b) {
        if (a['type'] == b['type']) {
          return (a['name'] as String).compareTo(b['name'] as String);
        }
        return a['type'] == 'dir' ? -1 : 1;
      });
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigate(String name) {
    final next = _currentPath.isEmpty ? name : '$_currentPath/$name';
    setState(() => _pathStack.add(next));
    _load();
  }

  void _navigateToBreadcrumb(int index) {
    if (index >= _pathStack.length - 1) return;
    setState(() => _pathStack.removeRange(index + 1, _pathStack.length));
    _load();
  }

  void _goUp() {
    if (_pathStack.length > 1) {
      setState(() => _pathStack.removeLast());
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context.watch<ContextNotifier>().state.context;
    final repo = ctx.selectedRepo ?? 'Repository';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            _pathStack.length > 1
                ? Icons.arrow_back_ios_new_rounded
                : Icons.arrow_back_ios_new_rounded,
            size: 18,
          ),
          onPressed: _pathStack.length > 1 ? _goUp : () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppTheme.repoGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder_open_rounded,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(repo, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
              size: 20,
            ),
            tooltip: _isGrid ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _isGrid = !_isGrid),
          ),
          IconButton(
            icon: const Icon(Icons.account_tree_outlined, size: 20),
            tooltip: 'Create Branch',
            onPressed: () => context.push('/branch/create'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => context.push('/files/create'),
        tooltip: 'New File',
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: Column(
        children: [
          _BreadcrumbBar(
            pathStack: _pathStack,
            onNavigate: _navigateToBreadcrumb,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: _buildContent(key: ValueKey('$_currentPath-$_isGrid')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent({Key? key}) {
    if (_isLoading) return _ShimmerList(key: key, isGrid: _isGrid);
    if (_error != null) {
      return AppErrorWidget(key: key, message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) return _EmptyDir(key: key);
    if (_isGrid) {
      return _FileGrid(
        key: key,
        items: _items,
        onNavigate: _navigate,
        onTapFile: _showFileSheet,
      );
    }
    return _FileList(
      key: key,
      items: _items,
      onNavigate: _navigate,
      onTapFile: _showFileSheet,
    );
  }

  void _showFileSheet(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FileInfoSheet(item: item),
    );
  }
}

// ── Breadcrumb navigation bar ─────────────────────────────────────────────────

class _BreadcrumbBar extends StatefulWidget {
  final List<String> pathStack;
  final void Function(int) onNavigate;

  const _BreadcrumbBar({required this.pathStack, required this.onNavigate});

  @override
  State<_BreadcrumbBar> createState() => _BreadcrumbBarState();
}

class _BreadcrumbBarState extends State<_BreadcrumbBar> {
  final _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(_BreadcrumbBar old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            for (int i = 0; i < widget.pathStack.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppTheme.textMuted),
                ),
              _BreadcrumbItem(
                label: i == 0
                    ? 'root'
                    : widget.pathStack[i].split('/').last,
                icon: i == 0 ? Icons.home_rounded : Icons.folder_rounded,
                isActive: i == widget.pathStack.length - 1,
                onTap: () => widget.onNavigate(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BreadcrumbItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _BreadcrumbItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.accent : AppTheme.textSecondary;
    return GestureDetector(
      onTap: isActive ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── File list view ─────────────────────────────────────────────────────────────

class _FileList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final void Function(String) onNavigate;
  final void Function(Map<String, dynamic>) onTapFile;

  const _FileList({
    super.key,
    required this.items,
    required this.onNavigate,
    required this.onTapFile,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final item = items[i];
        final isDir = item['type'] == 'dir';
        final name = item['name'] as String;
        final size = item['size'] as int?;
        final fs = fileStyleFor(name, isDir);

        return GestureDetector(
          onTap: isDir ? () => onNavigate(name) : () => onTapFile(item),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: fs.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(fs.icon, size: 20, color: fs.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!isDir && size != null)
                        Text(
                          formatFileSize(size),
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isDir)
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppTheme.textMuted)
                else if (fs.ext.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: fs.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      fs.ext.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        color: fs.color,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(
              delay: Duration(milliseconds: 25 * i),
              duration: const Duration(milliseconds: 200),
            )
            .slideX(begin: 0.06, curve: Curves.easeOut);
      },
    );
  }
}

// ── File grid view ─────────────────────────────────────────────────────────────

class _FileGrid extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final void Function(String) onNavigate;
  final void Function(Map<String, dynamic>) onTapFile;

  const _FileGrid({
    super.key,
    required this.items,
    required this.onNavigate,
    required this.onTapFile,
  });

  @override
  Widget build(BuildContext context) {
    final cols = MediaQuery.sizeOf(context).width > 600 ? 4 : 3;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: 0.82,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final isDir = item['type'] == 'dir';
        final name = item['name'] as String;
        final size = item['size'] as int?;
        final fs = fileStyleFor(name, isDir);

        return GestureDetector(
          onTap: isDir ? () => onNavigate(name) : () => onTapFile(item),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: fs.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(fs.icon, size: 24, color: fs.color),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isDir && size != null)
                  Text(
                    formatFileSize(size),
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textMuted),
                  ),
              ],
            ),
          )
              .animate()
              .fadeIn(
                delay: Duration(milliseconds: 20 * i),
                duration: const Duration(milliseconds: 200),
              )
              .scale(
                begin: const Offset(0.88, 0.88),
                curve: Curves.easeOut,
              ),
        );
      },
    );
  }
}

// ── File info bottom sheet ─────────────────────────────────────────────────────

class _FileInfoSheet extends StatelessWidget {
  final Map<String, dynamic> item;

  const _FileInfoSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String;
    final size = item['size'] as int?;
    final sha = item['sha'] as String?;
    final fs = fileStyleFor(name, false);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: fs.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(fs.icon, size: 28, color: fs.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: Theme.of(context).textTheme.titleSmall),
                      if (fs.ext.isNotEmpty)
                        Text(
                          '${fs.ext.toUpperCase()} file',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 12),
            if (size != null)
              _InfoRow(label: 'Size', value: formatFileSize(size)),
            if (sha != null)
              _InfoRow(label: 'SHA', value: sha.substring(0, 12)),
          ],
        ),
      ),
    );
  }
}

// ── Empty directory ───────────────────────────────────────────────────────────

class _EmptyDir extends StatelessWidget {
  const _EmptyDir({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(Icons.folder_open_rounded,
                size: 34, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          const Text('Empty directory',
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }
}

// ── Shimmer skeleton ──────────────────────────────────────────────────────────

class _ShimmerList extends StatelessWidget {
  final bool isGrid;

  const _ShimmerList({super.key, required this.isGrid});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surface,
      highlightColor: AppTheme.surfaceHigh,
      child: isGrid
          ? GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.82,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: 12,
              itemBuilder: (_, _) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: 8,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (_, _) => Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
