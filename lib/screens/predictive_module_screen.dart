import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/predictive_service.dart';
import '../main.dart';
import 'sales_history_screen.dart';

class PredictiveModuleScreen extends StatefulWidget {
  const PredictiveModuleScreen({Key? key}) : super(key: key);

  @override
  State<PredictiveModuleScreen> createState() => _PredictiveModuleScreenState();
}

class _PredictiveModuleScreenState extends State<PredictiveModuleScreen> {
  final TextEditingController _featuresController = TextEditingController(text: '0.1,0.2,0.3,0.4,0.5');
  final TextEditingController _latController = TextEditingController(text: '-1.2921');
  final TextEditingController _lonController = TextEditingController(text: '36.8219');
  final TextEditingController _countryController = TextEditingController(text: 'KE');
  final TextEditingController _eventController = TextEditingController(text: '0');
  final TextEditingController _productIdController = TextEditingController();
  String _season = 'spring';
  bool _isHoliday = false;
  double _trend = 0.0;
  bool _fetchWeather = true;
  bool _loading = false;
  double? _lastPrediction;

  @override
  void dispose() {
    _featuresController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _countryController.dispose();
    _eventController.dispose();
    _productIdController.dispose();
    super.dispose();
  }

  Future<void> _runPrediction() async {
    setState(() => _loading = true);
    final svc = PredictiveService();
    // parse features
    final raw = _featuresController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final features = <double>[];
    for (var r in raw) {
      final v = double.tryParse(r);
      if (v != null) features.add(v);
    }

    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    final events = int.tryParse(_eventController.text) ?? 0;

    // Fetch recent sales history for the given product id (if provided)
    List<Map<String, dynamic>>? salesHistory;
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final prodId = _productIdController.text.trim();
    if (prodId.isNotEmpty) {
      if (isFirebaseInitialized && FirebaseAuth.instance.currentUser != null) {
        try {
          final snap = await FirebaseFirestore.instance.collection('sales').where('productId', isEqualTo: prodId).where('ownerEmail', isEqualTo: FirebaseAuth.instance.currentUser?.email).orderBy('timestamp', descending: true).limit(50).get();
          salesHistory = snap.docs.map((d) {
            final data = d.data();
            return { 'qty': data['qty'] ?? 0, 'timestamp': data['timestamp'] is Timestamp ? (data['timestamp'] as Timestamp).toDate().toIso8601String() : (data['timestamp']?.toString() ?? '') };
          }).toList();
        } catch (_) { salesHistory = null; }
      } else {
        salesHistory = appState.salesHistory.where((s) => s['productId'] == prodId).map((s) => {'qty': s['qty'], 'timestamp': s['timestamp']}).toList();
      }
    }

    final pred = await svc.predictWithContext(features,
        season: _season,
        isHoliday: _isHoliday,
        trendScore: _trend,
        eventCount: events,
        latitude: lat,
        longitude: lon,
        fetchWeather: _fetchWeather,
        countryCode: _countryController.text.isEmpty ? null : _countryController.text,
        salesHistory: salesHistory);

    setState(() {
      _lastPrediction = pred;
      _loading = false;
    });

    // Add app notification
    if (pred != null) {
      Provider.of<AppStateProvider>(context, listen: false).addNotification('Prediction', 'Predicted: ${pred.toStringAsFixed(2)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final hasSales = appState.salesHistory.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Predictive Module')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hasSales) Card(color: Colors.yellow[50], child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: Text('No sales history recorded — predictions may be less accurate. Please record sales in Sales History.')), TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesHistoryScreen())), child: const Text('Open'))]))),
            const Text('Base features (comma-separated)'),
            const SizedBox(height: 8),
            TextField(controller: _featuresController, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'e.g. 0.1,0.2,0.3,0.4,0.5')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(value: _season, items: const [DropdownMenuItem(value: 'spring', child: Text('Spring')), DropdownMenuItem(value: 'summer', child: Text('Summer')), DropdownMenuItem(value: 'autumn', child: Text('Autumn')), DropdownMenuItem(value: 'winter', child: Text('Winter'))], onChanged: (v) { if (v != null) setState(() => _season = v); }, decoration: const InputDecoration(labelText: 'Season'))),
              const SizedBox(width: 12),
              Expanded(child: CheckboxListTile(value: _isHoliday, onChanged: (v) => setState(() => _isHoliday = v ?? false), title: const Text('Is Holiday'), controlAffinity: ListTileControlAffinity.leading)),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _productIdController, decoration: const InputDecoration(labelText: 'Product ID (optional - to use sales history)')),
            const SizedBox(height: 12),
            const Text('Trend score'),
            Slider(value: _trend, onChanged: (v) => setState(() => _trend = v), min: -2.0, max: 2.0, divisions: 40, label: _trend.toStringAsFixed(2)),
            const SizedBox(height: 8),
            TextField(controller: _eventController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Event count (nearby events)')),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: TextField(controller: _latController, decoration: const InputDecoration(labelText: 'Latitude'))), const SizedBox(width: 8), Expanded(child: TextField(controller: _lonController, decoration: const InputDecoration(labelText: 'Longitude')))]),
            const SizedBox(height: 8),
            Row(children: [Expanded(child: TextField(controller: _countryController, decoration: const InputDecoration(labelText: 'Country code (ISO)'))), const SizedBox(width: 12), Expanded(child: SwitchListTile(value: _fetchWeather, onChanged: (v) => setState(() => _fetchWeather = v), title: const Text('Fetch weather')))]),
            const SizedBox(height: 16),
            SizedBox(height: 48, child: ElevatedButton(onPressed: _loading ? null : _runPrediction, child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Get Prediction'))),
            const SizedBox(height: 12),
            if (_lastPrediction != null) Text('Last prediction: ${_lastPrediction!.toStringAsFixed(3)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
