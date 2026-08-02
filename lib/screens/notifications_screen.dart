import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../main.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedCategory = 'all';

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.themeMode == ThemeMode.dark;
    final notifications = appState.notifications;

    final filteredNotifications = _selectedCategory == 'all'
        ? notifications
        : notifications.where((n) => n['category'] == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _selectedCategory = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'general', child: Text('General')),
              const PopupMenuItem(value: 'prediction', child: Text('Predictions')),
              const PopupMenuItem(value: 'recommendation', child: Text('Recommendations')),
              const PopupMenuItem(value: 'report', child: Text('Reports')),
              const PopupMenuItem(value: 'alert', child: Text('Alerts')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedCategory != 'all')
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Chip(
                label: Text('Category: ${_selectedCategory.toUpperCase()}'),
                onDeleted: () => setState(() => _selectedCategory = 'all'),
                deleteIcon: const Icon(Icons.close),
              ),
            ),
          Expanded(
            child: filteredNotifications.isEmpty
                ? Center(
                    child: Text(
                      'No notifications',
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredNotifications.length,
                    itemBuilder: (context, index) {
                      final notification = filteredNotifications[index];
                      final isRead = notification['read'] ?? false;
                      final category = notification['category'] ?? 'general';

                      return Dismissible(
                        key: Key(notification['ts'].toString()),
                        onDismissed: (direction) {
                          appState.deleteNotification(index);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notification deleted')),
                          );
                        },
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getCategoryColor(category).withOpacity(0.2),
                              child: Icon(_getCategoryIcon(category), color: _getCategoryColor(category)),
                            ),
                            title: Text(
                              notification['title'] ?? '',
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification['body'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTimestamp(notification['ts']),
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                isRead ? Icons.mark_email_unread : Icons.mark_email_read,
                                color: Colors.blueAccent,
                              ),
                              onPressed: () {
                                // Toggle read status
                                notification['read'] = !isRead;
                                appState.notifyListeners();
                              },
                            ),
                            onTap: () => _showNotificationDetail(notification),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'prediction':
        return Colors.blueAccent;
      case 'recommendation':
        return Colors.green;
      case 'report':
        return Colors.orange;
      case 'alert':
        return Colors.red;
      default:
        return Colors.teal;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'prediction':
        return Icons.show_chart;
      case 'recommendation':
        return Icons.shopping_cart;
      case 'report':
        return Icons.description;
      case 'alert':
        return Icons.warning;
      default:
        return Icons.info_outline;
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts is DateTime) {
      final now = DateTime.now();
      final difference = now.difference(ts);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';

      return ts.toString().split('.')[0];
    }
    return ts?.toString() ?? '';
  }

  void _showNotificationDetail(Map<String, dynamic> notification) {
    final payload = notification['payload'] as Map<String, dynamic>?;
    final reportContent = payload != null && payload['report_id'] != null
        ? Provider.of<AppStateProvider>(context, listen: false).getReport(payload['report_id'])
        : null;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: _getCategoryColor(notification['category'] ?? 'general').withOpacity(0.1),
                        child: Icon(_getCategoryIcon(notification['category'] ?? 'general'), color: _getCategoryColor(notification['category'] ?? 'general')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification['title'] ?? '',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(notification['ts']),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    notification['body'] ?? '',
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  if (reportContent != null) _buildReportView(context, reportContent),
                  if (payload != null && payload['type'] == 'prediction')
                    _buildPredictionView(context, payload),
                  if (payload != null && payload['type'] == 'batch_forecast')
                    _buildBatchForecastView(context, payload),
                  if (payload != null && payload['type'] == 'recommendation')
                    _buildRecommendationView(context, payload),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionView(BuildContext context, Map<String, dynamic> payload) {
    final val = payload['predicted_value'] as num?;
    final features = payload['features'];
    final lat = payload['latitude'];
    final lon = payload['longitude'];
    final fetchWeather = payload['fetch_weather'];
    final event = payload['calendar_event'];
    final lead = payload['lead_time'];
    final trend = payload['market_trend'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'PREDICTED DEMAND',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          val != null ? val.toStringAsFixed(3) : 'N/A',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBatchForecastView(BuildContext context, Map<String, dynamic> payload) {
    final results = payload['results'] as List?;
    if (results == null || results.isEmpty) {
      return const Text('No batch forecast details available.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'Batch Forecast Details:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: results.length,
          itemBuilder: (context, idx) {
            final item = results[idx] as Map<String, dynamic>;
            final name = item['name'] ?? 'Unknown Product';
            final qty = item['qty'] ?? 0;
            final prediction = item['prediction'] as num?;
            final suggested = item['suggested'] ?? 0;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Stock: $qty', style: const TextStyle(fontSize: 12)),
                        Text(
                          'Pred: ${prediction != null ? prediction.toStringAsFixed(2) : 'N/A'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Reorder: $suggested',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: suggested > 0 ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecommendationView(BuildContext context, Map<String, dynamic> payload) {
    final items = payload['items'] as List?;
    if (items == null || items.isEmpty) {
      return const Text('No recommendations available.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'Stock Recommendations:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, idx) {
            final item = items[idx] as Map<String, dynamic>;
            final name = item['name'] ?? 'Unknown Product';
            final predictedSales = (item['prediction'] is num) ? (item['prediction'] as num).round() : 0;
            final currentStock = (item['qty'] is int) ? item['qty'] as int : (item['qty'] as num?)?.toInt() ?? 0;
            final suggested = (item['suggested'] is int) ? item['suggested'] as int : (item['suggested'] as num?)?.toInt() ?? 0;

            if (suggested <= 0 && predictedSales <= currentStock) return const SizedBox.shrink();

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.green.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shopping_cart, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Predicted Sales', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(
                              '$predictedSales units',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('Current Stock', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(
                              '$currentStock units',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Order', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(
                              '$suggested units',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (suggested > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Order $suggested units to meet predicted demand of $predictedSales',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReportView(BuildContext context, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Report Content',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: content));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            content,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }
  }
