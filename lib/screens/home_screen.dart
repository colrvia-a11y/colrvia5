import 'package:flutter/material.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/screens/dashboard_screen.dart';
import 'roller_screen.dart';
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
  int _currentIndex = 0; // Home tab is now index 0
  final GlobalKey<RollerScreenStatePublic> _rollerKey =
      GlobalKey<RollerScreenStatePublic>();

  late final List<Widget> _screens = [
    const HomeLandingScreen(), // 0: Home
    SearchScreen(
        onPaintSelectedForRoller: onPaintSelectedFromSearch), // 1: Search
    const DashboardScreen(), // 2: Account
    RollerScreen(key: _rollerKey), // 3: Roller
    const ColorStoryMainScreen(), // 4: Story
    const VisualizerScreen(), // 5: Visualizer
  ];

  void setTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void onPaintSelectedFromSearch(Paint paint) {
    Debug.info('HomeScreen', 'onPaintSelectedFromSearch',
        'Paint selected: ${paint.name}');

    // Switch to roller screen
    setState(() {
      _currentIndex = 1; // Roller is now at index 1
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
        currentIndex: _currentIndex > 2 ? 0 : _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Search',
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

// --- NEW HOME LANDING SCREEN ---
class HomeLandingScreen extends StatelessWidget {
  const HomeLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Getting Started
                Text('Getting Started', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _GettingStartedChecklist(),
                const SizedBox(height: 32),
                // Section 2: Color Stories
                Text('Color Stories', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _ColorStoriesSection(),
                const SizedBox(height: 32),
                // Section 3: Color Story Tools
                Text('Color Story Tools', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _ToolsCarousel(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GettingStartedChecklist extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual user state
    final bool hasAccount = false;
    final bool hasStartedStory = false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChecklistItem(
          label: 'Create Account',
          checked: hasAccount,
          onTap: () {
            // TODO: Link to create account center
          },
        ),
        _ChecklistItem(
          label: 'Start a Color Story',
          checked: hasStartedStory,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const StartColorStoryScreen(),
            ));
          },
        ),
        _ChecklistItem(
          label: 'Color Your Space',
          checked: false,
          onTap: () {
            // TODO: Link to visualizer page
          },
        ),
      ],
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onTap;

  const _ChecklistItem({required this.label, required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: (_) => onTap(),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _ColorStoriesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual user color stories
    final List<_ColorStory> stories = [
      _ColorStory('Example Story 1', true),
      _ColorStory('Example Story 2', true),
      _ColorStory('Example Story 3', true),
    ];
    return Row(
      children: [
        ...stories.map((story) => _ColorStoryPill(story: story)),
        GestureDetector(
          onTap: () {
            // TODO: Link to view more page
          },
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text('View More', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class _ColorStory {
  final String title;
  final bool isExample;
  _ColorStory(this.title, this.isExample);
}

class _ColorStoryPill extends StatelessWidget {
  final _ColorStory story;
  const _ColorStoryPill({required this.story});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: story.isExample ? Colors.grey[100] : Colors.blue[50],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: story.isExample ? Colors.grey : Colors.blue, width: 1),
      ),
      child: Row(
        children: [
          Text(story.title, style: TextStyle(fontWeight: FontWeight.bold)),
          if (story.isExample)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Example', style: TextStyle(fontSize: 10, color: Colors.orange[800])),
            ),
        ],
      ),
    );
  }
}

class _ToolsCarousel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final List<_ToolCardData> tools = [
      _ToolCardData('Color Roller', Icons.palette, Colors.purple[100]!, tabIndex: 3),
      _ToolCardData('Story', Icons.auto_stories, Colors.green[100]!, tabIndex: 4),
      _ToolCardData('Visualizer', Icons.psychology, Colors.blue[100]!, tabIndex: 5),
      _ToolCardData('Explore', Icons.explore, Colors.orange[100]!, tabIndex: null),
    ];
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tools.length,
        separatorBuilder: (_, __) => SizedBox(width: 16),
        itemBuilder: (context, index) {
          final tool = tools[index];
          return AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 260,
            child: _ToolCard(tool: tool),
          );
        },
      ),
    );
  }
}

class _ToolCardData {
  final String title;
  final IconData icon;
  final Color color;
  final int? tabIndex;
  _ToolCardData(this.title, this.icon, this.color, {this.tabIndex});
}

class _ToolCard extends StatelessWidget {
  final _ToolCardData tool;
  const _ToolCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: tool.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 4,
      child: InkWell(
        onTap: () {
          if (tool.tabIndex != null) {
            // Use ancestor HomeScreenState to set tab index
            final homeState = context.findAncestorStateOfType<HomeScreenState>();
            if (homeState != null) {
              homeState.setTab(tool.tabIndex!);
            }
          } else {
            // TODO: Link to Explore page
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tool.icon, size: 48, color: Colors.black54),
              const SizedBox(height: 16),
              Text(tool.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }
}

// Placeholder for Start Color Story page
class StartColorStoryScreen extends StatefulWidget {
  const StartColorStoryScreen({super.key});

  @override
  State<StartColorStoryScreen> createState() => _StartColorStoryScreenState();
}

class _StartColorStoryScreenState extends State<StartColorStoryScreen> {
  String? _selectedRoom;
  final List<String> _rooms = [
    'Living Room',
    'Bedroom',
    'Kitchen',
    'Bathroom',
    'Dining Room',
    'Office',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Start a Color Story'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Let's Design Your Space",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'A Color Story guides you through the process of designing your space. You will: \n\n• Design your room\n• Learn about color and style\n• Visualize your ideas',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start a Color Story', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text('What room are we designing?', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedRoom,
                      items: _rooms.map((room) => DropdownMenuItem(
                        value: room,
                        child: Text(room),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRoom = value;
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        labelText: 'Room',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
