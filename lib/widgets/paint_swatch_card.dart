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

  /// NEW: compact layout for rails
  final bool compact;

  const PaintSwatchCard({
    super.key,
    required this.paint,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.showMeta = true,
    this.compact = false, // <-- default false; rails will pass true
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.getPaintColor(paint.hex);
    final lrv = paint.computedLrv;
    final theme = Theme.of(context);

    final double swatchHeight = compact ? 96 : 110;

    return Stack(
      children: [
        Card(
          margin: EdgeInsets.zero, // avoid extra outer margin
          elevation: selected ? 4 : 1.5,
          shadowColor: Colors.black.withOpacity(0.10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Swatch
                Container(
                  height: swatchHeight,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.18),
                    ),
                  ),
                ),
                if (showMeta)
                  Padding(
                    padding: EdgeInsets.fromLTRB(12, compact ? 8 : 10, 12, compact ? 8 : 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paint.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${paint.brandName} • ${paint.code}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.62),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Wrap avoids right overflow; will use 2 lines if needed
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _pill(context, paint.hex.toUpperCase(), isMonospace: true, compact: compact),
                            _pill(context, 'LRV ${lrv.toStringAsFixed(0)}', compact: compact),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (selected)
          Positioned(
            top: 8,
            right: 8,
            child: Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ),
      ],
    );
  }

  Widget _pill(BuildContext context, String text, {bool isMonospace = false, bool compact = false}) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 2 : 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.60),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: compact ? 10 : 11,
          fontFamily: isMonospace ? 'monospace' : null,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
