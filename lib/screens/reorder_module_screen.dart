import 'package:flutter/material.dart';
import '../services/predictive_service.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class ReorderModuleScreen extends StatelessWidget {
  const ReorderModuleScreen({Key? key}) : super(key: key);

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
            TextField(decoration: const InputDecoration(labelText: 'Item name'), controller: TextEditingController(text: 'Sample Item')),
            const SizedBox(height: 8),
            TextField(decoration: const InputDecoration(labelText: 'Current quantity'), keyboardType: TextInputType.number, controller: TextEditingController(text: '3')),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final svc = PredictiveService();
                // Derive simple contextual factors
                final month = DateTime.now().month;
                String season = 'spring';
                if (month >= 3 && month <= 5) season = 'spring';
                if (month >= 6 && month <= 8) season = 'summer';
                if (month >= 9 && month <= 11) season = 'autumn';
                if (month == 12 || month <= 2) season = 'winter';

                // Example lat/lon (Nairobi). Replace with shop coords if available.
                final lat = -1.2921;
                final lon = 36.8219;

                final pred = await svc.predictWithContext([0.2, 0.1, 0.05, 0.0, 0.0],
                    season: season, trendScore: 0.1, eventCount: 0, latitude: lat, longitude: lon, fetchWeather: true, countryCode: 'KE');
                final suggested = pred == null ? 0 : (pred * 1.0).round();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Predicted demand: ${pred?.toStringAsFixed(2) ?? 'n/a'}; Suggested reorder: $suggested')));
                // Add notification
                Provider.of<AppStateProvider>(context, listen: false).addNotification('Reorder Suggestion', 'Suggested reorder: $suggested units');
              },
              child: const Text('Get Reorder Suggestion (with context)'),
            ),
            const SizedBox(height: 12),
            const Text('Note: This uses the predictive API. For accurate suggestions, train the model with your sales history.'),
          ],
        ),
      ),
    );
  }
}
