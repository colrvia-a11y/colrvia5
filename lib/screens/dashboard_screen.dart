// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/project_service.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';
import '../models/project.dart';
import '../widgets/auth_dialog.dart';
import 'roller_screen.dart';
import 'explore_screen.dart';
import 'color_story_wizard_screen.dart';
import 'visualizer_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'library_screen.dart';
import 'package:color_canvas/utils/debug_logger.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _reduceMotion = false;
  bool _hasCheckedReduceMotion = false;

  @override
  void initState() {
    super.initState();
    Debug.info('DashboardScreen', 'initState', 'Component initializing');
    // Track dashboard opened
    AnalyticsService.instance.logDashboardOpened();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Debug.info('DashboardScreen', 'didChangeDependencies', 'Dependencies changed, hasCheckedReduceMotion: $_hasCheckedReduceMotion');
    // Only check reduce motion once to prevent infinite MediaQuery access
    if (!_hasCheckedReduceMotion) {
      _checkReduceMotion();
      _hasCheckedReduceMotion = true;
    }
  }

  void _checkReduceMotion() {
    Debug.mediaQuery('DashboardScreen', '_checkReduceMotion', 'maybeDisableAnimationsOf');
    final newReduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduceMotion != newReduceMotion) {
      Debug.info('DashboardScreen', '_checkReduceMotion', 'Reduce motion changed: $_reduceMotion -> $newReduceMotion');
      _reduceMotion = newReduceMotion;
    }
  }

  Stream<List<ProjectDoc>> _getProjectsStream() {
    return ProjectService.myProjectsStream();
  }

  void _showSignInPrompt() {
    showDialog(
      context: context,
      builder: (context) => AuthDialog(
        onAuthSuccess: () {
          Navigator.pop(context);
          // No need to call setState - StreamBuilder will automatically rebuild
          // when FirebaseService.currentUser changes
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Debug.build('DashboardScreen', 'build', details: 'reduceMotion: $_reduceMotion, hasCheckedReduceMotion: $_hasCheckedReduceMotion');
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800);
    final subtle = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(.6));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Semantics(
        label: 'Dashboard screen',
        child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text('Colrvia', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const Spacer(),
                    // Change to a real Settings button + proper tooltip
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Settings',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Hero CTA
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              sliver: SliverToBoxAdapter(child: _HeroStartCard(titleStyle: titleStyle, subtle: subtle, reduceMotion: _reduceMotion)),
            ),

            // Funnel diagram
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              sliver: SliverToBoxAdapter(child: _FunnelDiagram()),
            ),

            // Active projects
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Semantics(
                  header: true,
                  label: 'Your Color Stories section',
                  child: Text('Your Color Stories', style: titleStyle),
                ),
              ),
            ),

            StreamBuilder<List<ProjectDoc>>(
              stream: _getProjectsStream(),
              builder: (context, snapshot) {
                // Show sign-in prompt if not authenticated
                if (FirebaseService.currentUser == null) {
                  return SliverToBoxAdapter(child: _SignInPromptCard(onSignIn: _showSignInPrompt));
                }
                
                final projects = snapshot.data ?? const <ProjectDoc>[];
                if (snapshot.connectionState == ConnectionState.waiting && projects.isEmpty) {
                  return SliverToBoxAdapter(child: _ProjectsSkeleton());
                }
                if (projects.isEmpty) {
                  return SliverToBoxAdapter(child: _EmptyProjects());
                }
                return SliverList.separated(
                  itemCount: projects.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => Semantics(
                    label: 'Project ${projects[i].title}, ${projects[i].funnelStage.name} stage',
                    button: true,
                    child: _ProjectCard(projects[i]),
                  ),
                );
              },
            ),

            // Helpful pills
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              sliver: SliverToBoxAdapter(child: _HelpfulPills()),
            ),

            // Library Section
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Library',
                  style: titleStyle?.copyWith(fontSize: 20),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              sliver: SliverToBoxAdapter(child: _LibrarySection()),
            ),

            // Support & Info Section
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Support & Info',
                  style: titleStyle?.copyWith(fontSize: 20),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              sliver: SliverToBoxAdapter(child: _SupportInfoSection()),
            ),

            // User Profile Section
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              sliver: SliverToBoxAdapter(child: _UserProfileSection()),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SupportInfoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildMenuItem(
          context,
          icon: Icons.auto_awesome,
          title: "What's New",
          onTap: () => _showComingSoon(context, "What's New"),
        ),
        _buildMenuItem(
          context,
          icon: Icons.chat_bubble_outline,
          title: 'Feedback',
          onTap: () => _showComingSoon(context, 'Feedback'),
        ),
        _buildMenuItem(
          context,
          icon: Icons.help_outline,
          title: 'FAQ',
          onTap: () => _showComingSoon(context, 'FAQ'),
        ),
        _buildMenuItem(
          context,
          icon: Icons.support_agent,
          title: 'Support',
          onTap: () => _showComingSoon(context, 'Support'),
        ),
        _buildMenuItem(
          context,
          icon: Icons.gavel_outlined,
          title: 'Legal',
          onTap: () => _showComingSoon(context, 'Legal'),
        ),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _UserProfileSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseService.currentUser;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(.1),
        ),
      ),
      child: Column(
        children: [
          if (user != null) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primary.withOpacity(.2),
                  child: Text(
                    user.email?.substring(0, 1).toUpperCase() ?? 'U',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.email ?? 'User',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Signed in',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(.6),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await FirebaseService.signOut();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Signed out successfully'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error signing out: $e')),
                        );
                      }
                    }
                  },
                  child: Text(
                    'Sign out',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.outline.withOpacity(.2),
                  child: Icon(
                    Icons.person_outline,
                    color: theme.colorScheme.onSurface.withOpacity(.7),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Not signed in',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Sign in to sync your projects',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(.6),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Sign in',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          // Version info
          const SizedBox(height: 12),
          Text(
            'Version 1.0.0',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibrarySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your saved palettes and color stories',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LibraryQuickAccessButton(
                  icon: Icons.palette_outlined,
                  title: 'Palettes',
                  onTap: () => _openLibraryWithFilter(context, LibraryFilter.palettes),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LibraryQuickAccessButton(
                  icon: Icons.auto_stories_outlined,
                  title: 'Stories',
                  onTap: () => _openLibraryWithFilter(context, LibraryFilter.stories),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openLibraryWithFilter(context, LibraryFilter.all),
              icon: const Icon(Icons.library_books_outlined),
              label: const Text('View All'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openLibraryWithFilter(BuildContext context, LibraryFilter filter) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibraryScreen(initialFilter: filter),
      ),
    );
  }
}

class _LibraryQuickAccessButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _LibraryQuickAccessButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStartCard extends StatelessWidget {
  const _HeroStartCard({required this.titleStyle, required this.subtle, required this.reduceMotion});
  final TextStyle? titleStyle;
  final TextStyle? subtle;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Start a new color story. Build from scratch or explore inspirations',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(.6),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          header: true,
          label: 'Start a Color Story',
          child: Text('Start a Color Story', style: titleStyle),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: 'Build from scratch or explore inspirations. You can always change your mind later.',
          child: Text('Build from scratch or explore inspirations. You can always change your mind later.', style: subtle),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Choose how to start your color story',
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            _ActionChipBig(
              icon: Icons.palette_outlined,
              label: 'Build',
              semanticLabel: 'Build palette from scratch',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RollerScreen())),
            ),
            _ActionChipBig(
              icon: Icons.explore_outlined,
              label: 'Explore',
              semanticLabel: 'Explore color inspirations',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreScreen())),
            ),
          ]),
        ),
      ]),
      ),
    );
  }
}

class _FunnelDiagram extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: const [
              // Build -> Story -> Visualize -> Share
              _FunnelChip(label: 'Build', icon: Icons.palette_outlined, active: true),
              Icon(Icons.arrow_forward_ios, size: 14),
              _FunnelChip(label: 'Story', icon: Icons.menu_book_outlined),
              Icon(Icons.arrow_forward_ios, size: 14),
              _FunnelChip(label: 'Visualize', icon: Icons.chair_outlined),
              Icon(Icons.arrow_forward_ios, size: 14),
              _FunnelChip(label: 'Share', icon: Icons.ios_share_outlined),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          label: 'How it works help',
          button: true,
          child: InkWell(
            onTap: () => _showHowItWorksSheet(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.help_outline,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(.7),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showHowItWorksSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _HowItWorksSheet(),
    );
  }
}

class _FunnelChip extends StatelessWidget {
  const _FunnelChip({required this.label, required this.icon, this.active = false});
  final String label;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label stage${active ? ', currently active' : ''}',
      child: Chip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        side: active ? BorderSide(color: theme.colorScheme.primary) : null,
        backgroundColor: active ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceVariant.withOpacity(.5),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard(this.p);
  final ProjectDoc p;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = {
      FunnelStage.build: 'Building',
      FunnelStage.story: 'Story drafted',
      FunnelStage.visualize: 'Visualizer ready',
      FunnelStage.share: 'Shared',
    }[p.funnelStage]!;

    final chips = <Widget>[];
    if ((p.roomType ?? '').isNotEmpty) {
      chips.add(Chip(label: Text(p.roomType!), visualDensity: VisualDensity.compact));
    }
    if ((p.styleTag ?? '').isNotEmpty) {
      chips.add(Chip(label: Text(p.styleTag!), visualDensity: VisualDensity.compact));
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Text(p.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(status),
        const SizedBox(height: 4),
        if (chips.isNotEmpty) Wrap(spacing: 6, runSpacing: -6, children: chips),
        const SizedBox(height: 4),
        Text('Updated ${_timeAgo(p.updatedAt)}', style: theme.textTheme.bodySmall),
      ]),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openStage(context, p),
    );
  }

  static String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours   < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  static void _openStage(BuildContext context, ProjectDoc p) {
    switch (p.funnelStage) {
      case FunnelStage.build:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => RollerScreen(projectId: p.id)));
        break;
      case FunnelStage.story:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ColorStoryWizardScreen(projectId: p.id)));
        break;
      case FunnelStage.visualize:
      case FunnelStage.share:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => VisualizerScreen(projectId: p.id)));
        break;
    }
  }
}

class _EmptyProjects extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('No Color Stories yet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Start by building a palette or exploring inspirations.'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          Semantics(
            label: 'Build palette from scratch',
            button: true,
            child: ActionChip(
              label: const Text('Build'),
              avatar: const Icon(Icons.palette_outlined),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RollerScreen())),
            ),
          ),
          Semantics(
            label: 'Explore color inspirations',
            button: true,
            child: ActionChip(
              label: const Text('Explore'),
              avatar: const Icon(Icons.explore_outlined),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreScreen())),
            ),
          ),
        ])
      ]),
    );
  }
}

class _HelpfulPills extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12, runSpacing: 12,
      children: [
        _Pill('How it Works', Icons.route_outlined, onTap: () {
          showModalBottomSheet(
            context: context,
            showDragHandle: true,
            builder: (c) => const _HowItWorksSheet(),
          );
        }),
        _Pill('Color Stories', Icons.collections_bookmark_outlined, onTap: () {
          // Deep link to Library with Stories filter (added in Prompt 4)
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const LibraryScreen(initialFilter: LibraryFilter.stories),
          ));
        }),
        _Pill('Top Projects', Icons.favorite_outline, onTap: () {
          // Jump to Explore sorted by "Most Loved"
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const ExploreScreen(),
          ));
        }),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.icon, {required this.onTap});
  final String label; final IconData icon; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true, label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(.6),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Text(label),
          ]),
        ),
      ),
    );
  }
}

class _ActionChipBig extends StatelessWidget {
  const _ActionChipBig({required this.icon, required this.label, required this.onTap, this.semanticLabel});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _HowItWorksSheet extends StatelessWidget {
  const _HowItWorksSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = (IconData i, String h, String s) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(i), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(h, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(s),
        ])),
      ]),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How it works', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Build → Story → Visualize → Share'),
          const SizedBox(height: 12),
          row(Icons.palette_outlined,  'Build',     'Craft your palette in Roller with smart locks & harmony.'),
          row(Icons.menu_book_outlined,'Story',     'Turn it into a guided Color Story with room/style/vibe.'),
          row(Icons.chair_outlined,    'Visualize', 'See it under different lighting and surfaces.'),
          row(Icons.ios_share_outlined,'Share',     'Export or share your Story Card and assets.'),
        ]),
      ),
    );
  }
}


class _SignInPromptCard extends StatelessWidget {
  const _SignInPromptCard({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(.2),
          width: 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Icon(
              Icons.account_circle_outlined,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Sign in to see your Color Stories',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Track your projects and sync across devices.'),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onSignIn,
          icon: const Icon(Icons.login),
          label: const Text('Sign In'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
        ),
      ]),
    );
  }
}

class _ProjectsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(3, (index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title skeleton
              Container(
                height: 16,
                width: 120 + (index * 20).toDouble(),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(.2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle skeleton
              Container(
                height: 14,
                width: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(.15),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ],
          ),
        )),
      ),
    );
  }
}