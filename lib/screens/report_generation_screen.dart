import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class ReportGenerationScreen extends StatelessWidget {
  const ReportGenerationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Generation')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Generate CSV reports for inventory and sales.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Generate Inventory CSV'),
              onPressed: () async {
                // Generate sample CSV from mock/demo data
                final csv = 'id,name,category,quantity\n1,Coffee Beans,Vinywaji,12\n2,Whole Milk,Bidhaa za Maziwa,3\n';
                // Save report in app state and show preview
                final appState = Provider.of<AppStateProvider>(context, listen: false);
                final id = appState.addReport('Inventory Report', csv);
                // Show preview dialog
                showDialog(context: context, builder: (ctx) => AlertDialog(
                  title: const Text('Inventory CSV Generated'),
                  content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Text(csv))),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                    TextButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: csv)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard'))); }, child: const Text('Copy')),
                  ],
                ));
                // Notification already created via addReport
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.download_for_offline),
              label: const Text('Generate Sales CSV'),
              onPressed: () async {
                final csv = 'date,product,qty,amount\n2026-06-01,Coffee Beans,2,20\n2026-06-02,Whole Milk,1,5\n';
                final appState = Provider.of<AppStateProvider>(context, listen: false);
                appState.addReport('Sales Report', csv);
                showDialog(context: context, builder: (ctx) => AlertDialog(
                  title: const Text('Sales CSV Generated'),
                  content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Text(csv))),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')), TextButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: csv)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sales CSV copied to clipboard'))); }, child: const Text('Copy'))],
                ));
              },
            ),
            const SizedBox(height: 20),
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
