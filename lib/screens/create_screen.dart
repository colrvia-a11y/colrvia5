import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// If these exist in your project, keep the imports.
// Otherwise, comment them out or replace with your own routes.
import 'roller_screen.dart';
import 'visualizer_screen.dart';

/// Simplified Create Hub
/// - Smaller stretchy hero with rubber-band reveal
/// - No greeting; header shows "create" and "design · learn · visualize"
/// - Clean, scrollable list of 4 categories (Interview, Roller, Visualizer, Learn)
/// - Each row has primary launch arrow + tiny chevron to expand inline details
/// - Keyboard & accessibility friendly
class CreateHubScreen extends StatefulWidget {
  final String? username; // kept for API compatibility (unused in UI)
  final String? heroImageUrl; // Optional override for hero photo

  const CreateHubScreen({super.key, this.username, this.heroImageUrl});

  @override
  State<CreateHubScreen> createState() => _CreateHubScreenState();
}

enum _Mode { interview, roller, visualizer, learn }

const double _kCurve = 24.0; // card corner radius
const Duration _kAnim = Duration(milliseconds: 240);
const Duration _kAnimFast = Duration(milliseconds: 160);

Color _accent(_Mode m) {
  switch (m) {
    case _Mode.interview:
      return const Color(0xFFFD6F61); // coral
    case _Mode.roller:
      return const Color(0xFF5BC0EB); // azure
    case _Mode.visualizer:
      return const Color(0xFF9C6ADE); // lavender
    case _Mode.learn:
      return const Color(0xFF64D2A3); // mint
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
      return 'Answer a few questions for a tailored palette & plan.';
    case _Mode.roller:
      return 'Design palettes fast — lock, iterate, explore.';
    case _Mode.visualizer:
      return 'Preview colors on your walls (Fast → HQ).';
    case _Mode.learn:
      return 'Tips, guides & how-tos for confident color choices.';
  }
}

List<String> _bullets(_Mode m) {
  switch (m) {
    case _Mode.interview:
      return const [
        'Palette + Color Plan in minutes',
        'Room-by-room guidance & sheen suggestions',
        'Save favorites & export Painter Pack',
      ];
    case _Mode.roller:
      return const [
        'Start from Blank · Seed Color · Photo · Suggestions',
        'Lock swatches; explore Softer/Brighter/Moodier variants',
        'Send to Visualizer · Color Plan · Compare',
      ];
    case _Mode.visualizer:
      return const [
        'Upload a photo or try Sample Rooms',
        'Edge-aware masking; quick A/B with Before/After',
        'Queue HQ render while you keep working',
      ];
    case _Mode.learn:
      return const [
        'Browse how-to articles and short videos',
        'Prep, tools, and finishes demystified',
        'Pro tips to avoid repaint regrets',
      ];
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

int _a(double opacity) => (opacity * 255).round().clamp(0, 255);

class _CreateHubScreenState extends State<CreateHubScreen>
    with TickerProviderStateMixin {
  // Expanded rows state
  final Set<_Mode> _expanded = <_Mode>{};

  // Keyboard focus per row
  final Map<_Mode, FocusNode> _focusNodes = {
    _Mode.interview: FocusNode(debugLabel: 'InterviewRow'),
    _Mode.roller: FocusNode(debugLabel: 'RollerRow'),
    _Mode.visualizer: FocusNode(debugLabel: 'VisualizerRow'),
    _Mode.learn: FocusNode(debugLabel: 'LearnRow'),
  };

  // Rubber-band hero
  final ScrollController _scrollController = ScrollController();
  double _elasticExtra = 0.0; // applied extra height (+)
  double _pullExtent = 0.0; // accumulated overscroll at top
  late final AnimationController _snapController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260))
        ..addListener(() => setState(() => _elasticExtra = _snapAnimation.value));
  late Animation<double> _snapAnimation;

  bool get _reduceMotion => MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;

  @override
  void dispose() {
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    _snapController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Rubber-band easing
  double _rubberBand(double distance, double maxExtra) {
    const resistance = 0.55;
    return maxExtra * (1 - 1 / ((distance * resistance / maxExtra) + 1));
  }

  void _snapBackHero() {
    _snapAnimation = Tween<double>(begin: _elasticExtra, end: 0).animate(
      CurvedAnimation(parent: _snapController, curve: _reduceMotion ? Curves.linear : Curves.easeOutBack),
    );
    _snapController.forward(from: 0);
    _pullExtent = 0.0;
    if (!_reduceMotion) HapticFeedback.selectionClick();
  }

  bool _onScroll(ScrollNotification n) {
    // Only care about top overscroll to stretch hero
    if (n is OverscrollNotification && n.metrics.pixels <= 0 && n.overscroll < 0) {
      _pullExtent += -n.overscroll; // convert to positive
      final extra = _rubberBand(_pullExtent, 140); // keep generous reveal
      setState(() => _elasticExtra = extra);
      return true;
    }
    if (n is ScrollUpdateNotification) {
      if (n.metrics.pixels > 0 && _pullExtent > 0) _snapBackHero();
    }
    if (n is ScrollEndNotification && _pullExtent > 0) {
      _snapBackHero();
    }
    return false;
  }

  void _toggleDetails(_Mode m) {
    if (!_reduceMotion) HapticFeedback.selectionClick();
    setState(() {
      if (_expanded.contains(m)) {
        _expanded.remove(m);
      } else {
        _expanded.add(m);
      }
    });
  }

  void _launch(_Mode m) {
    if (!_reduceMotion) HapticFeedback.lightImpact();
    switch (m) {
      case _Mode.interview:
        // TODO: Hook up Interview route here
        debugPrint('start_interview');
        break;
      case _Mode.roller:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RollerScreen()));
        break;
      case _Mode.visualizer:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VisualizerScreen()));
        break;
      case _Mode.learn:
        // TODO: Hook up Learn hub route here
        debugPrint('open_learn');
        break;
    }
  }

  void _handleKeys(KeyEvent e) {
    if (e is! KeyDownEvent) return;
    final all = _Mode.values;
    int currentIndex = all.indexWhere((m) => _focusNodes[m]!.hasFocus);
    if (currentIndex < 0) currentIndex = 0;

    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      final next = (currentIndex + 1) % all.length;
      _focusNodes[all[next]]!.requestFocus();
      if (!_reduceMotion) HapticFeedback.selectionClick();
    } else if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      final prev = (currentIndex - 1 + all.length) % all.length;
      _focusNodes[all[prev]]!.requestFocus();
      if (!_reduceMotion) HapticFeedback.selectionClick();
    } else if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _launch(all[currentIndex]);
    } else if (e.logicalKey == LogicalKeyboardKey.space) {
      _toggleDetails(all[currentIndex]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modes = const [_Mode.interview, _Mode.roller, _Mode.visualizer, _Mode.learn];

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeys,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: _HeroBanner(
                  extra: _elasticExtra,
                  username: widget.username, // kept for API compat; not shown
                  heroImageUrl: widget.heroImageUrl,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final m = modes[index];
                      return _CategoryRow(
                        mode: m,
                        icon: _iconFor(m),
                        title: _title(m),
                        subtitle: _tagline(m),
                        accent: _accent(m),
                        expanded: _expanded.contains(m),
                        focusNode: _focusNodes[m]!,
                        onLaunch: () => _launch(m),
                        onToggle: () => _toggleDetails(m),
                      );
                    },
                    childCount: modes.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final double extra; // stretch extra height
  final String? username; // kept for API compatibility (unused)
  final String? heroImageUrl;
  const _HeroBanner({required this.extra, this.username, this.heroImageUrl});

  @override
  Widget build(BuildContext context) {
    // Smaller initial height; reveal more on pull
    final h = max(220.0, MediaQuery.of(context).size.height * 0.30) + extra;

    // Header copy (lowercase as requested)
    const title = 'create hub';
    const subtitle = 'design · learn · visualize';

    // A reliable Unsplash photo (interior). Use provided URL if any.
    final url = heroImageUrl ??
        'https://images.unsplash.com/photo-1505691723518-36a5ac3b2a59?auto=format&fit=crop&w=2400&q=80';

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: SizedBox(
        height: h,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.network(
                url,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) {
                  // Graceful gradient fallback
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE9EEF3), Color(0xFFD8E0E7)],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Darken bottom for text legibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(_a(0.00)),
                      Colors.black.withAlpha(_a(0.55)),
                    ],
                  ),
                ),
              ),
            ),
            // Text (no welcome/greeting)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white.withAlpha(_a(0.90)),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
  final FocusNode focusNode;
  final VoidCallback onLaunch;
  final VoidCallback onToggle;

  const _CategoryRow({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.expanded,
    required this.focusNode,
    required this.onLaunch,
    required this.onToggle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: FocusableActionDetector(
        focusNode: focusNode,
        autofocus: mode == _Mode.interview,
        child: Material(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_kCurve),
            side: BorderSide(color: Colors.black.withAlpha(_a(0.06))),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Header row
              InkWell(
                onTap: onLaunch,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                  child: Row(
                    children: [
                      // Leading icon inside a subtle tint chip
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accent.withAlpha(_a(0.14)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: accent.withAlpha(_a(0.95))),
                      ),
                      const SizedBox(width: 12),
                      // Title + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.black.withAlpha(_a(0.94)),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.black.withAlpha(_a(0.70)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Chevron toggle
                      IconButton(
                        tooltip: expanded ? 'Hide details' : 'Show details',
                        icon: Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                        onPressed: onToggle,
                      ),
                      // Launch arrow (primary)
                      Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: Material(
                          color: Colors.black.withAlpha(_a(0.06)),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: onLaunch,
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.arrow_forward_rounded, size: 22),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Divider line that picks up accent subtly
              Container(height: 1, color: accent.withAlpha(_a(0.10))),

              // Details
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _DetailsBlock(mode: mode, accent: accent),
                crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: _kAnim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsBlock extends StatelessWidget {
  final _Mode mode;
  final Color accent;
  const _DetailsBlock({required this.mode, required this.accent});

  @override
  Widget build(BuildContext context) {
    final bullets = _bullets(mode);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(Colors.white, accent, 0.06)!,
            Color.lerp(Colors.white, accent, 0.12)!,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What you can do', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...bullets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(height: 1.35)),
                    Expanded(child: Text(b, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.black.withAlpha(_a(0.86))))),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _chipsFor(mode, theme),
          ),
        ],
      ),
    );
  }

  List<Widget> _chipsFor(_Mode mode, ThemeData theme) {
    final Map<_Mode, List<String>> chips = {
      _Mode.interview: const ['Start Interview'],
      _Mode.roller: const ['Blank', 'Seed color', 'From photo', 'Suggestions'],
      _Mode.visualizer: const ['Upload photo', 'Sample room'],
      _Mode.learn: const ['Browse guides', 'Popular topics'],
    };
    final items = chips[mode] ?? const <String>[];
    return items
        .map((label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withAlpha(_a(0.16)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withAlpha(_a(0.08))),
              ),
              child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ))
        .toList();
  }
}
