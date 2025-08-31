import 'package:flutter/material.dart';
import 'package:color_canvas/models/user_palette.dart';
import 'package:color_canvas/services/analytics_service.dart';

class CompareScreen extends StatelessWidget {
  final UserPalette? comparePalette;

  const CompareScreen({
    Key? key,
    this.comparePalette,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Track screen view
    AnalyticsService.instance.logScreenView('Compare Colors');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Colors'),
      ),
      body: comparePalette == null
          ? const Center(
              child: Text('No palette selected for comparison'),
            )
          : ColorPaletteView(palette: comparePalette!),
    );
  }
}

class ColorPaletteView extends StatelessWidget {
  final UserPalette palette;

  const ColorPaletteView({
    Key? key,
    required this.palette,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
      ),
      itemCount: palette.colors.length,
      itemBuilder: (context, index) {
        return ColorTile(color: palette.colors[index]);
      },
    );
  }
}

class ColorTile extends StatelessWidget {
  final Color color;

  const ColorTile({
    Key? key,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
