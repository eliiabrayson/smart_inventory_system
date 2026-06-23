import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SalesHistoryScreen extends StatelessWidget {
  const SalesHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final useFirestore = isFirebaseInitialized && FirebaseAuth.instance.currentUser != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Sales History')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (useFirestore)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('sales')
                      .where('ownerEmail', isEqualTo: FirebaseAuth.instance.currentUser?.email)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs;
                    final sales = docs.map((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return {
                        'id': d.id,
                        'name': data['name'] ?? 'Unknown',
                        'qty': data['qty'] ?? 0,
                        'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
                        'timestamp': data['timestamp'] is Timestamp ? (data['timestamp'] as Timestamp).toDate().toIso8601String() : (data['timestamp']?.toString() ?? ''),
                      };
                    }).toList();
                    final total = sales.fold<int>(0, (s, e) => s + (e['qty'] as int));
                    final revenue = sales.fold<double>(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0.0));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Total items sold: $total', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Revenue: USD ${revenue.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green)),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: sales.length,
                            itemBuilder: (context, i) {
                              final m = sales[i];
                              final ts = DateTime.tryParse(m['timestamp']?.toString() ?? '') ?? DateTime.now();
                              return ListTile(
                                title: Text(m['name']?.toString() ?? 'Unknown'),
                                subtitle: Text(ts.toLocal().toString().split(' ').first),
                                trailing: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('x${m['qty']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('\$${((m['amount'] as num?)?.toString() ?? '0')}', style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        Consumer<AppStateProvider>(builder: (context, appState, _) => ElevatedButton.icon(
                          onPressed: () => appState.addNotification('Sales Report', 'A sales report was viewed'),
                          icon: const Icon(Icons.notification_add),
                          label: const Text('Notify Admin'),
                        )),
                      ],
                    );
                  },
                ),
              )
            else
              Expanded(
                child: Builder(builder: (context) {
                  final sales = appState.salesHistory;
                  final total = sales.fold<int>(0, (s, e) => s + (e['qty'] as int));
                  final revenue = sales.fold<double>(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0.0));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Total items sold: $total', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Revenue: USD ${revenue.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green)),
                      const SizedBox(height: 12),
                      Expanded(
                        child: sales.isEmpty ? const Center(child: Text('No sales recorded')) : ListView.builder(
                          itemCount: sales.length,
                          itemBuilder: (context, i) {
                            final m = sales[i];
                            final ts = DateTime.tryParse(m['timestamp']?.toString() ?? '') ?? DateTime.now();
                            return ListTile(
                              title: Text(m['name']?.toString() ?? 'Unknown'),
                              subtitle: Text(ts.toLocal().toString().split(' ').first),
                              trailing: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('x${m['qty']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('\$${((m['amount'] as num?)?.toString() ?? '0')}', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Consumer<AppStateProvider>(builder: (context, appState, _) => ElevatedButton.icon(
                        onPressed: () => appState.addNotification('Sales Report', 'A sales report was viewed'),
                        icon: const Icon(Icons.notification_add),
                        label: const Text('Notify Admin'),
                      )),
                    ],
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}
