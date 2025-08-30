import 'package:flutter/material.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/screens/dashboard_screen.dart';
import 'package:color_canvas/screens/roller_screen.dart';
import 'package:color_canvas/screens/search_screen.dart';
import 'package:color_canvas/screens/color_story_main_screen.dart';
import 'package:color_canvas/screens/visualizer_screen.dart';
import 'package:color_canvas/utils/debug_logger.dart';

abstract class HomeScreenPaintSelection {
  void onPaintSelectedFromSearch(Paint paint);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    implements HomeScreenPaintSelection {
  int _currentIndex = 0; // Start with Roller tab
  final GlobalKey<RollerScreenStatePublic> _rollerKey =
      GlobalKey<RollerScreenStatePublic>();

  late final List<Widget> _screens = [
    RollerScreen(key: _rollerKey),
    const ColorStoryMainScreen(),
    SearchScreen(
        onPaintSelectedForRoller: onPaintSelectedFromSearch), // Pass callback
    const VisualizerScreen(),
    const DashboardScreen(), // Now the Account page
  ];

  @override
  void onPaintSelectedFromSearch(Paint paint) {
    Debug.info('HomeScreen', 'onPaintSelectedFromSearch',
        'Paint selected: ${paint.name}');

    // Switch to roller screen
    setState(() {
      _currentIndex = 0; // Roller is now at index 0
    });

    Debug.info('HomeScreen', 'onPaintSelectedFromSearch',
        'Switched to roller tab, scheduling dialog');

    // Show selection dialog to choose which column to replace
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showColumnSelectionDialog(paint);
    });
  }

  void _showColumnSelectionDialog(Paint paint) {
    Debug.info('HomeScreen', '_showColumnSelectionDialog',
        'Showing color selection dialog for: ${paint.name}');

    final rollerState = _rollerKey.currentState;
    if (rollerState == null) {
      Debug.error('HomeScreen', '_showColumnSelectionDialog',
          'RollerState is null, cannot show dialog');
      return;
    }

    final paletteSize = rollerState.getPaletteSize();
    Debug.info('HomeScreen', '_showColumnSelectionDialog',
        'Palette size: $paletteSize');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height *
              0.7, // Max 70% of screen height
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              'Add Color to Palette',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how to add ${paint.name} to your palette',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Show selected paint info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color:
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ColorUtils.getPaintColor(paint.hex),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paint.name,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        Text(
                          paint.brandName,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Add as New option (if possible)
            if (rollerState.canAddNewColor()) ...[
              Card(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3),
                child: InkWell(
                  onTap: () {
                    rollerState.addPaintToCurrentPalette(paint);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added ${paint.name} as new color'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add as New Color',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Expand palette to ${paletteSize + 1} colors',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                              ),
                            ],
                          ),
                        ),

                        // Preview of new color
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: ColorUtils.getPaintColor(paint.hex),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Show max size message if can't add new colors
            if (!rollerState.canAddNewColor()) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Palette is at maximum size (9 colors). Choose a color to replace.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                rollerState.canAddNewColor()
                    ? 'Or choose position to replace:'
                    : 'Choose position to replace:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            const SizedBox(height: 12),

            // Scrollable list of palette positions
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(paletteSize, (index) {
                    final currentPaint = rollerState.getPaintAtIndex(index);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          rollerState.replacePaintAtIndex(index, paint);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Replaced color ${index + 1} with ${paint.name}'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Current color
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: currentPaint != null
                                      ? ColorUtils.getPaintColor(
                                          currentPaint.hex)
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey[400]!),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Paint info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentPaint?.name ??
                                          'Empty Position ${index + 1}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    if (currentPaint != null)
                                      Text(
                                        currentPaint.brandName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                      ),
                                  ],
                                ),
                              ),

                              // Arrow and preview
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_forward,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color:
                                          ColorUtils.getPaintColor(paint.hex),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.color_lens_outlined),
            activeIcon: Icon(Icons.color_lens),
            label: 'Roller',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Story',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.weekend_outlined),
            activeIcon: Icon(Icons.weekend),
            label: 'Visualizer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
