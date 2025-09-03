# Interview + Voice Module Integration — Task Tracker

Plan was approved: implement Interview (Text + Talk) module with schema-driven engine, branching, and voice layer, wiring into JourneyService artifacts and progress.

Status legend:
- [x] Completed
- [ ] Pending
- [~] In progress

## Steps

1) Dependencies
- [x] Add voice deps to pubspec.yaml:
  - speech_to_text: ^6.6.0
  - flutter_tts: ^4.0.2
  - Keep just_audio as-is
- [x] Fix invalid assets line in pubspec.yaml:
  - - assets/documents/

2) New files to add
- [x] lib/services/interview_engine.dart — minimal schema-inspired engine with branching for roomType (v2 applied)
- [x] lib/services/voice_assistant.dart — STT/TTS wrapper for Talk mode (v2 applied)
- [x] lib/widgets/interview_widgets.dart — ChatBubble, OptionChips, MultiSelectChips (already present)

3) Replace screen implementation
- [x] lib/screens/interview_screen.dart — chat-style UI v2 applied:
  - Mode toggle (Text/Talk)
  - Progress: CreateFlowProgress.instance.set('interview', _engine.progress)
  - Artifacts: JourneyService.instance.setArtifact('answers', ...)
  - Advance: JourneyService.instance.completeCurrentStep()
  - Analytics: AnalyticsService.instance.logEvent('interview_completed')
  - Import paths aligned to project: package:color_canvas/...

4) Commands and verification
- [x] Run: flutter pub get
- [x] Run: flutter analyze
- [~] Run: flutter test (note: several unrelated tests fail due to Firebase/test harness; patch compiles and lints clean)
- [ ] Manual test:
  - Create → Interview flow works
  - Branching by roomType
  - Text/Talk input works (free text via voice)
  - artifacts.answers persisted
  - Step advances to Roller

## Notes
- Package name confirmed as color_canvas.
- JourneyService path: lib/services/journey/journey_service.dart
- CreateFlowProgress path: lib/services/create_flow_progress.dart
- AnalyticsService path: lib/services/analytics_service.dart
