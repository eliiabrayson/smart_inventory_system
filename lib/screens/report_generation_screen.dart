import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// Excel generation replaced with CSV fallback to avoid package type issues
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../main.dart';

class ReportGenerationScreen extends StatefulWidget {
  const ReportGenerationScreen({Key? key}) : super(key: key);

  @override
  State<ReportGenerationScreen> createState() => _ReportGenerationScreenState();
}

class _ReportGenerationScreenState extends State<ReportGenerationScreen> {
  bool _isLoading = false;
  
  Future<void> _generateInventoryReport(AppStateProvider appState, String format) async {
    setState(() => _isLoading = true);
    
    try {
      if (isFirebaseInitialized && FirebaseAuth.instance.currentUser != null) {
        final user = FirebaseAuth.instance.currentUser;
        final snapshot = await FirebaseFirestore.instance
            .collection('products')
            .where('ownerEmail', isEqualTo: user?.email)
            .get();
        
        if (format == 'pdf') {
          await _generateInventoryPDF(snapshot.docs, appState);
        } else if (format == 'excel') {
          await _generateInventoryExcel(snapshot.docs, appState);
        } else {
          await _generateInventoryCSV(snapshot.docs, appState);
        }
      } else {
        // Demo mode
        if (format == 'pdf') {
          await _generateDemoInventoryPDF(appState);
        } else if (format == 'excel') {
          await _generateDemoInventoryExcel(appState);
        } else {
          // Generate CSV for demo using empty docs
          await _generateInventoryCSV(<QueryDocumentSnapshot>[], appState);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating report: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateInventoryPDF(List<QueryDocumentSnapshot> docs, AppStateProvider appState) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Inventory Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['ID', 'Name', 'Category', 'Quantity', 'Price'],
                data: List<List<dynamic>>.generate(
                  docs.length,
                  (index) {
                    final data = docs[index].data() as Map<String, dynamic>? ?? <String, dynamic>{};
                    return [
                      docs[index].id,
                      data['name'] ?? 'Unknown',
                      data['category'] ?? 'Other',
                      data['quantity'] ?? 0,
                      '\$${data['price'] ?? 0}',
                    ];
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
    
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/inventory_report.pdf');
    await file.writeAsBytes(await pdf.save());
    
    if (mounted) {
      await Share.shareXFiles([XFile(file.path)], text: 'Inventory Report');
      appState.addReport('Inventory PDF Report', 'Generated at ${DateTime.now()}');
    }
  }

  Future<void> _generateInventoryExcel(List<QueryDocumentSnapshot> docs, AppStateProvider appState) async {
    // Excel writer omitted — fallback to CSV export for compatibility
    await _generateInventoryCSV(docs, appState);
  }

  Future<void> _generateInventoryCSV(List<QueryDocumentSnapshot> docs, AppStateProvider appState) async {
    String csv = 'id,name,category,quantity,price\n';
    
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
      final id = doc.id;
      final name = data['name'] ?? 'Unknown';
      final category = data['category'] ?? 'Other';
      final quantity = data['quantity'] ?? 0;
      final price = data['price'] ?? 0;
      
      csv += '$id,$name,$category,$quantity,$price\n';
    }
    
    final id = appState.addReport('Inventory Report', csv);
    
    if (mounted) {
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Inventory CSV Generated'),
        content: SizedBox(width: double.maxFinite, height: 300, child: SingleChildScrollView(child: Text(csv))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          TextButton(onPressed: () async { 
            await Clipboard.setData(ClipboardData(text: csv)); 
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard'))); 
          }, child: const Text('Copy')),
        ],
      ));
    }
  }

  Future<void> _generateDemoInventoryPDF(AppStateProvider appState) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Inventory Report (Demo)', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['ID', 'Name', 'Category', 'Quantity', 'Price'],
                data: [
                  ['1', 'Coffee Beans', 'Vinywaji', 12, 15.0],
                  ['2', 'Whole Milk', 'Bidhaa za Maziwa', 3, 3.5],
                ],
              ),
            ],
          );
        },
      ),
    );
    
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/inventory_report_demo.pdf');
    await file.writeAsBytes(await pdf.save());
    
    if (mounted) {
      await Share.shareXFiles([XFile(file.path)], text: 'Inventory Report (Demo)');
      appState.addReport('Inventory PDF Report (Demo)', 'Generated at ${DateTime.now()}');
    }
  }

  Future<void> _generateDemoInventoryExcel(AppStateProvider appState) async {
    // Excel writer omitted — fallback to CSV demo
    await _generateInventoryCSV(<QueryDocumentSnapshot>[], appState);
  }

  Future<void> _generateSalesReport(AppStateProvider appState, String format) async {
    setState(() => _isLoading = true);
    
    try {
      if (isFirebaseInitialized && FirebaseAuth.instance.currentUser != null) {
        final user = FirebaseAuth.instance.currentUser;
        final snapshot = await FirebaseFirestore.instance
            .collection('sales')
            .where('customerEmail', isEqualTo: user?.email)
            .orderBy('timestamp', descending: true)
            .get();
        
        if (format == 'pdf') {
          await _generateSalesPDF(snapshot.docs, appState);
        } else if (format == 'excel') {
          await _generateSalesExcel(snapshot.docs, appState);
        } else {
          await _generateSalesCSV(snapshot.docs, appState);
        }
      } else {
        // Demo mode
        if (format == 'pdf') {
          await _generateDemoSalesPDF(appState);
        } else if (format == 'excel') {
          await _generateDemoSalesExcel(appState);
        } else {
          // Generate CSV for demo using empty docs
          await _generateSalesCSV(<QueryDocumentSnapshot>[], appState);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating report: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateSalesPDF(List<QueryDocumentSnapshot> docs, AppStateProvider appState) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Sales Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['Date', 'Product', 'Qty', 'Amount', 'Customer'],
                data: List<List<dynamic>>.generate(
                  docs.length,
                  (index) {
                        final data = docs[index].data() as Map<String, dynamic>? ?? <String, dynamic>{};
                    final timestamp = data['timestamp'];
                    String dateStr = '';
                    if (timestamp is Timestamp) {
                      dateStr = timestamp.toDate().toIso8601String().split('T')[0];
                    } else {
                      dateStr = timestamp?.toString() ?? '';
                    }
                    return [
                      dateStr,
                      data['name'] ?? 'Unknown',
                      data['qty'] ?? 0,
                      '\$${data['amount'] ?? 0}',
                      data['customerEmail'] ?? '',
                    ];
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
    
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/sales_report.pdf');
    await file.writeAsBytes(await pdf.save());
    
    if (mounted) {
      await Share.shareXFiles([XFile(file.path)], text: 'Sales Report');
      appState.addReport('Sales PDF Report', 'Generated at ${DateTime.now()}');
    }
  }

  Future<void> _generateSalesExcel(List<QueryDocumentSnapshot> docs, AppStateProvider appState) async {
    // Excel writer omitted — fallback to CSV export for compatibility
    await _generateSalesCSV(docs, appState);
  }

  Future<void> _generateSalesCSV(List<QueryDocumentSnapshot> docs, AppStateProvider appState) async {
    String csv = 'date,product,qty,amount,customer_email\n';
    
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
      final timestamp = data['timestamp'];
      String dateStr = '';
      if (timestamp is Timestamp) {
        dateStr = timestamp.toDate().toIso8601String().split('T')[0];
      } else {
        dateStr = timestamp?.toString() ?? '';
      }
      final name = data['name'] ?? 'Unknown';
      final qty = data['qty'] ?? 0;
      final amount = data['amount'] ?? 0;
      final customerEmail = data['customerEmail'] ?? '';
      
      csv += '$dateStr,$name,$qty,$amount,$customerEmail\n';
    }
    
    appState.addReport('Sales Report', csv);
    
    if (mounted) {
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Sales CSV Generated'),
        content: SizedBox(width: double.maxFinite, height: 300, child: SingleChildScrollView(child: Text(csv))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          TextButton(onPressed: () async { 
            await Clipboard.setData(ClipboardData(text: csv)); 
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sales CSV copied to clipboard'))); 
          }, child: const Text('Copy')),
        ],
      ));
    }
  }

  Future<void> _generateDemoSalesPDF(AppStateProvider appState) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Sales Report (Demo)', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['Date', 'Product', 'Qty', 'Amount', 'Customer'],
                data: [
                  ['2026-08-01', 'Coffee Beans', 2, 20.0, 'user@example.com'],
                  ['2026-08-02', 'Whole Milk', 1, 3.5, 'user@example.com'],
                ],
              ),
            ],
          );
        },
      ),
    );
    
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/sales_report_demo.pdf');
    await file.writeAsBytes(await pdf.save());
    
    if (mounted) {
      await Share.shareXFiles([XFile(file.path)], text: 'Sales Report (Demo)');
      appState.addReport('Sales PDF Report (Demo)', 'Generated at ${DateTime.now()}');
    }
  }

  Future<void> _generateDemoSalesExcel(AppStateProvider appState) async {
    // Excel writer omitted — fallback to CSV demo
    await _generateSalesCSV(<QueryDocumentSnapshot>[], appState);
  }

  void _deleteReport(String reportId, AppStateProvider appState) {
    final confirmed = showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to delete this report?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    confirmed.then((value) {
      if (value == true) {
        appState.deleteReport(reportId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report deleted'), backgroundColor: Colors.green),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Report Generation')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Generate CSV reports for inventory and sales.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Text('Inventory Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF'),
                    onPressed: _isLoading ? null : () => _generateInventoryReport(appState, 'pdf'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.table_view),
                    label: const Text('Excel'),
                    onPressed: _isLoading ? null : () => _generateInventoryReport(appState, 'excel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('CSV'),
                    onPressed: _isLoading ? null : () => _generateInventoryReport(appState, 'csv'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Sales Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF'),
                    onPressed: _isLoading ? null : () => _generateSalesReport(appState, 'pdf'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.table_view),
                    label: const Text('Excel'),
                    onPressed: _isLoading ? null : () => _generateSalesReport(appState, 'excel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download_for_offline),
                    label: const Text('CSV'),
                    onPressed: _isLoading ? null : () => _generateSalesReport(appState, 'csv'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Generated Reports:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer<AppStateProvider>(
                builder: (context, appState, _) {
                  final reports = appState.reportsList;
                  if (reports.isEmpty) {
                    return const Center(child: Text('No reports generated yet'));
                  }
                  return ListView.builder(
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text('Report #${report['id'].toString().substring(0, 8)}'),
                          subtitle: Text('Generated: ${DateTime.fromMillisecondsSinceEpoch(int.parse(report['id'])).toLocal().toString().split('.')[0]}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteReport(report['id'].toString(), appState),
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Report Content'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: SingleChildScrollView(
                                    child: Text(report['content'].toString()),
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                                  TextButton(
                                    onPressed: () async {
                                      await Clipboard.setData(ClipboardData(text: report['content'].toString()));
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                                    },
                                    child: const Text('Copy'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Consumer<AppStateProvider>(builder: (context, appState, _) => ElevatedButton.icon(
              icon: const Icon(Icons.notification_important),
              label: const Text('Notify Admin (example)'),
              onPressed: () => appState.addNotification('Report Ready', 'Inventory report was generated'),
            )),
          ],
        ),
      ),
    );
  }
}
