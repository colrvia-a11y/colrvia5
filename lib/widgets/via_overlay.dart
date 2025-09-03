// lib/widgets/via_overlay.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/via_service.dart';
import '../services/analytics_service.dart';
import '../services/journey/journey_service.dart';

/// Premium floating assistant overlay for "Via".
/// Overlay-only: access bubble lives in HomeScreen.
/// States: peek ↔ expanded (no collapsed bubble state).
class ViaOverlay extends StatefulWidget {
  final String contextLabel;
  final Map<String, dynamic> state;

  /// Optional: invoked when Via suggests making a plan.
  final VoidCallback? onMakePlan;

  /// Optional: invoked when Via suggests opening the visualizer.
  final VoidCallback? onVisualize;

  /// Optional: if you want to pass the user's display name directly.
  final String? userDisplayName;

  /// Optional: start in expanded state (defaults to peek).
  final bool startOpen;

  /// Optional: custom ask handler. Should return Via's reply text.
  final Future<String> Function(
    String message, {
    String? contextLabel,
    Map<String, dynamic>? state,
  })? onAsk;

  /// Visual skin for 2025 UI feels.
  final ViaSkin skin;

  const ViaOverlay({
    super.key,
    required this.contextLabel,
    this.state = const {},
    this.onMakePlan,
    this.onVisualize,
    this.userDisplayName,
    this.startOpen = false,
    this.onAsk,
    this.skin = ViaSkin.paper,
  });

  @override
  State<ViaOverlay> createState() => _ViaOverlayState();
}

enum ViaSkin { paper, ink, peach }

class _ViaTheme {
  final Color panel;           // Panel background
  final Color text;            // Primary text
  final Color assistantBg;     // Assistant bubble bg
  final Color assistantBorder; // Assistant bubble border
  final Color userBg;          // User bubble bg
  final Color chipBg;          // Chip bg
  final Color chipBorder;      // Chip border
  final Color ghostBg;         // Icon ghost buttons
  final Color ghostIcon;       // Icon color in ghost button
  final Color fieldBg;         // Composer field background
  final Color scrim;           // Backdrop scrim

  const _ViaTheme({
    required this.panel,
    required this.text,
    required this.assistantBg,
    required this.assistantBorder,
    required this.userBg,
    required this.chipBg,
    required this.chipBorder,
    required this.ghostBg,
    required this.ghostIcon,
    required this.fieldBg,
    required this.scrim,
  });
}

const _kPeach = Color(0xFFF2B897);

_ViaTheme _resolveTheme(ViaSkin skin) {
  switch (skin) {
    case ViaSkin.ink:
      return const _ViaTheme(
        panel: Color(0xFF0E0E0E),
        text: Colors.white,
        assistantBg: Color(0xFF141414),
        assistantBorder: Color(0x26FFFFFF),
        userBg: _kPeach,
        chipBg: Color(0x14FFFFFF),
        chipBorder: Color(0x26FFFFFF),
        ghostBg: Color(0x1AFFFFFF),
        ghostIcon: Colors.white,
        fieldBg: Color(0x1AFFFFFF),
        scrim: Color(0x99000000),
      );
    case ViaSkin.peach:
      return const _ViaTheme(
        panel: _kPeach,
        text: Colors.black,
        assistantBg: Colors.white,
        assistantBorder: Color(0x20000000),
        userBg: Color(0xFF111111),
        chipBg: Color(0x33FFFFFF),
        chipBorder: Color(0x26000000),
        ghostBg: Color(0x33FFFFFF),
        ghostIcon: Colors.black,
        fieldBg: Colors.white,
        scrim: Color(0xB3000000),
      );
    case ViaSkin.paper:
    default:
      return const _ViaTheme(
        panel: Colors.white,
        text: Colors.black,
        assistantBg: Colors.white,
        assistantBorder: Color(0x14000000),
        userBg: Color(0xFFF7EDE4), // soft peach tint
        chipBg: Colors.white,
        chipBorder: Color(0x22000000),
        ghostBg: Color(0x0F000000),
        ghostIcon: Colors.black,
        fieldBg: Color(0xF2FFFFFF),
        scrim: Color(0x61000000),
      );
  }
}

enum _OverlayStage { peek, expanded }

class _ViaOverlayState extends State<ViaOverlay> with TickerProviderStateMixin {
  _OverlayStage _stage = _OverlayStage.peek;

  final TextEditingController _composer = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _listController = ScrollController();

  bool _sending = false;
  bool _isTyping = false;
  final List<_ChatBubble> _messages = <_ChatBubble>[];

  // Layout tuning
  static const double _kBottomNavGuard = 86; // keep above custom circular nav
  static const double _kSideGutter = 14;
  static const double _kPanelRadius = 28;

  // Drag
  double _dragDy = 0;
  static const double _kDragCloseVelocity = 800; // px/s
  static const double _kDragThreshold = 80;      // px

  // Typing indicator animation
  late final AnimationController _typingCtrl;
  late final Animation<double> _dot1;
  late final Animation<double> _dot2;
  late final Animation<double> _dot3;

  @override
  void initState() {
    super.initState();

    _stage = widget.startOpen ? _OverlayStage.expanded : _OverlayStage.peek;
    _seedGreeting();

    // Focus if starting expanded
    if (_stage == _OverlayStage.expanded) {
      Future.delayed(const Duration(milliseconds: 80), _focusNode.requestFocus);
    }

    _typingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _dot1 = CurvedAnimation(parent: _typingCtrl, curve: const Interval(0.00, 0.60, curve: Curves.easeInOut));
    _dot2 = CurvedAnimation(parent: _typingCtrl, curve: const Interval(0.20, 0.80, curve: Curves.easeInOut));
    _dot3 = CurvedAnimation(parent: _typingCtrl, curve: const Interval(0.40, 1.00, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _typingCtrl.dispose();
    _composer.dispose();
    _focusNode.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _closeOverlay() {
    AnalyticsService.instance.log('via_close', {'context': widget.contextLabel});
    Navigator.of(context).maybePop();
  }

  void _expand() {
    if (_stage == _OverlayStage.expanded) return;
    HapticFeedback.lightImpact();
    setState(() => _stage = _OverlayStage.expanded);
    Future.delayed(const Duration(milliseconds: 80), _focusNode.requestFocus);
  }

  void _collapseToPeek() {
    if (_stage == _OverlayStage.peek) return;
    HapticFeedback.selectionClick();
    setState(() => _stage = _OverlayStage.peek);
    FocusScope.of(context).unfocus();
  }

  // --- Messaging -------------------------------------------------------------

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _messages.insert(0, _ChatBubble(text: trimmed, fromUser: true, timestamp: DateTime.now()));
    });

    _composer.clear();
    _scrollToBottomSoon();

    AnalyticsService.instance.log('via_send', {
      'context': widget.contextLabel,
      'len': trimmed.length,
    });

    // Show typing indicator while we await reply
    setState(() => _isTyping = true);

    String reply = 'Working on that…';
    try {
      if (widget.onAsk != null) {
        reply = await widget.onAsk!(trimmed, contextLabel: widget.contextLabel, state: widget.state);
      } else {
        final service = ViaService() as dynamic;
        final res = await service.ask(trimmed, contextLabel: widget.contextLabel, state: widget.state);
        reply = (res?.toString() ?? reply);
      }
    } catch (_) {
      reply = "Here’s a first suggestion based on what I know. (I couldn’t reach the network just now.)";
    }

    setState(() {
      _isTyping = false;
      _messages.insert(0, _ChatBubble(text: reply, fromUser: false, timestamp: DateTime.now()));
      _sending = false;
    });

    _scrollToBottomSoon();
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listController.hasClients) {
        _listController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _seedGreeting() {
    if (_messages.isNotEmpty) return;
    final name = (widget.userDisplayName ??
            widget.state['firstName'] ??
            widget.state['userName'] ??
            '')
        .toString()
        .trim();
    final hi = name.isEmpty ? "Hi there" : "Hi $name";
    final msg = "$hi — how can I help today?";
    setState(() {
      _messages.add(_ChatBubble(text: msg, fromUser: false, timestamp: DateTime.now(), isSystem: true));
    });
  }

  // --- Suggestions -----------------------------------------------------------

  List<_Suggestion> _buildSuggestions() {
    final step = JourneyService.instance.state.value?.currentStepId;
    switch (step) {
      case 'interview.basic':
        return [
          _Suggestion('How do I answer?', 'Give me tips for the interview.'),
          _Suggestion('Suggest a palette', 'Suggest a starting palette.'),
        ];
      case 'roller.build':
        return [
          _Suggestion('Balance undertones', 'Help me balance undertones.'),
          _Suggestion('Add bridge color', 'Suggest a bridge color between hues.'),
        ];
      case 'visualizer.photo':
        return [
          _Suggestion('Pick a good photo', 'What makes a good reference photo?'),
        ];
      case 'visualizer.generate':
        return [
          _Suggestion('Refine edges', 'Sharpen mask edges and fix spill.'),
          _Suggestion('Try 10% darker', 'Show a slightly darker simulation.'),
        ];
      case 'plan.create':
        return [
          _Suggestion('Room plan tips', 'How should I use these colors?'),
        ];
      case 'guide.export':
        return [
          _Suggestion('What\'s next?', 'How do I share this guide?'),
        ];
      default:
        return [
          _Suggestion('Suggest a paint color', 'Suggest a paint color for my space.'),
          _Suggestion('Talk about lighting', 'Consider my room\'s orientation and time of day.'),
        ];
    }
  }

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = _resolveTheme(widget.skin);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom; // keyboard
    final media = MediaQuery.of(context).size;
    final isExpanded = _stage == _OverlayStage.expanded;

    final double peekHeight = media.height * 0.54;
    final double expandedHeight = media.height * 0.86;
    final double baseHeight = isExpanded ? expandedHeight : peekHeight;
    final double adjustedInsets = (viewInsets.clamp(0.0, baseHeight - 200)) as double;

    final double bottomOffset = viewInsets > 0 ? _kSideGutter : (_kSideGutter + _kBottomNavGuard);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // SCRIM
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => isExpanded ? _collapseToPeek() : _closeOverlay(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                color: theme.scrim,
              ),
            ),
          ),

          // PANEL
          Positioned(
            left: _kSideGutter,
            right: _kSideGutter,
            bottom: bottomOffset,
            child: GestureDetector(
              onVerticalDragUpdate: (d) {
                setState(() => _dragDy = (_dragDy + d.primaryDelta!).clamp(-140, 180));
              },
              onVerticalDragEnd: (d) {
                final vy = d.primaryVelocity ?? 0.0;
                if (vy > _kDragCloseVelocity || _dragDy > _kDragThreshold) {
                  if (isExpanded) {
                    _collapseToPeek();
                  } else {
                    _closeOverlay();
                  }
                } else if (vy < -_kDragCloseVelocity || _dragDy < -_kDragThreshold) {
                  _expand();
                }
                setState(() => _dragDy = 0);
              },
              child: Transform.translate(
                offset: Offset(0, _dragDy),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  height: baseHeight - adjustedInsets,
                  decoration: BoxDecoration(
                    color: theme.panel,
                    borderRadius: BorderRadius.circular(_kPanelRadius),
                    border: Border.all(
                      color: widget.skin == ViaSkin.peach
                          ? const Color(0x33FFFFFF)
                          : (widget.skin == ViaSkin.ink ? const Color(0x26FFFFFF) : const Color(0x14000000)),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 30,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    left: false,
                    right: false,
                    bottom: false,
                    child: Column(
                      children: [
                        // Drag handle + header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
                          child: Column(
                            children: [
                              Center(
                                child: Container(
                                  width: 38,
                                  height: 4.5,
                                  decoration: BoxDecoration(
                                    color: theme.text.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _OverlayHeader(
                                onClose: _closeOverlay,
                                onExpand: _expand,
                                onCollapse: _collapseToPeek,
                                isExpanded: isExpanded,
                                color: theme.text,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Peek: greeting + chips + quick mic/keyboard
                        if (_stage == _OverlayStage.peek) ...[
                          _GreetingAndChips(
                            greeting: _messages.isNotEmpty
                                ? _messages.last.text
                                : "Hi — how can I help today?",
                            suggestions: _buildSuggestions(),
                            onChip: (s) {
                              AnalyticsService.instance.log('via_chip', {
                                'label': s.label,
                                'context': widget.contextLabel
                              });
                              if (s.onTapOverride != null) {
                                s.onTapOverride!();
                                return;
                              }
                              _send(s.prompt);
                              _expand();
                            },
                            theme: theme,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _GhostIconButton(
                                  icon: Icons.mic_none_rounded,
                                  onTap: () => AnalyticsService.instance
                                      .log('via_mic_peek', {'context': widget.contextLabel}),
                                  theme: theme,
                                ),
                                const SizedBox(width: 8),
                                _GhostIconButton(
                                  icon: Icons.keyboard_rounded,
                                  onTap: () {
                                    _expand();
                                    Future.delayed(const Duration(milliseconds: 80), _focusNode.requestFocus);
                                  },
                                  theme: theme,
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Expanded: chat + composer
                        if (_stage == _OverlayStage.expanded) ...[
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: _ChatList(
                                messages: _messages,
                                controller: _listController,
                                theme: theme,
                                isTyping: _isTyping,
                                dot1: _dot1,
                                dot2: _dot2,
                                dot3: _dot3,
                              ),
                            ),
                          ),
                          _ComposerBar(
                            controller: _composer,
                            focusNode: _focusNode,
                            sending: _sending,
                            onSend: _send,
                            onMic: () => AnalyticsService.instance
                                .log('via_mic', {'context': widget.contextLabel}),
                            onAttachImage: () => AnalyticsService.instance
                                .log('via_attach_image', {'context': widget.contextLabel}),
                            onAttachDoc: () => AnalyticsService.instance
                                .log('via_attach_doc', {'context': widget.contextLabel}),
                            theme: theme,
                          ),
                          const SizedBox(height: 6),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// == UI Pieces ================================================================

class _OverlayHeader extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final bool isExpanded;
  final Color color;

  const _OverlayHeader({
    required this.onClose,
    required this.onExpand,
    required this.onCollapse,
    required this.isExpanded,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Via Assistant header',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
        child: Row(
          children: [
            Icon(Icons.flash_on_rounded, size: 22, color: _kPeach),
            const SizedBox(width: 8),
            Text(
              "Assistant",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
            ),
            const Spacer(),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: isExpanded ? onCollapse : onExpand,
              icon: Icon(isExpanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded, color: color),
              tooltip: isExpanded ? 'Collapse' : 'Expand',
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: Icon(Icons.close_rounded, color: color),
              tooltip: 'Close',
            ),
          ],
        ),
      ),
    );
  }
}

class _GreetingAndChips extends StatelessWidget {
  final String greeting;
  final List<_Suggestion> suggestions;
  final void Function(_Suggestion) onChip;
  final _ViaTheme theme;

  const _GreetingAndChips({
    required this.greeting,
    required this.suggestions,
    required this.onChip,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: theme.text),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.take(6).map((s) {
              return _ChipButton(
                label: s.label,
                onTap: () => onChip(s),
                theme: theme,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ChatList extends StatelessWidget {
  final List<_ChatBubble> messages;
  final ScrollController controller;
  final _ViaTheme theme;
  final bool isTyping;
  final Animation<double> dot1;
  final Animation<double> dot2;
  final Animation<double> dot3;

  const _ChatList({
    required this.messages,
    required this.controller,
    required this.theme,
    required this.isTyping,
    required this.dot1,
    required this.dot2,
    required this.dot3,
  });

  @override
  Widget build(BuildContext context) {
    final total = messages.length + (isTyping ? 1 : 0);

    return ListView.builder(
      reverse: true,
      controller: controller,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: total,
      itemBuilder: (context, i) {
        // With reverse:true, index 0 is the latest.
        if (isTyping && i == 0) {
          return Align(
            alignment: Alignment.centerLeft,
            child: _TypingBubble(theme: theme, dot1: dot1, dot2: dot2, dot3: dot3),
          );
        }
        final offset = isTyping ? 1 : 0;
        final m = messages[i - offset];

        final align = m.fromUser ? Alignment.centerRight : Alignment.centerLeft;
        final bg = m.fromUser ? theme.userBg : theme.assistantBg;
        final border = m.fromUser ? null : theme.assistantBorder;

        final textColor = _bestOn(bg);

        return Align(
          alignment: align,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: border == null ? null : Border.all(color: border, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              m.text,
              style: TextStyle(color: textColor, height: 1.35, fontSize: 15.5),
            ),
          ),
        );
      },
    );
  }

  Color _bestOn(Color bg) {
    final b = ThemeData.estimateBrightnessForColor(bg);
    return b == Brightness.dark ? Colors.white : Colors.black87;
  }
}

class _TypingBubble extends StatelessWidget {
  final _ViaTheme theme;
  final Animation<double> dot1, dot2, dot3;

  const _TypingBubble({
    required this.theme,
    required this.dot1,
    required this.dot2,
    required this.dot3,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.assistantBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.assistantBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(dot1),
          const SizedBox(width: 4),
          _dot(dot2),
          const SizedBox(width: 4),
          _dot(dot3),
        ],
      ),
    );
  }

  Widget _dot(Animation<double> a) {
    return FadeTransition(
      opacity: a.drive(Tween(begin: 0.25, end: 1.0)),
      child: const SizedBox(width: 6, height: 6, child: DecoratedBox(decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle))),
    );
  }
}

class _ComposerBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final ValueChanged<String> onSend;
  final VoidCallback onMic;
  final VoidCallback onAttachImage;
  final VoidCallback onAttachDoc;
  final _ViaTheme theme;

  const _ComposerBar({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
    required this.onMic,
    required this.onAttachImage,
    required this.onAttachDoc,
    required this.theme,
  });

  @override
  State<_ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends State<_ComposerBar> {
  void _submit() {
    final text = widget.controller.text;
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          _GhostIconButton(icon: Icons.image_rounded, onTap: widget.onAttachImage, theme: theme),
          const SizedBox(width: 6),
          _GhostIconButton(icon: Icons.folder_open_rounded, onTap: widget.onAttachDoc, theme: theme),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.fieldBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: theme is _ViaTheme && theme.panel == _kPeach
                      ? const Color(0x33000000)
                      : const Color(0x14000000),
                ),
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                minLines: 1,
                maxLines: 4,
                style: TextStyle(color: theme.text, fontSize: 15.5),
                decoration: InputDecoration(
                  hintText: "Type your question…",
                  hintStyle: TextStyle(color: theme.text.withOpacity(0.45)),
                  isDense: true,
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _GhostIconButton(icon: Icons.mic_none_rounded, onTap: widget.onMic, theme: theme),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: widget.sending ? null : _submit,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: _kPeach,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: widget.sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.arrow_upward_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final _ViaTheme theme;

  const _ChipButton({required this.label, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.chipBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.chipBorder, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: theme.text),
          ),
        ),
      ),
    );
  }
}

class _GhostIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final _ViaTheme theme;
  const _GhostIconButton({required this.icon, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.ghostBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: theme.ghostIcon),
      ),
    );
  }
}

// == Models ===================================================================

class _ChatBubble {
  final String text;
  final bool fromUser;
  final DateTime timestamp;
  final bool isSystem;
  _ChatBubble({
    required this.text,
    required this.fromUser,
    required this.timestamp,
    this.isSystem = false,
  });
}

class _Suggestion {
  final String label;
  final String prompt;
  final bool requiresCallback;
  final VoidCallback? onTapOverride;

  _Suggestion(this.label, this.prompt, {this.onTapOverride, bool? requiresCallback})
      : requiresCallback = requiresCallback ?? (onTapOverride != null);
}
