// lib/widgets/paint_swatch_card.dart
import 'package:flutter/material.dart';
import '../utils/color_utils.dart';
import '../firestore/firestore_data_schema.dart';

typedef PaintTap = void Function(Paint paint);

class PaintSwatchCard extends StatelessWidget {
  final Paint paint;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool showMeta;

  const PaintSwatchCard({
    super.key,
    required this.paint,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.showMeta = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.getPaintColor(paint.hex);
    final lrv = paint.computedLrv;
    final theme = Theme.of(context);
    return Stack(
      children: [
        Card(
          elevation: selected ? 3 : 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Swatch
                Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.18)),
                  ),
                ),
                if (showMeta)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paint.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${paint.brandName} • ${paint.code}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _pill(context, paint.hex.toUpperCase(), isMonospace: true),
                            const SizedBox(width: 6),
                            _pill(context, 'LRV ${lrv.toStringAsFixed(0)}'),
                          ],
                        )
                      ],
                    ),
                  )
              ],
            ),
          ),
        ),
        if (selected)
          Positioned(
            top: 8,
            right: 8,
            child: Icon(Icons.check_circle, color: theme.colorScheme.primary),
          )
      ],
    );
  }

  Widget _pill(BuildContext context, String text, {bool isMonospace = false}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 11,
          fontFamily: isMonospace ? 'monospace' : null,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
