import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaintDetailScreen extends StatefulWidget {
  final Paint paint;

  const PaintDetailScreen({
    super.key,
    required this.paint,
  });

  @override
  State<PaintDetailScreen> createState() => _PaintDetailScreenState();
}

class _PaintDetailScreenState extends State<PaintDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isFavorite = false;
  bool _isCheckingFavorite = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _fadeController.forward();
    _checkIfFavorite();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !_isCheckingFavorite) {
      setState(() => _isCheckingFavorite = true);
      try {
        final isFav =
            await FirebaseService.isPaintFavorited(widget.paint.id, user.uid);
        if (mounted) {
          setState(() {
            _isFavorite = isFav;
            _isCheckingFavorite = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isCheckingFavorite = false);
        }
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save favorites')),
      );
      return;
    }

    try {
      if (_isFavorite) {
        await FirebaseService.removeFavoritePaint(widget.paint.id);
      } else {
        await FirebaseService.addFavoritePaintWithData(user.uid, widget.paint);
      }

      setState(() => _isFavorite = !_isFavorite);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                _isFavorite ? 'Added to favorites' : 'Removed from favorites'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color get _paintColor => ColorUtils.getPaintColor(widget.paint.hex);

  bool get _isLightColor => ColorUtils.calculateLuminance(_paintColor) > 0.5;

  String _formatRgb() {
    return 'rgb(${widget.paint.rgb.join(', ')})';
  }

  String _formatLab() {
    return 'lab(${widget.paint.lab.map((v) => v.toStringAsFixed(1)).join(', ')})';
  }

  String _formatLch() {
    return 'lch(${widget.paint.lch.map((v) => v.toStringAsFixed(1)).join(', ')})';
  }

  List<Color> _generateTones() {
    // Generate tones by adjusting lightness
    final baseColor = _paintColor;
    final tones = <Color>[];

    // Lighter tones
    for (double factor in [0.9, 0.8, 0.7, 0.6, 0.5]) {
      tones.add(ColorUtils.lighten(baseColor, factor));
    }

    // Base color
    tones.add(baseColor);

    // Darker tones
    for (double factor in [0.1, 0.2, 0.3, 0.4, 0.5]) {
      tones.add(ColorUtils.darken(baseColor, factor));
    }

    return tones;
  }

  String _analyzeUndertones() {
    final rgb = widget.paint.rgb;
    final r = rgb[0];
    final g = rgb[1];
    final b = rgb[2];

    // Simple undertone analysis based on RGB values
    final total = r + g + b;
    final rPercent = r / total;
    final gPercent = g / total;
    final bPercent = b / total;

    List<String> undertones = [];

    if (rPercent > 0.4) undertones.add('Warm/Red');
    if (gPercent > 0.4) undertones.add('Green');
    if (bPercent > 0.4) undertones.add('Cool/Blue');

    // Additional analysis
    if (r > g && r > b) undertones.add('Red-based');
    if (g > r && g > b) undertones.add('Green-based');
    if (b > r && b > g) undertones.add('Blue-based');

    if ((r + g) > (b * 1.5)) undertones.add('Yellow undertone');
    if ((r + b) > (g * 1.5)) undertones.add('Purple undertone');
    if ((g + b) > (r * 1.5)) undertones.add('Cool undertone');

    return undertones.isNotEmpty ? undertones.join(', ') : 'Neutral';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Hero App Bar
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            elevation: 0,
            backgroundColor: _paintColor,
            foregroundColor: _isLightColor ? Colors.black87 : Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _paintColor,
                        ColorUtils.darken(_paintColor, 0.1),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Color swatch
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: _paintColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isLightColor
                                  ? Colors.black26
                                  : Colors.white24,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.paint.hex.toUpperCase(),
                          style: TextStyle(
                            color:
                                _isLightColor ? Colors.black87 : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: _toggleFavorite,
                icon: _isCheckingFavorite
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isLightColor ? Colors.black87 : Colors.white,
                      ),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Paint Info
                    _buildInfoSection(),
                    const SizedBox(height: 32),

                    // Color Values
                    _buildColorValuesSection(),
                    const SizedBox(height: 32),

                    // Tones
                    _buildTonesSection(),
                    const SizedBox(height: 32),

                    // Analysis
                    _buildAnalysisSection(),

                    const SizedBox(height: 100), // Bottom padding
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.paint.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.paint.brandName} • ${widget.paint.code}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
            if (widget.paint.collection != null) ...[
              const SizedBox(height: 8),
              Text(
                'Collection: ${widget.paint.collection}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
            if (widget.paint.finish != null) ...[
              const SizedBox(height: 4),
              Text(
                'Finish: ${widget.paint.finish}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildColorValuesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color Values',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildColorValueRow('HEX', widget.paint.hex.toUpperCase()),
                const Divider(),
                _buildColorValueRow('RGB', _formatRgb()),
                const Divider(),
                _buildColorValueRow('LAB', _formatLab()),
                const Divider(),
                _buildColorValueRow('LCH', _formatLch()),
                const Divider(),
                _buildColorValueRow(
                    'LRV', widget.paint.computedLrv.toStringAsFixed(1)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorValueRow(String label, String value) {
    return InkWell(
      onTap: () => _copyToClipboard(value, label),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.copy,
                  size: 16,
                  color:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTonesSection() {
    final tones = _generateTones();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color Tones',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Tone gradient bar
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: tones.asMap().entries.map((entry) {
                      final isBase =
                          entry.key == 5; // Base color is in the middle
                      return Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: entry.value,
                            border: isBase
                                ? Border.all(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    width: 3,
                                  )
                                : null,
                            borderRadius: entry.key == 0
                                ? const BorderRadius.only(
                                    topLeft: Radius.circular(7),
                                    bottomLeft: Radius.circular(7),
                                  )
                                : entry.key == tones.length - 1
                                    ? const BorderRadius.only(
                                        topRight: Radius.circular(7),
                                        bottomRight: Radius.circular(7),
                                      )
                                    : null,
                          ),
                          child: isBase
                              ? Center(
                                  child: Icon(
                                    Icons.circle,
                                    color: _isLightColor
                                        ? Colors.black54
                                        : Colors.white54,
                                    size: 12,
                                  ),
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lighter',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                    Text(
                      'Base',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      'Darker',
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
        ),
      ],
    );
  }

  Widget _buildAnalysisSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color Analysis',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnalysisRow(
                  'Undertones',
                  _analyzeUndertones(),
                  Icons.palette_outlined,
                ),
                const SizedBox(height: 16),
                _buildAnalysisRow(
                  'Brightness',
                  _isLightColor ? 'Light' : 'Dark',
                  _isLightColor ? Icons.wb_sunny : Icons.nights_stay,
                ),
                const SizedBox(height: 16),
                _buildAnalysisRow(
                  'Temperature',
                  ColorUtils.getColorTemperature(_paintColor),
                  Icons.thermostat,
                ),
                const SizedBox(height: 16),
                _buildAnalysisRow(
                  'LRV',
                  '${widget.paint.computedLrv.toStringAsFixed(1)}% - ${_getLrvDescription()}',
                  Icons.visibility,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getLrvDescription() {
    final lrv = widget.paint.computedLrv;
    if (lrv >= 70) return 'Very Light';
    if (lrv >= 50) return 'Light';
    if (lrv >= 30) return 'Medium';
    if (lrv >= 15) return 'Dark';
    return 'Very Dark';
  }
}
