import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/responsive.dart';

// ── Tool definitions ──────────────────────────────────────────────────────────

class _ToolInfo {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  const _ToolInfo(this.icon, this.title, this.subtitle, this.route);
}

class _ToolCategory {
  final String name;
  final IconData categoryIcon;
  final List<Color> gradient;
  final Color iconBg;
  final List<_ToolInfo> tools;
  const _ToolCategory({
    required this.name,
    required this.categoryIcon,
    required this.gradient,
    required this.iconBg,
    required this.tools,
  });
}

final _categories = [
  _ToolCategory(
    name: 'Repository',
    categoryIcon: Icons.folder_open_rounded,
    gradient: AppTheme.repoGradient,
    iconBg: const Color(0x331565C0),
    tools: const [
      _ToolInfo(Icons.folder_open_rounded, 'Files', 'Browse repository files', '/files'),
      _ToolInfo(Icons.upload_file_rounded, 'Create File', 'Commit a file to a branch', '/files/create'),
      _ToolInfo(Icons.account_tree_outlined, 'Branches', 'Create new branches', '/branch/create'),
      _ToolInfo(Icons.merge_rounded, 'Pull Requests', 'Create pull requests', '/pr/create'),
    ],
  ),
  _ToolCategory(
    name: 'Project Boards',
    categoryIcon: Icons.dashboard_rounded,
    gradient: AppTheme.projectGradient,
    iconBg: const Color(0x336A1B9A),
    tools: const [
      _ToolInfo(Icons.checklist_rounded, 'Tasks', 'View project board tasks', '/tasks'),
      _ToolInfo(Icons.person_add_outlined, 'Assign Task', 'Add assignees to issues', '/tasks/assign'),
      _ToolInfo(Icons.sync_alt_rounded, 'Update Status', 'Move tasks to new column', '/tasks/status'),
      _ToolInfo(Icons.add_chart_rounded, 'Create Field', 'Add custom project fields', '/project/field/create'),
      _ToolInfo(Icons.edit_note_rounded, 'Set Fields', 'Set custom field values', '/project/fields/set'),
    ],
  ),
  _ToolCategory(
    name: 'AI & RAG',
    categoryIcon: Icons.auto_awesome_rounded,
    gradient: AppTheme.aiGradient,
    iconBg: const Color(0x33BF360C),
    tools: const [
      _ToolInfo(Icons.chat_bubble_outline_rounded, 'Ask Codebase', 'Natural-language Q&A', '/ask'),
      _ToolInfo(Icons.manage_search_rounded, 'Explore Codebase', 'Browse files structurally', '/explore'),
    ],
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContextNotifier>().load();
    });
  }

  Future<void> _connectGitHub() async {
    final platform = kIsWeb ? 'web' : 'android';
    final state = '$platform:${DateTime.now().millisecondsSinceEpoch}';
    final uri = Uri.https('github.com', '/login/oauth/authorize', {
      'client_id': Constants.githubOAuthClientId,
      'scope': Constants.githubOAuthScope,
      'redirect_uri': Constants.githubOAuthRedirectUri,
      'state': state,
    });
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: uri.toString(),
        callbackUrlScheme: Constants.githubOAuthCallbackScheme,
      );
      final code = Uri.parse(result).queryParameters['code'];
      if (code != null && mounted) {
        await context.read<AuthNotifier>().connectGithub(
          code,
          redirectUri: Constants.githubOAuthRedirectUri,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GitHub connected successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GitHub connect cancelled: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>().state;
    final ctxState = context.watch<ContextNotifier>().state;
    final p = Responsive.pagePadding(context);

    return Scaffold(
      appBar: _buildAppBar(context, auth),
      body: MaxWidthBox(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: p, vertical: 20),
          children: [
            _HeroHeader(auth: auth, ctxState: ctxState),
            const SizedBox(height: 20),
            if (!auth.githubConnected) ...[
              _ConnectBanner(onConnect: _connectGitHub, isLoading: auth.isLoading),
              const SizedBox(height: 24),
            ],
            ..._categories.asMap().entries.map((entry) {
              final i = entry.key;
              final cat = entry.value;
              return _CategorySection(
                category: cat,
                enabled: auth.githubConnected,
                sectionIndex: i,
              );
            }),
            const SizedBox(height: 24),
            if (auth.firebaseUser != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Signed in as ${auth.firebaseUser!.email ?? auth.firebaseUser!.displayName ?? 'unknown'}',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, dynamic auth) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppTheme.greenGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.hub_rounded, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text('GitHub MCP'),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Repo & Project',
          onPressed: () => context.push('/settings'),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Sign out',
          onPressed: () => context.read<AuthNotifier>().signOut(),
        ),
      ],
    );
  }
}

// ── Hero header ───────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final dynamic auth;
  final dynamic ctxState;
  const _HeroHeader({required this.auth, required this.ctxState});

  @override
  Widget build(BuildContext context) {
    final ctx = ctxState.context;
    final name = auth.firebaseUser?.displayName?.split(' ').first
        ?? auth.firebaseUser?.email?.split('@').first
        ?? 'there';
    final hasCtx = ctx.selectedOwner != null;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF161B22), Color(0xFF1C2128)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppTheme.greenGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'G',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, $name',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: auth.githubConnected
                                ? AppTheme.accentLight
                                : AppTheme.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          auth.githubConnected
                              ? 'GitHub connected'
                              : 'GitHub not connected',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasCtx || ctxState.isLoading) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            ctxState.isLoading
                ? const SizedBox(
                    height: 16, width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    children: [
                      const Icon(Icons.folder_outlined, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        '${ctx.selectedOwner}/${ctx.selectedRepo}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (ctx.selectedProjectNumber != null) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.projectGradient[0].withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.projectGradient[0].withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'Project #${ctx.selectedProjectNumber}',
                            style: const TextStyle(
                              color: Color(0xFFCE93D8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ] else ...[
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('Choose a repo to get started'),
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.1, curve: Curves.easeOut);
  }
}

// ── Connect banner ────────────────────────────────────────────────────────────

class _ConnectBanner extends StatelessWidget {
  final VoidCallback onConnect;
  final bool isLoading;
  const _ConnectBanner({required this.onConnect, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.repoGradient[0].withValues(alpha: 0.15),
            AppTheme.repoGradient[1].withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.repoGradient[0].withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.repoGradient[0].withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.link_off, color: Color(0xFF90CAF9), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connect GitHub',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Required to access all tools (repo, read:org, project)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: isLoading ? null : onConnect,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              backgroundColor: AppTheme.repoGradient[0],
            ),
            child: isLoading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Connect'),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 150.ms, duration: 350.ms)
        .slideY(begin: 0.2, curve: Curves.easeOut);
  }
}

// ── Category section ──────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final _ToolCategory category;
  final bool enabled;
  final int sectionIndex;
  const _CategorySection({
    required this.category,
    required this.enabled,
    required this.sectionIndex,
  });

  @override
  Widget build(BuildContext context) {
    final cols = Responsive.gridCols(context);
    final baseDelay = sectionIndex * 80;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: category.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(category.categoryIcon,
                    size: 15, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(
                category.name,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(letterSpacing: 0.3),
              ),
            ],
          )
              .animate()
              .fadeIn(
                  delay: Duration(milliseconds: baseDelay),
                  duration: 300.ms)
              .slideX(begin: -0.15, curve: Curves.easeOut),
          const SizedBox(height: 12),

          // Tool grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              childAspectRatio: cols == 1 ? 4.0 : 1.55,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: category.tools.length,
            itemBuilder: (context, i) {
              return _ToolTile(
                tool: category.tools[i],
                gradient: category.gradient,
                iconBg: category.iconBg,
                enabled: enabled,
                animDelay: Duration(
                    milliseconds: baseDelay + 60 + i * 50),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Tool tile ─────────────────────────────────────────────────────────────────

class _ToolTile extends StatefulWidget {
  final _ToolInfo tool;
  final List<Color> gradient;
  final Color iconBg;
  final bool enabled;
  final Duration animDelay;
  const _ToolTile({
    required this.tool,
    required this.gradient,
    required this.iconBg,
    required this.enabled,
    required this.animDelay,
  });

  @override
  State<_ToolTile> createState() => _ToolTileState();
}

class _ToolTileState extends State<_ToolTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cols = Responsive.gridCols(context);
    final compact = cols == 1;

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled
            ? () => context.push(widget.tool.route)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered && widget.enabled
                  ? widget.gradient[0].withValues(alpha: 0.6)
                  : AppTheme.border,
            ),
            boxShadow: _hovered && widget.enabled
                ? [
                    BoxShadow(
                      color: widget.gradient[0].withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 14),
            child: compact
                ? _buildCompactLayout()
                : _buildGridLayout(),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: widget.animDelay, duration: 300.ms)
        .slideY(begin: 0.25, curve: Curves.easeOut);
  }

  Widget _buildGridLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.enabled
                    ? widget.iconBg
                    : AppTheme.textMuted.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.tool.icon,
                size: 18,
                color: widget.enabled
                    ? widget.gradient[0]
                    : AppTheme.textMuted,
              ),
            ),
            Icon(
              widget.enabled
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.lock_outline_rounded,
              size: 13,
              color: widget.enabled
                  ? AppTheme.textSecondary
                  : AppTheme.textMuted,
            ),
          ],
        ),
        const Spacer(),
        Text(
          widget.tool.title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: widget.enabled
                ? AppTheme.textPrimary
                : AppTheme.textMuted,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          widget.tool.subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: widget.enabled
                ? AppTheme.textSecondary
                : AppTheme.textMuted,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: widget.enabled
                ? widget.iconBg
                : AppTheme.textMuted.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            widget.tool.icon,
            size: 18,
            color: widget.enabled ? widget.gradient[0] : AppTheme.textMuted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.tool.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: widget.enabled
                      ? AppTheme.textPrimary
                      : AppTheme.textMuted,
                ),
              ),
              Text(
                widget.tool.subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Icon(
          widget.enabled
              ? Icons.chevron_right_rounded
              : Icons.lock_outline_rounded,
          color: widget.enabled ? AppTheme.textSecondary : AppTheme.textMuted,
          size: 18,
        ),
      ],
    );
  }
}
