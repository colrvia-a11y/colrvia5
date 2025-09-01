import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:share_plus/share_plus.dart';


/// Collects lightweight diagnostics and breadcrumbs for support.
/// Stores only non-PII identifiers and timestamps.
class DiagnosticsService {
  DiagnosticsService._();
  static final DiagnosticsService instance = DiagnosticsService._();

  final List<String> _breadcrumbs = [];

  /// Records a breadcrumb and forwards it to Crashlytics.
  void logBreadcrumb(String message) {
    final entry = '${DateTime.now().toIso8601String()} | $message';
    if (_breadcrumbs.length >= 50) {
      _breadcrumbs.removeAt(0);
    }
    _breadcrumbs.add(entry);
    FirebaseCrashlytics.instance.log(entry);
  }

  /// Returns an immutable copy of breadcrumbs.
  List<String> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  /// Exports breadcrumbs as a single text blob.
  String exportLogs() => breadcrumbs.join('\n');

  /// Shares diagnostics via the platform share sheet.
  Future<void> shareDiagnostics() async {
    await Share.share(exportLogs(), subject: 'Diagnostics');
  }

  /// Placeholder hook for when the screen is opened.
  void opened() {}
}
