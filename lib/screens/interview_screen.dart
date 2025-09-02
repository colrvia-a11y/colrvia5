import 'package:flutter/material.dart';
import '../services/create_flow_progress.dart';

class InterviewScreen extends StatefulWidget {
  const InterviewScreen({super.key});

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  int _currentStep = 0;
  final int _totalSteps = 5; // Example total steps

  void _onStepChanged(int step, int total) {
    CreateFlowProgress.instance.set('interview', step / total);
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _onStepChanged(_currentStep, _totalSteps);
    }
  }

  @override
  void dispose() {
    CreateFlowProgress.instance.clear('interview');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Interview')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Step ${_currentStep + 1} of $_totalSteps'),
            ElevatedButton(
              onPressed: _nextStep,
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}
