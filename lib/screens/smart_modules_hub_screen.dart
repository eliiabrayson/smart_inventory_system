import 'package:flutter/material.dart';
import '../services/predictive_service.dart';
import 'predictive_module_screen.dart';

class SmartModulesHubScreen extends StatefulWidget {
  const SmartModulesHubScreen({Key? key}) : super(key: key);

  @override
  State<SmartModulesHubScreen> createState() => _SmartModulesHubScreenState();
}

class _SmartModulesHubScreenState extends State<SmartModulesHubScreen> {
  final PredictiveService _svc = PredictiveService();
  double? _lastPrediction;
  bool _loading = false;

  Future<void> _getPrediction() async {
    setState(() => _loading = true);
    final pred = await _svc.predict([0.1, 0.2, 0.3, 0.4, 0.5]);
    setState(() {
      _lastPrediction = pred;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Modules')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PredictiveModuleScreen())),
              child: const Text('Open Predictive Module'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _getPrediction,
              child: _loading ? const CircularProgressIndicator() : const Text('Run Quick Prediction'),
            ),
            const SizedBox(height: 20),
            if (_lastPrediction != null)
              Text('Last prediction: ${_lastPrediction!.toStringAsFixed(3)}'),
            if (_lastPrediction == null)
              const Text('No predictions yet'),
          ],
        ),
      ),
    );
  }
}
