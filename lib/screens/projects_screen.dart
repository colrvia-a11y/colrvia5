import 'package:flutter/material.dart';
// Add a prefixed import for core widgets to avoid any local shadowing
import 'package:flutter/material.dart' as m
    show Text, Column, SizedBox, Container, Positioned;
import 'package:logging/logging.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/services/project_service.dart';
import 'package:color_canvas/models/project.dart';
import 'package:color_canvas/screens/palette_detail_screen.dart';
import 'package:color_canvas/screens/roller_screen.dart';
import 'package:color_canvas/screens/search_screen.dart';
import 'package:color_canvas/screens/explore_screen.dart';
import 'color_plan_screen.dart';
import 'package:color_canvas/screens/visualizer_screen.dart';
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/main.dart' show isFirebaseInitialized;

enum LibraryFilter { all, palettes, stories }

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key, this.initialFilter = LibraryFilter.all});
  final LibraryFilter initialFilter;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  static final _logger = Logger('ProjectsScreen');
  
  bool _isLoading = true;
  bool _hasPermissionError = false;
  late LibraryFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _loadData();
  }

  Future<void> _loadData() async {
    if (!isFirebaseInitialized) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: m.Text(
                'Firebase not configured. Items may not sync across devices.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    final user = FirebaseService.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final firebaseStatus = await FirebaseService.getFirebaseStatus();
      _logger.info('Firebase Status in library: $firebaseStatus');
      _logger.info('User ID: ${user.uid}, Email: ${user.email}');
      List<UserPalette> palettes = [];
      List<Paint> savedColors = [];
      List<ProjectDoc> colorStories = [];
      try {
        palettes = await FirebaseService.getUserPalettes(user.uid);
        _logger.info('Successfully loaded ${palettes.length} palettes');
      } catch (paletteError) {
        _logger.warning('Error loading palettes: $paletteError');
        if (paletteError.toString().contains('permission-denied')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: m.Text(
                    'Access denied. Please check your account permissions.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
      try {
        savedColors = await FirebaseService.getUserFavoriteColors(user.uid);
        _logger.info('Successfully loaded ${savedColors.length} favorite colors');
      } catch (colorsError) {
        _logger.warning('Error loading favorite colors: $colorsError');
        if (colorsError.toString().contains('permission-denied')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: m.Text(
                    'Access denied for saved colors. Please try signing out and back in.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
      try {
        final allProjects =
            await ProjectService.myProjectsStream(limit: 50).first;
        colorStories =
            allProjects.where((p) => p.colorStoryId != null).toList();
        _logger.info('Successfully loaded ${colorStories.length} color stories');
      } catch (storiesError) {
        _logger.warning('Error loading color stories: $storiesError');
      }
      setState(() {
        _isLoading = false;
        _hasPermissionError =
            palettes.isEmpty && savedColors.isEmpty && colorStories.isEmpty;
      });
    } catch (e) {
      _logger.severe('General error loading library data: $e');
      setState(() => _isLoading = false);
      if (e.toString().contains('permission-denied')) {
        if (mounted) {
          _showPermissionDeniedDialog();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: m.Text(
                  'Error loading data: ${e.toString().split(':').first}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildFilterChips(BuildContext context) {
    Chip chip(LibraryFilter f, String label) => Chip(
          label: m.Text(label),
          backgroundColor: _filter == f
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.6),
        );
    return Wrap(spacing: 8, children: [
      InkWell(
          onTap: () => setState(() => _filter = LibraryFilter.all),
          child: chip(LibraryFilter.all, 'All')),
      InkWell(
          onTap: () => setState(() => _filter = LibraryFilter.palettes),
          child: chip(LibraryFilter.palettes, 'Palettes')),
      InkWell(
          onTap: () => setState(() => _filter = LibraryFilter.stories),
          child: chip(LibraryFilter.stories, 'Color Stories')),
    ]);
  }

  Widget _buildFilteredContent() {
    final showPalettes =
        _filter == LibraryFilter.all || _filter == LibraryFilter.palettes;
    final showStories =
        _filter == LibraryFilter.all || _filter == LibraryFilter.stories;
    final projectsStream = ProjectService.myProjectsStream();
    final children = <Widget>[];
    if (showStories) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: m.Text('Color Stories',
            style: Theme.of(context).textTheme.titleLarge),
      ));
      children.add(StreamBuilder<List<ProjectDoc>>(
        stream: projectsStream,
        builder: (context, snap) {
          final list = (snap.data ?? <ProjectDoc>[])
              .where(
                  (p) => p.colorStoryId != null && p.colorStoryId!.isNotEmpty)
              .toList();
          if (list.isEmpty) {
            return const m.SizedBox.shrink();
          }
          return m.Column(
            children: list.map((project) => _ProjectCard(project)).toList(),
          );
        },
      ));
    }
    if (showPalettes) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child:
            m.Text('Palettes', style: Theme.of(context).textTheme.titleLarge),
      ));
      children.add(_PalettesSection());
    }
    if (children.isEmpty) {
      return const SliverToBoxAdapter(child: m.SizedBox.shrink());
    }
    return SliverList(
      delegate: SliverChildListDelegate(children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseService.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const m.Text('My Library')),
        body: const Center(
          child: m.Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_circle, size: 64, color: Colors.grey),
              m.SizedBox(height: 16),
              m.Text('Please sign in to view your palettes'),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const m.Text('My Library'),
        actions: [
          if (_hasPermissionError)
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: m.Text(
                        'Some data may not be available due to permission issues. Try signing out and back in.'),
                    duration: Duration(seconds: 4),
                  ),
                );
              },
              icon: const Icon(Icons.warning_amber_outlined,
                  color: Colors.orange),
              tooltip: 'Permission Issues',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                      child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _buildFilterChips(context),
                  )),
                  _buildFilteredContent(),
                ],
              ),
            ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: Colors.orange),
            m.SizedBox(width: 8),
            m.Text('Access Denied'),
          ],
        ),
        content: const m.Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            m.Text(
              'Your account doesn\'t have permission to access saved palettes and colors.',
            ),
            m.SizedBox(height: 12),
            m.Text(
              'This might be because:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            m.Text('• You need to verify your email address'),
            m.Text('• Your account is still being set up'),
            m.Text('• There\'s a temporary server issue'),
            m.SizedBox(height: 12),
            m.Text(
              'Try signing out and signing back in, or contact support if the issue persists.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pop();
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/home', (route) => false);
            },
            child: const m.Text('Go to Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const m.Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Project Card for the new filter system
class _ProjectCard extends StatelessWidget {
  const _ProjectCard(this.project);
  final ProjectDoc project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = {
      FunnelStage.build: 'Building',
      FunnelStage.story: 'Story drafted',
      FunnelStage.visualize: 'Visualizer ready',
      FunnelStage.share: 'Shared',
    }[project.funnelStage]!;

    final chips = <Widget>[];
    if ((project.roomType ?? '').isNotEmpty) {
      chips.add(Chip(
          label: m.Text(project.roomType!),
          visualDensity: VisualDensity.compact));
    }
    if ((project.styleTag ?? '').isNotEmpty) {
      chips.add(Chip(
          label: m.Text(project.styleTag!),
          visualDensity: VisualDensity.compact));
    }

    return m.Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: m.Text(project.title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        subtitle:
            m.Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          m.Text(status),
          const m.SizedBox(height: 4),
          if (chips.isNotEmpty)
            Wrap(spacing: 6, runSpacing: -6, children: chips),
          const m.SizedBox(height: 4),
          m.Text('Updated ${_timeAgo(project.updatedAt)}',
              style: theme.textTheme.bodySmall),
        ]),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openStage(context, project),
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  static void _openStage(BuildContext context, ProjectDoc project) {
    switch (project.funnelStage) {
      case FunnelStage.build:
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RollerScreen(projectId: project.id)));
        break;
      case FunnelStage.story:
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ColorPlanScreen(projectId: project.id)));
        break;
      case FunnelStage.visualize:
      case FunnelStage.share:
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => VisualizerScreen()));
        break;
    }
  }
}

// Palettes Section for the new filter system
class _PalettesSection extends StatelessWidget {
  const _PalettesSection();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseService.currentUser;
    if (user == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: m.Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_circle, size: 64, color: Colors.grey),
              m.SizedBox(height: 16),
              m.Text('Please sign in to view your palettes'),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<List<UserPalette>>(
      future: FirebaseService.getUserPalettes(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final palettes = snapshot.data ?? [];
        if (palettes.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: m.Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.palette_outlined, size: 64, color: Colors.grey),
                  m.SizedBox(height: 16),
                  m.Text('No palettes yet'),
                  m.SizedBox(height: 8),
                  m.Text(
                      'Save color combinations from the Roller to see them here.'),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: palettes.length,
          itemBuilder: (context, index) {
            final palette = palettes[index];
            return EnhancedPaletteCard(
              palette: palette,
              onTap: () => _openPaletteDetail(context, palette),
              onDelete: () => _deletePalette(context, palette),
              onEdit: () => _editPaletteTags(context, palette),
              onOpenInRoller: () => _openPaletteInRoller(context, palette),
            );
          },
        );
      },
    );
  }

  void _openPaletteDetail(BuildContext context, UserPalette palette) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaletteDetailScreen(palette: palette),
      ),
    );
  }

  void _openPaletteInRoller(BuildContext context, UserPalette palette) {
    Navigator.of(context)
        .popUntil((route) => route.settings.name == '/' || route.isFirst);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RollerScreen(seedPaletteId: palette.id),
      ),
    );
  }

  Future<void> _deletePalette(BuildContext context, UserPalette palette) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const m.Text('Delete Palette'),
        content: m.Text('Are you sure you want to delete "${palette.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const m.Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const m.Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseService.deletePalette(palette.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: m.Text('Palette deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: m.Text('Error deleting palette: $e')),
          );
        }
      }
    }
  }

  Future<void> _editPaletteTags(
      BuildContext context, UserPalette palette) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => EditTagsDialog(
        initialTags: palette.tags,
        availableTags: [],
      ),
    );

    if (result != null) {
      try {
        final updatedPalette = palette.copyWith(
          tags: result,
          updatedAt: DateTime.now(),
        );
        await FirebaseService.updatePalette(updatedPalette);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: m.Text('Error updating tags: $e')),
          );
        }
      }
    }
  }
}

class EnhancedPaletteCard extends StatelessWidget {
  final UserPalette palette;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onOpenInRoller;

  const EnhancedPaletteCard({
    super.key,
    required this.palette,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
    required this.onOpenInRoller,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: m.Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Large color preview (top half)
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Row(
                  children: palette.colors.map((paletteColor) {
                    final color = ColorUtils.hexToColor(paletteColor.hex);

                    return Expanded(
                      child: m.Container(
                        height: double.infinity,
                        color: color,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Content section (bottom half) - Made more flexible
            Flexible(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: m.Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title and menu
                    Row(
                      children: [
                        Expanded(
                          child: m.Text(
                            palette.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          onSelected: (value) {
                            switch (value) {
                              case 'roller':
                                onOpenInRoller();
                                break;
                              case 'edit':
                                onEdit();
                                break;
                              case 'delete':
                                onDelete();
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'roller',
                              child: Row(
                                children: [
                                  Icon(Icons.casino, size: 16),
                                  m.SizedBox(width: 8),
                                  m.Text('Open in Roller'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 16),
                                  m.SizedBox(width: 8),
                                  m.Text('Edit Tags'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      size: 16, color: Colors.red),
                                  m.SizedBox(width: 8),
                                  m.Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const m.SizedBox(height: 4),

                    // Metadata
                    m.Text(
                      '${palette.colors.length} colors • ${_formatDate(palette.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),

                    if (palette.tags.isNotEmpty) ...[
                      const m.SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: palette.tags
                            .take(2)
                            .map((tag) => m.Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: m.Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // No longer needed - using stored color info directly

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inMinutes}m ago';
    }
  }
}

class SavedColorCard extends StatelessWidget {
  final Paint paint;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const SavedColorCard({
    super.key,
    required this.paint,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.getPaintColor(paint.hex);
    final isLight = color.computeLuminance() > 0.5;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: m.Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Color swatch
            Expanded(
              flex: 3,
              child: m.Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Stack(
                  children: [
                    m.Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onRemove,
                        child: m.Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: isLight ? Colors.black87 : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Paint info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: m.Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    m.Text(
                      paint.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    m.Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        m.Text(
                          paint.brandName,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                    fontSize: 10,
                                  ),
                        ),
                        m.Text(
                          paint.code,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[500],
                                    fontSize: 9,
                                    fontFamily: 'monospace',
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditTagsDialog extends StatefulWidget {
  final List<String> initialTags;
  final List<String> availableTags;

  const EditTagsDialog({
    super.key,
    required this.initialTags,
    required this.availableTags,
  });

  @override
  State<EditTagsDialog> createState() => _EditTagsDialogState();
}

class _EditTagsDialogState extends State<EditTagsDialog> {
  late List<String> _selectedTags;
  final _customTagController = TextEditingController();

  // Common tag suggestions
  final List<String> _commonTags = [
    'living room',
    'bedroom',
    'kitchen',
    'bathroom',
    'office',
    'neutral',
    'warm',
    'cool',
    'bold',
    'modern',
    'traditional',
    'cozy',
    'bright',
    'dark'
  ];

  @override
  void initState() {
    super.initState();
    _selectedTags = List.from(widget.initialTags);
  }

  @override
  void dispose() {
    _customTagController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _addCustomTag() {
    final tag = _customTagController.text.trim().toLowerCase();
    if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
        _customTagController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestedTags = {..._commonTags, ...widget.availableTags}
        .where((tag) => !_selectedTags.contains(tag))
        .toList()
      ..sort();

    return AlertDialog(
      title: const m.Text('Edit Tags'),
      content: SingleChildScrollView(
        child: m.Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected tags
            if (_selectedTags.isNotEmpty) ...[
              const m.Text('Selected Tags:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const m.SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _selectedTags
                    .map((tag) => Chip(
                          label: m.Text(tag),
                          onDeleted: () => _toggleTag(tag),
                          deleteIcon: const Icon(Icons.close, size: 16),
                        ))
                    .toList(),
              ),
              const m.SizedBox(height: 16),
            ],

            // Add custom tag
            const m.Text('Add Custom Tag:',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const m.SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customTagController,
                    decoration: const InputDecoration(
                      hintText: 'Enter tag name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addCustomTag(),
                  ),
                ),
                const m.SizedBox(width: 8),
                IconButton(
                  onPressed: _addCustomTag,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),

            const m.SizedBox(height: 16),

            // Suggested tags
            const m.Text('Suggested Tags:',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const m.SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: suggestedTags
                  .map((tag) => FilterChip(
                        label: m.Text(tag),
                        onSelected: (_) => _toggleTag(tag),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const m.Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedTags),
          child: const m.Text('Save'),
        ),
      ],
    );
  }
}

class ColorDetailDialog extends StatelessWidget {
  final Paint paint;

  const ColorDetailDialog({
    super.key,
    required this.paint,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.getPaintColor(paint.hex);

    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: m.Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Large color swatch
          m.Container(
            height: 200,
            width: double.infinity,
            color: color,
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: m.Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                m.Text(
                  paint.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const m.SizedBox(height: 8),
                _buildDetailRow('Brand', paint.brandName),
                _buildDetailRow('Code', paint.code),
                _buildDetailRow('Hex', paint.hex),
                const m.SizedBox(height: 16),
                m.SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const m.Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          m.SizedBox(
            width: 60,
            child: m.Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: m.Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wrapper to handle opening roller with initial colors while preserving bottom navigation
class _RollerWithInitialColorsWrapper extends StatefulWidget {
  final List<String> initialPaintIds;

  const _RollerWithInitialColorsWrapper({
    required this.initialPaintIds,
  });

  @override
  State<_RollerWithInitialColorsWrapper> createState() =>
      _RollerWithInitialColorsWrapperState();
}

class _RollerWithInitialColorsWrapperState
    extends State<_RollerWithInitialColorsWrapper> {
  @override
  void initState() {
    super.initState();
    // Navigate to home screen immediately after this widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _HomeScreenWithRollerInitialColors(
            initialPaintIds: widget.initialPaintIds,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Modified HomeScreen that starts with roller tab and initial colors
class _HomeScreenWithRollerInitialColors extends StatefulWidget {
  final List<String> initialPaintIds;

  const _HomeScreenWithRollerInitialColors({
    required this.initialPaintIds,
  });

  @override
  State<_HomeScreenWithRollerInitialColors> createState() =>
      _HomeScreenWithRollerInitialColorsState();
}

class _HomeScreenWithRollerInitialColorsState
    extends State<_HomeScreenWithRollerInitialColors> {
  int _currentIndex = 0; // Start with roller tab
  late final List<Widget> _screens = [
    RollerScreen(initialPaintIds: widget.initialPaintIds),
    const SearchScreen(),
    const ExploreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Show success message after navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: m.Text('Opened palette in Roller!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.palette),
            label: 'Generate',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
        ],
      ),
    );
  }
}
