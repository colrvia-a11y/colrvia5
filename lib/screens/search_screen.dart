// lib/screens/search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/utils/debug_logger.dart';
import 'package:color_canvas/services/analytics_service.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/services/firebase_service.dart';
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
    if ((_page + 1) * _pageSize >= _cached.length) return;
    setState(() {
      _page++;
      _visible.addAll(_cached.skip(_page * _pageSize).take(_pageSize));
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
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
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search error: $e')));
    }
  }

  void _selectPaint(Paint paint) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: ColorUtils.getPaintColor(paint.hex),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.25)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(paint.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          Text(paint.brandName, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () { Navigator.pop(context); _loadPaintIntoRoller(paint); },
                  icon: const Icon(Icons.color_lens),
                  label: const Text('Load into Roller'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaintDetailScreen(paint: paint)));
                  },
                  icon: const Icon(Icons.info_outline),
                  label: const Text('View details'),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  void _loadPaintIntoRoller(Paint paint) {
    if (widget.onPaintSelectedForRoller != null) {
      widget.onPaintSelectedForRoller!(paint);
      return;
    }
    final home = context.findAncestorStateOfType<HomeScreenState>();
    if (home != null) {
      home.onPaintSelectedFromSearch(paint);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load ${paint.name} into Roller.')));
    }
  }

  void _toggleCompare(Paint p) {
    setState(() {
      if (_selectedForCompare.contains(p.id)) _selectedForCompare.remove(p.id);
      else if (_selectedForCompare.length < 4) _selectedForCompare.add(p.id);
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
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.12))),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Search by name, brand, code, or hex…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _showClearButton
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() { _showSearchResults = false; _visible.clear(); _cached.clear(); }); _searchFocusNode.unfocus(); })
                  : null,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              _debounceTimer?.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 400), () => _performSearch(value));
            },
          ),
          const SizedBox(height: 10),
          _activeFiltersChips(theme),
        ],
      ),
    );
  }

  Widget _activeFiltersChips(ThemeData theme) {
    final chips = <Widget>[];
    if (filters.colorFamily != null) chips.add(_chip(theme, filters.colorFamily!, () => setState(() => filters = filters.copyWith(colorFamily: null))));
    if (filters.undertone != null) chips.add(_chip(theme, 'undertone: ${filters.undertone}', () => setState(() => filters = filters.copyWith(undertone: null))));
    if (filters.temperature != null) chips.add(_chip(theme, filters.temperature!, () => setState(() => filters = filters.copyWith(temperature: null))));
    if (filters.lrvRange != null) chips.add(_chip(theme, 'LRV ${filters.lrvRange!.start.round()}–${filters.lrvRange!.end.round()}', () => setState(() => filters = filters.copyWith(lrvRange: null))));
    if (filters.brandName != null) chips.add(_chip(theme, filters.brandName!, () => setState(() => filters = filters.copyWith(brandName: null))));
    if (chips.isEmpty) return const SizedBox.shrink();
    return Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 6, runSpacing: 6, children: chips));
  }

  Widget _chip(ThemeData theme, String label, VoidCallback onDeleted) {
    return InputChip(
      label: Text(label),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close, size: 18),
    );
  }

  Widget _buildSegmentedControl(ThemeData theme) {
    final tabs = ['Explore','All Colors','Rooms & Combos','Brands'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: SegmentedButton<int>(
        segments: tabs.asMap().entries.map((e) => ButtonSegment(value: e.key, label: Text(e.value))).toList(),
        selected: <int>{_tabIndex},
        onSelectionChanged: (s) => setState(() => _tabIndex = s.first),
        showSelectedIcon: false,
        style: ButtonStyle(
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
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
      children: [
        const SizedBox(height: 6),
        ExploreRail(
          title: 'Warm Reds',
          colorFamily: 'Red',
          temperature: 'Warm',
          onSelect: _selectPaint,
          onLongPress: _toggleCompare,
        ),
        ExploreRail(
          title: 'Light Blues (LRV 70–85)',
          colorFamily: 'Blue',
          lrvRange: const RangeValues(70, 85),
          onSelect: _selectPaint,
          onLongPress: _toggleCompare,
        ),
        ExploreRail(
          title: 'Balanced Greiges',
          colorFamily: 'Neutral',
          undertone: 'green', // greiges often lean green/green-yellow
          onSelect: _selectPaint,
          onLongPress: _toggleCompare,
        ),
        ExploreRail(
          title: 'Cool Charcoals',
          colorFamily: 'Neutral',
          temperature: 'Cool',
          lrvRange: const RangeValues(5, 22),
          onSelect: _selectPaint,
          onLongPress: _toggleCompare,
        ),
        ExploreRail(
          title: 'Bedrooms we love',
          onSelect: _selectPaint,
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.78),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final p = list[i];
                  final selected = _selectedForCompare.contains(p.id);
                  return PaintSwatchCard(
                    paint: p,
                    selected: selected,
                    onTap: () => _selectPaint(p),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _visible.length,
      itemBuilder: (_, i) {
        final p = _visible[i];
        final selected = _selectedForCompare.contains(p.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PaintSwatchCard(
            paint: p,
            selected: selected,
            onTap: () => _selectPaint(p),
            onLongPress: () => _toggleCompare(p),
          ),
        );
      },
    );
  }
}
