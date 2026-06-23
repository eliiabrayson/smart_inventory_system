import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/predictive_service.dart';
import 'predictive_module_screen.dart';
import 'report_generation_screen.dart';
import 'reorder_module_screen.dart';
import 'sales_history_screen.dart';
import 'notifications_screen.dart';
import 'module_card.dart';

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
      appBar: AppBar(
        title: const Text('Smart Modules'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Left column with module cards
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 260,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        SizedBox(width: double.infinity, child: ModuleCard(
                          title: 'Sales History',
                          subtitle: 'View recent sales and trends',
                          icon: Icons.history,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesHistoryScreen())),
                        )),
                        const SizedBox(height: 8),
                        SizedBox(width: double.infinity, child: ModuleCard(
                          title: 'Predictive Module',
                          subtitle: 'On-demand demand forecasting (uses sales history)',
                          icon: Icons.show_chart,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PredictiveModuleScreen())),
                        )),
                        const SizedBox(height: 12),
                        SizedBox(width: double.infinity, child: ModuleCard(
                          title: 'Report Generation',
                          subtitle: 'Export inventory & sales CSV',
                          icon: Icons.insert_chart_outlined,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportGenerationScreen())),
                        )),
                        const SizedBox(height: 12),
                        SizedBox(width: double.infinity, child: ModuleCard(
                          title: 'Reorder Helper',
                          subtitle: 'Suggest reorder quantities',
                          icon: Icons.shopping_cart_checkout,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReorderModuleScreen())),
                        )),
                        const SizedBox(height: 12),
                        SizedBox(width: double.infinity, child: ModuleCard(
                          title: 'Reorder Helper',
                          subtitle: 'Suggest reorder quantities',
                          icon: Icons.shopping_cart_checkout,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReorderModuleScreen())),
                        )),
                        const SizedBox(height: 12),
                        SizedBox(width: double.infinity, child: ModuleCard(
                          title: 'Notifications',
                          subtitle: 'View system alerts and reports',
                          icon: Icons.notifications,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                        )),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // Right side: details / actions
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loading ? null : _getPrediction,
                          child: _loading ? const CircularProgressIndicator() : const Text('Run Quick Prediction'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.analytics_rounded),
                          label: const Text('Run Batch Forecast'),
                          onPressed: () async {
                            // Collect items from Firestore or use demo list
                            List<Map<String, dynamic>> items = [];
                            if (FirebaseAuth.instance.currentUser != null) {
                              final snap = await FirebaseFirestore.instance.collection('products').where('ownerEmail', isEqualTo: FirebaseAuth.instance.currentUser!.email).get();
                              items = snap.docs.map((d) => {...(d.data() as Map<String, dynamic>), 'id': d.id}).toList();
                            } else {
                              items = [
                                {'id': 'demo1', 'name': 'Coffee Beans', 'quantity': 12},
                                {'id': 'demo2', 'name': 'Whole Milk', 'quantity': 3},
                              ];
                            }
                            if (items.isEmpty) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items to forecast')));
                              return;
                            }
                            final month = DateTime.now().month;
                            String season = 'spring';
                            if (month >= 3 && month <= 5) season = 'spring';
                            if (month >= 6 && month <= 8) season = 'summer';
                            if (month >= 9 && month <= 11) season = 'autumn';
                            if (month == 12 || month <= 2) season = 'winter';
                            final lat = -1.2921;
                            final lon = 36.8219;
                            final body = {
                              'items': items.map((it) {
                                final qty = (it['quantity'] is int) ? (it['quantity'] as int).toDouble() : (double.tryParse(it['quantity']?.toString() ?? '0') ?? 0.0);
                                final features = [qty / 100.0, 0.0, 0.0, 0.0, 0.0];
                                return {
                                  'features': features,
                                  'season': season,
                                  'latitude': lat,
                                  'longitude': lon,
                                  'fetch_weather': true,
                                  'country_code': 'KE',
                                };
                              }).toList()
                            };
                            final url = Uri.parse('http://127.0.0.1:8000/forecast_batch');
                            try {
                              final resp = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)).timeout(const Duration(seconds: 20));
                              if (resp.statusCode == 200) {
                                final map = jsonDecode(resp.body) as Map<String, dynamic>;
                                final results = (map['results'] as List).cast<Map<String, dynamic>>();
                                final paired = <Map<String, dynamic>>[];
                                for (var i = 0; i < items.length; i++) {
                                  final it = items[i];
                                  final pred = results.length > i ? (results[i]['prediction'] as num).toDouble() : 0.0;
                                  final qty = (it['quantity'] is int) ? it['quantity'] as int : int.tryParse(it['quantity']?.toString() ?? '0') ?? 0;
                                  final suggested = (pred - qty).round();
                                  paired.add({'id': it['id'], 'name': it['name'] ?? 'Unknown', 'qty': qty, 'prediction': pred, 'suggested': suggested});
                                }
                                if (mounted) {
                                  showDialog(context: context, builder: (ctx) => AlertDialog(
                                    title: const Text('Batch Forecast'),
                                    content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: paired.map((p) => ListTile(title: Text(p['name']), subtitle: Text('Current: ${p['qty']}, Predicted: ${p['prediction'].toStringAsFixed(2)}'), trailing: Text('Reorder: ${p['suggested']}'))).toList()))),
                                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                                  ));
                                }
                              } else {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Forecast failed: ${resp.statusCode}')));
                              }
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Forecast error: $e')));
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        if (_lastPrediction != null)
                          Text('Last prediction: ${_lastPrediction!.toStringAsFixed(3)}'),
                        if (_lastPrediction == null)
                          const Text('No predictions yet'),
                        const SizedBox(height: 16),
                        // Placeholder for module details or help text
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                              Text('Module Details', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              Text('Select a module on the left to open it. Use "Run Quick Prediction" to get a demand estimate.'),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Bottom actions removed (duplicate). Use the right-side panel for actions.
          ],
          ),
        ),
      ),
    );
  }
}
