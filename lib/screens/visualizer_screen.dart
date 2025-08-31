// lib/screens/visualizer_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/visualizer_service.dart';
import '../data/sample_rooms.dart';

class VisualizerScreen extends StatefulWidget {
  final String projectId;
  final List<String> paletteColorIds;
  const VisualizerScreen({super.key, required this.projectId, required this.paletteColorIds});
  @override
  State<VisualizerScreen> createState() => _VisualizerScreenState();
}

class _VisualizerScreenState extends State<VisualizerScreen> {
  final _svc = VisualizerService();
  String? _imageUrl; // chosen photo or sample
  String _mode = 'A'; // A/B
  VisualizerJob? _fastJob;
  VisualizerJob? _hqJob;
  DateTime? _hqStart;
  StreamSubscription<VisualizerJob>? _hqSub;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visualizer'), actions: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'A', label: Text('A')),
            ButtonSegment(value: 'B', label: Text('B'))
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
      ]),
      body: _imageUrl == null ? _buildSampleChooser() : _buildWorkspace(),
    );
  }

  Widget _buildSampleChooser() {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      children: [
        for (final r in sampleRooms)
          GestureDetector(
            onTap: () => setState(() => _imageUrl = r.assetPath),
            child: Card(
              child: Column(children: [
                Expanded(child: Image.asset(r.assetPath, fit: BoxFit.cover)),
                Padding(padding: const EdgeInsets.all(8), child: Text(r.title)),
              ]),
            ),
          )
      ],
    );
  }

  @override
  void dispose() {
    _hqSub?.cancel();
    super.dispose();
  }

  Widget _buildWorkspace() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (_fastJob?.previewUrl != null) Image.network(_fastJob!.previewUrl!),
      if (_hqJob?.resultUrl != null)
        Padding(padding: const EdgeInsets.only(top: 12), child: Image.network(_hqJob!.resultUrl!)),
      Row(children: [
        ElevatedButton.icon(
            onPressed: _runFast,
            icon: const Icon(Icons.flash_on),
            label: const Text('Fast Preview')),
        const SizedBox(width: 8),
        OutlinedButton.icon(
            onPressed: _runHq, icon: const Icon(Icons.hd), label: const Text('HQ Render')),
      ]),
      if (_hqJob != null) _Progress(job: _hqJob!),
    ]);
  }

  Future<void> _runFast() async {
    // Telemetry: fast preview request
    // ignore: avoid_print
    print('render_fast_requested size=${widget.paletteColorIds.length}');
    final job = await _svc.renderFast(_imageUrl!, widget.paletteColorIds);
    setState(() => _fastJob = job);
  }

  Future<void> _runHq() async {
    // Telemetry: HQ request
    // ignore: avoid_print
    print('render_hq_requested size=${widget.paletteColorIds.length}');
    final job = await _svc.renderHq(_imageUrl!, widget.paletteColorIds);
    setState(() => _hqJob = job);
    _hqStart = DateTime.now();
    _hqSub?.cancel();
    _hqSub = _svc.watchJob(job.jobId).listen((j) {
      setState(() => _hqJob = j);
      if (j.status == 'complete' && _hqStart != null) {
        final ms = DateTime.now().difference(_hqStart!).inMilliseconds;
        // Telemetry: HQ completed
        // ignore: avoid_print
        print('render_hq_completed ms_elapsed='+ms.toString());
        _hqSub?.cancel();
      }
    });
  }
}

class _Progress extends StatelessWidget {
  final VisualizerJob job;
  const _Progress({required this.job});
  @override
  Widget build(BuildContext context) {
    final map = {'queued': 0.2, 'preview': 0.5, 'running': 0.7, 'complete': 1.0};
    final v = map[job.status] ?? 0.1;
    return Column(children: [
      LinearProgressIndicator(value: v < 1 ? v : null),
      const SizedBox(height: 8),
      Text('Status: ${job.status}')
    ]);
  }
}
