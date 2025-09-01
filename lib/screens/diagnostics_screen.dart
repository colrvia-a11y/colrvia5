import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/diagnostics_service.dart';
import '../services/feature_flags.dart';
import '../services/sync_queue_service.dart';
import '../services/analytics_service.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  String _version = '';
  List<String> _events = [];
  List<Map<String, dynamic>> _pending = [];

  @override
  void initState() {
    super.initState();
    _load();
    AnalyticsService.instance.logEvent('diagnostics_opened');
  }

  Future<void> _load() async {
    final info = await PackageInfo.fromPlatform();
    final pending = await SyncQueueService.instance.pendingOps();
    setState(() {
      _version = info.version;
      _events = DiagnosticsService.instance.breadcrumbs.reversed.toList();
      _pending = pending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final flags = FeatureFlags.instance.flags;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              AnalyticsService.instance.logEvent('diagnostics_shared');
              DiagnosticsService.instance.shareDiagnostics();
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Version: $_version'),
          const SizedBox(height: 8),
          Text('Feature flags: ${flags.keys.join(', ')}'),
          const SizedBox(height: 16),
          const Text('Recent events:'),
          ..._events.map((e) => Text(e)).toList(),
          const SizedBox(height: 16),
          Text('Pending sync items: ${_pending.length}'),
        ],
      ),
    );
  }
}
