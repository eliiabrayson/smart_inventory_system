import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _salesData = [];
  List<Map<String, dynamic>> _categoryData = [];
  List<Map<String, dynamic>> _topProducts = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      if (isFirebaseInitialized && FirebaseAuth.instance.currentUser != null) {
        final user = FirebaseAuth.instance.currentUser;
        
        // Load products stats
        final productsSnap = await FirebaseFirestore.instance
            .collection('products')
            .where('ownerEmail', isEqualTo: user?.email)
            .get();
        
        final totalProducts = productsSnap.docs.length;
        int lowStock = 0;
        int outOfStock = 0;
        double totalValue = 0;
        int totalQuantity = 0;
        
        Map<String, int> categoryCounts = {};
        
        for (var doc in productsSnap.docs) {
          final data = doc.data();
          final quantity = (data['quantity'] is num) ? (data['quantity'] as num).toInt() : 0;
          final price = (data['price'] is num) ? (data['price'] as num).toDouble() : 0.0;
          final category = data['category']?.toString() ?? 'Other';
          
          totalValue += quantity * price;
          totalQuantity += quantity;
          
          if (quantity == 0) outOfStock++;
          else if (quantity < 5) lowStock++;
          
          categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
        }
        
        // Load sales data for last 7 days
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        final salesSnap = await FirebaseFirestore.instance
            .collection('sales')
            .where('customerEmail', isEqualTo: user?.email)
            .where('timestamp', isGreaterThanOrEqualTo: sevenDaysAgo)
            .orderBy('timestamp', descending: true)
            .get();
        
        double totalRevenue = 0;
        int totalSales = 0;
        Map<String, int> productSales = {};
        Map<String, double> dailyRevenue = {};
        
        for (var doc in salesSnap.docs) {
          final data = doc.data();
          final amount = (data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0;
          final qty = (data['qty'] is num) ? (data['qty'] as num).toInt() : 0;
          final name = data['name']?.toString() ?? 'Unknown';
          final timestamp = data['timestamp'];
          
          totalRevenue += amount;
          totalSales += qty;
          
          productSales[name] = (productSales[name] ?? 0) + qty;
          
          if (timestamp is Timestamp) {
            final date = timestamp.toDate();
            final dateKey = DateFormat('yyyy-MM-dd').format(date);
            dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0) + amount;
          }
        }
        
        // Get top 5 products
        final sortedProducts = productSales.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        final topProductsList = sortedProducts.take(5).map((e) => {
          'name': e.key,
          'sales': e.value,
        }).toList();
        final topSellingProduct = topProductsList.isNotEmpty ? topProductsList.first : {'name': 'No sales yet', 'sales': 0};
        final averageStock = totalProducts > 0 ? (totalQuantity / totalProducts).round() : 0;
        final categoryCount = categoryCounts.length;
        
        // Convert category data for pie chart
        final categoryList = categoryCounts.entries.map((e) => {
          'category': e.key,
          'count': e.value,
        }).toList();
        
        // Convert daily revenue for line chart
        final revenueList = dailyRevenue.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        
        final salesChartData = revenueList.map((e) => {
          'date': e.key,
          'revenue': e.value,
        }).toList();
        
        setState(() {
          _stats = {
            'totalProducts': totalProducts,
            'lowStock': lowStock,
            'outOfStock': outOfStock,
            'totalValue': totalValue,
            'totalRevenue': totalRevenue,
            'totalSales': totalSales,
            'averageStock': averageStock,
            'categoryCount': categoryCount,
            'topSellingProduct': topSellingProduct,
          };
          _salesData = salesChartData;
          _categoryData = categoryList;
          _topProducts = topProductsList;
          _isLoading = false;
        });
      } else {
        // Demo mode
        setState(() {
          _stats = {
            'totalProducts': 25,
            'lowStock': 5,
            'outOfStock': 2,
            'totalValue': 1500.0,
            'totalRevenue': 850.0,
            'totalSales': 45,
            'averageStock': 6,
            'categoryCount': 5,
            'topSellingProduct': {'name': 'Coffee Beans', 'sales': 15},
          };
          _salesData = [
            {'date': '2026-08-01', 'revenue': 120.0},
            {'date': '2026-08-02', 'revenue': 95.0},
            {'date': '2026-08-03', 'revenue': 150.0},
            {'date': '2026-08-04', 'revenue': 85.0},
            {'date': '2026-08-05', 'revenue': 200.0},
            {'date': '2026-08-06', 'revenue': 110.0},
            {'date': '2026-08-07', 'revenue': 90.0},
          ];
          _categoryData = [
            {'category': 'Vinywaji', 'count': 8},
            {'category': 'Bidhaa za Maziwa', 'count': 6},
            {'category': 'Chakula na Nafaka', 'count': 5},
            {'category': 'Elektroniki', 'count': 3},
            {'category': 'Nyingine', 'count': 3},
          ];
          _topProducts = [
            {'name': 'Coffee Beans', 'sales': 15},
            {'name': 'Whole Milk', 'sales': 12},
            {'name': 'Bread', 'sales': 8},
            {'name': 'Rice', 'sales': 6},
            {'name': 'Sugar', 'sales': 4},
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsCards(appState, isDark),
                    const SizedBox(height: 24),
                    _buildSalesTrendChart(isDark),
                    const SizedBox(height: 24),
                    _buildCategoryDistributionChart(isDark),
                    const SizedBox(height: 24),
                    _buildTopProductsList(isDark),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsCards(AppStateProvider appState, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Total Products',
              '${_stats['totalProducts'] ?? 0}',
              Icons.inventory_2,
              Colors.blue,
              isDark,
            ),
            _buildStatCard(
              'Low Stock',
              '${_stats['lowStock'] ?? 0}',
              Icons.warning,
              Colors.orange,
              isDark,
            ),
            _buildStatCard(
              'Out of Stock',
              '${_stats['outOfStock'] ?? 0}',
              Icons.error,
              Colors.red,
              isDark,
            ),
            _buildStatCard(
              'Total Value',
              '\$${(_stats['totalValue'] ?? 0).toStringAsFixed(2)}',
              Icons.attach_money,
              Colors.green,
              isDark,
            ),
            _buildStatCard(
              'Revenue (7d)',
              '\$${(_stats['totalRevenue'] ?? 0).toStringAsFixed(2)}',
              Icons.trending_up,
              Colors.purple,
              isDark,
            ),
            _buildStatCard(
              'Sales (7d)',
              '${_stats['totalSales'] ?? 0}',
              Icons.shopping_cart,
              Colors.teal,
              isDark,
            ),
            _buildStatCard(
              'Avg. Stock',
              '${_stats['averageStock'] ?? 0}',
              Icons.storage,
              Colors.indigo,
              isDark,
            ),
            _buildStatCard(
              'Categories',
              '${_stats['categoryCount'] ?? 0}',
              Icons.category,
              Colors.brown,
              isDark,
            ),
            _buildStatCard(
              'Top Selling Product',
              '${(_stats['topSellingProduct'] as Map<String, dynamic>?)?['name'] ?? 'No sales yet'}',
              Icons.star,
              Colors.amber,
              isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Card(
      elevation: 2,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTrendChart(bool isDark) {
    return Card(
      elevation: 2,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Trend (Last 7 Days)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _salesData.isEmpty
                  ? const Center(child: Text('No sales data available'))
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 50,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.withOpacity(0.3),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < _salesData.length) {
                                  final dateStr = _salesData[index]['date'] as String;
                                  final date = DateTime.parse(dateStr);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      DateFormat('MM/dd').format(date),
                                      style: TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                              reservedSize: 30,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '\$${value.toInt()}',
                                  style: TextStyle(fontSize: 10, color: Colors.grey),
                                );
                              },
                              reservedSize: 40,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _salesData.asMap().entries.map((entry) {
                              final index = entry.key;
                              final revenue = (entry.value['revenue'] as num).toDouble();
                              return FlSpot(index.toDouble(), revenue);
                            }).toList(),
                            isCurved: true,
                            color: Colors.blueAccent,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blueAccent.withOpacity(0.2),
                            ),
                          ),
                        ],
                        minY: 0,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDistributionChart(bool isDark) {
    return Card(
      elevation: 2,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product Categories',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _categoryData.isEmpty
                  ? const Center(child: Text('No category data available'))
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: _categoryData.asMap().entries.map((entry) {
                          final index = entry.key;
                          final category = entry.value['category'] as String;
                          final count = entry.value['count'] as int;
                          final total = _categoryData.fold<int>(0, (sum, item) => sum + (item['count'] as int));
                          final percentage = (count / total * 100).toStringAsFixed(1);
                          
                          final colors = [
                            Colors.blue,
                            Colors.green,
                            Colors.orange,
                            Colors.purple,
                            Colors.teal,
                            Colors.red,
                            Colors.amber,
                            Colors.cyan,
                          ];
                          
                          return PieChartSectionData(
                            value: count.toDouble(),
                            title: '$percentage%',
                            color: colors[index % colors.length],
                            radius: 50,
                            titleStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categoryData.asMap().entries.map((entry) {
                final index = entry.key;
                final category = entry.value['category'] as String;
                final count = entry.value['count'] as int;
                
                final colors = [
                  Colors.blue,
                  Colors.green,
                  Colors.orange,
                  Colors.purple,
                  Colors.teal,
                  Colors.red,
                  Colors.amber,
                  Colors.cyan,
                ];
                
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[index % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$category ($count)',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsList(bool isDark) {
    return Card(
      elevation: 2,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Selling Products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            _topProducts.isEmpty
                ? const Center(child: Text('No sales data available'))
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _topProducts.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final product = _topProducts[index];
                      final name = product['name'] as String;
                      final sales = product['sales'] as int;
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent.withOpacity(0.2),
                          child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        title: Text(name, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                        trailing: Text(
                          '$sales sold',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
