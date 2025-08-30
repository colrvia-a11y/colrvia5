import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show compute, kDebugMode;
import 'dart:math' as math;
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/utils/palette_generator.dart';
import 'package:color_canvas/utils/palette_isolate.dart';
import 'package:color_canvas/widgets/paint_column.dart';
import 'package:color_canvas/widgets/refine_sheet.dart';
import 'package:color_canvas/widgets/brand_filter_dialog.dart';
import 'package:color_canvas/widgets/save_palette_panel.dart';
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/data/sample_paints.dart';
import 'package:color_canvas/utils/debug_logger.dart';

// Custom intents for keyboard navigation
class GoToPrevPageIntent extends Intent {
  const GoToPrevPageIntent();
}

class GoToNextPageIntent extends Intent {
  const GoToNextPageIntent();
}

enum ActiveTool { style, sort, adjust, count, save, share }

abstract class RollerScreenStatePublic extends State<RollerScreen> {
  int getPaletteSize();
  Paint? getPaintAtIndex(int index);
  void replacePaintAtIndex(int index, Paint paint);
  bool canAddNewColor();
  void addPaintToCurrentPalette(Paint paint);
}

class RollerScreen extends StatefulWidget {
  final String? projectId;
  final String? seedPaletteId;
  final List<String>? initialPaintIds;   // NEW
  final List<Paint>? initialPaints;      // NEW

  const RollerScreen({
    super.key,
    this.projectId,
    this.seedPaletteId,
    this.initialPaintIds,
    this.initialPaints,
  });

  @override
  State<RollerScreen> createState() => _RollerScreenState();
}

class _RollerScreenState extends RollerScreenStatePublic {
  List<Paint> _currentPalette = [];
  List<bool> _lockedStates = [];
  List<Paint> _availablePaints = [];
  List<Brand> _availableBrands = [];
  Set<String> _selectedBrandIds = {};
  HarmonyMode _currentMode = HarmonyMode.neutral;
  bool _isLoading = true;
  bool _diversifyBrands = true;
  int _paletteSize = 5;
  bool _isRolling = false;
  
  // TikTok-style vertical swipe feed
  final PageController _pageCtrl = PageController();
  final List<List<Paint>> _pages = <List<Paint>>[];
  int _visiblePage = 0;
  
  // Memory management (how many pages to keep in RAM at any time)
  static const int _retainWindow = 80; // tune 60–120 after profiling
  
  // Concurrency guard for page generation
  final Set<int> _generatingPages = <int>{};
  
  // First-time swipe hint
  bool _showSwipeHint = true;
  
  static const int _minPaletteSize = 1;
  
  // Adjust state variables
  double _hueShift = 0.0;  // -45..+45 degrees
  double _satScale = 1.0;  // 0.6..1.4 multiplier
  
  // Rolling request ID to drop stale results
  int _rollRequestId = 0;
  
  // Track original palette order before any LRV sorting (for stable ties)
  final Map<String, int> _originalIndexMap = {};
  
  // Tools dock state
  bool _toolsOpen = false;
  ActiveTool? _activeTool;
  
  // Track if user has manually applied brand filters
  final bool _hasAppliedFilters = false;
  
  // Debug: Track setState calls to identify infinite loops
  int _setStateCount = 0;
  DateTime? _lastSetStateTime;

  // Roles removed; palette size is the single source of truth
  
  // Throttled setState to prevent infinite loops
  void _safeSetState(VoidCallback callback, {String? details}) {
    if (!mounted) return;
    
    final now = DateTime.now();
    
    // Debug logging for setState calls
    Debug.setState('RollerScreen', '_safeSetState', details: details);
    
    // Throttle setState calls in debug mode
    if (kDebugMode) {
      _setStateCount++;
      if (_lastSetStateTime != null && now.difference(_lastSetStateTime!).inMilliseconds < 16) {
        // More than 60 FPS setState calls - potential loop detected
        Debug.warning('RollerScreen', '_safeSetState', 'Rapid setState calls detected - count: $_setStateCount');
        if (_setStateCount > 100) {
          Debug.error('RollerScreen', '_safeSetState', 'Potential infinite setState loop detected! Skipping setState.');
          return;
        }
      }
      _lastSetStateTime = now;
      
      // Reset counter every second  
      if (_setStateCount > 50 && now.difference(_lastSetStateTime!).inSeconds >= 1) {
        _setStateCount = 0;
      }
      
      if (_setStateCount % 50 == 0) {
        Debug.info('RollerScreen', '_safeSetState', 'setState count: $_setStateCount');
      }
    }
    
    setState(callback);
  }

  @override
  void initState() {
    super.initState();
    
    Debug.info('RollerScreen', 'initState', 'Component initializing');
    print('RollerScreen: initState called, about to load paints');
    
    // Load paints from database with fallback to sample data
    _loadPaints();
  }
  

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _safeJumpToPage(int page) {
    if (!mounted) return;
    if (_pageCtrl.hasClients) {
      _pageCtrl.jumpToPage(page);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageCtrl.hasClients) {
          _pageCtrl.jumpToPage(page);
        }
      });
    }
  }

  // Check if current mode is a harmony mode that should be LRV sorted
  

  // LRV sorter that's stable on ties
  int _byLrvDescThenStable(Paint a, Paint b) {
    final la = a.computedLrv;
    final lb = b.computedLrv;
    final cmp = lb.compareTo(la); // DESC (light to dark)
    if (cmp != 0) return cmp;
    // Fallback to original index for stable sort
    final aIndex = _originalIndexMap[a.id] ?? 0;
    final bIndex = _originalIndexMap[b.id] ?? 0;
    return aIndex.compareTo(bIndex);
  }

  // NEW: Always run pinned-LRV sort, across all modes
  List<Paint> _displayColorsForCurrentMode(List<Paint> base) {
    if (base.isEmpty) return base;

    // Map current ids to their indices for tie-stability
    _originalIndexMap.clear();
    for (int i = 0; i < base.length; i++) {
      _originalIndexMap[base[i].id] = i;
    }

    final result = List<Paint>.from(base);
    final List<int> unlockedIndices = <int>[];
    final List<Paint> unlockedPaints = <Paint>[];

    // Partition into locked vs unlocked by slot
    for (int i = 0; i < base.length; i++) {
      final isLocked = (i < _lockedStates.length) && _lockedStates[i];
      if (!isLocked) {
        unlockedIndices.add(i);
        unlockedPaints.add(base[i]);
      }
    }

    // Sort only the unlocked subset by LRV DESC (stable)
    unlockedPaints.sort(_byLrvDescThenStable);

    // Write sorted unlocked back into their original positions
    for (int j = 0; j < unlockedIndices.length; j++) {
      result[unlockedIndices[j]] = unlockedPaints[j];
    }

    return result;
  }

  Future<void> _loadPaints() async {
    List<Paint> paints = [];
    List<Brand> brands = [];
    
    print('RollerScreen: _loadPaints started');

    // First try to load from database
    print('Loading from database...');
    try {
      paints = await FirebaseService.getAllPaints();
      brands = await FirebaseService.getAllBrands();
      print('Database data loaded: ${paints.length} paints, ${brands.length} brands');
      
      // If no data in database, fall back to sample data
      if (paints.isEmpty) {
        print('No paints found in database, falling back to sample data');
        paints = await SamplePaints.getSamplePaints();
        brands = SamplePaints.getSampleBrands();
        print('Sample data fallback loaded: ${paints.length} paints, ${brands.length} brands');
      }
    } catch (e) {
      print('Error loading from database: $e, falling back to sample data');
      try {
        paints = await SamplePaints.getSamplePaints();
        brands = SamplePaints.getSampleBrands();
        print('Sample data fallback loaded: ${paints.length} paints, ${brands.length} brands');
      } catch (sampleError) {
        print('Error loading sample data: $sampleError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to load paint data. Please try again later.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
    }
    
    print('Final result: Loaded ${paints.length} paints and ${brands.length} brands');
    
    setState(() {
      _availablePaints = paints;
      _availableBrands = brands;
      _selectedBrandIds = brands.map((b) => b.id).toSet(); // All brands selected by default
      _lockedStates = List.filled(_paletteSize, false);
      _isLoading = false;
    });
    
    // NEW: try to seed from incoming palette/color
    await _maybeSeedFromInitial();
  }

  Future<List<Paint>> _rollPaletteAsync(List<Paint?> anchors, [List<List<double>>? slotLrvHints]) async {
    final available = _getFilteredPaints()
        .map((p) => p.toJson()..['id'] = p.id)
        .toList();

    final anchorMaps = anchors
        .map((p) => p == null ? null : (p.toJson()..['id'] = p.id))
        .toList();

    final args = {
      'available': available,
      'anchors': anchorMaps,
      'modeIndex': _currentMode.index,
      'diversify': _diversifyBrands,
      'slotLrvHints': slotLrvHints,
    };

    final resultMaps = await compute(rollPaletteInIsolate, args);

    // Rehydrate Paints on the UI isolate
    return [
      for (final m in resultMaps) Paint.fromJson(m, m['id'] as String),
    ];
  }

  void _rollPalette() async {
    if (_getFilteredPaints().isEmpty || _isRolling) return;

    HapticFeedback.lightImpact();
    setState(() => _isRolling = true);

    try {
      final anchors = List<Paint?>.filled(_paletteSize, null);
      for (int i = 0; i < _paletteSize && i < _lockedStates.length; i++) {
        if (_lockedStates[i] && i < _currentPalette.length) {
          anchors[i] = _currentPalette[i];
        }
      }

      final int requestId = ++_rollRequestId;
      List<Paint> rolled;
      
      try {
        // Try async palette generation first
        rolled = await _rollPaletteAsync(anchors);
      } catch (e) {
        print('Async palette generation failed: $e, falling back to sync');
        // Fallback to synchronous palette generation
        rolled = PaletteGenerator.rollPalette(
          availablePaints: _getFilteredPaints(),
          anchors: anchors,
          mode: _currentMode,
          diversifyBrands: _diversifyBrands,
        );
      }
      
      if (!mounted || requestId != _rollRequestId) return; // drop stale result

      final adjusted = _applyAdjustments(rolled);
      final paletteForDisplay = _displayColorsForCurrentMode(adjusted.take(_paletteSize).toList());

      _safeSetState(() {
        _currentPalette = paletteForDisplay;
        _isRolling = false;
      });

      // Ensure the current page is updated or added
      if (_visiblePage < _pages.length) {
        _pages[_visiblePage] = List<Paint>.from(_currentPalette);
      } else if (_pages.isEmpty) {
        _pages.add(List<Paint>.from(_currentPalette));
      }
    } catch (e) {
      print('Error in _rollPalette: $e');
      if (mounted) {
        _safeSetState(() => _isRolling = false);
      }
    }
  }

  void _toggleLock(int index) {
    // Ensure the lock array is long enough
    while (_lockedStates.length <= index) {
      _lockedStates.add(false);
    }

    HapticFeedback.selectionClick();

    setState(() {
      // Flip the lock
      _lockedStates[index] = !_lockedStates[index];

      // Keep the current page snapshot in sync with on-screen palette
      if (_visiblePage < _pages.length) {
        _pages[_visiblePage] = List<Paint>.from(_currentPalette);
      }

      // CRITICAL: Invalidate any pages beyond the current one so the next page
      // regenerates using the new lock anchors in _ensurePage(...)
      if (_visiblePage < _pages.length - 1) {
        _pages.removeRange(_visiblePage + 1, _pages.length);
      }
    });

    // Optional prefetch to hide spinner when user swipes next
    _ensurePage(_visiblePage + 1);
  }

  void _rollStripe(int index) {
    // Extend _lockedStates if needed
    while (_lockedStates.length <= index) {
      _lockedStates.add(false);
    }
    
    if (_lockedStates[index] || _getFilteredPaints().isEmpty || _isRolling) return;
    
    HapticFeedback.lightImpact();
    
    // Generate new paint for ONLY this stripe, preserving all other colors
    final anchors = List<Paint?>.filled(_paletteSize, null);
    for (int i = 0; i < _paletteSize && i < _currentPalette.length; i++) {
      if (i != index) { // Preserve all colors EXCEPT the one we're rolling
        anchors[i] = _currentPalette[i];
      }
      // anchors[index] remains null so it gets a new color
    }
    
    final rolled = PaletteGenerator.rollPalette(
      availablePaints: _getFilteredPaints(),
      anchors: anchors,
      mode: _currentMode,
      diversifyBrands: _diversifyBrands,
    );
    
    final adjusted = _applyAdjustments(rolled);
    
    setState(() {
      _currentPalette = adjusted.take(_paletteSize).toList();
    });

    // Sync current page cache after rolling a stripe
    if (_visiblePage < _pages.length) {
      _pages[_visiblePage] = List<Paint>.from(_currentPalette);
    }
  }


  void _showRefineSheet(int index) {
    if (index >= _currentPalette.length) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => RefineSheet(
        paint: _currentPalette[index],
        availablePaints: _getFilteredPaints(),
        onPaintSelected: (newPaint) {
          setState(() {
            _currentPalette[index] = newPaint;
          });
          
          // Sync current page cache after refining a color
          if (_visiblePage < _pages.length) {
            _pages[_visiblePage] = List<Paint>.from(_currentPalette);
          }
          
          Navigator.pop(context);
        },
      ),
    );
  }

  void _removeStripe(int index) {
    if (_paletteSize <= _minPaletteSize) return;
    
    HapticFeedback.lightImpact();
    setState(() {
      _paletteSize--;
      if (index < _currentPalette.length) {
        _currentPalette.removeAt(index);
      }
      if (index < _lockedStates.length) {
        _lockedStates.removeAt(index);
      }
    });
    
    // Sync current page cache after removing a stripe
    if (_visiblePage < _pages.length) {
      _pages[_visiblePage] = List<Paint>.from(_currentPalette);
    }
  }

  Future<void> _maybeSeedFromInitial() async {
    try {
      List<Paint> seeds = [];

      if (widget.initialPaints != null && widget.initialPaints!.isNotEmpty) {
        seeds = widget.initialPaints!;
      } else if (widget.initialPaintIds != null && widget.initialPaintIds!.isNotEmpty) {
        seeds = await FirebaseService.getPaintsByIds(widget.initialPaintIds!);
        
        // Reorder fetched paints to match the incoming IDs order
        final order = <String, int>{};
        for (var i = 0; i < widget.initialPaintIds!.length; i++) {
          order[widget.initialPaintIds![i]] = i;
        }
        seeds.sort((a, b) => (order[a.id] ?? 1 << 30).compareTo(order[b.id] ?? 1 << 30));
      }

      if (seeds.isEmpty) {
        // No initial seeds, proceed with normal roll
        if (_availablePaints.isNotEmpty) {
          _rollPalette();
          // Wait a moment for the palette to be generated, then add to pages
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _currentPalette.isNotEmpty && _pages.isEmpty) {
              _safeSetState(() {
                _pages.add(List<Paint>.from(_currentPalette));
              });
            }
          });
        }
        return;
      }

      // Fit to current palette size
      final take = seeds.take(_paletteSize).toList();
      final sortedTake = _displayColorsForCurrentMode(take);

      _safeSetState(() {
        _currentPalette = sortedTake;
        _pages
          ..clear()
          ..add(List<Paint>.from(_currentPalette));
        _lockedStates = List<bool>.filled(_currentPalette.length, true); // lock seeds initially
      });
    } catch (e) {
      print('Error in _maybeSeedFromInitial: $e');
      // Fall back to normal roll if seeding fails
      if (_availablePaints.isNotEmpty) {
        _rollPalette();
        // Wait a moment for the palette to be generated, then add to pages
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _currentPalette.isNotEmpty && _pages.isEmpty) {
            _safeSetState(() {
              _pages.add(List<Paint>.from(_currentPalette));
            });
          }
        });
      }
    }
  }

  List<Paint> _getFilteredPaints() {
    if (_selectedBrandIds.isEmpty || _selectedBrandIds.length == _availableBrands.length) {
      return _availablePaints;
    }
    return _availablePaints.where((paint) => _selectedBrandIds.contains(paint.brandId)).toList();
  }
  
  List<Paint> _visiblePaletteSnapshot() {
    if (_visiblePage >= 0 && _visiblePage < _pages.length) {
      return List<Paint>.from(_pages[_visiblePage]);
    }
    return List<Paint>.from(_currentPalette);
  }

  // Tools dock: helpers and panel builder
  void _closeDock() {
    _safeSetState(() {
      _toolsOpen = false;
      _activeTool = null;
    });
  }

  void _resizeLocksAndPaletteTo(int size) {
    // Adjust locks length
    if (_lockedStates.length > size) {
      _lockedStates = _lockedStates.take(size).toList();
    } else if (_lockedStates.length < size) {
      _lockedStates = [
        ..._lockedStates,
        ...List<bool>.filled(size - _lockedStates.length, false),
      ];
    }
    // Trim palette if needed
    if (_currentPalette.length > size) {
      _currentPalette = _currentPalette.take(size).toList();
    }
  }

  Widget _buildToolPanel(ActiveTool tool) {
    switch (tool) {
      case ActiveTool.style:
        return _StylePanel(
          currentMode: _currentMode,
          diversifyBrands: _diversifyBrands,
          paletteSize: _paletteSize,
          onModeChanged: (mode) {
            _safeSetState(() => _currentMode = mode);
            _resetFeedToPageZero();
          },
          onDiversifyChanged: (value) {
            _safeSetState(() => _diversifyBrands = value);
            _resetFeedToPageZero();
          },
          onPaletteSizeChanged: (size) {
            _safeSetState(() {
              _paletteSize = size.clamp(1, 9);
              _resizeLocksAndPaletteTo(_paletteSize);
            });
            _resetFeedToPageZero();
          },
          onDone: _closeDock,
        );
      case ActiveTool.sort:
        return _BrandFilterPanelHost(
          availableBrands: _availableBrands,
          selectedBrandIds: _selectedBrandIds,
          onBrandsSelected: (brands) {
            _safeSetState(() => _selectedBrandIds = brands);
            _resetFeedToPageZero();
          },
          onDone: _closeDock,
        );
      case ActiveTool.adjust:
        return _AdjustPanelHost(
          hueShift: _hueShift,
          satScale: _satScale,
          onHueChanged: (value) {
            _safeSetState(() => _hueShift = value);
            // Debounce rapid changes
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted) _rollPalette();
            });
          },
          onSatChanged: (value) {
            _safeSetState(() => _satScale = value);
            // Debounce rapid changes
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted) _rollPalette();
            });
          },
          onReset: () {
            _safeSetState(() {
              _hueShift = 0.0;
              _satScale = 1.0;
            });
            _rollPalette();
          },
          onDone: _closeDock,
        );
      case ActiveTool.count:
        return _CountPanelHost(
          paletteSize: _paletteSize,
          onSizeChanged: (size) {
            _safeSetState(() {
              _paletteSize = size;
              _resizeLocksAndPaletteTo(_paletteSize);
              if (_visiblePage < _pages.length) {
                _pages[_visiblePage] = List<Paint>.from(_currentPalette);
              }
              if (_visiblePage < _pages.length - 1) {
                _pages.removeRange(_visiblePage + 1, _pages.length);
              }
            });
            _resetFeedToPageZero();
          },
          onDone: _closeDock,
        );
      case ActiveTool.save:
        return _SavePanelHost(
          projectId: widget.projectId,
          paints: _visiblePaletteSnapshot(),
          onSaved: _closeDock,
          onCancel: _closeDock,
        );
      case ActiveTool.share:
        return _SharePanelHost(
          onShare: () {
            _shareCurrentPalette();
            _closeDock();
          },
        );
    }
  }
  
  // Helper methods for live hue/saturation adjustments with ΔE2000 mapping
  List<double> _lchToLab(double l, double c, double hDeg) {
    final h = hDeg * math.pi / 180.0;
    final a = c * math.cos(h);
    final b = c * math.sin(h);
    return [l, a, b];
  }

  Paint _nearestToTargetLab(List<double> targetLab, List<Paint> candidates) {
    Paint? best;
    double bestDe = double.infinity;
    for (final p in candidates) {
      final de = ColorUtils.deltaE2000(p.lab, targetLab);
      if (de < bestDe) { bestDe = de; best = p; }
    }
    return best ?? candidates.first;
  }

  Paint _adjustPaint(Paint p, List<Paint> pool) {
    final l = p.lch[0];
    final c = (_satScale * p.lch[1]).clamp(0.0, 150.0);
    final h = (_hueShift + p.lch[2]) % 360.0;
    final targetLab = _lchToLab(l, c, h);
    return _nearestToTargetLab(targetLab, pool);
  }

  List<Paint> _applyAdjustments(List<Paint> palette) {
    final pool = _getFilteredPaints();
    if (pool.isEmpty) return palette;
    return [
      for (var i = 0; i < palette.length; i++)
        (_lockedStates.length > i && _lockedStates[i])
            ? palette[i]
            : _adjustPaint(palette[i], pool)
    ];
  }

  @override
  Widget build(BuildContext context) {
    Debug.build('RollerScreen', 'build', details: 'isLoading: $_isLoading, paletteSize: $_paletteSize, pagesCount: ${_pages.length}');
    
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Focus(
                  autofocus: true,
                  child: Shortcuts(
                    shortcuts: {
                      LogicalKeySet(LogicalKeyboardKey.arrowUp): const GoToPrevPageIntent(),
                      LogicalKeySet(LogicalKeyboardKey.arrowDown): const GoToNextPageIntent(),
                    },
                    child: Actions(
                      actions: {
                        GoToPrevPageIntent: CallbackAction<GoToPrevPageIntent>(onInvoke: (_) { _goToPrevPage(); return null; }),
                        GoToNextPageIntent: CallbackAction<GoToNextPageIntent>(onInvoke: (_) { _goToNextPage(); return null; }),
                      },
                      child: PageView.builder(
                        controller: _pageCtrl,
                        scrollDirection: Axis.vertical,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) {
                          if (index >= _pages.length) {
                            // Use post-frame callback to avoid calling _ensurePage during build
                            // Only schedule if not already generating this page
                            if (!_generatingPages.contains(index)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && !_generatingPages.contains(index)) {
                                  _ensurePage(index);
                                }
                              });
                            }
                            return const Center(child: CircularProgressIndicator());
                          }
                          final palette = _pages[index];
                          return _buildPaletteView(palette);
                        },
                      ),
                    ),
                  ),
                ),
                // Overlay: pinned locked stripes drawn above the PageView
                Positioned.fill(
                  child: Column(
                    children: List.generate(_paletteSize, (i) {
                      final bool locked = i < _lockedStates.length && _lockedStates[i];
                      final bool hasPaint = i < _currentPalette.length;
                      if (!locked || !hasPaint) {
                        // Transparent, non-interactive spacer so underlying PageView is tappable
                        return Expanded(
                          child: IgnorePointer(
                            ignoring: true,
                            child: const SizedBox.shrink(),
                          ),
                        );
                      }

                      final color = ColorUtils.getPaintColor(_currentPalette[i].hex);

                      // Locked row: draw a solid color block that stays pinned while pages scroll under it.
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _toggleLock(i), // tap again to unlock
                          child: Container(
                            color: color,
                            // (Optional polish) small lock chip so users see it's locked
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12, top: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock, size: 14, color: Colors.white),
                                      SizedBox(width: 6),
                                      Text('Locked', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                if (_showSwipeHint)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Swipe ↑ for next palette',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                // Global rolling indicator
                if (_isRolling)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black.withOpacity(0.1),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                // 1) Tap-catcher to close the tools dock when open
                if (_toolsOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => _safeSetState(() {
                        _toolsOpen = false;
                        _activeTool = null;
                      }),
                      behavior: HitTestBehavior.translucent,
                    ),
                  ),

                // 2) The vertical Tools dock with horizontal panels
                Positioned(
                  right: 12,
                  bottom: 24,
                  child: ToolsDock(
                    open: _toolsOpen,
                    activeTool: _activeTool,
                    onToggle: () {
                      HapticFeedback.selectionClick();
                      _safeSetState(() => _toolsOpen = !_toolsOpen);
                    },
                    onSelect: (t) {
                      _safeSetState(() {
                        if (t == null) {
                          _activeTool = null;
                          _toolsOpen = false;
                        } else {
                          _toolsOpen = true;
                          _activeTool = t;
                        }
                      });
                    },
                    items: [
                      DockItem(tool: ActiveTool.style, icon: Icons.auto_awesome, label: 'Style'),
                      DockItem(tool: ActiveTool.sort, icon: Icons.filter_list, label: 'Sort'),
                      DockItem(tool: ActiveTool.adjust, icon: Icons.tune, label: 'Adjust'),
                      DockItem(tool: ActiveTool.count, icon: Icons.grid_goldenratio, label: 'Count'),
                      DockItem(tool: ActiveTool.save, icon: Icons.bookmark_add_outlined, label: 'Save'),
                      DockItem(tool: ActiveTool.share, icon: Icons.ios_share_outlined, label: 'Share'),
                    ],
                    panelBuilder: (tool) => _buildToolPanel(tool),
                  ),
                ),
              ],
            ),
    );
  }

  void _resetFeedToPageZero() {
    // Combine multiple setState calls into one to reduce rebuilds
    _safeSetState(() {
      _pages.clear();
      _visiblePage = 0;
    });
    
    // Roll palette and add to pages after state is set
    _rollPalette();
    
    // Use postFrameCallback to ensure palette is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _currentPalette.isNotEmpty && _pages.isEmpty) {
        _safeSetState(() {
          _pages.add(List<Paint>.from(_currentPalette));
        });
      }
      _safeJumpToPage(0);
    });
  }


  void _onPageChanged(int i) {
    Debug.info('RollerScreen', '_onPageChanged', 'Page changed from $_visiblePage to $i');
    
    HapticFeedback.selectionClick();
    
    // Only update state if values actually changed to prevent unnecessary rebuilds
    if (_visiblePage != i || _showSwipeHint) {
      _safeSetState(() {
        _visiblePage = i;
        _showSwipeHint = false;
        if (i < _pages.length) {
          final pageColors = _pages[i];
          final newPalette = _displayColorsForCurrentMode(pageColors);
          // Only update palette if it's actually different
          if (_currentPalette.length != newPalette.length || 
              !_palettesEqual(_currentPalette, newPalette)) {
            _currentPalette = newPalette;
          }
        }
      }, details: 'Page changed from $_visiblePage to $i');
    }

    // Prefetch exactly one page ahead when reaching the end of cached pages
    if (i + 1 >= _pages.length) {
      _ensurePage(i + 1);
    }
  }
  
  void _shareCurrentPalette() {
    // Minimal placeholder to clear analyzer warning; hook up Share later
    final names = _currentPalette.map((p) => p.name).join(', ');
    debugPrint('Share palette: [$names]');
  }

  // Helper method to compare palettes for equality
  bool _palettesEqual(List<Paint> a, List<Paint> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  // Keyboard navigation methods
  void _goToPrevPage() {
    if (_visiblePage > 0) {
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  void _goToNextPage() {
    _ensurePage(_visiblePage + 1);
    _pageCtrl.nextPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }


  Widget _buildPaletteView(List<Paint> palette) {
    return Column(
      children: List.generate(_paletteSize, (i) {
        final paint = i < palette.length ? palette[i] : null;
        final isLocked = i < _lockedStates.length ? _lockedStates[i] : false;
        return Expanded(
          child: AnimatedPaintStripe(
            paint: paint,
            previousPaint: null,
            isLocked: isLocked,
            isRolling: _isRolling,
            onTap: () => _toggleLock(i),
            onSwipeRight: () => _rollStripe(i),
            onSwipeLeft: _paletteSize > 2 ? () => _removeStripe(i) : null,
            onRefine: () => _showRefineSheet(i),
          ),
        );
      }),
    );
  }

  Future<void> _ensurePage(int pageIndex) async {
    Debug.info('RollerScreen', '_ensurePage', 'Ensuring page $pageIndex (current pages: ${_pages.length})');
    
    // Do not generate negative pages
    if (pageIndex < 0) return;

    final filtered = _getFilteredPaints();
    if (filtered.isEmpty) {
      Debug.warning('RollerScreen', '_ensurePage', 'No paints available after filtering');
      // Only show the message if user has manually applied filters
      if (_hasAppliedFilters && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No paints match your filters.')),
            );
          }
        });
      }
      return;
    }

    if (pageIndex < _pages.length) {
      final existingPage = _pages[pageIndex];
      final sortedPage = _displayColorsForCurrentMode(existingPage);
      // Only update if the palette is actually different
      if (pageIndex == _visiblePage && !_palettesEqual(_currentPalette, sortedPage)) {
        Debug.postFrameCallback('RollerScreen', '_ensurePage', details: 'Updating existing page $pageIndex');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _safeSetState(() => _currentPalette = sortedPage, details: 'Updated existing page $pageIndex');
          }
        });
      }
      return;
    }

    if (_generatingPages.contains(pageIndex) || _isRolling) {
      Debug.info('RollerScreen', '_ensurePage', 'Page $pageIndex already generating or roller is rolling');
      return;
    }
    _generatingPages.add(pageIndex);
    Debug.info('RollerScreen', '_ensurePage', 'Starting generation for page $pageIndex');

    try {
      // 1) Snapshot the visible page so anchors come from what the user actually sees.
      if (_visiblePage < _pages.length) {
        _pages[_visiblePage] = List<Paint>.from(_currentPalette);
      }

      // 2) Build anchors from the snapshot of the visible page, not from _currentPalette
      //    (which can be reassigned during the transition).
      final List<Paint> base = (_visiblePage < _pages.length)
          ? List<Paint>.from(_pages[_visiblePage])
          : List<Paint>.from(_currentPalette);

      final anchors = List<Paint?>.generate(_paletteSize, (i) {
        final locked = i < _lockedStates.length && _lockedStates[i];
        return (locked && i < base.length) ? base[i] : null;
      });

      final rolled = await _rollPaletteAsync(anchors);
      
      final adjusted = _applyAdjustments(rolled);
      final newPage = _displayColorsForCurrentMode(adjusted.take(_paletteSize).toList());

      if (!mounted) return;
      
      // Use postFrameCallback to avoid setState during build
      Debug.postFrameCallback('RollerScreen', '_ensurePage', details: 'Adding generated page $pageIndex');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _safeSetState(() {
          if (pageIndex == _pages.length) {
            _pages.add(newPage);
          } else if (pageIndex < _pages.length) {
            _pages[pageIndex] = newPage;
          }
          // 3) Bind the live palette only when updating the page that is actually visible.
          if (pageIndex == _visiblePage && !_palettesEqual(_currentPalette, newPage)) {
            _currentPalette = List<Paint>.from(newPage);
          }
        }, details: 'Generated and added page $pageIndex');
      });
      

      // Cap memory by trimming old pages behind the user
      if (_pages.length > _retainWindow && _visiblePage > 10) {
        final keepFrom = (_visiblePage - 25).clamp(0, _pages.length - 1);
        if (keepFrom > 0) {
          _pages.removeRange(0, keepFrom);
          _visiblePage -= keepFrom;
          _safeJumpToPage(_visiblePage);
        }
      }

    } catch (e) {
      Debug.error('RollerScreen', '_ensurePage', 'Error generating page $pageIndex: $e');
    } finally {
      _generatingPages.remove(pageIndex);
      Debug.info('RollerScreen', '_ensurePage', 'Finished processing page $pageIndex');
    }
  }

  // Public interface methods for integration with SearchScreen
  @override
  int getPaletteSize() => _paletteSize;

  @override
  Paint? getPaintAtIndex(int index) {
    if (index >= 0 && index < _currentPalette.length) {
      return _currentPalette[index];
    }
    return null;
  }

  @override
  void replacePaintAtIndex(int index, Paint paint) {
    if (index >= 0 && index < _currentPalette.length) {
      setState(() {
        _currentPalette[index] = paint;
      });
      
      // Sync current page cache after replacing paint
      if (_visiblePage < _pages.length) {
        _pages[_visiblePage] = List<Paint>.from(_currentPalette);
      }
    }
  }

  @override
  bool canAddNewColor() {
    return _paletteSize < 9; // Maximum palette size is 9
  }

  @override
  void addPaintToCurrentPalette(Paint paint) {
    if (!canAddNewColor()) return; // Don't add if at max size
    
    _safeSetState(() {
      _paletteSize++;
      _currentPalette.add(paint);
      _lockedStates.add(false); // New color starts unlocked
      
      // Sync current page cache after adding paint
      if (_visiblePage < _pages.length) {
        _pages[_visiblePage] = List<Paint>.from(_currentPalette);
      }
    }, details: 'Added new paint: ${paint.name}, new palette size: $_paletteSize');
  }
}


  

class _StyleOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  
  const _StyleOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: selected 
                            ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity( 0.7)
                            : Theme.of(context).colorScheme.onSurface.withOpacity( 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DockItem {
  final ActiveTool tool;
  final IconData icon;
  final String label;
  DockItem({required this.tool, required this.icon, required this.label});
}

class ToolsDock extends StatefulWidget {
  final bool open;
  final ActiveTool? activeTool;
  final VoidCallback onToggle;
  final Function(ActiveTool?) onSelect;
  final List<DockItem> items;
  final Widget Function(ActiveTool) panelBuilder;

  const ToolsDock({
    super.key,
    required this.open,
    required this.activeTool,
    required this.onToggle,
    required this.onSelect,
    required this.items,
    required this.panelBuilder,
  });

  @override
  State<ToolsDock> createState() => _ToolsDockState();
}

class _ToolsDockState extends State<ToolsDock> with TickerProviderStateMixin {
  late AnimationController _dockController;
  late AnimationController _panelController;
  late Animation<double> _panelProgress;
  final double _dockWidthPx = 72.0; // fixed width to prevent infinite loop

  @override
  void initState() {
    super.initState();
    _dockController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _panelController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _panelProgress = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(ToolsDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      if (widget.open) {
        _dockController.forward();
      } else {
        _dockController.reverse();
        _panelController.reverse();
      }
    }
    if (widget.activeTool != oldWidget.activeTool) {
      if (widget.activeTool != null) {
        _panelController.forward();
      } else {
        _panelController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _dockController.dispose();
    _panelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Panel (to the left)
        AnimatedBuilder(
          animation: _panelProgress,
          builder: (context, child) {
            final size = MediaQuery.of(context).size;

            // Matches the Container margin on the panel
            const double rightMargin = 12.0; // Container margin: EdgeInsets.only(right: 12)
            const double gapBetween = 12.0;  // same as rightMargin, it's the visual gap to the pill/rail

            // How much horizontal space we can use for the panel *today*, next to the pill/rail
            final double available = size.width - rightMargin - gapBetween - _dockWidthPx;

            // Never exceed available space; prefer 320 on larger screens
            final double targetWidth = available <= 0 ? 0 : available.clamp(0.0, 320.0);

            final double panelWidth = _panelProgress.value * targetWidth;
            if (panelWidth <= 1) return const SizedBox.shrink();

            return Container(
              width: panelWidth,
              constraints: BoxConstraints(
                // Cap height to visible viewport so it never runs off the bottom
                maxHeight: size.height * 0.8,
              ),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity( 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: widget.activeTool != null
                  ? widget.panelBuilder(widget.activeTool!)
                  : null,
            );
          },
        ),
        
        // Dock (collapsed/expanded)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: widget.open
              ? _RailItem(
                  key: const ValueKey('expanded'),
                  items: widget.items,
                  activeTool: widget.activeTool,
                  onSelect: widget.onSelect,
                  onMeasured: null, // Disabled to prevent infinite loop
                )
              : _ToolsCollapsed(
                  key: const ValueKey('collapsed'),
                  onTap: widget.onToggle,
                  onMeasured: null, // Disabled to prevent infinite loop
                ),
        ),
      ],
    );
  }
}

class _ToolsCollapsed extends StatelessWidget {
  final VoidCallback onTap;
  final ValueChanged<double>? onMeasured;
  const _ToolsCollapsed({super.key, required this.onTap, this.onMeasured});

  @override
  Widget build(BuildContext context) {
    // Temporarily disable size measurement to prevent infinite loop
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   final w = context.size?.width;
    //   if (w != null) onMeasured?.call(w);
    // });
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.black, size: 20),
              SizedBox(width: 8),
              Text('Tools', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final List<DockItem> items;
  final ActiveTool? activeTool;
  final Function(ActiveTool?) onSelect;
  final ValueChanged<double>? onMeasured;

  const _RailItem({
    super.key,
    required this.items,
    required this.activeTool,
    required this.onSelect,
    this.onMeasured,
  });

  @override
  Widget build(BuildContext context) {
    // Temporarily disable size measurement to prevent infinite loop
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   final w = context.size?.width;
    //   if (w != null) onMeasured?.call(w);
    // });
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: items.map((item) => _buildRailButton(item)).toList(),
        ),
      ),
    );
  }

  Widget _buildRailButton(DockItem item) {
    final isActive = activeTool == item.tool;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onSelect(isActive ? null : item.tool),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: isActive
              ? BoxDecoration(
                  color: Colors.black.withOpacity( 0.05),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Column(
            children: [
              Icon(item.icon, color: Colors.black, size: 22),
              const SizedBox(height: 4),
              Text(item.label, style: const TextStyle(color: Colors.black, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// Tool Panel Hosts
class _StylePanel extends StatelessWidget {
  final HarmonyMode currentMode;
  final bool diversifyBrands;
  final int paletteSize;
  final Function(HarmonyMode) onModeChanged;
  final Function(bool) onDiversifyChanged;
  final Function(int) onPaletteSizeChanged;
  final VoidCallback onDone;

  const _StylePanel({
    required this.currentMode,
    required this.diversifyBrands,
    required this.paletteSize,
    required this.onModeChanged,
    required this.onDiversifyChanged,
    required this.onPaletteSizeChanged,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Harmony Style', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          
          _StyleOptionTile(
            title: 'Designer',
            subtitle: 'Curated combinations',
            selected: currentMode == HarmonyMode.designer,
            onTap: () => onModeChanged(HarmonyMode.designer),
          ),
          _StyleOptionTile(
            title: 'Neutral',
            subtitle: 'Muted & balanced tones',
            selected: currentMode == HarmonyMode.neutral,
            onTap: () => onModeChanged(HarmonyMode.neutral),
          ),
          _StyleOptionTile(
            title: 'Analogous',
            subtitle: 'Similar hue neighbors',
            selected: currentMode == HarmonyMode.analogous,
            onTap: () => onModeChanged(HarmonyMode.analogous),
          ),
          _StyleOptionTile(
            title: 'Complementary',
            subtitle: 'Opposite color wheel',
            selected: currentMode == HarmonyMode.complementary,
            onTap: () => onModeChanged(HarmonyMode.complementary),
          ),
          _StyleOptionTile(
            title: 'Triad',
            subtitle: 'Three evenly spaced',
            selected: currentMode == HarmonyMode.triad,
            onTap: () => onModeChanged(HarmonyMode.triad),
          ),
          
          // Designer specific: Palette Size (1–9)
          if (currentMode == HarmonyMode.designer) ...[
            const SizedBox(height: 24),
            Text('Palette Size', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Choose the number of colors (1–9)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(9, (i) {
                final size = i + 1;
                final isSelected = paletteSize == size;
                return FilterChip(
                  label: Text(size.toString()),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      onPaletteSizeChanged(size);
                    }
                  },
                );
              }),
            ),
          ],
          
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Diversify brands'),
            subtitle: const Text('Mix different paint brands'),
            value: diversifyBrands,
            onChanged: onDiversifyChanged,
          ),
          
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDone,
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandFilterPanelHost extends StatelessWidget {
  final List<Brand> availableBrands;
  final Set<String> selectedBrandIds;
  final Function(Set<String>) onBrandsSelected;
  final VoidCallback onDone;

  const _BrandFilterPanelHost({
    required this.availableBrands,
    required this.selectedBrandIds,
    required this.onBrandsSelected,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return BrandFilterPanel(
      availableBrands: availableBrands,
      selectedBrandIds: selectedBrandIds,
      onBrandsSelected: onBrandsSelected,
      onDone: onDone,
    );
  }
}

class _AdjustPanelHost extends StatelessWidget {
  final double hueShift;
  final double satScale;
  final Function(double) onHueChanged;
  final Function(double) onSatChanged;
  final VoidCallback onReset;
  final VoidCallback onDone;

  const _AdjustPanelHost({
    required this.hueShift,
    required this.satScale,
    required this.onHueChanged,
    required this.onSatChanged,
    required this.onReset,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Adjust Colors', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text('Hue Shift: ${hueShift.round()}°'),
          Slider(
            value: hueShift,
            min: -45,
            max: 45,
            divisions: 90,
            onChanged: onHueChanged,
          ),
          const SizedBox(height: 8),
          Text('Saturation: ${(satScale * 100).round()}%'),
          Slider(
            value: satScale,
            min: 0.6,
            max: 1.4,
            divisions: 40,
            onChanged: onSatChanged,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReset,
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onDone,
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountPanelHost extends StatelessWidget {
  final int paletteSize;
  final Function(int) onSizeChanged;
  final VoidCallback onDone;

  const _CountPanelHost({
    required this.paletteSize,
    required this.onSizeChanged,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Palette Size', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: List.generate(9, (i) {
              final size = i + 1;
              return ChoiceChip(
                label: Text('$size'),
                selected: paletteSize == size,
                onSelected: (_) {
                  onSizeChanged(size);
                  onDone();
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SharePanelHost extends StatelessWidget {
  final VoidCallback onShare;

  const _SharePanelHost({required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Share Palette', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share),
              label: const Text('Share Now'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavePanelHost extends StatelessWidget {
  final String? projectId;
  final List<Paint> paints;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const _SavePanelHost({
    this.projectId,
    required this.paints,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (paints.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.palette_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Roll a palette first.', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    }
    
    return SavePalettePanel(
      projectId: projectId,
      paints: paints,
      onSaved: onSaved,
      onCancel: onCancel,
    );
  }
}

