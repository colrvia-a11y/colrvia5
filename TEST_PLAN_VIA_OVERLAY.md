# Thorough Test Plan — Via Overlay (Peek + Expanded)

Scope
- Component: lib/widgets/via_overlay.dart
- Entry points:
  - HomeScreen → showDialog(ViaOverlay) (peek by default)
  - ColorPlanDetailScreen → ViaOverlay (feature flag gated)
- Goals:
  - Ensure readability, minimal elegance, and keyboard/mic integrations
  - Resolve: transparent background readability issues, gradient cutting text, layout when keyboard opens

Environment Matrix
- Devices:
  - Small phone (e.g., iPhone SE / Pixel 4a)
  - Medium phone (e.g., iPhone 13 / Pixel 6)
  - Large phone (e.g., iPhone 14 Pro Max / Pixel 7 Pro)
- Orientation: Portrait, Landscape
- Theme: Light, Dark
- Platform: iOS and Android

What changed (high level)
- Peek state: added mic and keyboard icons (bottom-right) — minimal icon-only actions
- Expanded state: height now reduces when keyboard opens (prevents header/buttons being pushed offscreen)
- Improved edge feathering mask (larger solid center) to prevent text clipping
- Kept frosted glass/gradient aesthetic; rely on scrim + interior white gradient for readability

Test Cases

A. Launch and Backdrop
1. Launch Via overlay from Home (peek) 
   - Expect: Scrim appears (dark backdrop), overlay panel sits above bottom nav guard
   - Readability: Greeting text and suggestion chips readable on various content behind
   - Visual: No abrupt jumps, soft animation
2. Tap outside overlay in peek
   - Expect: Overlay closes; scrim removed
3. Long-press on Home Via bubble (ensure no regression)
   - Expect: Radial quick actions still work, not impacted by overlay changes

B. Peek State — Actions Bar (Mic + Keyboard)
1. Icons present bottom-right, clean/minimal, correct spacing, tappable hitboxes
2. Tap mic icon
   - Expect: No crash; Analytics via_mic_peek logged (observe console/logcat)
3. Tap keyboard icon
   - Expect: Overlay expands and composer text field is focused; OS keyboard opens
   - Verify: Expanded layout (see Section C) handles keyboard correctly

C. Expanded State — Keyboard Safety and Layout
1. Without keyboard:
   - Header, chat list, composer all visible
   - Feathered edges do not clip text; inner content fully readable
2. With keyboard open:
   - Overlay height reduces (baseHeight - adjustedViewInsets)
   - Header (top) and send button (bottom) remain visible; nothing pushed off-screen
   - Chat list scrolls correctly; no overlap with composer
   - Dismiss keyboard (back button/tap outside text) restores height
3. Different screen sizes/orientations:
   - No content clipping; layout remains elegant and stable
   - Landscape: especially confirm chat list + composer visibility

D. Readability and Gradient/Mask
1. Confirm text readability on:
   - Peek greeting + chips
   - Expanded chat bubbles, both user and assistant
2. Verify feather mask stops (0.78, 0.96, 1.0) do not cut off text at the edges
3. Confirm readability in Light/Dark themes

E. Integration Points
1. HomeScreen:
   - showDialog overlay opens in peek; barrier works; back/close works
   - Long press Via bubble quick actions unaffected
2. ColorPlanDetailScreen (if FeatureFlags.viaMvp enabled)
   - Overlay toggle appears and functions; no overlap or z-order issues with content

F. Accessibility and Safe Areas
1. SafeArea: No content under notches/home indicators
2. Dynamic Type / Font scaling: Larger fonts still readable and not clipped
3. Motion sensitivity: No aggressive parallax tied to overlay panel
4. Screen readers (VoiceOver/TalkBack): Buttons announce labels (Assistant, Close, Expand/Collapse, Mic, Keyboard)

G. Analytics / Logging
1. Verify without runtime errors:
   - via_chip
   - via_mic_peek (peek mic icon)
   - via_mic (composer mic)
2. No noisy logs or exceptions in console

H. Edge Cases
1. Rapid tap mic/keyboard in peek repeatedly
   - No flicker, no crash, no stuck states
2. Open keyboard then rotate device
   - Layout reflows; no elements off-screen, no text clipped
3. Very short content (few messages) and very long content (many messages)
   - List performance and scroll behavior maintain UX quality

Regression Risks to Watch
- composer TextField focus/defocus cycles
- overlay height math: adjustedViewInsets = clamp(viewInsets, 0, baseHeight - 200)
  - Ensure on very small devices/large keyboard, height remains adequate
- default ViaService call path still intact (no code changes to networking from this patch)

Pass/Fail Criteria
- PASS if:
  - Peek icons work, keyboard opens via keyboard icon, mic icon logs without runtime errors
  - Expanded overlay remains fully operable with keyboard open; header/buttons visible
  - No gradient/mask cutting text; readability improved everywhere
- FAIL if any clipping, hidden controls with keyboard, unreadable text, or crashes/log errors

Bug Log Template
- Title:
- Device/OS:
- Orientation/Theme:
- Steps:
- Expected:
- Actual:
- Screenshots / Logs:
- Severity: (Blocker / Major / Minor)

Notes for QA
- Use slow animations developer setting to visually confirm transitions are smooth
- Capture screenshots of peek and expanded states (with/without keyboard) per device size
