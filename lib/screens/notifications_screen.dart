import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Consumer<AppStateProvider>(builder: (context, appState, _) {
        final notes = appState.notifications;
        if (notes.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('No notifications'), const SizedBox(height: 12), ElevatedButton(onPressed: () => appState.addNotification('Welcome', 'Notifications enabled'), child: const Text('Generate sample'))]));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: notes.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, i) {
            final n = notes[i];
            final read = (n['read'] is bool) ? n['read'] as bool : false;
            String title = (n['title'] ?? '').toString();
            String body = (n['body'] ?? '').toString();
            // Normalize timestamp display
            DateTime ts;
            if (n['ts'] is DateTime) {
              ts = n['ts'] as DateTime;
            } else {
              try {
                ts = DateTime.parse(n['ts'].toString());
              } catch (_) {
                ts = DateTime.now();
              }
            }
            return ListTile(
              leading: Icon(read ? Icons.mark_email_read : Icons.mark_email_unread, color: read ? Colors.grey : Colors.blueAccent),
              title: Text(title),
              subtitle: Text(body),
              trailing: Text(ts.toLocal().toString().split('.').first, style: const TextStyle(fontSize: 10)),
              onTap: () {
                appState.markNotificationRead(i);
                final payload = n['payload'] as Map<String, dynamic>?;
                if (payload != null && payload['report_id'] != null) {
                  final rid = payload['report_id'].toString();
                  final content = appState.getReport(rid);
                  showDialog(context: context, builder: (ctx) => AlertDialog(
                    title: const Text('Report Preview'),
                    content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Text(content ?? 'Report not found'))),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                  ));
                }
              },
            );
          },
        );
      }),
    );
  }
}
