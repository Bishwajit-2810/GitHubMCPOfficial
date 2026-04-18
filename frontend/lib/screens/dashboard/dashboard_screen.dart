import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../providers/providers.dart';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('GitHub connect cancelled: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>().state;
    final ctxState = context.watch<ContextNotifier>().state;
    final ctx = ctxState.context;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GitHub MCP'),
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ContextBanner(ctx: ctx, isLoading: ctxState.isLoading),
          const SizedBox(height: 16),

          if (!auth.githubConnected) ...[
            _ConnectCard(onConnect: _connectGitHub, isLoading: auth.isLoading),
            const SizedBox(height: 16),
          ],

          _FeatureTile(
            icon: Icons.checklist_rounded,
            title: 'Tasks',
            subtitle: 'View and manage GitHub project board tasks',
            enabled: auth.githubConnected,
            onTap: () => context.push('/tasks'),
          ),
          const SizedBox(height: 12),
          _FeatureTile(
            icon: Icons.folder_open_rounded,
            title: 'Files',
            subtitle: 'Browse repository files and directories',
            enabled: auth.githubConnected,
            onTap: () => context.push('/files'),
          ),
          const SizedBox(height: 12),
          _FeatureTile(
            icon: Icons.merge_rounded,
            title: 'Pull Requests',
            subtitle: 'Create pull requests from any branch',
            enabled: auth.githubConnected,
            onTap: () => context.push('/pr/create'),
          ),
          const SizedBox(height: 12),
          _FeatureTile(
            icon: Icons.account_tree_outlined,
            title: 'Branches',
            subtitle: 'Create new branches from any source',
            enabled: auth.githubConnected,
            onTap: () => context.push('/branch/create'),
          ),
          const SizedBox(height: 12),
          _FeatureTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Ask Codebase',
            subtitle: 'Natural-language Q&A over the indexed repo',
            enabled: auth.githubConnected,
            onTap: () => context.push('/ask'),
          ),
          const SizedBox(height: 24),

          if (auth.firebaseUser != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Signed in as ${auth.firebaseUser!.email ?? auth.firebaseUser!.displayName ?? 'unknown'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _ContextBanner extends StatelessWidget {
  final dynamic ctx;
  final bool isLoading;

  const _ContextBanner({required this.ctx, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final hasContext = ctx.selectedOwner != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 20,
                    color: hasContext
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: hasContext
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${ctx.selectedOwner}/${ctx.selectedRepo}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (ctx.selectedProjectNumber != null)
                                Text(
                                  'Project #${ctx.selectedProjectNumber}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          )
                        : Text(
                            'No repo selected — tap Settings to choose one',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  final VoidCallback onConnect;
  final bool isLoading;

  const _ConnectCard({required this.onConnect, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link_off, size: 18),
                const SizedBox(width: 8),
                Text(
                  'GitHub not connected',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your GitHub account to enable task management and codebase Q&A (requires repo, read:org, project scopes).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.link),
                label: const Text('Connect GitHub'),
                onPressed: isLoading ? null : onConnect,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: enabled
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: enabled
            ? const Icon(Icons.chevron_right)
            : const Icon(Icons.lock_outline, size: 18),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
