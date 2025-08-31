import 'package:color_canvas/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/utils/color_utils.dart';

import 'package:color_canvas/screens/paint_detail_screen.dart';
import 'package:color_canvas/screens/compare_colors_screen.dart';
import 'package:color_canvas/utils/debug_logger.dart';
import 'dart:async';
// ...existing code...

class SearchScreen extends StatefulWidget {
  final Function(Paint)? onPaintSelectedForRoller;

  const SearchScreen({
    super.key,
    this.onPaintSelectedForRoller,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Paint> _searchResults = [];
  List<ColorPalette> _placeholderPalettes = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  bool _showClearButton = false;
  final Set<String> _selectedForCompare = {};

  // Debouncing variables
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    Debug.info('SearchScreen', 'initState', 'Component initializing');
    _generatePlaceholderPalettes();
    _searchController.addListener(_onSearchTextChanged);
  }

  void _onSearchTextChanged() {
    Debug.info('SearchScreen', '_onSearchTextChanged',
        'Text changed: "${_searchController.text}"');
    if (mounted) {
      setState(() {
        _showClearButton = _searchController.text.isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _generatePlaceholderPalettes() {
    Debug.info('SearchScreen', '_generatePlaceholderPalettes',
        'Generating placeholder palettes (disabled)');
    // Temporarily disable palette generation to test infinite loop
    _placeholderPalettes = [];

    // // Generate placeholder palettes for the grid - reduced count to prevent infinite loops
    // final random = Random();
    // _placeholderPalettes = List.generate(20, (index) {
    //   final colors = List.generate(5, (_) {
    //     return Color.fromRGBO(
    //       random.nextInt(256),
    //       random.nextInt(256),
    //       random.nextInt(256),
    //       1.0,
    //     );
    //   });
    //
    //   final paletteNames = [
    //     'Autumn Vibes', 'Ocean Breeze', 'Desert Sunset', 'Forest Dream',
    //     'Urban Chic', 'Pastel Spring', 'Bold Statement', 'Minimalist',
    //     'Retro Wave', 'Earth Tones', 'Neon Nights', 'Cozy Cabin',
    //     'Modern Art', 'Vintage Soul', 'Fresh Morning', 'Twilight Hour'
    //   ];
    //
    //   return ColorPalette(
    //     id: 'placeholder_$index',
    //     name: '${paletteNames[random.nextInt(paletteNames.length)]} ${index + 1}',
    //     colors: colors,
    //   );
    // });
  }

  Future<void> _performSearch(String query) async {
    Debug.info('SearchScreen', '_performSearch', 'Searching for: "$query"');
    if (!mounted) return;

    if (query.trim().isEmpty) {
      if (mounted) {
        Debug.setState('SearchScreen', '_performSearch',
            details: 'Clearing search results');
        setState(() {
          _searchResults = [];
          _showSearchResults = false;
        });
      }
      return;
    }

    if (mounted) {
      Debug.setState('SearchScreen', '_performSearch',
          details: 'Starting search');
      setState(() {
        _isSearching = true;
        _showSearchResults = true;
      });
    }

    try {
      final results = await FirebaseService.searchPaints(query.trim());
      Debug.info(
          'SearchScreen', '_performSearch', 'Found ${results.length} results');
      if (mounted) {
        Debug.setState('SearchScreen', '_performSearch',
            details: 'Setting search results');
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      Debug.error('SearchScreen', '_performSearch', 'Search failed: $e');
      if (mounted) {
        Debug.setState('SearchScreen', '_performSearch',
            details: 'Search error occurred');
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    }
  }

  void _selectPaint(Paint paint) {
    // Show options: View Details or Load into Roller
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
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
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      Text(
                        paint.brandName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _loadPaintIntoRoller(paint);
              },
              icon: const Icon(Icons.color_lens),
              label: const Text('Load into Roller'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PaintDetailScreen(paint: paint),
                  ),
                );
              },
              icon: const Icon(Icons.info_outline),
              label: const Text('View Details'),
            ),
          ],
        ),
      ),
    );
  }

  void _loadPaintIntoRoller(Paint paint) {
    Debug.info('SearchScreen', '_loadPaintIntoRoller',
        'Attempting to load paint: ${paint.name}');

    // First try using the direct callback if available
    if (widget.onPaintSelectedForRoller != null) {
      Debug.info(
          'SearchScreen', '_loadPaintIntoRoller', 'Using direct callback');
      widget.onPaintSelectedForRoller!(paint);
      return;
    }

    // Fallback: Find the HomeScreen state in the widget tree
  final homeScreenState = context.findAncestorStateOfType<HomeScreenState>();

    if (homeScreenState != null) {
      Debug.info('SearchScreen', '_loadPaintIntoRoller',
          'Found HomeScreenState, calling onPaintSelectedFromSearch');
      homeScreenState.onPaintSelectedFromSearch(paint);
    } else {
      Debug.error('SearchScreen', '_loadPaintIntoRoller',
          'HomeScreenState not found in widget tree and no callback provided');

      // Fallback: show snackbar with error information
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load ${paint.name} into Roller.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              _loadPaintIntoRoller(paint);
            },
          ),
        ),
      );
    }
  }

  void _toggleCompareSelection(Paint paint) {
    setState(() {
      if (_selectedForCompare.contains(paint.id)) {
        _selectedForCompare.remove(paint.id);
      } else if (_selectedForCompare.length < 4) {
        _selectedForCompare.add(paint.id);
      }
    });
  }

  void _loadPaletteIntoRoller(ColorPalette palette) {
    // For now, show a snackbar. Later this can load the palette into the roller
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loading "${palette.name}" into Roller...'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            // Navigate to roller tab
            // This would need to be implemented with proper palette loading
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Debug.build('SearchScreen', 'build',
        details:
            'showSearchResults: $_showSearchResults, searchResults: ${_searchResults.length}, placeholderPalettes: ${_placeholderPalettes.length}');

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      floatingActionButton: _selectedForCompare.length >= 2
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CompareColorsScreen(
                      paletteColorIds: _selectedForCompare.toList(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.compare),
              label: Text('Compare (${_selectedForCompare.length})'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color:
                        Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search by name, brand, code, or hex...',
                  hintStyle: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                  suffixIcon: _showClearButton
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            if (mounted) {
                              setState(() {
                                _searchResults = [];
                                _showSearchResults = false;
                              });
                            }
                            _searchFocusNode.unfocus();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) {
                  // Cancel previous timer
                  _debounceTimer?.cancel();

                  // Start new timer for debounced search
                  _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                    _performSearch(value);
                  });
                },
                onTap: () {
                  // Show search suggestions or recent searches here if needed
                },
              ),
            ),

            // Content Area
            Expanded(
              child: _showSearchResults
                  ? _buildSearchResults()
                  : _buildPaletteGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching...'),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final paint = _searchResults[index];
        return _buildPaintSearchCard(paint);
      },
    );
  }

  Widget _buildPaintSearchCard(Paint paint) {
    final color = ColorUtils.getPaintColor(paint.hex);
    final selected = _selectedForCompare.contains(paint.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          Card(
            child: InkWell(
              onTap: () => _selectPaint(paint),
              onLongPress: () => _toggleCompareSelection(paint),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Color swatch
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.3),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Paint info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paint.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${paint.brandName} • ${paint.code}',
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
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  paint.hex.toUpperCase(),
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'LRV ${paint.computedLrv.toStringAsFixed(0)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Tap indicator
                    Icon(
                      Icons.touch_app,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Selection indicator
          if (selected)
            Positioned(
              top: 8,
              right: 8,
              child: Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaletteGrid() {
    if (_placeholderPalettes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.palette_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No palettes available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Palettes temporarily disabled',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Discover Palettes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),

        // Grid of palettes
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.9, // Adjusted for fixed height containers
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final palette = _placeholderPalettes[index];
                return _buildPaletteCard(palette);
              },
              childCount: _placeholderPalettes.length,
            ),
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }

  Widget _buildPaletteCard(ColorPalette palette) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _loadPaletteIntoRoller(palette),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Color swatches - using fixed dimensions to prevent layout loops
            SizedBox(
              height: 120,
              child: Row(
                children: palette.colors.asMap().entries.map((entry) {
                  return Flexible(
                    child: Container(
                      color: entry.value,
                      width: double.infinity,
                    ),
                  );
                }).toList(),
              ),
            ),

            // Palette info - fixed height to prevent layout loops
            Container(
              height: 80,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    palette.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.palette,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${palette.colors.length} colors',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper class for placeholder palettes
class ColorPalette {
  final String id;
  final String name;
  final List<Color> colors;

  ColorPalette({
    required this.id,
    required this.name,
    required this.colors,
  });
}
