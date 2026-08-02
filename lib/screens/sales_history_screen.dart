import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({Key? key}) : super(key: key);

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  
  Widget _buildLocalSales(AppStateProvider appState) {
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
          child: sales.isEmpty 
              ? const Center(child: Text('No sales recorded')) 
              : ListView.builder(
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
      ],
    );
  }

  Future<void> _deleteSale(String saleId, Map<String, dynamic> saleData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sale Record'),
        content: Text('Are you sure you want to delete this sale of ${saleData['name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      if (isFirebaseInitialized) {
        await FirebaseFirestore.instance.collection('sales').doc(saleId).delete();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale record deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

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
                      .where('customerEmail', isEqualTo: FirebaseAuth.instance.currentUser?.email)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      print('Firestore error: ${snap.error}');
                      // Fallback to local state on error
                      return _buildLocalSales(appState);
                    }
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      // Show local sales if no Firestore data
                      return _buildLocalSales(appState);
                    }
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
                              return Dismissible(
                                key: Key(m['id'].toString()),
                                direction: DismissDirection.endToStart,
                                onDismissed: (direction) => _deleteSale(m['id'].toString(), m),
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                child: ListTile(
                                  title: Text(m['name']?.toString() ?? 'Unknown'),
                                  subtitle: Text(ts.toLocal().toString().split(' ').first),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('x${m['qty']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text('\$${((m['amount'] as num?)?.toString() ?? '0')}', style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _deleteSale(m['id'].toString(), m),
                                      ),
                                    ],
                                  ),
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
                            return Dismissible(
                              key: Key(m['id'].toString()),
                              direction: DismissDirection.endToStart,
                              onDismissed: (direction) {
                                setState(() {
                                  sales.removeAt(i);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sale record deleted (demo)'), backgroundColor: Colors.green),
                                );
                              },
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              child: ListTile(
                                title: Text(m['name']?.toString() ?? 'Unknown'),
                                subtitle: Text(ts.toLocal().toString().split(' ').first),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('x${m['qty']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('\$${((m['amount'] as num?)?.toString() ?? '0')}', style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          sales.removeAt(i);
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Sale record deleted (demo)'), backgroundColor: Colors.green),
                                        );
                                      },
                                    ),
                                  ],
                                ),
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
