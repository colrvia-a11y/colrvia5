import 'package:flutter/material.dart';
import '../services/create_flow_progress.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  int _completed = 0;
  final int _total = 10; // Example total lessons

  void _completeLesson() {
    if (_completed < _total) {
      setState(() => _completed++);
      CreateFlowProgress.instance.set('learn', _completed / _total);
    }
  }

  @override
  void dispose() {
    CreateFlowProgress.instance.clear('learn');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Lessons completed: $_completed / $_total'),
            ElevatedButton(
              onPressed: _completeLesson,
              child: const Text('Complete Lesson'),
            ),
          ],
        ),
      ),
    );
  }
}
