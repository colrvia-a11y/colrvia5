import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/user_prefs_service.dart';
import 'onboarding_screen.dart';
import 'roller_screen.dart';
import 'visualizer_screen.dart';

enum _Tab { interview, roller, visualize }

const double kCurve = 32.0; // Reusable radius constant
const Color surfaceColor = Colors.white; // single source of truth for page surface

// Ambient gradient wash (very low opacity)
Color _accentForTab(_Tab t) {
  switch (t) {
    case _Tab.interview:
      return const Color(0xFFFD6F61); // soft coral
    case _Tab.roller:
      return const Color(0xFF5BC0EB); // light azure
    case _Tab.visualize:
      return const Color(0xFF9C6ADE); // lavender
  }
}

// Slight tinted fills for cards (on white page), extremely subtle
Color _cardTint(Color accent) => Color.alphaBlend(accent.withAlpha(13), Colors.white);

/// Entry hub for starting new workflows. (Version A + discover sections + your edits)
class CreateScreen extends StatefulWidget {
  final ImageProvider? heroImage;
  final String? heroSemanticLabel;

  const CreateScreen({
    super.key,
    this.heroImage,
    this.heroSemanticLabel,
  });

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> with TickerProviderStateMixin {
  _Tab _selectedTab = _Tab.interview;

  // Focus nodes
  final FocusNode _interviewFocusNode = FocusNode();
  final FocusNode _rollerFocusNode = FocusNode();
  final FocusNode _visualizeFocusNode = FocusNode();
  final FocusNode _ctaFocusNode = FocusNode();

  // Scroll + sections
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _sec1Key = GlobalKey();
  final GlobalKey _sec2Key = GlobalKey();
  final GlobalKey _sec3Key = GlobalKey();
  double _p1 = 0, _p2 = 0, _p3 = 0; // visibility progress 0..1

  // Intro (entrance) polish
  late final AnimationController _introController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final Animation<double> _introFade =
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic);
  late final Animation<Offset> _introSlide =
      Tween<Offset>(begin: const Offset(0, .05), end: Offset.zero)
          .animate(CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic));

  // Pull-to-reveal via overscroll rubber-band on hero
  double _elasticExtra = 0.0; // applied extra height (+)
  double _pullExtent = 0.0; // accumulated overscroll at top
  late final AnimationController _snapController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260))
        ..addListener(() {
          setState(() {
            _elasticExtra = _snapAnimation.value;
          });
        });
  late Animation<double> _snapAnimation;

  // Tiny parallax on the hero image — anchor top; we only stretch height now
  double get _parallaxOffsetY => 0.0;

  bool get _reduceMotion => MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_reduceMotion) {
        _introController.forward();
      } else {
        _introController.value = 1.0;
      }
    });
  }

  @override
  void dispose() {
    _interviewFocusNode..unfocus()..dispose();
    _rollerFocusNode..unfocus()..dispose();
    _visualizeFocusNode..unfocus()..dispose();
    _ctaFocusNode..unfocus()..dispose();
    _introController.dispose();
    _snapController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Keyboard nav (desktop)
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        setState(() {
          _selectedTab = _Tab.values[(_selectedTab.index - 1 + _Tab.values.length) % _Tab.values.length];
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        setState(() {
          _selectedTab = _Tab.values[(_selectedTab.index + 1) % _Tab.values.length];
        });
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        _ctaFocusNode.requestFocus();
      }
    }
  }

  Future<void> _checkOnboarding() async {
    // REGION: CODEX-ADD onboarding-gate
    final prefs = await UserPrefsService.fetch();
    if (!prefs.firstRunCompleted && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const OnboardingScreen(),
        ),
      );
    }
    // END REGION: CODEX-ADD onboarding-gate
  }

  ImageProvider _getHeroImageForTab(_Tab tab) {
    switch (tab) {
      case _Tab.interview:
        return const NetworkImage('https://picsum.photos/seed/interview/1200/1600');
      case _Tab.roller:
        return const NetworkImage('https://picsum.photos/seed/roller/1200/1600');
      case _Tab.visualize:
        return const NetworkImage('https://picsum.photos/seed/visualize/1200/1600');
    }
  }

  void _onStartGuided() {
    debugPrint('start_guided');
  }

  void _onStartRoller() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RollerScreen()));
  }

  void _onStartVisualizer() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const VisualizerScreen()));
  }

  // Rubber-band easing used when stretching the hero.
  double _rubberBand(double distance, double maxExtra) {
    const resistance = 0.55;
    return maxExtra * (1 - 1 / ((distance * resistance / maxExtra) + 1));
  }

  void _snapBackHero() {
    _snapAnimation = Tween<double>(begin: _elasticExtra, end: 0).animate(
      CurvedAnimation(
        parent: _snapController,
        curve: _reduceMotion ? Curves.linear : Curves.easeOutBack,
      ),
    );
    _snapController.forward(from: 0);
    _pullExtent = 0.0;
    if (!_reduceMotion) HapticFeedback.selectionClick();
  }

  bool _onScrollNotification(ScrollNotification n) {
    final size = MediaQuery.of(context).size;
    final viewH = size.height;

    // Handle overscroll at top to stretch hero (no snap paging elsewhere).
    if (n is OverscrollNotification && n.metrics.pixels <= 0 && n.overscroll < 0) {
      _pullExtent += -n.overscroll; // convert to positive distance
      final extra = _rubberBand(_pullExtent, 140);
      setState(() => _elasticExtra = extra);
      return true;
    }
    if (n is ScrollUpdateNotification) {
      if (n.metrics.pixels > 0 && _pullExtent > 0) {
        // user started scrolling normally; reset stretch
        _snapBackHero();
      }
      _updateSectionProgress(viewH);
      return false;
    }
    if (n is ScrollEndNotification) {
      if (_pullExtent > 0) _snapBackHero();
      _updateSectionProgress(viewH);
      return false;
    }
    return false;
  }

  void _updateSectionProgress(double viewportHeight) {
    double vis1 = _visibleProgressOf(_sec1Key, viewportHeight);
    double vis2 = _visibleProgressOf(_sec2Key, viewportHeight);
    double vis3 = _visibleProgressOf(_sec3Key, viewportHeight);

    // Throttle updates to avoid rebuild spam
    bool changed = (vis1 - _p1).abs() > 0.02 || (vis2 - _p2).abs() > 0.02 || (vis3 - _p3).abs() > 0.02;
    if (!changed) return;

    setState(() {
      _p1 = vis1;
      _p2 = vis2;
      _p3 = vis3;
      // Background stays pure white as requested (no dynamic tinting).
    });
  }

  double _visibleProgressOf(GlobalKey key, double viewportHeight) {
    final ctx = key.currentContext;
    if (ctx == null) return 0.0;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return 0.0;

    final pos = box.localToGlobal(Offset.zero);
    final top = pos.dy;
    final bottom = top + box.size.height;
    final viewTop = 0.0;
    final viewBottom = viewportHeight;

    final overlap = max(0.0, min(bottom, viewBottom) - max(top, viewTop));
    final denom = min(box.size.height, viewportHeight);
    if (denom <= 0) return 0.0;

    return (overlap / denom).clamp(0.0, 1.0);
  }

  Future<void> _scrollToSection(int index) async {
    final key = [_sec1Key, _sec2Key, _sec3Key][index];
    final ctx = key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;

    // Compute absolute offset within the scroll view
    final position = box.localToGlobal(Offset.zero);
    final current = _scrollController.offset;
    final targetOffset = current + position.dy - 16.0; // small top margin

    await _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Base hero height ~ 58% of screen, min 420.
    final baseHero = max(420.0, screenHeight * 0.58);
    final heroHeight = baseHero + _elasticExtra;

    // Ambient gradient is very faint so the page still reads as white
    final accent = _accentForTab(_selectedTab).withAlpha(5);

    return KeyboardListener(
      focusNode: FocusNode(), // dummy focus node for KeyboardListener
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: Stack(
          children: [
            // Pure white background
            Container(color: surfaceColor),

            // Ambient gradient wash (very light, behind content)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent, Colors.transparent, accent],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Content scroll
            NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  // Top zone: hero + dots + primary tab content panel
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _Hero(
                          heroImage: _getHeroImageForTab(_selectedTab),
                          heroSemanticLabel: widget.heroSemanticLabel ??
                              'A beautiful abstract image representing creativity',
                          height: heroHeight,
                          parallaxOffsetY: _parallaxOffsetY,
                          headingText: 'color your next chapter',
                          bottomRadius: kCurve,
                          fadeIn: _introFade,
                          slideIn: _introSlide,
                          segmentedPill: _SegmentedPill(
                            selectedTab: _selectedTab,
                            onTabSelected: (tab) {
                              if (tab == _selectedTab) return;
                              setState(() {
                                _selectedTab = tab;
                              });
                              if (!_reduceMotion) {
                                HapticFeedback.selectionClick();
                              }
                            },
                            interviewFocusNode: _interviewFocusNode,
                            rollerFocusNode: _rollerFocusNode,
                            visualizeFocusNode: _visualizeFocusNode,
                            keys: {
                              _Tab.interview: const Key('tab-interview'),
                              _Tab.roller: const Key('tab-roller'),
                              _Tab.visualize: const Key('tab-visualize'),
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        _PageDots(
                          count: 3,
                          activeIndex: _selectedTab.index,
                          onTap: (i) async {
                            setState(() => _selectedTab = _Tab.values[i]);
                            if (!_reduceMotion) HapticFeedback.selectionClick();
                            await Future.delayed(const Duration(milliseconds: 80));
                            _scrollToSection(i);
                          },
                        ),
                        const SizedBox(height: 12),
                        _TabPanel(
                          selectedTab: _selectedTab,
                          topRadius: kCurve,
                          ctaFocusNode: _ctaFocusNode,
                          onStartGuided: () {
                            if (!_reduceMotion) HapticFeedback.lightImpact();
                            _onStartGuided();
                          },
                          onStartRoller: () {
                            if (!_reduceMotion) HapticFeedback.lightImpact();
                            _onStartRoller();
                          },
                          onStartVisualizer: () {
                            if (!_reduceMotion) HapticFeedback.lightImpact();
                            _onStartVisualizer();
                          },
                          keys: {
                            _Tab.interview: const Key('panel-interview'),
                            _Tab.roller: const Key('panel-roller'),
                            _Tab.visualize: const Key('panel-visualize'),
                          },
                          ctaKeys: {
                            _Tab.interview: const Key('cta-interview'),
                            _Tab.roller: const Key('cta-roller'),
                            _Tab.visualize: const Key('cta-visualize'),
                          },
                        ),
                      ],
                    ),
                  ),

                  // --- Extra breathing space before discover sections ---
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),

                  // Discover Sections (near full-screen each), spaced further apart
                  SliverToBoxAdapter(
                    child: _FeatureSection(
                      key: _sec1Key,
                      height: max(screenHeight * 0.92, 560),
                      direction: AxisDirection.left, // card slides from left
                      accent: _accentForTab(_Tab.interview),
                      overline: 'INTERVIEW',
                      title: 'Get a tailored color plan in minutes',
                      bullets: const [
                        'Answer quick questions; we’ll align to your vibe & light.',
                        'See curated palettes with room-by-room guidance.',
                        'Save favorites and revisit anytime.',
                      ],
                      ctaText: 'Start Interview',
                      onTap: () {
                        if (!_reduceMotion) HapticFeedback.lightImpact();
                        _onStartGuided();
                      },
                      // images (examples/placeholder)
                      imageUrls: const [
                        'https://picsum.photos/seed/interview-1/600/800',
                        'https://picsum.photos/seed/interview-2/800/600',
                        'https://picsum.photos/seed/interview-3/700/700',
                      ],
                      progress: _p1,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 56)),

                  SliverToBoxAdapter(
                    child: _FeatureSection(
                      key: _sec2Key,
                      height: max(screenHeight * 0.92, 560),
                      direction: AxisDirection.right, // card slides from right
                      accent: _accentForTab(_Tab.roller),
                      overline: 'ROLLER',
                      title: 'Design palettes fast—lock, iterate, explore',
                      bullets: const [
                        'Lock swatches, shuffle smart variants, compare quickly.',
                        'Fine-tune tones; keep neutrals consistent.',
                        'Export your set or apply across rooms.',
                      ],
                      ctaText: 'Open Roller',
                      onTap: () {
                        if (!_reduceMotion) HapticFeedback.lightImpact();
                        _onStartRoller();
                      },
                      imageUrls: const [
                        'https://picsum.photos/seed/roller-1/600/800',
                        'https://picsum.photos/seed/roller-2/800/600',
                        'https://picsum.photos/seed/roller-3/700/700',
                      ],
                      progress: _p2,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 56)),

                  SliverToBoxAdapter(
                    child: _FeatureSection(
                      key: _sec3Key,
                      height: max(screenHeight * 0.92, 560),
                      direction: AxisDirection.left,
                      accent: _accentForTab(_Tab.visualize),
                      overline: 'VISUALIZE',
                      title: 'Preview colors on your walls in minutes',
                      bullets: const [
                        'Quick preview to shortlist; queue HQ renders when ready.',
                        'Edge-aware masking; swap colors instantly.',
                        'Share with collaborators for feedback.',
                      ],
                      ctaText: 'Visualize My Room',
                      onTap: () {
                        if (!_reduceMotion) HapticFeedback.lightImpact();
                        _onStartVisualizer();
                      },
                      imageUrls: const [
                        'https://picsum.photos/seed/visualize-1/600/800',
                        'https://picsum.photos/seed/visualize-2/800/600',
                        'https://picsum.photos/seed/visualize-3/700/700',
                      ],
                      progress: _p3,
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 64)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final ImageProvider heroImage;
  final String heroSemanticLabel;
  final double height;
  final double parallaxOffsetY;
  final String headingText;
  final double bottomRadius;
  final Widget segmentedPill;

  // Entrance polish
  final Animation<double> fadeIn;
  final Animation<Offset> slideIn;

  const _Hero({
    required this.heroImage,
    required this.heroSemanticLabel,
    required this.height,
    required this.parallaxOffsetY,
    required this.headingText,
    required this.bottomRadius,
    required this.segmentedPill,
    required this.fadeIn,
    required this.slideIn,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(bottomRadius),
        bottomRight: Radius.circular(bottomRadius),
      ),
      child: Semantics(
        label: heroSemanticLabel,
        image: true,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            children: [
              // Image layer with anchored top (keeps full-bleed at top even when stretching)
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(0, parallaxOffsetY),
                  child: Image(
                    image: heroImage,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
              // Gradient overlay for legibility
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(0),
                        Colors.black.withAlpha(140),
                      ],
                    ),
                  ),
                ),
              ),
              // Heading + entrance motion
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: FadeTransition(
                      opacity: fadeIn,
                      child: SlideTransition(
                        position: slideIn,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final textScaler = MediaQuery.of(context).textScaler;
                            const double base = 28.0;
                            const double maxSize = 56.0;
                            final responsive =
                                base + (constraints.maxWidth / 600) * (maxSize - base);
                            final fs =
                                textScaler.scale(responsive).clamp(base, maxSize);
                            return Text(
                              headingText,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: fs.toDouble(),
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Segmented Pill (raised slightly from the bottom to avoid blending at the curve)
              Positioned(
                bottom: 28.0,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: fadeIn,
                  child: SlideTransition(
                    position: slideIn,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: segmentedPill,
                    ),
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

class _SegmentedPill extends StatelessWidget {
  final _Tab selectedTab;
  final ValueChanged<_Tab> onTabSelected;
  final FocusNode interviewFocusNode;
  final FocusNode rollerFocusNode;
  final FocusNode visualizeFocusNode;
  final Map<_Tab, Key> keys;

  const _SegmentedPill({
    required this.selectedTab,
    required this.onTabSelected,
    required this.interviewFocusNode,
    required this.rollerFocusNode,
    required this.visualizeFocusNode,
    required this.keys,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
    final screenW = MediaQuery.of(context).size.width;

    // Narrower pill & tighter spacing
    final double pillW = min(360.0, screenW - 64.0);
    const double pillH = 42.0;
    const double edgePad = 6.0;

    return SizedBox(
      width: pillW,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            padding: const EdgeInsets.all(edgePad),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(77),
              borderRadius: BorderRadius.circular(50.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(51),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final total = constraints.maxWidth;
                final tabWidth = (total - edgePad * 2) / 3;
                final idx = selectedTab.index;

                return SizedBox(
                  height: pillH,
                  width: total,
                  child: Stack(
                    children: [
                      // Sliding highlight "glide"
                      AnimatedPositioned(
                        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        left: edgePad + idx * tabWidth,
                        top: edgePad,
                        bottom: edgePad,
                        width: tabWidth,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(50.0),
                          ),
                        ),
                      ),
                      // Tabs (labels) on top
                      Row(
                        children: [
                          for (final tab in _Tab.values)
                            Expanded(
                              child: _Pressable(
                                key: keys[tab],
                                hoverScale: 1.02,
                                pressedScale: 0.965,
                                onTap: () {
                                  onTabSelected(tab);
                                  switch (tab) {
                                    case _Tab.interview:
                                      interviewFocusNode.requestFocus();
                                      break;
                                    case _Tab.roller:
                                      rollerFocusNode.requestFocus();
                                      break;
                                    case _Tab.visualize:
                                      visualizeFocusNode.requestFocus();
                                      break;
                                  }
                                },
                                child: Focus(
                                  focusNode: () {
                                    switch (tab) {
                                      case _Tab.interview:
                                        return interviewFocusNode;
                                      case _Tab.roller:
                                        return rollerFocusNode;
                                      case _Tab.visualize:
                                        return visualizeFocusNode;
                                    }
                                  }(),
                                  child: Semantics(
                                    selected: selectedTab == tab,
                                    button: true,
                                    label: 'Select ${_tabLabel(tab)} tab',
                                    child: Center(
                                      child: Text(
                                        _tabLabel(tab),
                                        style: TextStyle(
                                          color: selectedTab == tab
                                              ? Colors.black
                                              : Colors.white.withAlpha(204),
                                          fontWeight: selectedTab == tab
                                              ? FontWeight.w600
                                              : FontWeight.w300,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _tabLabel(_Tab t) {
    switch (t) {
      case _Tab.interview:
        return 'Interview';
      case _Tab.roller:
        return 'Roller';
      case _Tab.visualize:
        return 'Visualize';
    }
  }
}

// Micro-interaction wrapper: scale on press/hover + optional haptics
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final double hoverScale;

  const _Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
    this.hoverScale = 1.02,
  });

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _hovering = false;
  bool _pressed = false;

  double get _targetScale {
    if (_pressed) return widget.pressedScale;
    if (_hovering) return widget.hoverScale;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          if (!reduceMotion) HapticFeedback.selectionClick();
          widget.onTap?.call();
        },
        child: AnimatedScale(
          scale: _targetScale,
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

class _TabPanel extends StatelessWidget {
  final _Tab selectedTab;
  final double topRadius;
  final FocusNode ctaFocusNode;
  final Map<_Tab, Key> keys;
  final Map<_Tab, Key> ctaKeys;
  final VoidCallback onStartGuided;
  final VoidCallback onStartRoller;
  final VoidCallback onStartVisualizer;

  const _TabPanel({
    required this.selectedTab,
    required this.topRadius,
    required this.ctaFocusNode,
    required this.keys,
    required this.ctaKeys,
    required this.onStartGuided,
    required this.onStartRoller,
    required this.onStartVisualizer,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(topRadius),
          topRight: Radius.circular(topRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        child: _buildTabContent(context),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context) {
    String text;
    String ctaText;
    VoidCallback onCtaPressed;

    switch (selectedTab) {
      case _Tab.interview:
        text = 'Answer a few quick questions and we’ll suggest a palette and plan.';
        ctaText = 'Start Interview';
        onCtaPressed = onStartGuided;
        break;
      case _Tab.roller:
        text = 'Design your paint palette fast—lock swatches, explore variants, and save.';
        ctaText = 'Open Roller';
        onCtaPressed = onStartRoller;
        break;
      case _Tab.visualize:
        text = 'See colors on your walls in minutes—get a fast preview, queue HQ render.';
        ctaText = 'Visualize My Room';
        onCtaPressed = onStartVisualizer;
        break;
    }

    final panelKey = keys[selectedTab]!;
    final ctaKey = ctaKeys[selectedTab]!;

    return SingleChildScrollView(
      key: ValueKey(selectedTab),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: Column(
          key: panelKey,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w300,
                  ),
            ),
            const SizedBox(height: 28.0),
            SizedBox(
              width: 220,
              child: _Pressable(
                onTap: onCtaPressed,
                pressedScale: 0.965,
                hoverScale: 1.015,
                child: ElevatedButton(
                  key: ctaKey,
                  focusNode: ctaFocusNode,
                  onPressed: onCtaPressed,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: Semantics(
                    button: true,
                    label: 'Activate $ctaText',
                    child: Text(
                      ctaText,
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                      ),
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

// Dots under the hero (tap to jump to discover sections)
class _PageDots extends StatelessWidget {
  final int count;
  final int activeIndex;
  final ValueChanged<int>? onTap;

  const _PageDots({
    required this.count,
    required this.activeIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;

    return Semantics(
      label: 'Navigation dots for options',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final bool isActive = i == activeIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: GestureDetector(
              onTap: onTap == null ? null : () => onTap!(i),
              child: AnimatedContainer(
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: isActive ? 10 : 8,
                height: isActive ? 10 : 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? Colors.black : Colors.black.withAlpha(64),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// A near full-screen feature section that slides/fades into view as you scroll.
/// Direction alternates: left → right → left. Images slide from the **opposite** side.
class _FeatureSection extends StatelessWidget {
  final AxisDirection direction; // left or right (card slide-in)
  final double height;
  final Color accent;
  final String overline;
  final String title;
  final List<String> bullets;
  final String ctaText;
  final VoidCallback onTap;
  final List<String> imageUrls; // 3 images
  final double progress; // 0..1 visibility (from parent)

  const _FeatureSection({
    super.key,
    required this.direction,
    required this.height,
    required this.accent,
    required this.overline,
    required this.title,
    required this.bullets,
    required this.ctaText,
    required this.onTap,
    required this.imageUrls,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;

    // Map visibility progress to slide/opacity windows
    final p = progress.clamp(0.0, 1.0);
    double window(double start, double end) {
      final t = ((p - start) / (end - start)).clamp(0.0, 1.0);
      return t;
    }

    final cardIn = window(0.15, 0.55); // card slide/opacity
    final content1 = window(0.25, 0.60);
    final content2 = window(0.33, 0.68);
    final content3 = window(0.41, 0.76);
    final contentCTA = window(0.50, 0.85);

    final dxSign = (direction == AxisDirection.right) ? 1.0 : -1.0;
    final slidePx = reduceMotion ? 0.0 : (1.0 - cardIn) * 140.0 * dxSign;
    final cardOpacity = reduceMotion ? (p > 0.02 ? 1.0 : 0.0) : cardIn;

    // Images slide from the OPPOSITE side
    final imgDxSign = -dxSign;
    final imgIn = window(0.20, 0.58);
    final imgSlidePx = reduceMotion ? 0.0 : (1.0 - imgIn) * 160.0 * imgDxSign;
    final imgOpacity = reduceMotion ? (p > 0.05 ? 1.0 : 0.0) : imgIn;

    final double maxW = min(MediaQuery.of(context).size.width - 32, 980.0);
    final cardColor = _cardTint(accent);

    final bool wide = maxW >= 900.0;
    final bool textOnLeft = direction != AxisDirection.right; // zig-zag layout

    Widget content = _SectionContent(
      overline: overline,
      title: title,
      bullets: bullets,
      ctaText: ctaText,
      onTap: onTap,
      p1: content1,
      p2: content2,
      p3: content3,
      pCTA: contentCTA,
    );

    Widget images = Opacity(
      opacity: imgOpacity,
      child: Transform.translate(
        offset: Offset(imgSlidePx, 0),
        child: _MosaicImages(
          urls: imageUrls,
          accent: accent,
          // alternate mosaic emphasis so they feel different
          variant: textOnLeft ? 1 : 2,
        ),
      ),
    );

    List<Widget> rowChildren;
    if (textOnLeft) {
      rowChildren = [
        Expanded(child: content),
        const SizedBox(width: 24),
        SizedBox(width: wide ? 360 : 280, child: images),
      ];
    } else {
      rowChildren = [
        SizedBox(width: wide ? 360 : 280, child: images),
        const SizedBox(width: 24),
        Expanded(child: content),
      ];
    }

    return RepaintBoundary(
      child: SizedBox(
        height: height,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints.tightFor(width: maxW),
            child: Opacity(
              opacity: cardOpacity,
              child: Transform.translate(
                offset: Offset(slidePx, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.black.withAlpha(15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      // Stack layout on narrow screens: text over images
                      if (c.maxWidth < 780) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            content,
                            const SizedBox(height: 20),
                            images,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: rowChildren,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionContent extends StatelessWidget {
  final String overline;
  final String title;
  final List<String> bullets;
  final String ctaText;
  final VoidCallback onTap;
  final double p1, p2, p3, pCTA; // 0..1 per-element progress windows

  const _SectionContent({
    required this.overline,
    required this.title,
    required this.bullets,
    required this.ctaText,
    required this.onTap,
    required this.p1,
    required this.p2,
    required this.p3,
    required this.pCTA,
  });

  Widget _reveal(double t, Widget child) {
    final reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final opacity = reduceMotion ? (t > 0.02 ? 1.0 : 0.0) : t;
    final dy = reduceMotion ? 0.0 : (1.0 - t) * 12.0;
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, dy),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _reveal(
          p1,
          Text(
            overline,
            style: text.labelLarge?.copyWith(
              letterSpacing: 1.2,
              color: Colors.black54,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _reveal(
          p2,
          Text(
            title,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _reveal(
          p2,
          const Divider(height: 20),
        ),
        const SizedBox(height: 4),
        _reveal(
          p2,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(min(3, bullets.length), (i) {
              final t = [p1, p2, p3][min(i, 2)];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: _reveal(
                  t,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ', style: TextStyle(height: 1.3)),
                      Expanded(
                        child: Text(
                          bullets[i],
                          style: text.bodyLarge?.copyWith(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),
        _reveal(
          pCTA,
          Align(
            alignment: Alignment.centerLeft,
            child: _Pressable(
              pressedScale: 0.965,
              hoverScale: 1.02,
              onTap: onTap,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: Text(
                  ctaText,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 3-image mosaic that varies in shape; uses accent for subtle border highlights.
class _MosaicImages extends StatelessWidget {
  final List<String> urls; // expect 3
  final Color accent;
  final int variant; // 1 or 2

  const _MosaicImages({
    required this.urls,
    required this.accent,
    required this.variant,
  });

  Widget _tile(String url, {required double aspect, required BorderRadius radius}) {
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: accent.withAlpha(26)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AspectRatio(
          aspectRatio: aspect,
          child: Image.network(url, fit: BoxFit.cover),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = urls.isNotEmpty ? urls[0] : 'https://picsum.photos/seed/a/800/600';
    final b = urls.length > 1 ? urls[1] : 'https://picsum.photos/seed/b/600/800';
    final c = urls.length > 2 ? urls[2] : 'https://picsum.photos/seed/c/700/700';

    // Two variants to give slight variety in shapes/weights.
    if (variant == 1) {
      // Tall-left, two stacks right
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                flex: 12,
                child: _tile(a, aspect: 3 / 4, radius: BorderRadius.circular(18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 10,
                child: Column(
                  children: [
                    _tile(b, aspect: 16 / 9, radius: BorderRadius.circular(16)),
                    const SizedBox(height: 12),
                    _tile(c, aspect: 1, radius: BorderRadius.circular(16)),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Wide-top, two below
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tile(b, aspect: 16 / 9, radius: BorderRadius.circular(18)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _tile(a, aspect: 4 / 5, radius: BorderRadius.circular(16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _tile(c, aspect: 1, radius: BorderRadius.circular(16)),
              ),
            ],
          ),
        ],
      );
    }
  }
}