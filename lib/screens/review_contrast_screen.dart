import 'package:flutter/material.dart';
import 'package:color_canvas/services/journey/journey_service.dart';

class ReviewContrastScreen extends StatelessWidget {
  const ReviewContrastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final journey = JourneyService.instance;
    final colors = (journey.state.value?.artifacts['palettePreview'] as List?)
            ?.cast<String>() ??
        const <String>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Contrast Review')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: colors.isNotEmpty
                  ? colors.map((h) => _SwatchRow(hex: h)).toList()
                  : const [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No palette loaded'),
                      ),
                    ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () async {
                await journey.setArtifact(
                    'contrastReport', {'checked': true});
                await journey.completeCurrentStep();
                if (context.mounted) {
                  Navigator.of(context).maybePop();
                }
              },
              child: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwatchRow extends StatelessWidget {
  final String hex;
  const _SwatchRow({required this.hex});

  @override
  Widget build(BuildContext context) {
    final color =
        Color(int.parse(hex.replaceAll('#', ''), radix: 16) | 0xFF000000);
    return ListTile(
      leading: Container(width: 40, height: 40, color: color),
      title: Text('Sample text', style: TextStyle(color: _contrast(color))),
    );
  }

  Color _contrast(Color c) =>
      c.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}
