import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/models/color_story.dart' as model;
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/services/project_service.dart';
import 'package:color_canvas/services/ai_service.dart';
import 'package:color_canvas/services/analytics_service.dart';
// ...existing code...
import 'color_plan_detail_screen.dart';
import 'package:color_canvas/screens/settings_screen.dart';
import 'package:color_canvas/utils/color_utils.dart';
// REGION: CODEX-ADD color-plan-screen-imports
import 'package:color_canvas/models/color_plan.dart';
// END REGION: CODEX-ADD color-plan-screen-imports

class ColorPlanScreen extends StatefulWidget {
  final String projectId;
  final String? paletteId; // Pre-selected palette
  final String? remixStoryId; // Story ID for remix mode

  const ColorPlanScreen(
      {super.key, required this.projectId, this.paletteId, this.remixStoryId});

  @override
  State<ColorPlanScreen> createState() => _ColorPlanScreenState();
}

class _ColorPlanScreenState extends State<ColorPlanScreen> {
  final PageController _pageController = PageController();

  // Form data
  String? _selectedPaletteId;
  UserPalette? _selectedPalette;
  String _roomType = 'living';
  String _styleTag = 'modern-farmhouse';
  Map<String, double> _vibeValues = {
    'calm_energetic': 0.5, // calm ↔ energetic
    'warm_cool': 0.5, // warm ↔ cool
    'airy_cozy': 0.5, // airy ↔ cozy
  };
  final Set<String> _brandHints = {};
  String _guidanceLevel = 'balanced';

  // UI state
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isGenerating = false;
  List<UserPalette> _availablePalettes = [];

  // Remix mode
  bool get _isRemixMode => widget.remixStoryId != null;
  model.ColorStory? _originalStory;

  // Room types
  final List<Map<String, dynamic>> _roomTypes = [
    {'id': 'living', 'label': 'Living Room', 'icon': Icons.weekend},
    {'id': 'bedroom', 'label': 'Bedroom', 'icon': Icons.bed},
    {'id': 'kitchen', 'label': 'Kitchen', 'icon': Icons.kitchen},
    {'id': 'bathroom', 'label': 'Bathroom', 'icon': Icons.bathtub},
    {'id': 'dining', 'label': 'Dining Room', 'icon': Icons.dining},
    {'id': 'office', 'label': 'Home Office', 'icon': Icons.desk},
    {'id': 'exterior', 'label': 'Exterior', 'icon': Icons.home},
  ];

  // Style tags
  final List<Map<String, dynamic>> _styleTags = [
    {'id': 'coastal', 'label': 'Coastal', 'description': 'Breezy and relaxed'},
    {
      'id': 'modern-farmhouse',
      'label': 'Modern Farmhouse',
      'description': 'Rustic meets contemporary'
    },
    {
      'id': 'traditional',
      'label': 'Traditional',
      'description': 'Timeless and elegant'
    },
    {
      'id': 'contemporary',
      'label': 'Contemporary',
      'description': 'Clean and current'
    },
    {'id': 'rustic', 'label': 'Rustic', 'description': 'Natural and warm'},
    {
      'id': 'minimalist',
      'label': 'Minimalist',
      'description': 'Simple and uncluttered'
    },
    {
      'id': 'japandi',
      'label': 'Japandi',
      'description': 'Japanese-Scandinavian fusion'
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedPaletteId = widget.paletteId;
    _loadData();

    // Track wizard open
    AnalyticsService.instance.logEvent('wizard_open', {
      'source': _isRemixMode
          ? 'remix'
          : widget.paletteId != null
              ? 'palette_detail'
              : 'explore_fab',
      'pre_selected_palette': widget.paletteId != null,
      'remix_mode': _isRemixMode,
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load user palettes
      final userId = FirebaseService.currentUser?.uid;
      if (userId != null) {
        final palettes = await FirebaseService.getUserPalettes(userId);
        setState(() => _availablePalettes = palettes);

        // If palette ID provided, find and set it
        if (_selectedPaletteId != null) {
          try {
            _selectedPalette = palettes.firstWhere(
              (p) => p.id == _selectedPaletteId!,
            );
          } catch (e) {
            // Palette ID not found, fall back to first available palette
            if (palettes.isNotEmpty) {
              _selectedPalette = palettes.first;
              _selectedPaletteId = palettes.first.id;
            }
          }
        } else if (palettes.isNotEmpty) {
          // Default to most recent
          _selectedPalette = palettes.first;
          _selectedPaletteId = palettes.first.id;
        }
      }

      // Load original story for remix mode
      if (_isRemixMode && widget.remixStoryId != null) {
        try {
          _originalStory =
              await FirebaseService.getColorStory(widget.remixStoryId!);
          if (_originalStory != null) {
            _prefillFromOriginalStory();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Error loading original story: \$e')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading data: \$e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Prefill form with original story inputs for remix mode
  void _prefillFromOriginalStory() {
    if (_originalStory == null) return;

    final story = _originalStory!;

    setState(() {
      // Set room type and style from original story
      if (story.room.isNotEmpty) {
        _roomType = story.room;
      }
      if (story.style.isNotEmpty) {
        _styleTag = story.style;
      }

      // Try to reconstruct vibe values from vibe words
      if (story.vibeWords.isNotEmpty) {
        _reconstructVibeValues(story.vibeWords);
      }

      // Note: model.ColorStory doesn't have brandHints or sourcePaletteId
      // so we keep the current palette selection
    });
  }

  /// Reconstruct vibe slider values from vibe words
  void _reconstructVibeValues(List<String> vibeWords) {
    // Reset to defaults
    _vibeValues = {
      'calm_energetic': 0.5,
      'warm_cool': 0.5,
      'airy_cozy': 0.5,
    };

    // Adjust based on vibe words
    for (final word in vibeWords) {
      switch (word.toLowerCase()) {
        case 'calm':
        case 'serene':
        case 'peaceful':
          _vibeValues['calm_energetic'] = 0.2;
          break;
        case 'energetic':
        case 'vibrant':
        case 'bold':
          _vibeValues['calm_energetic'] = 0.8;
          break;
        case 'warm':
        case 'cozy':
          _vibeValues['warm_cool'] = 0.2;
          _vibeValues['airy_cozy'] = 0.8;
          break;
        case 'cool':
        case 'crisp':
          _vibeValues['warm_cool'] = 0.8;
          break;
        case 'airy':
        case 'spacious':
        case 'open':
          _vibeValues['airy_cozy'] = 0.2;
          break;
      }
    }
  }

  Future<void> _generateColorStory() async {
    // 🐛 DEBUG: Enhanced validation with detailed logging
    debugPrint('🐛 Wizard: _generateColorStory called');
    debugPrint('🐛 Wizard: _canGenerate() = ${_canGenerate()}');
    debugPrint('🐛 Wizard: _selectedPalette = $_selectedPalette');
    debugPrint(
        '🐛 Wizard: _selectedPalette?.colors.length = ${_selectedPalette?.colors.length}');
    debugPrint('🐛 Wizard: _roomType = "$_roomType"');
    debugPrint('🐛 Wizard: _styleTag = "$_styleTag"');

    // Check authentication before generating
    final user = FirebaseService.currentUser;
    if (user == null) {
      // Show dialog to prompt sign in
      final shouldSignIn = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign In Required'),
          content: const Text(
              'You need to sign in to generate color stories. Your stories will be saved to your account so you can access them later.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign In'),
            ),
          ],
        ),
      );

      if (shouldSignIn == true && mounted) {
        // Navigate to settings screen for sign in
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );

        // Check if user signed in after returning from settings
        if (FirebaseService.currentUser == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Sign in required to generate color stories')),
            );
          }
          return;
        }
      } else {
        return; // User cancelled
      }
    }

    if (!_canGenerate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pick a palette with at least one color first.'),
          ),
        );
      }
      return;
    }

    // Extra safety check
    final palette = _selectedPalette;
    if (palette == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No palette selected')),
        );
      }
      return;
    }

    if (palette.colors.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected palette has no colors')),
        );
      }
      return;
    }

    // Validate palette colors for null safety
    for (int i = 0; i < palette.colors.length; i++) {
      final color = palette.colors[i];
      debugPrint(
          '🐛 Wizard: Color[$i] - hex: "${color.hex}", name: "${color.name}", brand: "${color.brand}", code: "${color.code}"');

      if (color.hex.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Color ${i + 1} is missing hex value')),
          );
        }
        return;
      }
    }

    setState(() => _isGenerating = true);

    try {
      final vibeWords = _getVibeWords();
      final brandHints = _brandHints.toList();

      debugPrint('🐛 Wizard: vibeWords = $vibeWords');
      debugPrint('🐛 Wizard: brandHints = $brandHints');
      debugPrint('🐛 Wizard: About to call AiService.generateColorStory');

      // Track generation start
      AnalyticsService.instance.logEvent('story_generate_start', {
        'palette_id': _selectedPaletteId,
        'style_tag': _styleTag,
        'room_type': _roomType,
        'vibe_words': vibeWords,
        'brand_hints': brandHints,
        'guidance_level': _guidanceLevel,
      });

      // Use the new simplified AiService API
      final storyId = await AiService.generateColorStory(
        palette: palette,
        room: _roomType,
        style: _styleTag,
        vibeWords: vibeWords,
        brandHints: brandHints,
      );

      debugPrint('🐛 Wizard: AiService returned storyId = $storyId');

      if (!mounted) return;

      // Update project with story ID
      try {
        // Use constructor projectId (no lookups)
        await ProjectService.setStory(widget.projectId, storyId);
        AnalyticsService.instance.logStoryGenerated(widget.projectId, storyId);
      } catch (e) {
        debugPrint('Failed to update project with story: $e');
      }

      debugPrint(
          '🐛 Wizard: About to navigate to ColorPlanDetailScreen with storyId = $storyId');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) => ColorPlanDetailScreen(storyId: storyId)),
        );
      }

      // TEST: Create a public test document to verify rules work
      debugPrint(
          '🐛 Wizard: Testing Firestore rules by creating a public test document');

      try {
        final testDocId = 'test_${DateTime.now().millisecondsSinceEpoch}';
        final currentUser = FirebaseService.currentUser;

        debugPrint('🐛 Wizard: Current user for test: ${currentUser?.uid}');

        // Create a test document with public access
        await FirebaseFirestore.instance
            .collection('colorStories')
            .doc(testDocId)
            .set({
          'id': testDocId,
          'ownerId': currentUser?.uid ?? 'test-user',
          'access': 'public',
          'status': 'test',
          'name': 'Test Document',
          'storyText': 'This is a test document',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('🐛 Wizard: Test document created successfully');

        // Try to read it back
        final testDoc = await FirebaseFirestore.instance
            .collection('colorStories')
            .doc(testDocId)
            .get();

        debugPrint('🐛 Wizard: Test document read result:');
        debugPrint('🐛 Wizard: - Exists: ${testDoc.exists}');
        if (testDoc.exists) {
          final data = testDoc.data() ?? {};
          debugPrint('🐛 Wizard: - Access: ${data['access']}');
          debugPrint('🐛 Wizard: - OwnerId: ${data['ownerId']}');
          debugPrint(
              '🐛 Wizard: SUCCESS - Firestore rules work for public documents');
        }

        // Clean up test document
        await FirebaseFirestore.instance
            .collection('colorStories')
            .doc(testDocId)
            .delete();
        debugPrint('🐛 Wizard: Test document cleaned up');
      } catch (e) {
        debugPrint('🐛 Wizard: Test document error: $e');
        debugPrint(
            '🐛 Wizard: This suggests a fundamental Firestore rules or auth issue');
      }

      // Now test the cloud function generated document with retry for timing
      debugPrint(
          '🐛 Wizard: Testing cloud function generated document: $storyId');

      // Try multiple times with increasing delays to account for cloud function timing
      bool documentFound = false;
      for (int attempt = 1; attempt <= 5 && !documentFound; attempt++) {
        try {
          if (attempt > 1) {
            final delay = attempt * 1000; // 1s, 2s, 3s, 4s, 5s
            debugPrint('🐛 Wizard: Waiting ${delay}ms before attempt $attempt');
            await Future.delayed(Duration(milliseconds: delay));
          }

          final directDoc = await FirebaseFirestore.instance
              .collection('colorStories')
              .doc(storyId)
              .get();

          debugPrint(
              '🐛 Wizard: Cloud function document result (attempt $attempt):');
          debugPrint('🐛 Wizard: - Document exists: ${directDoc.exists}');

          if (directDoc.exists) {
            documentFound = true;
            final data = directDoc.data() ?? {};
            debugPrint('🐛 Wizard: - Document ownerId: ${data['ownerId']}');
            debugPrint('🐛 Wizard: - Document access: ${data['access']}');
            debugPrint(
                '🐛 Wizard: - Current user: ${FirebaseService.currentUser?.uid}');
            debugPrint(
                '🐛 Wizard: - User match: ${data['ownerId'] == FirebaseService.currentUser?.uid}');
            debugPrint('🐛 Wizard: - Document status: ${data['status']}');
            debugPrint(
                '🐛 Wizard: SUCCESS - Document found after $attempt attempts');
            break;
          } else {
            debugPrint(
                '🐛 Wizard: - Document does not exist on attempt $attempt');
          }
        } catch (e) {
          debugPrint(
              '🐛 Wizard: Document access error on attempt $attempt: $e');
        }
      }

      if (!documentFound) {
        debugPrint(
            '🐛 Wizard: CRITICAL: Cloud function document never appeared after 5 attempts');
        debugPrint(
            '🐛 Wizard: This indicates the cloud function is not actually creating the document');
      }

      if (!mounted) return;

      // Navigate to the color plan detail screen
      Navigator.pushReplacementNamed(
        context,
        '/colorPlanDetail',
        arguments: storyId,
      );

      debugPrint('🐛 Wizard: Navigation call completed');
    } catch (e) {
      if (mounted) {
        String errorMessage;
        if (e.toString().contains('unauthenticated') ||
            e.toString().contains('Authentication') ||
            e.toString().contains('sign in')) {
          errorMessage = 'Please sign in to generate color stories';
        } else if (e.toString().contains('Palette not found')) {
          errorMessage = 'Selected palette not found';
        } else if (e.toString().contains('network') ||
            e.toString().contains('connection')) {
          errorMessage = 'Check your internet connection and try again';
        } else {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _generateColorStory,
            ),
          ),
        );

        // Track error with more details
        AnalyticsService.instance.logEvent('story_generate_error', {
          'error': e.toString(),
          'error_type': e.runtimeType.toString(),
          'palette_id': _selectedPaletteId,
          'user_id': FirebaseService.currentUser?.uid ?? 'anonymous',
        });
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  List<String> _getVibeWords() {
    final words = <String>[];

    // Convert slider values to descriptive words
    if (_vibeValues['calm_energetic']! < 0.3) {
      words.add('calm');
    } else if (_vibeValues['calm_energetic']! > 0.7) {
      words.add('energetic');
    }

    if (_vibeValues['warm_cool']! < 0.3) {
      words.add('cool');
    } else if (_vibeValues['warm_cool']! > 0.7) {
      words.add('warm');
    }

    if (_vibeValues['airy_cozy']! < 0.3) {
      words.add('airy');
    } else if (_vibeValues['airy_cozy']! > 0.7) {
      words.add('cozy');
    }

    // Add some defaults if no strong preferences
    if (words.isEmpty) {
      words.addAll(['balanced', 'harmonious']);
    }

    return words;
  }

  void _nextStep() {
    HapticFeedback.selectionClick();
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    HapticFeedback.selectionClick();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _canGenerate() {
    return _selectedPalette != null &&
        _selectedPalette!.colors.isNotEmpty &&
        _roomType.isNotEmpty &&
        _styleTag.isNotEmpty &&
        !_isGenerating;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRemixMode ? 'Remix Color Story' : 'Create Color Story'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_currentStep < 3)
            TextButton(
              onPressed: _canGenerate() ? _nextStep : null,
              child: const Text('Next'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Remix mode banner
                if (_isRemixMode)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.3),
                          Theme.of(context)
                              .colorScheme
                              .secondaryContainer
                              .withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_fix_high,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Remix keeps your palette—tweak the vibe.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Progress indicator
                LinearProgressIndicator(
                  value: (_currentStep + 1) / 4,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                ),

                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildPaletteSelectionStep(),
                      _buildRoomAndStyleStep(),
                      _buildVibeStep(),
                      _buildConstraintsStep(),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildPaletteSelectionStep() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isRemixMode ? 'Your Palette' : 'Choose a Palette',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _isRemixMode
                ? 'This palette will be used for the remix (read-only)'
                : 'Select the color palette you want to turn into a story',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (_availablePalettes.isEmpty)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.palette, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No saved palettes found'),
                  Text('Create some palettes first in the Roller tab'),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _availablePalettes.length,
                itemBuilder: (context, index) {
                  final palette = _availablePalettes[index];
                  final isSelected = palette.id == _selectedPaletteId;

                  return Opacity(
                    opacity: (_isRemixMode && !isSelected) ? 0.4 : 1.0,
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: _isRemixMode
                            ? null
                            : () {
                                setState(() {
                                  _selectedPaletteId = palette.id;
                                  _selectedPalette = palette;
                                });
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Color preview
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: palette.colors.take(5).map((color) {
                                  return Container(
                                    width: 24,
                                    height: 24,
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.hexToColor(color.hex),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.grey.withValues(alpha: 0.3),
                                        width: 0.5,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(width: 16),

                              // Palette info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      palette.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Text(
                                      '\${palette.colors.length} colors',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),

                              // Selection indicator
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoomAndStyleStep() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Room & Style',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'What room and style are you designing?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // Room Type
          Text(
            'Room Type',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _roomTypes.map((room) {
              final isSelected = _roomType == room['id'];
              return FilterChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(room['icon'], size: 16),
                    const SizedBox(width: 4),
                    Text(room['label']),
                  ],
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _roomType = room['id']);
                  }
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Style
          Text(
            'Style',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _styleTags.length,
              itemBuilder: (context, index) {
                final style = _styleTags[index];
                final isSelected = _styleTag == style['id'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    selected: isSelected,
                    title: Text(style['label']),
                    subtitle: Text(style['description']),
                    trailing: isSelected
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () => setState(() => _styleTag = style['id']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVibeStep() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set the Vibe',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Adjust the sliders to define the mood you want',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),

          // Vibe sliders
          _buildVibeSlider(
            'Energy Level',
            'Calm',
            'Energetic',
            'calm_energetic',
            Icons.self_improvement,
            Icons.flash_on,
          ),

          const SizedBox(height: 32),

          _buildVibeSlider(
            'Temperature',
            'Cool',
            'Warm',
            'warm_cool',
            Icons.ac_unit,
            Icons.whatshot,
          ),

          const SizedBox(height: 32),

          _buildVibeSlider(
            'Atmosphere',
            'Airy',
            'Cozy',
            'airy_cozy',
            Icons.air,
            Icons.home,
          ),

          const Spacer(),

          // Live preview card
          if (_selectedPalette != null) _buildPreviewCard(),
        ],
      ),
    );
  }

  Widget _buildVibeSlider(
    String title,
    String leftLabel,
    String rightLabel,
    String key,
    IconData leftIcon,
    IconData rightIcon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(leftIcon, size: 20, color: Colors.grey),
            const SizedBox(width: 8),
            Text(leftLabel, style: Theme.of(context).textTheme.bodySmall),
            Expanded(
              child: Slider(
                value: _vibeValues[key]!,
                onChanged: (value) {
                  setState(() => _vibeValues[key] = value);
                },
                divisions: 4,
              ),
            ),
            Text(rightLabel, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
            Icon(rightIcon, size: 20, color: Colors.grey),
          ],
        ),
      ],
    );
  }

  Widget _buildConstraintsStep() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferences',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Any specific constraints or preferences?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // Brand hints
          Text(
            'Preferred Brands (optional)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                ['Sherwin-Williams', 'Benjamin Moore', 'Behr'].map((brand) {
              final isSelected = _brandHints.contains(brand);
              return FilterChip(
                selected: isSelected,
                label: Text(brand),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _brandHints.add(brand);
                    } else {
                      _brandHints.remove(brand);
                    }
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Guidance level
          Text(
            'Detail Level',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          RadioGroup<String>(
            onChanged: (value) => setState(() => _guidanceLevel = value!),
            child: const Column(
              children: [
                ListTile(
                  title: Text('Minimal'),
                  subtitle: Text('Essential guidance only'),
                  leading: Radio<String>(
                    value: 'minimal',
                  ),
                ),
                ListTile(
                  title: Text('Balanced'),
                  subtitle: Text('Good mix of inspiration and practical tips'),
                  leading: Radio<String>(
                    value: 'balanced',
                  ),
                ),
                ListTile(
                  title: Text('Detailed'),
                  subtitle: Text('Comprehensive room design guide'),
                  leading: Radio<String>(
                    value: 'detailed',
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Generate button
          if (_selectedPalette != null) _buildPreviewCard(),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    if (_selectedPalette == null) return const SizedBox();

    final colors = _selectedPalette!.colors;
    final lightestColor = colors.first.hex;
    final darkestColor = colors.last.hex;

    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorUtils.hexToColor(lightestColor).withValues(alpha: 0.8),
            ColorUtils.hexToColor(darkestColor).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Color dots
          Positioned(
            top: 16,
            left: 16,
            child: Row(
              children: colors.take(5).map((color) {
                return Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: ColorUtils.hexToColor(color.hex),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                );
              }).toList(),
            ),
          ),

          // Live preview text
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '\${_selectedPalette!.name} Story',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_getVibeWords().join(', ')} • $_roomType • ${_styleTags.firstWhere((s) => s['id'] == _styleTag)['label']}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _previousStep,
              child: const Text('Back'),
            ),
          const Spacer(),
          if (_currentStep < 3)
            FilledButton(
              onPressed: _canGenerate() ? _nextStep : null,
              child: const Text('Next'),
            )
          else
            FilledButton(
              onPressed: _canGenerate() ? _generateColorStory : null,
              child: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Generate Story'),
            ),
        ],
      ),
    );
  }

// REGION: CODEX-ADD color-plan-screen
  Widget _buildPlanPreview(ColorPlan plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (plan.placementMap.isNotEmpty)
          Text('Placements: ' +
              plan.placementMap
                  .map((p) => '${p.area}-${p.colorId}')
                  .join(', ')),
        if (plan.cohesionTips.isNotEmpty)
          Text('Cohesion: ' + plan.cohesionTips.join('; ')),
        if (plan.accentRules.isNotEmpty)
          Text('Accent: ' +
              plan.accentRules
                  .map((a) => '${a.context}: ${a.guidance}')
                  .join('; ')),
        if (plan.doDont.isNotEmpty)
          Text(
              'Do: ${plan.doDont.first.doText}\nDon\'t: ${plan.doDont.first.dontText}'),
        if (plan.sampleSequence.isNotEmpty)
          Text('Sequence: ' + plan.sampleSequence.join(' -> ')),
        if (plan.roomPlaybook.isNotEmpty)
          Text('Rooms: ' +
              plan.roomPlaybook.map((r) => r.roomType).join(', ')),
      ],
    );
  }
// END REGION: CODEX-ADD color-plan-screen

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
