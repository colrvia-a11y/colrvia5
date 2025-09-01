// home_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../firestore/firestore_data_schema.dart';
import '../services/user_prefs_service.dart';
import 'create_screen.dart';
import 'projects_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'roller_screen.dart';
import 'package:color_canvas/widgets/via_overlay.dart';

/// Home scaffold with 4 bottom tabs: Create, Projects, Search, Account.
/// Custom circular, icons-only bottom navigation with transparent background.
/// SINGLE access point: new floating ViaBubble (replaces old FAB design).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  /// Called by SearchScreen to load a paint into the RollerScreen.
  void onPaintSelectedFromSearch(Paint paint) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RollerScreen(initialPaintIds: [paint.id]),
      ),
    );
  }

  int _currentIndex = 0;

  final _screens = <Widget>[
    const CreateScreen(),
    const ProjectsScreen(),
    const SearchScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _determineLanding();
  }

  Future<void> _determineLanding() async {
    final prefs = await UserPrefsService.fetch();
    setState(() => _currentIndex = prefs.firstRunCompleted ? 1 : 0);
  }

  void _onItemTapped(int index) => setState(() => _currentIndex = index);

  void _openVia({String contextLabel = 'ViaBubble'}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (_) => ViaOverlay(contextLabel: contextLabel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // allows content behind the transparent nav
      body: _screens[_currentIndex],
      bottomNavigationBar: _CircularIconNavBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // NEW persistent access bubble for Via (single source of truth)
      floatingActionButton: ViaBubble(
        tooltip: 'Ask Via',
        onTap: () {
          HapticFeedback.selectionClick();
          _openVia(contextLabel: 'Home');
        },
      ),
    );
  }
}

/// Icons-only circular nav with semi-transparent dark circles.
/// Selected item shows thin border and icon in #f2b897 while the circle bg stays the same.
class _CircularIconNavBar extends StatelessWidget {
  const _CircularIconNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _highlight = Color(0xFFF2B897);
  static const _icons = <IconData>[
    Icons.add_circle_outline, // Create
    Icons.folder,             // Projects
    Icons.search,             // Search
    Icons.person,             // Account
  ];

  @override
  Widget build(BuildContext context) {
    final circleBg = Colors.black.withOpacity(0.20);
    final unselectedIcon = Colors.white.withOpacity(0.90);

    return SafeArea(
      top: false,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_icons.length, (index) {
            final selected = currentIndex == index;
            return _NavCircleButton(
              icon: _icons[index],
              selected: selected,
              onPressed: () => onTap(index),
              circleColor: circleBg,
              iconColor: selected ? _highlight : unselectedIcon,
              borderColor: selected ? _highlight : Colors.transparent,
            );
          }),
        ),
      ),
    );
  }
}

class _NavCircleButton extends StatelessWidget {
  const _NavCircleButton({
    required this.icon,
    required this.selected,
    required this.onPressed,
    required this.circleColor,
    required this.iconColor,
    required this.borderColor,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;
  final Color circleColor;
  final Color iconColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    const double diameter = 56;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                    color: Colors.black.withOpacity(0.10),
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------- New Via access bubble ----------------------
/// Frosted, glowing, feathered bubble that feels integrated with the UI.
/// Tap → opens ViaOverlay. Keep ViaOverlay free of any access bubble UI.
class ViaBubble extends StatefulWidget {
  const ViaBubble({
    super.key,
    this.size = 64,
    this.tooltip,
    this.onTap,
  });

  final double size;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  State<ViaBubble> createState() => _ViaBubbleState();
}

class _ViaBubbleState extends State<ViaBubble>
    with SingleTickerProviderStateMixin {
  static const _peach = Color(0xFFF2B897);
  late final AnimationController _breath;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    final bubble = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.96 : 1.0,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ambient glow halo
              AnimatedBuilder(
                animation: _breath,
                builder: (_, __) {
                  final t = _breath.value;
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _peach.withOpacity(0.32 + t * 0.10),
                          blurRadius: 28 + t * 10,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Frosted core with soft gradient (feathered look)
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.10),
                          Colors.white.withOpacity(0.04),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.14),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
              // Via icon (bolt)
              const Icon(Icons.bolt_rounded, size: 28, color: Colors.white),
              // Thin peach ring to echo brand
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _peach.withOpacity(0.55),
                    width: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Tooltip(
      message: widget.tooltip ?? 'Ask Via',
      preferBelow: false,
      child: bubble,
    );
  }
}
