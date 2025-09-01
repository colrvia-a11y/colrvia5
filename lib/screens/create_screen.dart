import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Optional: wire up your actual routes if these exist in your app.
// import 'roller_screen.dart';
// import 'visualizer_screen.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key, this.userName});
  final String? userName;

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

enum _Mode { interview, roller, visualizer, learn }

const double _kCurve = 28.0; // rounded corners for each slab top
const double _kOverlap = 16.0; // upward overlap so slabs visually stack
const Duration _kAnim = Duration(milliseconds: 220);
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
      return 'Tips, guides & how‑tos for confident color choices.';
  }
}

List<String> _bullets(_Mode m) {
  switch (m) {
    case _Mode.interview:
      return const [
        'Palette + Color Plan generated in minutes.',
        'Room‑by‑room guidance & sheen suggestions.',
        'Easy next steps: Visualize or export Painter Pack.',
      ];
    case _Mode.roller:
      return const [
        'Start from Blank · Seed Color · Photo · Suggestions.',
        'Lock swatches; explore Softer/Brighter/Moodier/Warmer/Cooler variants.',
        'Send to Visualizer · Color Plan · Compare.',
      ];
    case _Mode.visualizer:
      return const [
        'Upload a photo or try Sample Rooms.',
        'Edge‑aware masking; A/B two palettes with Before/After.',
        'Queue HQ render while you keep working.',
      ];
    case _Mode.learn:
      return const [
        'Browse how‑to articles and short videos.',
        'Prep, tools, and finishes demystified.',
        'Pro tips to avoid repaint regrets.',
      ];
  }
}

class _CreateScreenState extends State<CreateScreen> with TickerProviderStateMixin {
  // Stretchy hero state
  double _elasticExtra = 0.0; // current stretched amount
  double _pullExtent = 0.0; // accumulated overscroll
  late final AnimationController _snap =
      AnimationController(vsync: this, duration: _kAnim)
        ..addListener(() => setState(() {
              _elasticExtra = _snapAnim.value;
              _pullExtent = _pullAnim.value;
            }));
  late Animation<double> _snapAnim = const AlwaysStoppedAnimation(0);
  late Animation<double> _pullAnim = const AlwaysStoppedAnimation(0);

  final ScrollController _scroll = ScrollController();

  // Inline expansions — multiple can be open
  final Set<_Mode> _expanded = <_Mode>{};

  bool get _reduceMotion => MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;

  void _toggle(_Mode m) {
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
        debugPrint('start_interview'); // hook up your route
        break;
      case _Mode.roller:
        debugPrint('open_roller');
        // Navigator.push(context, MaterialPageRoute(builder: (_) => const RollerScreen()));
        break;
      case _Mode.visualizer:
        debugPrint('open_visualizer');
        // Navigator.push(context, MaterialPageRoute(builder: (_) => const VisualizerScreen()));
        break;
      case _Mode.learn:
        debugPrint('open_learn');
        break;
    }
  }

  String get _greetingText {
    final name = widget.userName?.trim();
    final hi = (name != null && name.isNotEmpty)
        ? 'Hi $name,\nwelcome to your Create Hub.'
        : 'Welcome,\nto your Create Hub';
    return hi;
  }

  // Rubber‑band ease used when stretching the hero.
  double _rubber(double distance, double maxExtra) {
    const resistance = 0.55;
    return maxExtra * (1 - 1 / ((distance * resistance / maxExtra) + 1));
  }

  void _snapBack() {
    final curve = CurvedAnimation(
        parent: _snap,
        curve: _reduceMotion ? Curves.linear : Curves.easeOutBack);
    _snapAnim = Tween<double>(begin: _elasticExtra, end: 0).animate(curve);
    _pullAnim = Tween<double>(begin: _pullExtent, end: 0).animate(curve);
    _snap
      ..reset()
      ..forward();
    if (!_reduceMotion) HapticFeedback.selectionClick();
  }

  bool _onScroll(ScrollNotification n) {
    // Only stretch on overscroll at top
    if (n is OverscrollNotification && n.metrics.pixels <= 0 && n.overscroll < 0) {
      _pullExtent += -n.overscroll;
      setState(() => _elasticExtra = _rubber(_pullExtent, 140));
      return true;
    }
    if (n is ScrollEndNotification && _pullExtent > 0) {
      _snapBack();
      return true;
    }
    if (n is ScrollUpdateNotification && n.metrics.pixels > 0 && _pullExtent > 0) {
      _snapBack();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final heroBase = (height * 0.38).clamp(320.0, 520.0);
    final heroH = heroBase + _elasticExtra + _pullExtent;

    const modes = [_Mode.interview, _Mode.roller, _Mode.visualizer, _Mode.learn];

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: CustomScrollView(
          controller: _scroll,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: Offset(0, -_pullExtent),
                child: _HeroHeader(height: heroH, text: _greetingText),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 24),
              sliver: SliverList.builder(
                itemCount: modes.length,
                itemBuilder: (context, i) {
                  final m = modes[i];
                  return Transform.translate(
                    offset: const Offset(0, -_kOverlap),
                    child: _SlabCard(
                      key: ValueKey(m),
                      mode: m,
                      expanded: _expanded.contains(m),
                      onToggle: () => _toggle(m),
                      onLaunch: () => _launch(m),
                      isFirst: i == 0,
                      isLast: i == modes.length - 1,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.height, required this.text});
  final double height;
  final String text;

  @override
  Widget build(BuildContext context) {
    // Use a reliable Unsplash URL; provide graceful fallback on 404
    const url =
        'https://images.unsplash.com/photo-1505691723518-36a5ac3b2a59?auto=format&fit=crop&w=2400&q=80';

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(_kCurve),
        bottomRight: Radius.circular(_kCurve),
      ),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.network(
                url,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, _, __) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFdfe7e2), Color(0xFFb8c2bd)],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Legibility overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(10),
                      Colors.black.withAlpha(130),
                    ],
                  ),
                ),
              ),
            ),
            // Greeting text
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
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

class _SlabCard extends StatelessWidget {
  const _SlabCard({
    super.key,
    required this.mode,
    required this.expanded,
    required this.onToggle,
    required this.onLaunch,
    required this.isFirst,
    required this.isLast,
  });

  final _Mode mode;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onLaunch;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accent(mode);
    final radius = BorderRadius.only(
      topLeft: Radius.circular(_kCurve),
      topRight: Radius.circular(_kCurve),
      bottomLeft: Radius.circular(isLast ? _kCurve : 0),
      bottomRight: Radius.circular(isLast ? _kCurve : 0),
    );

    // Shadow must match the rounded shape and be fully clipped so no color stripes appear.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Card with shadow + clipped gradient background
        Material(
          elevation: 10,
          shadowColor: Colors.black.withAlpha(28),
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: radius),
          child: ClipRRect(
            borderRadius: radius,
            child: InkWell(
              onTap: expanded ? onToggle : onLaunch,
              splashColor: Colors.white.withAlpha(10),
              highlightColor: Colors.white.withAlpha(6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(Colors.white, accent, 0.22)!,
                      Color.lerp(Colors.white, accent, 0.38)!,
                    ],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _title(mode),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          // Launch arrow
                          _GhostIconButton(
                            tooltip: 'Launch ${_title(mode)}',
                            icon: Icons.arrow_forward_rounded,
                            onPressed: onLaunch,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _tagline(mode),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white.withAlpha(235),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: onToggle,
                            icon: Icon(
                              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              color: Colors.white,
                            ),
                            tooltip: expanded ? 'Hide details' : 'Show details',
                          ),
                        ],
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: _DetailsCard(mode: mode, accent: accent),
                        ),
                        crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        duration: _kAnim,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // A tiny underlap cap to completely cover any rounding seams from previous slab
        if (!isFirst)
          Positioned(
            top: -1,
            left: 0,
            right: 0,
            height: _kOverlap + 2,
            child: IgnorePointer(
              ignoring: true,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(_kCurve),
                  topRight: Radius.circular(_kCurve),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(Colors.white, accent, 0.22)!,
                        Color.lerp(Colors.white, accent, 0.38)!,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.mode, required this.accent});
  final _Mode mode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bullets = _bullets(mode);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withAlpha(26)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 10, offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('What you can do', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(height: 1.35)),
                  Expanded(
                    child: Text(b, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.black87)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GhostIconButton extends StatelessWidget {
  const _GhostIconButton({required this.tooltip, required this.icon, required this.onPressed});
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}