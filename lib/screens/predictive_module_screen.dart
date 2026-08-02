import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/predictive_service.dart';
import '../main.dart';

class PredictiveModuleScreen extends StatefulWidget {
  const PredictiveModuleScreen({Key? key}) : super(key: key);

  @override
  State<PredictiveModuleScreen> createState() => _PredictiveModuleScreenState();
}

class _PredictiveModuleScreenState extends State<PredictiveModuleScreen> {
  final TextEditingController _featuresController = TextEditingController(text: '0.0,0.0,0.0,0.0,0.0');
  final TextEditingController _latController = TextEditingController(text: '-1.2921');
  final TextEditingController _lonController = TextEditingController(text: '36.8219');
  final TextEditingController _calendarEventController = TextEditingController(text: '0');
  final TextEditingController _leadTimeController = TextEditingController(text: '7');
  double _marketTrend = 0.0;
  bool _fetchWeather = true;
  bool _loading = false;
  double? _lastPrediction;

  List<Map<String, dynamic>> _productsList = [];
  Map<String, dynamic>? _selectedProduct;
  List<double> _historicalSales = [0.0, 0.0, 0.0, 0.0, 0.0];
  bool _fetchingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _fetchingProducts = true);
    List<Map<String, dynamic>> temp = [];
    try {
      if (isFirebaseInitialized && FirebaseAuth.instance.currentUser != null) {
        final email = FirebaseAuth.instance.currentUser?.email;
        final snap = await FirebaseFirestore.instance
            .collection('products')
            .where('ownerEmail', isEqualTo: email)
            .get();
        temp = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      } else {
        temp = [
          {'id': '1', 'name': 'Coffee Beans', 'quantity': 12, 'category': 'Vinywaji'},
          {'id': '2', 'name': 'Whole Milk', 'quantity': 3, 'category': 'Bidhaa za Maziwa'},
        ];
      }
    } catch (e) {
      debugPrint('Failed to load products: $e');
    }
    setState(() {
      _productsList = temp;
      _fetchingProducts = false;
      if (_productsList.isNotEmpty) {
        _selectedProduct = _productsList.first;
        _updateHistoricalSales();
      }
    });
  }

  Future<void> _updateHistoricalSales() async {
    if (_selectedProduct == null) return;
    final pid = _selectedProduct!['id'].toString();
    List<double> sales = [];

    try {
      if (isFirebaseInitialized && FirebaseAuth.instance.currentUser != null) {
        final snap = await FirebaseFirestore.instance
            .collection('sales')
            .where('productId', isEqualTo: pid)
            .orderBy('timestamp', descending: true)
            .limit(5)
            .get();
        
        for (var doc in snap.docs) {
          final data = doc.data();
          final qty = (data['qty'] as num?)?.toDouble() ?? 0.0;
          sales.add(qty);
        }
      } else {
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        final localSales = appState.salesHistory
            .where((s) => s['productId'].toString() == pid)
            .toList();
        localSales.sort((a, b) => b['timestamp'].toString().compareTo(a['timestamp'].toString()));
        for (var s in localSales.take(5)) {
          sales.add((s['qty'] as num).toDouble());
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch sales history: $e');
    }

    while (sales.length < 5) {
      sales.add(0.0);
    }
    if (sales.length > 5) {
      sales = sales.sublist(0, 5);
    }

    setState(() {
      _historicalSales = sales;
      _featuresController.text = _historicalSales.map((e) => e.toStringAsFixed(1)).join(',');
    });
  }

  @override
  void dispose() {
    _featuresController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _calendarEventController.dispose();
    _leadTimeController.dispose();
    super.dispose();
  }

  Future<void> _runPrediction() async {
    setState(() => _loading = true);
    final svc = PredictiveService();

    final raw = _featuresController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final features = <double>[];
    for (var r in raw) {
      final v = double.tryParse(r);
      if (v != null) features.add(v);
    }

    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    final calendarEvent = int.tryParse(_calendarEventController.text) ?? 0;
    final leadTime = double.tryParse(_leadTimeController.text) ?? 7.0;

    double? pred;
    try {
      pred = await svc.predictWithContext(
        features,
        calendarEvent: calendarEvent,
        leadTime: leadTime,
        marketTrend: _marketTrend,
        latitude: lat,
        longitude: lon,
        fetchWeather: _fetchWeather,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prediction error: $e. Make sure python_api is running.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    setState(() {
      _lastPrediction = pred;
      _loading = false;
    });

    if (pred != null && mounted) {
      Provider.of<AppStateProvider>(context, listen: false).addNotification(
        'Demand Prediction Success',
        'Demand prediction completed successfully for ${_selectedProduct?['name'] ?? 'Product'}. Predicted value: ${pred.toStringAsFixed(3)}',
        payload: {
          'type': 'prediction',
          'product_name': _selectedProduct?['name'] ?? 'Unknown Product',
          'value': pred,
          'features': features,
          'latitude': lat,
          'longitude': lon,
          'calendar_event': calendarEvent,
          'lead_time': leadTime,
          'market_trend': _marketTrend,
          'fetch_weather': _fetchWeather,
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully predicted: ${pred.toStringAsFixed(3)}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Predictive Module')),
      body: _fetchingProducts
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Select Product', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: _selectedProduct,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _productsList.map((p) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: p,
                        child: Text(p['name'] ?? 'Unknown Product'),
                      );
                    }).toList(),
                    onChanged: (p) {
                      setState(() {
                        _selectedProduct = p;
                      });
                      _updateHistoricalSales();
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('Historical Sales Features (comma-separated)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _featuresController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'e.g. 0.0,0.0,0.0,0.0,0.0',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Note: Pre-filled with the last 5 sales quantities for the selected product.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  _sectionHeader('Weather', Icons.wb_sunny_outlined),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _fetchWeather,
                    onChanged: (v) => setState(() => _fetchWeather = v),
                    title: const Text('Fetch live weather'),
                    subtitle: const Text('Uses location below to get temperature, precipitation & humidity'),
                  ),
                  Row(children: [
                    Expanded(child: TextField(controller: _latController, decoration: const InputDecoration(labelText: 'Latitude'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _lonController, decoration: const InputDecoration(labelText: 'Longitude'))),
                  ]),
                  const SizedBox(height: 20),
                  _sectionHeader('Calendar Event', Icons.event_outlined),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _calendarEventController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Nearby calendar events count',
                      hintText: 'Number of events affecting demand',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionHeader('Lead Time', Icons.schedule_outlined),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _leadTimeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Lead time (days)',
                      hintText: 'Days until supplier delivery',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionHeader('Market Trend', Icons.trending_up),
                  const SizedBox(height: 8),
                  Slider(
                    value: _marketTrend,
                    onChanged: (v) => setState(() => _marketTrend = v),
                    min: -2.0,
                    max: 2.0,
                    divisions: 40,
                    label: _marketTrend.toStringAsFixed(2),
                  ),
                  Text(
                    'Trend score: ${_marketTrend.toStringAsFixed(2)} (-2 declining, +2 rising)',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _runPrediction,
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Get Prediction'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_lastPrediction != null)
                    Text(
                      'Last prediction: ${_lastPrediction!.toStringAsFixed(3)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
    );
  }
}
