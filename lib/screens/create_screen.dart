import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'roller_screen.dart';
import 'visualizer_screen.dart';
import 'interview_screen.dart';
import 'learn_screen.dart';
import '../services/create_flow_progress.dart';

/// ✨ Delightful Create Hub Redesign with Section Headers
class CreateHubScreen extends StatefulWidget {
  final String? username;
  final String? heroImageUrl;
  const CreateHubScreen({super.key, this.username, this.heroImageUrl});

  @override
  State<CreateHubScreen> createState() => _CreateHubScreenState();
}

enum _Mode { interview, roller, visualizer, learn }

const double _kCurve = 24.0;
const Duration _kAnim = Duration(milliseconds: 300);

Color _accent(_Mode m) {
  switch (m) {
    case _Mode.interview:
      return const Color(0xFFFD6F61);
    case _Mode.roller:
      return const Color(0xFF5BC0EB);
    case _Mode.visualizer:
      return const Color(0xFF9C6ADE);
    case _Mode.learn:
      return const Color(0xFF64D2A3);
  }
}

String _title(_Mode m) {
  switch (m) {
    case _Mode.interview:
      return 'Interview';
    case _Mode.roller:
      return 'Roller';
    case _Mode.visualizer:
      return 'Visualizer';
    case _Mode.learn:
      return 'Learn';
  }
}

String _tagline(_Mode m) {
  switch (m) {
    case _Mode.interview:
      return 'Tailored palette & plan.';
    case _Mode.roller:
      return 'Design palettes fast — explore & lock.';
    case _Mode.visualizer:
      return 'See colors on your walls instantly.';
    case _Mode.learn:
      return 'Tips, guides & pro tricks.';
  }
}

IconData _iconFor(_Mode m) {
  switch (m) {
    case _Mode.interview:
      return Icons.chat_bubble_outline;
    case _Mode.roller:
      return Icons.tune;
    case _Mode.visualizer:
      return Icons.photo_library_outlined;
    case _Mode.learn:
      return Icons.menu_book_outlined;
  }
}

class _CreateHubScreenState extends State<CreateHubScreen>
    with TickerProviderStateMixin {
  final Set<_Mode> _expanded = {};
  final ScrollController _scrollController = ScrollController();

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;

  void _launch(_Mode m) {
    if (!_reduceMotion) HapticFeedback.lightImpact();
    switch (m) {
      case _Mode.interview:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const InterviewScreen()));
        break;
      case _Mode.roller:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const RollerScreen()));
        break;
      case _Mode.visualizer:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const VisualizerScreen()));
        break;
      case _Mode.learn:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const LearnScreen()));
        break;
    }
  }

  void _toggleDetails(_Mode m) {
    setState(() =>
        _expanded.contains(m) ? _expanded.remove(m) : _expanded.add(m));
    if (!_reduceMotion) HapticFeedback.selectionClick();
  }

  @override
  void dispose() {
    CreateFlowProgress.instance.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _HeroBanner(
              scrollController: _scrollController,
              heroImageUrl: widget.heroImageUrl,
            ),
          ),
          // Section 1: Design a Palette
          SliverToBoxAdapter(
            child: _SectionHeader(title: "Design a Palette"),
          ),
          _buildModeList([_Mode.interview, _Mode.roller]),
          // Section 2: Refine your Palette
          SliverToBoxAdapter(
            child: _SectionHeader(title: "Refine your Palette"),
          ),
          _buildModeList([_Mode.learn]),
          // Section 3: See your Palette
          SliverToBoxAdapter(
            child: _SectionHeader(title: "See your Palette"),
          ),
          _buildModeList([_Mode.visualizer]),
        ],
      ),
    );
  }

  Widget _buildModeList(List<_Mode> modes) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final m = modes[index];
            return _AnimatedRow(
              index: index,
              child: _CategoryRow(
                mode: m,
                icon: _iconFor(m),
                title: _title(m),
                subtitle: _tagline(m),
                accent: _accent(m),
                expanded: _expanded.contains(m),
                onLaunch: () => _launch(m),
                onToggle: () => _toggleDetails(m),
              ),
            );
          },
          childCount: modes.length,
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final ScrollController scrollController;
  final String? heroImageUrl;
  const _HeroBanner({required this.scrollController, this.heroImageUrl});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final url = heroImageUrl ??
        'https://images.unsplash.com/photo-1505691723518-36a5ac3b2a59?auto=format&fit=crop&w=2400&q=80';

    return SizedBox(
      height: size.height * 0.35,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: scrollController,
            builder: (context, child) {
              final offset = scrollController.hasClients
                  ? scrollController.offset * 0.3
                  : 0.0;
              return Positioned(
                top: -offset,
                left: 0,
                right: 0,
                height: size.height * 0.5,
                child: Image.asset(url, fit: BoxFit.cover),
              );
            },
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('create hub',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text('design · learn · visualize',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }
}

class _AnimatedRow extends StatelessWidget {
  final int index;
  final Widget child;
  const _AnimatedRow({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 30, end: 0),
      duration: Duration(milliseconds: 300 + index * 120),
      curve: Curves.easeOutBack,
      builder: (context, offset, c) => Transform.translate(
        offset: Offset(0, offset),
        child: Opacity(opacity: 1 - offset / 30, child: c),
      ),
      child: child,
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final _Mode mode;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool expanded;
  final VoidCallback onLaunch;
  final VoidCallback onToggle;

  const _CategoryRow({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.expanded,
    required this.onLaunch,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _kAnim,
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kCurve),
        boxShadow: [
          if (expanded)
            BoxShadow(
                color: accent.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6))
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCurve),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(_kCurve),
              onTap: onLaunch,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text(subtitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.black54)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded),
                      onPressed: onToggle,
                      color: accent,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded),
                      onPressed: onLaunch,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: _kAnim,
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: _QuickActions(mode: mode, accent: accent),
            )
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final _Mode mode;
  final Color accent;
  const _QuickActions({required this.mode, required this.accent});

  @override
  Widget build(BuildContext context) {
    final actions = {
      _Mode.interview: ['Start'],
      _Mode.roller: ['Blank', 'Seed color', 'Photo', 'Suggestions'],
      _Mode.visualizer: ['Upload', 'Sample room'],
      _Mode.learn: ['Guides', 'Topics'],
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions[mode]!
            .map((label) => ActionChip(
                  label: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  backgroundColor: accent.withValues(alpha: 0.15),
                  onPressed: () => debugPrint('tap $label in $mode'),
                ))
            .toList(),
      ),
    );
  }
}
