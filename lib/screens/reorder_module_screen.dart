import 'package:flutter/material.dart';
import '../services/predictive_service.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class ReorderModuleScreen extends StatefulWidget {
  const ReorderModuleScreen({Key? key}) : super(key: key);

  @override
  State<ReorderModuleScreen> createState() => _ReorderModuleScreenState();
}

class _ReorderModuleScreenState extends State<ReorderModuleScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Sample Item');
  final TextEditingController _qtyController = TextEditingController(text: '3');
  final TextEditingController _leadTimeController = TextEditingController(text: '7');
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _leadTimeController.dispose();
    super.dispose();
  }

  Future<void> _getSuggestion() async {
    setState(() => _loading = true);
    final svc = PredictiveService();
    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    final leadTime = double.tryParse(_leadTimeController.text) ?? 7.0;
    const lat = -1.2921;
    const lon = 36.8219;

    final pred = await svc.predictWithContext(
      [qty / 100.0, 0.0, 0.0, 0.0, 0.0],
      calendarEvent: 0,
      leadTime: leadTime,
      marketTrend: 0.1,
      latitude: lat,
      longitude: lon,
      fetchWeather: true,
    );

    final suggested = pred == null ? 0 : (pred - qty).round().clamp(0, 9999);
    setState(() => _loading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Predicted demand: ${pred?.toStringAsFixed(2) ?? 'n/a'}; Suggested reorder: $suggested')),
      );
      Provider.of<AppStateProvider>(context, listen: false)
          .addNotification('Reorder Suggestion', 'Suggested reorder: $suggested units');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reorder Module')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Suggest reorder quantities using predictive model', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Item name'),
              controller: _nameController,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Current quantity'),
              keyboardType: TextInputType.number,
              controller: _qtyController,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Lead time (days)'),
              keyboardType: TextInputType.number,
              controller: _leadTimeController,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _getSuggestion,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Get Reorder Suggestion'),
            ),
            const SizedBox(height: 12),
            const Text('Uses weather, calendar events, lead time and market trend for demand prediction.'),
          ],
        ),
      ),
    );
  }
}
