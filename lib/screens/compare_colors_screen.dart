// lib/screens/compare_colors_screen.dart
import 'package:flutter/material.dart';

class CompareColorsScreen extends StatelessWidget {
  final List<String> paletteColorIds;
  const CompareColorsScreen({super.key, required this.paletteColorIds});

  @override
  Widget build(BuildContext context) {
    final ids = paletteColorIds.take(4).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Compare Colors')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: ids.map((id) => Expanded(child: _SwatchCard(id: id))).toList()),
          const SizedBox(height: 16),
          _ContrastTable(ids: ids),
        ],
      ),
    );
  }
}

class _SwatchCard extends StatelessWidget {
  final String id; const _SwatchCard({required this.id});
  @override Widget build(BuildContext context) {
    return Card(child: SizedBox(height: 120, child: Center(child: Text(id))));
  }
}

class _ContrastTable extends StatelessWidget {
  final List<String> ids; const _ContrastTable({required this.ids});
  @override Widget build(BuildContext context) {
    return Table(border: TableBorder.all(color: Colors.black12), children: [
      TableRow(children: [const SizedBox(), for (final j in ids) Padding(padding: const EdgeInsets.all(8), child: Text(j, style: const TextStyle(fontWeight: FontWeight.bold)))]),
      for (final i in ids) TableRow(children: [
        Padding(padding: const EdgeInsets.all(8), child: Text(i, style: const TextStyle(fontWeight: FontWeight.bold))),
        for (final j in ids)
          Padding(padding: const EdgeInsets.all(8), child: Text(i == j ? '—' : _contrast(i, j).toStringAsFixed(2))),
      ]),
    ]);
  }

  double _contrast(String a, String b) {
    // TODO: replace with real LRV lookup and contrast formula
    return (a.hashCode % 100 - b.hashCode % 100).abs() / 100.0 * 10.0;
  }
}
