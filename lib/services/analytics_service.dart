// lib/services/analytics_service.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();
  factory AnalyticsService() => instance; // allow AnalyticsService() calls
  static final instance = AnalyticsService._();
  final FirebaseAnalytics _fa = FirebaseAnalytics.instance;

  // Keep a small rolling buffer of recent analytics events for diagnostics
  final List<Map<String, Object?>> _recentEvents = [];
  List<Map<String, Object?>> get recentEvents => List.unmodifiable(_recentEvents);

  Future<void> logAppOpen() => _fa.logAppOpen();
  Future<void> setUserId(String? uid) => _fa.setUserId(id: uid);

  Future<void> logEvent(String name, [Map<String, Object?> params = const {}]) async {
    // record locally for diagnostics (trim to last 50)
    _recentEvents.add({
      'name': name,
      'params': params,
      'at': DateTime.now().toIso8601String(),
    });
    if (_recentEvents.length > 50) {
      _recentEvents.removeRange(0, _recentEvents.length - 50);
    }
    final cleaned = <String, Object>{};
    params.forEach((k, v) {
      if (v == null) return;
      if (v is num || v is String || v is bool || v is List) cleaned[k] = v;
      // ignore non-primitive values to avoid runtime/type issues
    });
    await _fa.logEvent(name: name, parameters: cleaned);
    if (kDebugMode) debugPrint('[analytics] $name $cleaned');
  }

  /// Accepts nullable values, then filters out nulls and only keeps primitive types,
  /// because FirebaseAnalytics requires Map<String, Object> (non-null values).
  Future<void> log(String name, [Map<String, Object?> params = const {}]) async {
    final cleaned = <String, Object>{};
    params.forEach((k, v) {
      if (v == null) return;
      if (v is num || v is String || v is bool || v is List) cleaned[k] = v;
      // ignore non-primitive values to avoid runtime/type issues
    });

    await _fa.logEvent(name: name, parameters: cleaned);
    if (kDebugMode) debugPrint('[analytics] $name $cleaned');
  }

  // Typed helpers used across the app
  Future<void> interviewStarted({String? mode}) {
    return logEvent('interview_started', {'mode': mode ?? 'unknown'});
  }

  Future<void> interviewAnswerSet(String id) =>
      logEvent('interview_answer', {'id': id});
  Future<void> interviewCompleted() => logEvent('interview_completed');
  Future<void> reviewConfirmed() => logEvent('review_confirmed');
  Future<void> paletteGenerated({String? brand}) {
    return logEvent('palette_generated', {'brand': brand ?? 'unknown'});
  }

  Future<void> visualizerOpened() => logEvent('visualizer_opened');
  Future<void> visualizerStroke({required String role}) =>
      logEvent('viz_stroke', {'role': role});
  Future<void> vizExport() => logEvent('viz_export');
  Future<void> talkStart() => logEvent('talk_start');
  Future<void> talkEnd() => logEvent('talk_end');
  Future<void> logDashboardOpened() => logEvent('dashboard_opened');

  // Backward-compat stubs for existing call sites across the app
  Future<void> logProjectStageChanged(String projectId, Object stage) =>
      logEvent('project_stage_changed', {'projectId': projectId, 'stage': stage.toString()});

  Future<void> resumeLastShown(String projectId) =>
      logEvent('resume_last_shown', {'projectId': projectId});

  Future<void> resumeLastClicked(String projectId, String screen) =>
      logEvent('resume_last_clicked', {'projectId': projectId, 'screen': screen});

  Future<void> planGenerated(String projectId, String planId) =>
      logEvent('plan_generated', {'projectId': projectId, 'planId': planId});

  Future<void> planFallbackCreated() => logEvent('plan_fallback_created');

  Future<void> compareOpened(int count) =>
      logEvent('compare_opened', {'count': count});

  Future<void> permissionMicrocopyShown(String type) =>
      logEvent('permission_microcopy_shown', {'type': type});

  Future<void> permissionRequested(String type) =>
      logEvent('permission_requested', {'type': type});

  Future<void> featureFlagState(String flag, bool enabled) =>
      logEvent('feature_flag_state', {'flag': flag, 'enabled': enabled});

  // === NEW: used by save_palette_panel.dart ===
  Future<void> logRollerSaveToProject(String projectId, String savedPaletteId) {
    return log('roller_save_to_project', {
      'project_id': projectId,
      'saved_palette_id': savedPaletteId,
    });
  }

  // -------- Compatibility and richer API stubs --------

  // Screen view helpers
  Future<void> setCurrentScreen({required String screenName, String? screenClass}) =>
      _fa.logScreenView(screenName: screenName, screenClass: screenClass);
  Future<void> logScreenView(String screenName) =>
      setCurrentScreen(screenName: screenName);

  // User property
  Future<void> setUserProperty(String name, String value) =>
      _fa.setUserProperty(name: name, value: value);

  // Color Story analytics (examples and call sites)
  Future<void> trackColorStoryOpen({
    required String storyId,
    String? slug,
    String? title,
    List<String>? themes,
    List<String>? families,
    List<String>? rooms,
    bool? isFeatured,
    String? source,
  }) =>
      logEvent('color_story_open', {
        'storyId': storyId,
        if (slug != null) 'slug': slug,
        if (title != null) 'title': title,
        if (themes != null) 'themes': themes,
        if (families != null) 'families': families,
        if (rooms != null) 'rooms': rooms,
        if (isFeatured != null) 'isFeatured': isFeatured,
        if (source != null) 'source': source,
      });

  Future<void> trackColorStoryUseClick({
    required String storyId,
    String? slug,
    String? title,
    int? paletteColorCount,
    List<String>? colorHexCodes,
  }) =>
      logEvent('color_story_use_click', {
        'storyId': storyId,
        if (slug != null) 'slug': slug,
        if (title != null) 'title': title,
        if (paletteColorCount != null) 'paletteColorCount': paletteColorCount,
        if (colorHexCodes != null) 'colorHexCodes': colorHexCodes,
      });

  Future<void> trackColorStorySaveClick({
    required String storyId,
    String? slug,
    String? title,
    bool? isAlreadySaved,
  }) =>
      logEvent('color_story_save_click', {
        'storyId': storyId,
        if (slug != null) 'slug': slug,
        if (title != null) 'title': title,
        if (isAlreadySaved != null) 'isAlreadySaved': isAlreadySaved,
      });

  Future<void> trackColorStoryShareClick({
    required String storyId,
    String? slug,
    String? title,
    String? shareMethod,
  }) =>
      logEvent('color_story_share_click', {
        'storyId': storyId,
        if (slug != null) 'slug': slug,
        if (title != null) 'title': title,
        if (shareMethod != null) 'method': shareMethod,
      });

  // Explore analytics
  Future<void> trackExploreFilterChange({
    required List<String> selectedThemes,
    required List<String> selectedFamilies,
    required List<String> selectedRooms,
    required bool featuredOnly,
    required String changeType,
    int? totalResultCount,
  }) =>
      logEvent('explore_filter_change', {
        'themes': selectedThemes,
        'families': selectedFamilies,
        'rooms': selectedRooms,
        'featuredOnly': featuredOnly,
        'changeType': changeType,
        if (totalResultCount != null) 'resultCount': totalResultCount,
      });

  Future<void> trackExploreSearch({
    required String searchQuery,
    int? resultCount,
    List<String>? activeFilters,
  }) =>
      logEvent('explore_search', {
        'query': searchQuery,
        if (resultCount != null) 'resultCount': resultCount,
        if (activeFilters != null) 'filters': activeFilters,
      });

  // CTA and onboarding helpers used around the app
  Future<void> onboardingCompleted() => logEvent('onboarding_completed');
  Future<void> ctaPlanClicked(String projectId) =>
      logEvent('cta_plan_clicked', {'projectId': projectId});
  Future<void> ctaVisualizeClicked(String projectId) =>
      logEvent('cta_visualize_clicked', {'projectId': projectId});
  Future<void> ctaCompareClicked(String projectId) =>
      logEvent('cta_compare_clicked', {'projectId': projectId});

  // Visualizer-related helpers
  Future<void> logVisualizerOpenedFromStory(String projectId) =>
      logEvent('visualizer_opened_from_story', {'projectId': projectId});
  Future<void> painterPackExported(int pageCount, int colorCount) =>
      logEvent('painter_pack_exported', {'pages': pageCount, 'colors': colorCount});
  Future<void> logExportShared(String projectId) =>
      logEvent('export_shared', {'projectId': projectId});
  Future<void> logStartFromExplore(String storyId, String projectId) =>
      logEvent('remix_started_from_explore', {'storyId': storyId, 'projectId': projectId});

  // Webview analytics helpers
  Future<void> logWebviewPageStarted(String url) =>
      logEvent('webview_page_started', {'url': url});
  Future<void> logWebviewPageFinished(String url) =>
      logEvent('webview_page_finished', {'url': url});
  Future<void> logWebviewError(String error) =>
      logEvent('webview_error', {'error': error});
  Future<void> logExportGuideShared(String projectId) =>
      logEvent('export_guide_shared', {'projectId': projectId});
}
