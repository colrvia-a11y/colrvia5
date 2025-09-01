import 'package:flutter/material.dart';
import '../services/via_service.dart';
import '../services/analytics_service.dart';

class ViaOverlay extends StatefulWidget {
  final String contextLabel;
  final Map<String, dynamic> state;
  final VoidCallback? onMakePlan;
  final VoidCallback? onVisualize;

  const ViaOverlay({
    super.key,
    required this.contextLabel,
    this.state = const {},
    this.onMakePlan,
    this.onVisualize,
  });

  @override
  State<ViaOverlay> createState() => _ViaOverlayState();
}

class _ViaOverlayState extends State<ViaOverlay> {
  bool _open = true;

  void _toggle() => setState(() => _open = !_open);

  Future<void> _handleText(String action) async {
    final text = await ViaService().reply(widget.contextLabel, {
      ...widget.state,
      'action': action,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
    await AnalyticsService.instance.viaActionClicked(action);
  }

  void _handleNav(String action, VoidCallback? callback) {
    AnalyticsService.instance.viaActionClicked(action);
    if (action == 'Make Plan') {
      AnalyticsService.instance.ctaPlanClicked('via');
    } else if (action == 'Visualize') {
      AnalyticsService.instance.ctaVisualizeClicked('via');
    }
    callback?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_open)
            Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Explain'),
                      onPressed: () => _handleText('Explain'),
                    ),
                    ActionChip(
                      label: const Text('Simplify'),
                      onPressed: () => _handleText('Simplify'),
                    ),
                    ActionChip(
                      label: const Text('Budget'),
                      onPressed: () => _handleText('Budget'),
                    ),
                    ActionChip(
                      label: const Text('Make Plan'),
                      onPressed: () => _handleNav('Make Plan', widget.onMakePlan),
                    ),
                    ActionChip(
                      label: const Text('Visualize'),
                      onPressed: () => _handleNav('Visualize', widget.onVisualize),
                    ),
                  ],
                ),
              ),
            ),
          if (_open) const SizedBox(height: 8),
          FloatingActionButton.small(
            onPressed: _toggle,
            child: Icon(_open ? Icons.close : Icons.chat_bubble),
          ),
        ],
      ),
    );
  }
}
