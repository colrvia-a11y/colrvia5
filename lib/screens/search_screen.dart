// lib/screens/search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:color_canvas/services/analytics_service.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/screens/paint_detail_screen.dart';
import 'package:color_canvas/screens/compare_colors_screen.dart';
import 'package:color_canvas/screens/home_screen.dart';
import '../models/color_filters.dart';
import '../services/paint_query_service.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/paint_swatch_card.dart';
import '../widgets/explore_rail.dart';

class SearchScreen extends StatefulWidget {
  final Function(Paint)? onPaintSelectedForRoller;
  const SearchScreen({super.key, this.onPaintSelectedForRoller});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounceTimer;
  bool _showClearButton = false;
  bool _showSearchResults = false;
  bool _isSearching = false;
  int _page = 0;
  static const int _pageSize = 40;
  List<Paint> _cached = [];
  List<Paint> _visible = [];

  // Compare selection
  final Set<String> _selectedForCompare = {};

  // Tabs
  int _tabIndex = 0; // 0 Explore, 1 All Colors, 2 Rooms&Combos, 3 Brands

  // Filters (for All Colors)
  ColorFilters filters = ColorFilters();
  PaintSort sort = PaintSort.relevance;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    // 🔆 glow hook: rebuild when focus changes
    _searchFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _showClearButton = _searchController.text.isNotEmpty);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    if ((_page + 1) * _pageSize >= _cached.length) {
      return;
    }
    setState(() {
      _page++;
      _visible.addAll(_cached.skip(_page * _pageSize).take(_pageSize));
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) {
      return;
    }
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _showSearchResults = false;
        _visible = [];
        _cached = [];
        _page = 0;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });
    try {
      final results = await PaintQueryService.instance.textSearch(query, limit: 200);
      _cached = results;
      _page = 0;
      _visible = _cached.take(_pageSize).toList();
      setState(() => _isSearching = false);
      AnalyticsService.instance.logEvent('search_performed', {'q': query, 'count': results.length});
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search error: $e')));
    }
  }

  void _openDetails(Paint p) {
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PaintDetailScreen(paint: p)),
    );
  }


  void _toggleCompare(Paint p) {
    setState(() {
      if (_selectedForCompare.contains(p.id)) {
        _selectedForCompare.remove(p.id);
      } else if (_selectedForCompare.length < 4) {
        _selectedForCompare.add(p.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: _selectedForCompare.length >= 2
          ? FloatingActionButton.extended(
              onPressed: () {
                AnalyticsService.instance.logEvent('compare_opened', {'count': _selectedForCompare.length});
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompareColorsScreen(paletteColorIds: _selectedForCompare.toList())));
              },
              icon: const Icon(Icons.compare),
              label: Text('Compare (${_selectedForCompare.length})'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            _buildSegmentedControl(theme),
            Expanded(
              child: _showSearchResults ? _buildSearchResults() : _buildBodyForTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.40),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
        ),
      ),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20), // was 16
              boxShadow: [
                // base drop shadow
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
                // subtle focus glow ring
                if (_searchFocusNode.hasFocus) BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.20),
                  blurRadius: 20,
                  spreadRadius: 1.5,
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search by name, brand, code, or hex…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _showClearButton
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _showSearchResults = false;
                            _visible.clear();
                            _cached.clear();
                          });
                          _searchFocusNode.unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (value) {
                _debounceTimer?.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 400), () => _performSearch(value));
              },
              onSubmitted: _performSearch, // enter key triggers search
              textInputAction: TextInputAction.search,
            ),
          ),
          const SizedBox(height: 14), // more breathing room (was 10)
          _activeFiltersChips(theme),
        ],
      ),
    );
  }

  Widget _activeFiltersChips(ThemeData theme) {
    final chips = <Widget>[];

    if (filters.colorFamily != null) {
      chips.add(_removableChip('Family: ${filters.colorFamily!}', () {
        setState(() => filters = filters.copyWith(colorFamily: null));
      }));
    }
    if (filters.undertone != null) {
      chips.add(_removableChip('Undertone: ${filters.undertone!}', () {
        setState(() => filters = filters.copyWith(undertone: null));
      }));
    }
    if (filters.temperature != null) {
      chips.add(_removableChip('Temp: ${filters.temperature!}', () {
        setState(() => filters = filters.copyWith(temperature: null));
      }));
    }
    if (filters.lrvRange != null) {
      final r = filters.lrvRange!;
      chips.add(_removableChip('LRV ${r.start.round()}–${r.end.round()}', () {
        setState(() => filters = filters.copyWith(lrvRange: null));
      }));
    }
    if (filters.brandName != null) {
      chips.add(_removableChip('Brand: ${filters.brandName!}', () {
        setState(() => filters = filters.copyWith(brandName: null));
      }));
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    chips.add(
      InputChip(
        label: const Text('Clear all'),
        avatar: const Icon(Icons.clear_all, size: 16),
        onPressed: () => setState(() => filters.clear()),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  Widget _removableChip(String text, VoidCallback onDelete) {
    return InputChip(
      label: Text(text),
      onDeleted: onDelete, // shows the “x” and calls onDelete
      deleteIcon: const Icon(Icons.close, size: 16),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildSegmentedControl(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // keeps the container at least the width of the screen so it looks “full”
            minWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.60),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: const Text('Explore', softWrap: false, overflow: TextOverflow.ellipsis)),
                  ButtonSegment(value: 1, label: const Text('All Colors', softWrap: false, overflow: TextOverflow.ellipsis)),
                  ButtonSegment(value: 2, label: const Text('Rooms & Combos', softWrap: false, overflow: TextOverflow.fade)),
                  ButtonSegment(value: 3, label: const Text('Brands', softWrap: false, overflow: TextOverflow.ellipsis)),
                ],
                selected: <int>{_tabIndex},
                onSelectionChanged: (s) {
                  HapticFeedback.selectionClick();
                  setState(() => _tabIndex = s.first);
                },
                showSelectedIcon: false,
                style: ButtonStyle(
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  side: WidgetStateProperty.resolveWith((states) {
                    final sel = states.contains(WidgetState.selected);
                    return BorderSide(
                      color: sel
                          ? theme.colorScheme.primary.withValues(alpha: 0.40)
                          : theme.colorScheme.outline.withValues(alpha: 0.40),
                      width: 1,
                    );
                  }),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    final sel = states.contains(WidgetState.selected);
                    return sel
                        ? theme.colorScheme.primary.withValues(alpha: 0.16)
                        : Colors.transparent;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    final sel = states.contains(WidgetState.selected);
                    return sel ? theme.colorScheme.primary : theme.colorScheme.onSurface;
                  }),
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyForTab() {
    switch (_tabIndex) {
      case 0: return _buildExplore();
      case 1: return _buildAllColors();
      case 2: return _buildRoomsCombos();
      case 3: return _buildBrands();
      default: return const SizedBox.shrink();
    }
  }

  // ---------- Explore ----------
  Widget _buildExplore() {
    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.only(
        bottom: 24 + kBottomNavigationBarHeight,
      ),
      children: [
        const SizedBox(height: 6),
        ExploreRail(
          title: 'Warm Reds',
          colorFamily: 'Red',
          temperature: 'Warm',
          onSelect: _openDetails,
          onLongPress: _toggleCompare,
          onSeeAll: ({colorFamily, undertone, temperature, lrvRange}) {
            setState(() {
              if (colorFamily != null) {
                filters = filters.copyWith(colorFamily: colorFamily);
              }
              if (undertone != null) {
                filters = filters.copyWith(undertone: undertone);
              }
              if (temperature != null) {
                filters = filters.copyWith(temperature: temperature);
              }
              if (lrvRange != null) {
                filters = filters.copyWith(lrvRange: lrvRange);
              }
              _tabIndex = 1; // jump to All Colors
            });
          },
        ),
        ExploreRail(
          title: 'Light Blues (LRV 70–85)',
          colorFamily: 'Blue',
          lrvRange: const RangeValues(70, 85),
          onSelect: _openDetails,
          onLongPress: _toggleCompare,
          onSeeAll: ({colorFamily, undertone, temperature, lrvRange}) {
            setState(() {
              filters = filters.copyWith(
                colorFamily: colorFamily,
                lrvRange: lrvRange,
              );
              _tabIndex = 1;
            });
          },
        ),
        ExploreRail(
          title: 'Balanced Greiges',
          colorFamily: 'Neutral',
          undertone: 'green', // greiges often lean green/green-yellow
          onSelect: _openDetails,
          onLongPress: _toggleCompare,
          onSeeAll: ({colorFamily, undertone, temperature, lrvRange}) {
            setState(() {
              filters = filters.copyWith(
                colorFamily: colorFamily,
                undertone: undertone,
              );
              _tabIndex = 1;
            });
          },
        ),
        ExploreRail(
          title: 'Cool Charcoals',
          colorFamily: 'Neutral',
          temperature: 'Cool',
          lrvRange: const RangeValues(5, 22),
          onSelect: _openDetails,
          onLongPress: _toggleCompare,
          onSeeAll: ({colorFamily, undertone, temperature, lrvRange}) {
            setState(() {
              filters = filters.copyWith(
                colorFamily: colorFamily,
                temperature: temperature,
                lrvRange: lrvRange,
              );
              _tabIndex = 1;
            });
          },
        ),
        ExploreRail(
          title: 'Bedrooms we love',
          onSelect: _openDetails,
          onLongPress: _toggleCompare,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------- All Colors (grid + filters) ----------
  Widget _buildAllColors() {
    return FutureBuilder<List<Paint>>(
      future: PaintQueryService.instance.getAllPaints(hardLimit: 1600),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var list = snapshot.data!;
        list = PaintQueryService.instance.applyFilters(
          list,
          colorFamily: filters.colorFamily,
          undertone: filters.undertone,
          temperature: filters.temperature,
          lrvRange: filters.lrvRange,
          brandName: filters.brandName,
        );
        list = PaintQueryService.instance.sortList(list, sort);
        return Column(
          children: [
            _filterSortBar(),
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: EdgeInsets.fromLTRB(
                  16, 8, 16,
                  24 + kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                mainAxisExtent: MediaQuery.textScalerOf(context).scale(1.0) > 1.1 ? 232 : 220,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final p = list[i];
                  final selected = _selectedForCompare.contains(p.id);
                  return PaintSwatchCard(
                    paint: p,
                    compact: true,
                    selected: selected,
                    onTap: () => _openDetails(p),
                    onLongPress: () => _toggleCompare(p),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _filterSortBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12))),
      ),
      child: Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.6,
                  minChildSize: 0.4,
                  maxChildSize: 0.95,
                  builder: (context, controller) => SingleChildScrollView(
                    controller: controller,
                    child: FilterSheet(
                      initial: filters,
                      onApply: (f) => setState(() => filters = f),
                    ),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.tune),
            label: const Text('Filters'),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<PaintSort>(
            onSelected: (s) => setState(() => sort = s),
            itemBuilder: (_) => const [
              PopupMenuItem(value: PaintSort.relevance, child: Text('Sort: Relevance')),
              PopupMenuItem(value: PaintSort.hue, child: Text('Sort: Hue')),
              PopupMenuItem(value: PaintSort.lrvAsc, child: Text('Sort: LRV ↑')),
              PopupMenuItem(value: PaintSort.lrvDesc, child: Text('Sort: LRV ↓')),
            ],
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.sort),
              label: Text(_sortLabel(sort)),
            ),
          ),
          const Spacer(),
          if (_selectedForCompare.isNotEmpty) Text('${_selectedForCompare.length} selected'),
        ],
      ),
    );
  }

  String _sortLabel(PaintSort s) {
    switch (s) {
      case PaintSort.hue: return 'Hue';
      case PaintSort.lrvAsc: return 'LRV ↑';
      case PaintSort.lrvDesc: return 'LRV ↓';
      case PaintSort.newest: return 'Newest';
      case PaintSort.mostSaved: return 'Most saved';
      default: return 'Relevance';
    }
  }

  // ---------- Rooms & Combos (placeholder v1) ----------
  Widget _buildRoomsCombos() {
    final cards = [
      _roomCard('Bedroom Starter Packs', Icons.bed, 'Warm Bedroom Neutrals', 'High-Contrast Retreat', 'Calming Blue-Greens'),
      _roomCard('Kitchen Combinations', Icons.kitchen, 'Classic White + Soft Black', 'Greige + Brass Friendly', 'Fresh Coastal'),
      _roomCard('Exterior Winners', Icons.house, 'Light + Charcoal Trim', 'Moody Modern', 'Warm Cream + Slate'),
    ];
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16, 12, 16,
        24 + kBottomNavigationBarHeight,
      ),
      itemBuilder: (_, i) => cards[i],
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: cards.length,
    );
  }

  Widget _roomCard(String title, IconData icon, String a, String b, String c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                _miniPalette('• $a'),
                _miniPalette('• $b'),
                _miniPalette('• $c'),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon: curated combos'))); }, icon: const Icon(Icons.chevron_right), label: const Text('Explore')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniPalette(String label) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _toneBox(Colors.black12),
          _toneBox(Colors.black26),
          _toneBox(Colors.black38),
          const SizedBox(width: 8),
          Expanded(child: Text(label, maxLines: 2)),
        ],
      ),
    );
  }

  Widget _toneBox(Color c) => Container(
    width: 20, height: 20, margin: const EdgeInsets.only(right: 4),
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
  );

  // ---------- Brands (placeholder) ----------
  Widget _buildBrands() {
    final brands = ['Sherwin-Williams','Benjamin Moore','Behr'];
    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: 24 + kBottomNavigationBarHeight,
      ),
      itemCount: brands.length,
      itemBuilder: (_, i) => ListTile(
        leading: const Icon(Icons.factory_outlined),
        title: Text(brands[i]),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          setState(() { filters = filters.copyWith(brandName: brands[i]); _tabIndex = 1; });
        },
      ),
    );
  }

  // ---------- Search Results ----------
  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [CircularProgressIndicator(), SizedBox(height: 10), Text('Searching…')],
      ));
    }
    if (_visible.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
          const SizedBox(height: 8),
          Text('No results', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Try different keywords', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65))),
        ],
      ));
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        16, 12, 16,
        24 + kBottomNavigationBarHeight,
      ),
      itemCount: _visible.length,
      itemBuilder: (_, i) {
        final p = _visible[i];
        final selected = _selectedForCompare.contains(p.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PaintSwatchCard(
            paint: p,
            selected: selected,
            onTap: () => _openDetails(p),
            onLongPress: () => _toggleCompare(p),
          ),
        );
      },
    );
  }
}
