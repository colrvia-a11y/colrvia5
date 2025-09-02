// lib/widgets/explore_rail.dart
import 'package:flutter/material.dart';
import '../services/paint_query_service.dart';
import '../widgets/paint_swatch_card.dart';
import '../firestore/firestore_data_schema.dart';

class ExploreRail extends StatefulWidget {
  final String title;
  final String? colorFamily;
  final String? undertone;
  final String? temperature;
  final RangeValues? lrvRange;
  final void Function(Paint) onSelect;
  final void Function(Paint) onLongPress;

  const ExploreRail({
    super.key,
    required this.title,
    this.colorFamily,
    this.undertone,
    this.temperature,
    this.lrvRange,
    required this.onSelect,
    required this.onLongPress,
  });

  @override
  State<ExploreRail> createState() => _ExploreRailState();
}

class _ExploreRailState extends State<ExploreRail> {
  List<Paint>? items;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await PaintQueryService.instance.exploreRail(
      colorFamily: widget.colorFamily,
      undertone: widget.undertone,
      temperature: widget.temperature,
      lrvRange: widget.lrvRange,
      sort: PaintSort.hue,
      limit: 16,
    );
    if (!mounted) return;
    setState(() { items = list; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _skeleton();
    }
    if (items == null || items!.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: () {
                  // TODO: open All Colors tab with pre-applied filters
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('See all (coming soon)')));
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items!.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final p = items![i];
              return SizedBox(
                width: 150,
                child: PaintSwatchCard(
                  paint: p,
                  onTap: () => widget.onSelect(p),
                  onLongPress: () => widget.onLongPress(p),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _skeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 22, width: 140, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6))),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 8,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => Container(
              width: 150,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
