// VISUALIZER 2030 — LUXE UI
// Full-bleed preview, frosted control dock, filmstrip variants, compare modes.
// Depends on: photo_view, image_picker, firebase_core/auth/storage, your VisualizerService.

import 'dart:ui' show ImageFilter;
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:http/http.dart' as http;

import '../services/visualizer_service.dart';
import '../firestore/firestore_data_schema.dart'; // for UserPalette
import '../services/analytics_service.dart';
import '../models/color_story.dart';
import '../data/sample_rooms.dart';
import '../widgets/via_overlay.dart';
import 'color_plan_screen.dart';
import '../models/lighting_profile.dart';
import '../services/lighting_service.dart';
import 'photo_import_sheet.dart';
import '../models/visualizer_mask.dart';
// REGION: CODEX-ADD user-prefs-import
import '../services/user_prefs_service.dart';
// END REGION: CODEX-ADD user-prefs-import
// REGION: CODEX-ADD permissions-import
import '../services/permissions_service.dart';
import 'package:permission_handler/permission_handler.dart';
// END REGION: CODEX-ADD permissions-import
import '../services/accessibility_service.dart';

enum CompareMode { none, grid, split, slider }

class VisualizerScreen extends StatefulWidget {
  final String? projectId;
  final String? storyId;
  final String? assignmentsParam; // URL-safe JSON string
  final Map<String, String>? initialAssignments;
  final List<ColorUsageItem>? initialGuide;
  final UserPalette? initialPalette;
  
  const VisualizerScreen({
    super.key, 
    this.projectId,
    this.storyId,
    this.assignmentsParam,
    this.initialAssignments, 
    this.initialGuide,
    this.initialPalette,
  });

  @override
  State<VisualizerScreen> createState() => _VisualizerScreenState();
}

class _VisualizerScreenState extends State<VisualizerScreen>
    with TickerProviderStateMixin {
  final _picker = ImagePicker();

  // Source
  String _mode = 'photo'; // 'photo' or 'mockup'
  Uint8List? _inputBytes; // local preview for uploaded photo

  // Apply
  String _roomType = 'living room';
  String _style = 'modern minimal';
  final List<String> _surfaces = ['walls']; // can include cabinets/trim/etc
  final List<String> _variants = []; // active palette hexes
  final List<String> _paletteA = [];
  final List<String> _paletteB = [];
  int _activePalette = 0;

  final VisualizerService _viz = VisualizerService();
  StreamSubscription<VisualizerJob>? _jobSub;
  String? _previewUrl;
  String? _hqStatus;

  LightingProfile _lightingProfile = LightingProfile.mixed;

  // Masking
  bool _showMaskTools = false;
  bool _eraseMode = false;
  double _brushSize = 24;
  final List<VisualizerMask> _masks = [];
  final List<VisualizerMask> _undoStack = [];
  final List<VisualizerMask> _redoStack = [];

  // Output
  bool _busy = false;
  List<Map<String, dynamic>> _results = []; // {hex, downloadUrl, filePath}
  int _selectedA = 0;
  int _selectedB = 0;
  CompareMode _compare = CompareMode.none;

  @override
  void initState() {
    super.initState();

    AccessibilityService.instance
        .addListener(() => mounted ? setState(() {}) : null);
    AccessibilityService.instance.load();
    
    // Track visualizer screen view
    AnalyticsService.instance.screenView('visualizer');

    // Track funnel analytics if opened with projectId
    if (widget.projectId != null) {
      AnalyticsService.instance.logVisualizerOpenedFromStory(widget.projectId!);
      UserPrefsService.setLastProject(widget.projectId!, 'visualizer');
    }

    if (widget.projectId != null) {
      LightingService().getProfile(widget.projectId!).then((p) {
        if (mounted) {
          setState(() => _lightingProfile = p);
        }
      });
    }
    
    // Seed from palette if present
    if (widget.initialPalette != null) {
      _variants.addAll(
        widget.initialPalette!.colors.map((c) => c.hex),
      );
      while (_variants.length > 5) _variants.removeLast();
    } else {
      // Extract colors from initialGuide if available
      if (widget.initialGuide != null) {
        _variants.addAll(widget.initialGuide!.map((item) => item.hex).where((hex) => hex.isNotEmpty));
        while (_variants.length > 5) { _variants.removeLast(); }
      }
      
      // Add sensible defaults if still empty
      if (_variants.isEmpty) {
        _variants.addAll(['#F5F5F5', '#EAEAEA', '#CCCCCC']);
      }
    }

    _paletteA.addAll(_variants);
    _paletteB.addAll(_variants);
  }

  @override
  void dispose() {
    _jobSub?.cancel();
    super.dispose();
  }

  // ─────────────────────────── Actions
  Future<void> _pickImage() async {
    final granted = await PermissionsService.confirmAndRequest(
      context,
      Permission.photos,
    );
    if (!granted) return;
    final file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _inputBytes = bytes;
      _previewUrl = null;
      _results = [];
    });
    if (widget.projectId != null) {
      final selected = await showLightingProfilePicker(
        context,
        current: _lightingProfile,
      );
      if (selected != null) {
        setState(() => _lightingProfile = selected);
        await LightingService().setProfile(widget.projectId!, selected);
        AnalyticsService.instance.lightingProfileSelected(selected.name);
      }
    }
  }

  Future<void> _loadSample(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      setState(() {
        _inputBytes = response.bodyBytes;
        _previewUrl = null;
        _results = [];
      });
    }
  }

  void _switchPalette(int index) {
    setState(() {
      if (_activePalette == 0) {
        _paletteA
          ..clear()
          ..addAll(_variants);
      } else {
        _paletteB
          ..clear()
          ..addAll(_variants);
      }
      _activePalette = index;
      _variants
        ..clear()
        ..addAll(index == 0 ? _paletteA : _paletteB);
    });
  }

  Future<void> _renderFast() async {
    if (_variants.isEmpty) {
      _toast('Add one or more HEX colors.');
      return;
    }
    if (_inputBytes == null) {
      _toast('Upload or pick a photo.');
      return;
    }
    AnalyticsService.instance.renderFastRequested();
    final job = await _viz.renderFast('sample', _variants,
        lightingProfile: _lightingProfile.name);
    setState(() {
      _previewUrl = job.previewUrl;
      _results = [
        {'hex': _variants.isNotEmpty ? _variants.first : '#000000', 'downloadUrl': job.previewUrl}
      ];
      _selectedA = 0;
      _selectedB = 0;
    });
  }

  Future<void> _renderHq() async {
    if (_variants.isEmpty) {
      _toast('Add one or more HEX colors.');
      return;
    }
    if (_inputBytes == null) {
      _toast('Upload or pick a photo.');
      return;
    }
    AnalyticsService.instance.renderHqRequested();
    final start = DateTime.now();
    final job = await _viz.renderHq('sample', _variants,
        lightingProfile: _lightingProfile.name);
    setState(() {
      _hqStatus = job.status;
    });
    _jobSub?.cancel();
    _jobSub = _viz.watchJob(job.jobId).listen((j) {
      setState(() {
        _hqStatus = j.status;
        if (j.resultUrl != null) {
          _previewUrl = j.resultUrl;
          if (_results.isNotEmpty) {
            _results[0]['downloadUrl'] = j.resultUrl;
          } else {
            _results = [
              {'hex': _variants.isNotEmpty ? _variants.first : '#000000', 'downloadUrl': j.resultUrl}
            ];
          }
        }
      });
      if (j.status == 'complete') {
        final ms = DateTime.now().difference(start).inMilliseconds;
        AnalyticsService.instance.renderHqCompleted(ms);
        _jobSub?.cancel();
      }
    });
  }

  Future<void> _runGeneration() async {
    if (_busy) return;
    if (_variants.isEmpty) {
      _toast('Add one or more HEX colors.');
      return;
    }
    if (_mode == 'photo' && _inputBytes == null) {
      _toast('Upload a photo or switch to mockup.');
      return;
    }

    setState(() {
      _busy = true;
      _results = [];
      _compare = CompareMode.none;
    });

    try {
      List<Map<String, dynamic>> out;
      if (_mode == 'photo') {
        // NOTE: replace 'me' with actual auth uid if you have it available here.
        final uid = 'me';
        final gs = await VisualizerService.uploadInputBytes(
            uid, 'input.png', _inputBytes!);

        out = await VisualizerService.generateFromPhoto(
          inputGsPath: gs,
          roomType: _roomType,
          surfaces: _surfaces,
          variants: _variants.length,
          storyId: widget.storyId,
          lightingProfile: _lightingProfile.name,
        );
      } else {
        out = await VisualizerService.generateMockup(
          roomType: _roomType,
          style: _style,
          variants: _variants.length,
          lightingProfile: _lightingProfile.name,
        );
      }

      setState(() {
        _results = out;
        _selectedA = 0;
        _selectedB = out.length > 1 ? 1 : 0;
      });
      _toast('Your visualizations are ready.');
    } catch (e) {
      _toast('Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ─────────────────────────── UI
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('AI Visualizer'),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFAFAFA), Color(0xFFF0F3F7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Full-bleed preview canvas
          Positioned.fill(
            child: _buildPreviewCanvas(theme),
          ),

          Positioned(
            top: 12,
            left: 12,
            child: IconButton(
              icon: Icon(_showMaskTools ? Icons.close : Icons.brush),
              tooltip:
                  _showMaskTools ? 'Close mask tools' : 'Open mask tools',
              constraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: () =>
                  setState(() => _showMaskTools = !_showMaskTools),
            ),
          ),
          Positioned(
            top: 56,
            left: 12,
            right: 12,
            child: _buildMaskingToolbar(),
          ),

          // Frosted control dock (Draggable bottom sheet feel)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _Frosted(
                child: _ControlDock(
                  busy: _busy,
                  mode: _mode,
                  onModeChanged: (m) => setState(() => _mode = m),
                  onUploadPhoto: _pickImage,
                  hasPhoto: _inputBytes != null,
                  roomType: _roomType,
                  onRoomTypeChanged: (v) => setState(() => _roomType = v),
                  style: _style,
                  onStyleChanged:
                      _mode == 'mockup' ? (v) => setState(() => _style = v) : null,
                  surfaces: _surfaces,
                  onToggleSurface: (s) {
                    setState(() {
                      if (_surfaces.contains(s)) {
                        _surfaces.remove(s);
                      } else {
                        _surfaces.add(s);
                      }
                      if (_surfaces.isEmpty) _surfaces.add('walls');
                    });
                  },
                  variants: _variants,
                  onVariantsChanged: (list) {
                    setState(() {
                      _variants
                        ..clear()
                        ..addAll(list.take(5));
                      if (_activePalette == 0) {
                        _paletteA
                          ..clear()
                          ..addAll(_variants);
                      } else {
                        _paletteB
                          ..clear()
                          ..addAll(_variants);
                      }
                    });
                  },
                  paletteIndex: _activePalette,
                  onPaletteChanged: _switchPalette,
                  onFast: _renderFast,
                  onHq: _renderHq,
                  onGenerate: _runGeneration,
                ),
              ),
            ),
          ),

          if (_hqStatus != null && _hqStatus != 'complete')
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _Frosted(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(_hqStatus!),
                    ],
                  ),
                ),
              ),
            ),

          // Lighting profile quick control
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: _Frosted(
              child: InkWell(
                onTap: widget.projectId == null
                    ? null
                    : () async {
                        final selected = await showLightingProfilePicker(
                          context,
                          current: _lightingProfile,
                        );
                        if (selected != null && widget.projectId != null) {
                          setState(() => _lightingProfile = selected);
                          await LightingService()
                              .setProfile(widget.projectId!, selected);
                        }
                      },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text('Light: ${_lightingProfile.label}'),
                ),
              ),
            ),
          ),

          // Busy overlay
          if (_busy)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(red: 0, green: 0, blue: 0, alpha: 0.08),
                child: const Center(
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: CircularProgressIndicator(strokeWidth: 4),
                ),
              ),
            ),
          ),
          ViaOverlay(
            contextLabel: 'visualizer',
            onMakePlan: widget.projectId == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ColorPlanScreen(
                          projectId: widget.projectId!,
                          paletteColorIds: const [],
                        ),
                      ),
                    );
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCanvas(ThemeData theme) {
    // States:
    // - No results yet: show source/mockup hint + photo preview if uploaded
    // - Results: show compare modes (none/grid/split/slider)
    final hasResults = _results.isNotEmpty;

    return AnimatedSwitcher(
      duration: Duration(
          milliseconds:
              AccessibilityService.instance.reduceMotion ? 0 : 280),
      child: hasResults
          ? _buildResults()
          : _buildSourcePreview(theme),
    );
  }

  // REGION: CODEX-ADD viz-masking-toolbar
  Widget _buildMaskingToolbar() {
    if (!_showMaskTools) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_eraseMode ? Icons.crop_square : Icons.brush),
            tooltip: _eraseMode ? 'Draw mask' : 'Erase mask',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => setState(() => _eraseMode = !_eraseMode),
          ),
          Slider(
            value: _brushSize,
            min: 4,
            max: 100,
            onChanged: (v) => setState(() => _brushSize = v),
            divisions: 19,
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo mask',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: _undoStack.isEmpty
                ? null
                : () {
                    final last = _undoStack.removeLast();
                    _redoStack.add(last);
                    _masks.remove(last);
                    AnalyticsService.instance.logEvent('mask_undo');
                    setState(() {});
                  },
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: 'Redo mask',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: _redoStack.isEmpty
                ? null
                : () {
                    final mask = _redoStack.removeLast();
                    _masks.add(mask);
                    _undoStack.add(mask);
                    AnalyticsService.instance.logEvent('mask_redo');
                    setState(() {});
                  },
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Mask assist',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: _onMaskAssist,
          ),
        ],
      ),
    );
  }
  // END REGION: CODEX-ADD viz-masking-toolbar

  Future<void> _onMaskAssist() async {
    if (_previewUrl == null) return;
    AnalyticsService.instance
        .logEvent('mask_assist_requested', {'image': _previewUrl});
    final polygons = await _viz.maskAssist(_previewUrl!);
    polygons.forEach((surface, polys) {
      final mask = VisualizerMask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        surface: surface,
        polygons: polys,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _masks.add(mask);
      _undoStack.add(mask);
      AnalyticsService.instance
          .logEvent('mask_created', {'surface': surface, 'points': polys.length});
      // TODO: integrate real user/project/photo IDs
      if (widget.projectId != null) {
        _viz.saveMask('user', widget.projectId!, 'photo', mask);
      }
    });
    setState(() {});
    AnalyticsService.instance.logEvent(
        'mask_assist_applied', {'polygons': polygons.length});
  }

  Widget _buildSourcePreview(ThemeData theme) {
    return Stack(
      children: [
        // gradient backdrop for polish
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEFF1F5), Color(0xFFF7F7F7)],
              ),
            ),
          ),
        ),
        if (_inputBytes != null)
          Positioned.fill(
            child: PhotoView(
              backgroundDecoration: const BoxDecoration(color: Colors.transparent),
              imageProvider: MemoryImage(_inputBytes!),
              minScale: PhotoViewComputedScale.contained,
              heroAttributes: const PhotoViewHeroAttributes(tag: 'input'),
            ),
          ),
        if (_inputBytes == null)
          GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: SampleRooms.images.length,
            itemBuilder: (_, i) {
              final url = SampleRooms.images[i];
              return GestureDetector(
                onTap: () => _loadSample(url),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(url, fit: BoxFit.cover),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildResults() {
    final base = switch (_compare) {
      CompareMode.grid   => _ResultsGrid(results: _results),
      CompareMode.split  => _SplitCompare(
        aUrl: _results[_selectedA]['downloadUrl'],
        bUrl: _results[_selectedB]['downloadUrl'],
      ),
      CompareMode.slider => _BeforeAfter(
        beforeUrl: _results[_selectedA]['downloadUrl'],
        afterUrl: _results[_selectedB]['downloadUrl'],
      ),
      _ => _SinglePreview(url: _results[_selectedA]['downloadUrl']),
    };

    return Stack(
      children: [
        Positioned.fill(child: base),
        VariantToolbar(
          results: _results,
          selectedA: _selectedA,
          selectedB: _selectedB,
          onSelectA: (i) => setState(() => _selectedA = i),
          onSelectB: (i) => setState(() => _selectedB = i),
          compareMode: _compare,
          onModeChanged: (m) => setState(() => _compare = m),
        ),
      ],
    );
  }
}

// ─────────────────────────── Frosted Glass Container
class _Frosted extends StatelessWidget {
  final Widget child;
  const _Frosted({required this.child});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────── Control Dock (bottom)
class _ControlDock extends StatelessWidget {
  final bool busy;

  final String mode;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onUploadPhoto;
  final bool hasPhoto;

  final String roomType;
  final ValueChanged<String> onRoomTypeChanged;

  final String style;
  final ValueChanged<String>? onStyleChanged;

  final List<String> surfaces;
  final ValueChanged<String> onToggleSurface;

  final List<String> variants;
  final ValueChanged<List<String>> onVariantsChanged;
  final int paletteIndex;
  final ValueChanged<int> onPaletteChanged;
  final VoidCallback onFast;
  final VoidCallback onHq;
  final VoidCallback onGenerate;

  const _ControlDock({
    required this.busy,
    required this.mode,
    required this.onModeChanged,
    required this.onUploadPhoto,
    required this.hasPhoto,
    required this.roomType,
    required this.onRoomTypeChanged,
    required this.style,
    required this.onStyleChanged,
    required this.surfaces,
    required this.onToggleSurface,
    required this.variants,
    required this.onVariantsChanged,
    required this.paletteIndex,
    required this.onPaletteChanged,
    required this.onFast,
    required this.onHq,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final canGenerate = !busy && variants.isNotEmpty && (mode == 'mockup' || hasPhoto);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mode switch + Upload
        Row(
          children: [
            _Segmented(
              options: const ['Use my photo', 'Generate mockup'],
              selectedIndex: mode == 'photo' ? 0 : 1,
              onChanged: (i) => onModeChanged(i == 0 ? 'photo' : 'mockup'),
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: Duration(
                  milliseconds:
                      AccessibilityService.instance.reduceMotion ? 0 : 200),
              child: mode == 'photo'
                  ? TextButton.icon(
                      key: const ValueKey('upload_button'),
                      onPressed: busy ? null : onUploadPhoto,
                      icon: const Icon(Icons.upload_rounded),
                      label: Text(hasPhoto ? 'Change photo' : 'Upload photo'),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Room / Style
        Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Dropdown(
              label: 'Room',
              value: roomType,
              items: const ['living room', 'kitchen', 'bathroom', 'bedroom', 'exterior'],
              onChanged: (v) => onRoomTypeChanged(v!),
            ),
            AnimatedSwitcher(
              duration: Duration(
                  milliseconds:
                      AccessibilityService.instance.reduceMotion ? 0 : 200),
              child: onStyleChanged != null
                  ? _Dropdown(
                      key: const ValueKey('style_dropdown'),
                      label: 'Style',
                      value: style,
                      items: const ['modern minimal','transitional','contemporary','farmhouse','midcentury'],
                      onChanged: (v) => onStyleChanged!(v!),
                    )
                  : const SizedBox.shrink(key: ValueKey('no_style')),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Palette A/B
        Row(
          children: [
            const Text('Palette'),
            const SizedBox(width: 8),
            _Segmented(
              options: const ['A', 'B'],
              selectedIndex: paletteIndex,
              onChanged: onPaletteChanged,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Surfaces + Variants
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SurfaceRow(
                selected: surfaces,
                onToggle: onToggleSurface,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HexEditor(
                initial: variants,
                onChanged: onVariantsChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Fast/HQ render buttons
        Row(
          children: [
            OutlinedButton(
              onPressed: busy ? null : onFast,
              child: const Text('Fast'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onHq,
              child: const Text('HQ'),
            ),
            const SizedBox(width: 12),
            const Text('HQ renders in background',
                style: TextStyle(color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 10),

        // Generate
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: canGenerate ? onGenerate : null,
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: Text(busy ? 'Rendering…' : 'Generate'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(140, 44)),
            ),
            const SizedBox(width: 12),
            const Text('Up to 5 variants per run for speed.',
                style: TextStyle(color: Colors.black54)),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────── Small UI pieces

class _Segmented extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  const _Segmented({
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedContainer(
                duration: Duration(
                    milliseconds: AccessibilityService.instance.reduceMotion
                        ? 0
                        : 200),
                child: ChoiceChip(
                  label: Text(options[i]),
                  selected: i == selectedIndex,
                  onSelected: (_) => onChanged(i),
                  selectedColor: Colors.white,
                  side: BorderSide(
                      color: i == selectedIndex
                          ? Colors.black.withValues(alpha: 0.12)
                          : Colors.transparent),
                ),
              ),
            )
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _Dropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label),
      const SizedBox(width: 8),
      DropdownButton<String>(
          value: value,
          items:
              items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged),
    ]);
  }
}

class _SurfaceRow extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<String> onToggle;
  const _SurfaceRow({required this.selected, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    final options = ['walls', 'cabinets', 'trim', 'door', 'shutters'];
    return Wrap(
      runSpacing: 6,
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Surfaces'),
        ...options.map((s) {
          final on = selected.contains(s);
          return FilterChip(
            label: Text(s),
            selected: on,
            onSelected: (_) => onToggle(s),
          );
        }),
      ],
    );
  }
}

class _HexEditor extends StatefulWidget {
  final List<String> initial;
  final ValueChanged<List<String>> onChanged;
  const _HexEditor({required this.initial, required this.onChanged});
  @override
  State<_HexEditor> createState() => _HexEditorState();
}

class _HexEditorState extends State<_HexEditor> {
  late List<TextEditingController> ctrls;

  @override
  void initState() {
    super.initState();
    final start = widget.initial.isEmpty
        ? ['#F5F5F5', '#EAEAEA', '#CCCCCC']
        : widget.initial;
    ctrls = start.take(5).map((h) => TextEditingController(text: h)).toList();
  }

  @override
  void dispose() {
    for (final c in ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _notify() =>
      widget.onChanged(ctrls.map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList());

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Variants'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < ctrls.length; i++)
              SizedBox(
                width: 118,
                child: TextField(
                  controller: ctrls[i],
                  decoration: const InputDecoration(
                    labelText: 'HEX',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _notify(),
                ),
              ),
            if (ctrls.length < 5)
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                onPressed: () {
                  setState(() => ctrls.add(TextEditingController(text: '#CCCCCC')));
                  _notify();
                },
              )
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────── Preview Modes

class _SinglePreview extends StatelessWidget {
  final String url;
  const _SinglePreview({required this.url});
  @override
  Widget build(BuildContext context) {
    return PhotoView(
      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
      imageProvider: NetworkImage(url),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 3.0,
    );
  }
}

class _ResultsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  const _ResultsGrid({required this.results});
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 160), // leave space for dock
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12),
      itemCount: results.length,
      itemBuilder: (_, i) {
        final r = results[i];
        return _ResultCard(hex: r['hex'], url: r['downloadUrl']);
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String hex;
  final String url;
  const _ResultCard({required this.hex, required this.url});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
      ),
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Stack(
        children: [
          Positioned.fill(child: Image.network(url, fit: BoxFit.cover)),
          Positioned(
            left: 8,
            bottom: 8,
            child: _HexPill(hex: hex),
          ),
        ],
      ),
    );
  }
}

class _HexPill extends StatelessWidget {
  final String hex;
  const _HexPill({required this.hex});
  @override
  Widget build(BuildContext context) {
    Color swatch;
    try {
      swatch = _parseHex(hex);
    } catch (_) {
      swatch = Colors.black;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16, 
            height: 16, 
            decoration: BoxDecoration(
              color: swatch, 
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.12), width: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(hex.toUpperCase(), style: const TextStyle(letterSpacing: 1.1, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

Color _parseHex(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

// ─────────────────────────── Split & Before/After

class _SplitCompare extends StatelessWidget {
  final String aUrl;
  final String bUrl;
  const _SplitCompare({required this.aUrl, required this.bUrl});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Image.network(aUrl, fit: BoxFit.cover)),
        const VerticalDivider(width: 1, color: Colors.black26),
        Expanded(child: Image.network(bUrl, fit: BoxFit.cover)),
      ],
    );
  }
}

class _BeforeAfter extends StatefulWidget {
  final String beforeUrl;
  final String afterUrl;
  const _BeforeAfter({required this.beforeUrl, required this.afterUrl});
  @override
  State<_BeforeAfter> createState() => _BeforeAfterState();
}

class _BeforeAfterState extends State<_BeforeAfter> {
  double _fraction = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth * _fraction;
      return GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            _fraction = (_fraction + d.delta.dx / c.maxWidth).clamp(0.0, 1.0);
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(widget.beforeUrl, fit: BoxFit.cover),
            ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: _fraction,
                child: Image.network(widget.afterUrl, fit: BoxFit.cover),
              ),
            ),
            Positioned(left: w - 12, top: 0, bottom: 0,
              child: Container(width: 2, color: Colors.white70)),
            Positioned(left: w - 24, top: 0, bottom: 0,
              child: Center(child: _dragHandle())),
          ],
        ),
      );
    });
  }

  Widget _dragHandle() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: const Icon(Icons.drag_indicator_rounded),
    );
  }
}

// ─────────────────────────── Variant Toolbar (Top Overlay)

class VariantToolbar extends StatefulWidget {
  final List<Map<String, dynamic>> results;
  final int selectedA;
  final int selectedB;
  final ValueChanged<int> onSelectA;
  final ValueChanged<int> onSelectB;
  final CompareMode compareMode;
  final ValueChanged<CompareMode> onModeChanged;

  const VariantToolbar({
    super.key,
    required this.results,
    required this.selectedA,
    required this.selectedB,
    required this.onSelectA,
    required this.onSelectB,
    required this.compareMode,
    required this.onModeChanged,
  });

  @override
  State<VariantToolbar> createState() => _VariantToolbarState();
}

class _VariantToolbarState extends State<VariantToolbar> {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _Frosted(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Compare mode
              Row(
                children: [
                  const Text('Compare'),
                  const SizedBox(width: 8),
                  _Segmented(
                    options: const ['Single', 'Grid', 'Split', 'Slider'],
                    selectedIndex: {
                      CompareMode.none: 0,
                      CompareMode.grid: 1,
                      CompareMode.split: 2,
                      CompareMode.slider: 3,
                    }[widget.compareMode]!,
                    onChanged: (i) {
                      widget.onModeChanged(
                        [CompareMode.none, CompareMode.grid, CompareMode.split, CompareMode.slider][i],
                      );
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Filmstrip
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.results.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final r = widget.results[i];
                    final url = r['downloadUrl'];
                    final hex = r['hex'] ?? '#000000';
                    final chosen = (i == widget.selectedA) || (i == widget.selectedB);
                    return AnimatedContainer(
                      duration: Duration(
                          milliseconds:
                              AccessibilityService.instance.reduceMotion
                                  ? 0
                                  : 200),
                      child: GestureDetector(
                        onTap: () => widget.onSelectA(i),
                        onLongPress: () => widget.onSelectB(i),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(url, width: 120, height: 80, fit: BoxFit.cover),
                              ),
                              Positioned(
                                left: 6,
                                bottom: 6,
                                child: _HexPill(hex: hex),
                              ),
                              if (chosen)
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.blue.shade600, width: 3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
