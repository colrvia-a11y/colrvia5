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
import 'package:color_canvas/models/color_strip_history.dart';
// REGION: CODEX-ADD analytics-service-import
import 'package:color_canvas/services/analytics_service.dart';
// END REGION: CODEX-ADD analytics-service-import
// REGION: CODEX-ADD user-prefs-import
import 'package:color_canvas/services/user_prefs_service.dart';
// END REGION: CODEX-ADD user-prefs-import
import 'package:color_canvas/utils/palette_transforms.dart' as transforms;
import 'package:color_canvas/utils/lab.dart';
import 'package:color_canvas/services/project_service.dart';
import 'package:color_canvas/widgets/via_overlay.dart';
import 'package:color_canvas/screens/color_plan_screen.dart';
import 'package:color_canvas/screens/visualizer_screen.dart';
import 'package:color_canvas/widgets/fixed_elements_sheet.dart';
import 'package:color_canvas/models/fixed_elements.dart';
import 'package:color_canvas/services/fixed_element_service.dart';

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
  final Map<String, Paint> _paintById = {};
  Set<String> _selectedBrandIds = {};
  HarmonyMode _currentMode = HarmonyMode.neutral;
  bool _isLoading = true;
  bool _diversifyBrands = true;
  int _paletteSize = 5;
  bool _isRolling = false;
  List<FixedElement> _fixedElements = [];
  
  // Enhanced color history tracking for each strip
  final List<ColorStripHistory> _stripHistories = [];
  
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
  
  // Track scheduled post-frame callbacks to prevent loops
  final Set<int> _scheduledCallbacks = {};

  // Track page generation attempts to prevent infinite loops
  final Map<int, int> _pageGenerationAttempts = {};
  static const int _maxPageGenerationAttempts = 3;

  // Track palette updates within a frame and pending callbacks that mutate it
  bool _paletteUpdatedThisFrame = false;
  final Set<int> _activePaletteCallbacks = {};
  int _nextPaletteCallbackId = 0;
  
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

  void _markPaletteUpdated() {
    _paletteUpdatedThisFrame = true;
    _activePaletteCallbacks.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paletteUpdatedThisFrame = false;
    });
  }

  @override
  void initState() {
    super.initState();
    
    Debug.info('RollerScreen', 'initState', 'Component initializing');
    Debug.info('RollerScreen', 'initState', 'About to load paints');

    // Load paints from database with fallback to sample data
    _loadPaints();

    if (widget.projectId != null) {
      UserPrefsService.setLastProject(widget.projectId!, 'roller');
      FixedElementService().listElements(widget.projectId!).then((els) {
        if (mounted) {
          setState(() => _fixedElements = els);
        }
      });
    }
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
    
    Debug.info('RollerScreen', '_loadPaints', 'Started');

    // First try to load from database
    Debug.info('RollerScreen', '_loadPaints', 'Loading from database...');
    try {
      paints = await FirebaseService.getAllPaints();
      brands = await FirebaseService.getAllBrands();
      Debug.info('RollerScreen', '_loadPaints', 'Database loaded: ${paints.length} paints, ${brands.length} brands');
      
      // If no data in database, fall back to sample data
      if (paints.isEmpty) {
        Debug.warning('RollerScreen', '_loadPaints', 'No paints found in database; falling back to samples');
        paints = await SamplePaints.getAllPaints();
        brands = await SamplePaints.getSampleBrands();
        Debug.info('RollerScreen', '_loadPaints', 'Sample fallback loaded: ${paints.length} paints, ${brands.length} brands');
      }
    } catch (e) {
      Debug.error('RollerScreen', '_loadPaints', 'DB load error: $e; falling back to samples');
      try {
        paints = await SamplePaints.getAllPaints();
        brands = await SamplePaints.getSampleBrands();
        Debug.info('RollerScreen', '_loadPaints', 'Sample fallback loaded: ${paints.length} paints, ${brands.length} brands');
      } catch (sampleError) {
        Debug.error('RollerScreen', '_loadPaints', 'Sample data load error: $sampleError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to load paint data. Please try again later.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
    }
    
    Debug.info('RollerScreen', '_loadPaints', 'Final loaded: ${paints.length} paints, ${brands.length} brands');

    _paintById.clear();
    for (final p in paints) {
      _paintById[p.id] = p;
    }

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
      'fixedUndertones': _fixedElements.map((e) => e.undertone).toList(),
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
        Debug.warning('RollerScreen', '_rollPalette', 'Async generation failed: $e; falling back to sync');
        // Fallback to synchronous palette generation
        rolled = PaletteGenerator.rollPalette(
          availablePaints: _getFilteredPaints(),
          anchors: anchors,
          mode: _currentMode,
          diversifyBrands: _diversifyBrands,
          fixedUndertones: _fixedElements.map((e) => e.undertone).toList(),
        );
      }
      
      if (!mounted || requestId != _rollRequestId) return; // drop stale result

      final adjusted = _applyAdjustments(rolled);
      final paletteForDisplay = _displayColorsForCurrentMode(adjusted.take(_paletteSize).toList());

      _safeSetState(() {
        _currentPalette = paletteForDisplay;
        _isRolling = false;
      });

      // Update strip histories with new colors
      _ensureStripHistories();
      for (int i = 0; i < _currentPalette.length; i++) {
        final isLocked = i < _lockedStates.length ? _lockedStates[i] : false;
        if (!isLocked) {
          // Only add to history if the strip isn't locked
          _stripHistories[i].addPaint(_currentPalette[i]);
        }
      }

      // Ensure the current page is updated or added
      if (_visiblePage < _pages.length) {
        _pages[_visiblePage] = List<Paint>.from(_currentPalette);
      } else if (_pages.isEmpty) {
        _pages.add(List<Paint>.from(_currentPalette));
      }
      _markPaletteUpdated();
    } catch (e) {
      Debug.error('RollerScreen', '_rollPalette', 'Error: $e');
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

  /// Ensures strip histories list matches current palette size
  void _ensureStripHistories() {
    while (_stripHistories.length < _paletteSize) {
      _stripHistories.add(ColorStripHistory());
    }
    // Remove excess histories if palette size decreased
    if (_stripHistories.length > _paletteSize) {
      _stripHistories.removeRange(_paletteSize, _stripHistories.length);
    }
  }

  /// Navigate to next color variation for a specific strip
  void _navigateStripForward(int index) {
    _ensureStripHistories();
    if (index >= _stripHistories.length) return;
    
    final history = _stripHistories[index];
    
    if (history.canGoForward) {
      // Navigate forward in existing history
      final nextPaint = history.goForward();
      if (nextPaint != null) {
        _updateStripColor(index, nextPaint);
      }
    } else {
      // Generate a new color variation
      _rollStripe(index);
    }
  }

  /// Navigate to previous color variation for a specific strip
  void _navigateStripBackward(int index) {
    _ensureStripHistories();
    if (index >= _stripHistories.length) return;
    
    final history = _stripHistories[index];
    
    if (history.canGoBack) {
      // Navigate backward in history
      final prevPaint = history.goBack();
      if (prevPaint != null) {
        _updateStripColor(index, prevPaint);
      }
    } else {
      // If no history, generate a new color
      _rollStripe(index);
    }
  }

  /// Updates a specific strip color and syncs with current palette
  void _updateStripColor(int index, Paint newPaint) {
    if (index >= _currentPalette.length) return;
    
    setState(() {
      _currentPalette[index] = newPaint;
    });

    // Sync current page cache
    if (_visiblePage < _pages.length) {
      _pages[_visiblePage] = List<Paint>.from(_currentPalette);
    }
    _markPaletteUpdated();
  }

  void _rollStripe(int index) {
    // Extend _lockedStates if needed
    while (_lockedStates.length <= index) {
      _lockedStates.add(false);
    }
    
    if (_lockedStates[index] || _getFilteredPaints().isEmpty || _isRolling) return;
    
    HapticFeedback.lightImpact();
    
    // Set rolling state to prevent concurrent operations
    setState(() => _isRolling = true);
    
    try {
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
        fixedUndertones: _fixedElements.map((e) => e.undertone).toList(),
      );
      
      final adjusted = _applyAdjustments(rolled);
      
      setState(() {
        _currentPalette = adjusted.take(_paletteSize).toList();
        _isRolling = false; // Reset rolling state
      });

      // Add new color to strip history
      _ensureStripHistories();
      if (index < _currentPalette.length && index < _stripHistories.length) {
        _stripHistories[index].addPaint(_currentPalette[index]);
      }

      // Sync current page cache after rolling a stripe
      if (_visiblePage < _pages.length) {
        _pages[_visiblePage] = List<Paint>.from(_currentPalette);
      }
      _markPaletteUpdated();
    } catch (e) {
      Debug.error('RollerScreen', '_rollStripe', 'Error: $e');
      if (mounted) {
        setState(() => _isRolling = false);
      }
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
          _markPaletteUpdated();
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _openFixedElements() async {
    if (widget.projectId == null) return;
    final updated = await showModalBottomSheet<List<FixedElement>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FixedElementsSheet(
        projectId: widget.projectId!,
        elements: _fixedElements,
      ),
    );
    if (updated != null) {
      setState(() => _fixedElements = updated);
    }
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
    _markPaletteUpdated();
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
      Debug.error('RollerScreen', '_maybeSeedFromInitial', 'Error: $e');
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
    if (_availablePaints.isEmpty) {
      Debug.warning('RollerScreen', '_getFilteredPaints', 'Available paints list is empty');
      return [];
    }
    
    if (_selectedBrandIds.isEmpty || _selectedBrandIds.length == _availableBrands.length) {
      return _availablePaints;
    }
    
    final filtered = _availablePaints.where((paint) => _selectedBrandIds.contains(paint.brandId)).toList();
    Debug.info('RollerScreen', '_getFilteredPaints', 'Filtered ${_availablePaints.length} paints to ${filtered.length}');
    return filtered;
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
    
    // Ensure strip histories match new size
    _ensureStripHistories();
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
                            // Only schedule if not already generating this page AND not already scheduled
                            if (!_generatingPages.contains(index) && !_scheduledCallbacks.contains(index)) {
                              _scheduledCallbacks.add(index);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _scheduledCallbacks.remove(index);
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
                // Removed legacy pinned "Locked" overlay (duplicate lock system)
                if (_showSwipeHint)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
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
                        color: Colors.black.withValues(alpha: 0.1),
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
                ViaOverlay(
                  contextLabel: 'roller',
                  onMakePlan: widget.projectId == null
                      ? null
                      : () {
                          final ids =
                              _currentPalette.map((p) => p.id).toList();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ColorPlanScreen(
                                projectId: widget.projectId!,
                                paletteColorIds: ids,
                              ),
                            ),
                          );
                        },
                  onVisualize: widget.projectId == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VisualizerScreen(
                                projectId: widget.projectId,
                              ),
                            ),
                          );
                        },
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomCtas(context),
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

  void _applyVariant(String kind) {
    final ids = _currentPalette.map((p) => p.id).toList();
    if (ids.isEmpty) return;

    Lab labOf(String id) {
      final p = _paintById[id];
      if (p == null) return const Lab(0, 0, 0);
      return Lab(p.lab[0], p.lab[1], p.lab[2]);
    }

    String? nearestId(Lab lab) {
      final paints = _getFilteredPaints();
      final nearest =
          ColorUtils.nearestByDeltaE([lab.l, lab.a, lab.b], paints);
      return nearest?.id;
    }

    List<String> newIds;
    switch (kind) {
      case 'brighter':
        newIds = transforms.brighter(ids, labOf, nearestId);
        break;
      case 'moodier':
        newIds = transforms.moodier(ids, labOf, nearestId);
        break;
      case 'warmer':
        newIds = transforms.warmer(ids, labOf, nearestId);
        break;
      case 'cooler':
        newIds = transforms.cooler(ids, labOf, nearestId);
        break;
      case 'softer':
      default:
        newIds = transforms.softer(ids, labOf, nearestId);
        break;
    }

    for (int i = 0; i < newIds.length; i++) {
      if (i < _lockedStates.length && _lockedStates[i]) {
        newIds[i] = ids[i];
      } else if (!_paintById.containsKey(newIds[i])) {
        newIds[i] = ids[i];
      }
    }

    final newPalette = <Paint>[];
    for (int i = 0; i < newIds.length; i++) {
      final id = newIds[i];
      newPalette.add(_paintById[id] ?? _currentPalette[i]);
    }

    _ensureStripHistories();
    for (int i = 0; i < newPalette.length; i++) {
      final isLocked = i < _lockedStates.length ? _lockedStates[i] : false;
      if (!isLocked) {
        _stripHistories[i].addPaint(newPalette[i]);
      }
    }

    _safeSetState(() {
      _currentPalette = newPalette;
      if (_visiblePage < _pages.length) {
        _pages[_visiblePage] = List<Paint>.from(_currentPalette);
      }
    });
    _markPaletteUpdated();

    AnalyticsService.instance
        .logEvent('palette_variant_applied', {'kind': kind, 'size': newPalette.length});
    if (widget.projectId != null) {
      ProjectService.addPaletteHistory(widget.projectId!, kind, newIds);
    }
  }
  
  void _shareCurrentPalette() {
    // Minimal placeholder to clear analyzer warning; hook up Share later
    final names = _currentPalette.map((p) => p.name).join(', ');
    debugPrint('Share palette: [$names]');
  }

  // REGION: CODEX-ADD core-loop-cta-row
  Widget _buildBottomCtas(BuildContext context) {
    final paletteIds = _currentPalette.map((p) => p.id).toList();
    final hasPalette = paletteIds.isNotEmpty;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPalette)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  ActionChip(
                    label: const Text('Softer'),
                    onPressed: () => _applyVariant('softer'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Brighter'),
                    onPressed: () => _applyVariant('brighter'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Moodier'),
                    onPressed: () => _applyVariant('moodier'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Warmer'),
                    onPressed: () => _applyVariant('warmer'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Cooler'),
                    onPressed: () => _applyVariant('cooler'),
                  ),
                ],
              ),
            ),
          if (hasPalette) const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: hasPalette && widget.projectId != null
                        ? () {
                            Navigator.pushNamed(context, '/colorPlan', arguments: {
                              'projectId': widget.projectId!,
                              'paletteColorIds': paletteIds,
                            });
                            AnalyticsService.instance.ctaPlanClicked('roller');
                          }
                        : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Make a Color Plan'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/visualizer', arguments: {
                        'projectId': widget.projectId,
                        'paletteColorIds': paletteIds,
                      });
                      AnalyticsService.instance.ctaVisualizeClicked('roller');
                    },
                    icon: const Icon(Icons.image),
                    label: const Text('Visualize'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: hasPalette
                      ? () {
                          Navigator.pushNamed(context, '/compareColors', arguments: {
                            'projectId': widget.projectId,
                            'paletteColorIds': paletteIds,
                          });
                          AnalyticsService.instance.ctaCompareClicked('roller');
                        }
                      : null,
                  icon: const Icon(Icons.compare),
                  tooltip: 'Compare',
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: widget.projectId == null ? null : _openFixedElements,
                  icon: const Icon(Icons.layers_outlined),
                  tooltip: 'Fixed Elements',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // END REGION: CODEX-ADD core-loop-cta-row

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
            key: ValueKey(paint?.id ?? 'empty_$i'),
            paint: paint,
            previousPaint: null,
            isLocked: isLocked,
            isRolling: _isRolling,
            onTap: () => _toggleLock(i),
            // Enhanced navigation: Right swipe = forward, Left swipe = backward
            onSwipeRight: () => _navigateStripForward(i),
            onSwipeLeft: () => _navigateStripBackward(i),
            onRefine: () => _showRefineSheet(i),
            onDelete: _paletteSize > 2 ? () => _removeStripe(i) : null,
          ),
        );
      }),
    );
  }

  Future<void> _ensurePage(int pageIndex) async {
    Debug.info('RollerScreen', '_ensurePage', 'Ensuring page $pageIndex (current pages: ${_pages.length})');
    
    // Do not generate negative pages
    if (pageIndex < 0) return;
    
    // Prevent infinite loops by limiting generation attempts
    final attempts = _pageGenerationAttempts[pageIndex] ?? 0;
    if (attempts >= _maxPageGenerationAttempts) {
      Debug.error('RollerScreen', '_ensurePage', 'Too many generation attempts for page $pageIndex ($attempts). Aborting.');
      return;
    }
    _pageGenerationAttempts[pageIndex] = attempts + 1;

    final filtered = _getFilteredPaints();
    if (filtered.isEmpty) {
      Debug.warning('RollerScreen', '_ensurePage', 'No paints available after filtering');
      Debug.warning('RollerScreen', '_ensurePage', 'Available paints: ${_availablePaints.length}, Selected brands: ${_selectedBrandIds.length}');
      
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
      if (pageIndex == _visiblePage &&
          !_paletteUpdatedThisFrame &&
          !_palettesEqual(_currentPalette, sortedPage)) {
        Debug.postFrameCallback('RollerScreen', '_ensurePage', details: 'Updating existing page $pageIndex');
        final callbackId = ++_nextPaletteCallbackId;
        _activePaletteCallbacks.add(callbackId);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_activePaletteCallbacks.remove(callbackId)) return;
          if (mounted) {
            _safeSetState(() => _currentPalette = sortedPage, details: 'Updated existing page $pageIndex');
            _markPaletteUpdated();
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
      final needsPaletteUpdate =
          pageIndex == _visiblePage && !_paletteUpdatedThisFrame && !_palettesEqual(_currentPalette, newPage);
      int? callbackId;
      if (needsPaletteUpdate) {
        callbackId = ++_nextPaletteCallbackId;
        _activePaletteCallbacks.add(callbackId);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (callbackId != null && !_activePaletteCallbacks.remove(callbackId)) return;
        if (!mounted) return;
        _safeSetState(() {
          if (pageIndex == _pages.length) {
            _pages.add(newPage);
          } else if (pageIndex < _pages.length) {
            _pages[pageIndex] = newPage;
          }
          if (needsPaletteUpdate) {
            _currentPalette = List<Paint>.from(newPage);
            _markPaletteUpdated();
          }
        }, details: 'Generated and added page $pageIndex');
      });
      
      // Reset generation attempts on success
      _pageGenerationAttempts.remove(pageIndex);
      

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
      _markPaletteUpdated();
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
    _markPaletteUpdated();
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
                            ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                    color: Colors.black.withValues(alpha: 0.08),
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
                  color: Colors.black.withValues(alpha: 0.05),
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

