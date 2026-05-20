import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'services/csv_service.dart';
import 'scanner_screen.dart';

class InventoryDashboard extends StatefulWidget {
  const InventoryDashboard({super.key});

  @override
  State<InventoryDashboard> createState() => _InventoryDashboardState();
}

class _InventoryDashboardState extends State<InventoryDashboard> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedCategory = "Zote";
  String _sortBy = "Name";

  final List<String> _categoriesEn = ["All", "Beverages", "Pantry/Grains", "Produce", "Meat", "Dairy", "Electronics", "Household", "Beauty/Health", "Clothing", "Hardware", "Stationery", "Pharmacy", "Other"];
  final List<String> _categoriesSw = ["Zote", "Vinywaji", "Chakula na Nafaka", "Matunda na Mboga", "Nyama na Samaki", "Bidhaa za Maziwa", "Elektroniki", "Vifaa vya Nyumbani", "Urembo na Afya", "Mavazi", "Vifaa vya Ujenzi", "Vifaa vya Ofisi", "Dawa", "Nyingine"];

  // Demo data for fallback
  final List<Map<String, dynamic>> _mockItems = [
    {'id': '1', 'name': 'Coffee Beans', 'quantity': 12, 'category': 'Vinywaji'},
    {'id': '2', 'name': 'Whole Milk', 'quantity': 3, 'category': 'Bidhaa za Maziwa'},
  ];

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.themeMode == ThemeMode.dark;
    final categories = appState.locale.languageCode == 'sw' ? _categoriesSw : _categoriesEn;
    
    if (!categories.contains(_selectedCategory)) {
      _selectedCategory = categories[0];
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(appState.translate('app_name'), style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(appState.locale.languageCode == 'en' ? "Inventory Pro Suite" : "Zana za Ghala Mahiri", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showSortOptions(appState),
            tooltip: appState.translate('tooltip_sort'),
            icon: const Icon(Icons.sort_rounded, color: Colors.blueAccent),
          ),
          IconButton(
            tooltip: appState.translate('tooltip_settings'),
            onPressed: () => _showSettings(context, appState), 
            icon: const Icon(Icons.settings_outlined, color: Colors.blueAccent),
          ),
          IconButton(
            tooltip: appState.translate('tooltip_logout'),
            onPressed: () => FirebaseAuth.instance.signOut(), 
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isFirebaseInitialized ? _buildFirebaseContent(appState, categories) : _buildDemoContent(appState, categories),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: appState.translate('tooltip_add'),
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(appState.translate('add_product'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showItemForm(context, appState),
      ),
    );
  }

  void _showSortOptions(AppStateProvider appState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(appState.translate('tooltip_sort'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha_rounded),
              title: const Text("Name"),
              trailing: _sortBy == "Name" ? const Icon(Icons.check_circle, color: Colors.blueAccent) : null,
              onTap: () {
                setState(() => _sortBy = "Name");
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.numbers_rounded),
              title: const Text("Quantity"),
              trailing: _sortBy == "Quantity" ? const Icon(Icons.check_circle, color: Colors.blueAccent) : null,
              onTap: () {
                setState(() => _sortBy = "Quantity");
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context, AppStateProvider appState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(appState.translate('settings'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SwitchListTile(
              title: Text(appState.translate('theme')),
              secondary: const Icon(Icons.dark_mode_outlined),
              value: appState.themeMode == ThemeMode.dark,
              onChanged: (val) => appState.toggleTheme(),
            ),
            const Divider(),
            ListTile(
              title: Text(appState.translate('language')),
              leading: const Icon(Icons.language_rounded),
              trailing: DropdownButton<String>(
                value: appState.locale.languageCode,
                onChanged: (String? newValue) {
                  if (newValue != null) appState.setLanguage(newValue);
                },
                items: const [
                  DropdownMenuItem(value: 'en', child: Text("English")),
                  DropdownMenuItem(value: 'sw', child: Text("Kiswahili")),
                ],
              ),
            ),
            const Divider(),
            // Bulk Import Feature
            ListTile(
              title: const Text("Bulk Import (CSV)"),
              subtitle: const Text("Upload multiple products at once"),
              leading: const Icon(Icons.upload_file_rounded, color: Colors.green),
              onTap: () {
                Navigator.pop(context);
                _handleBulkUpload();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBulkUpload() async {
    final products = await CsvService.pickAndParseCsv();
    if (products != null && products.isNotEmpty) {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text("Importing products...")]), duration: Duration(seconds: 1)),
        );
      }

      int count = 0;
      for (var product in products) {
        await _saveItemSilently(
          name: product['name'],
          category: product['category'],
          qty: product['quantity'],
        );
        count++;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Successfully imported $count products!"), backgroundColor: Colors.green),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No products found. Use format: Name, Category, Qty"), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _handleBarcodeScan(AppStateProvider appState) async {
    final String? scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      if (isFirebaseInitialized && FirebaseAuth.instance.currentUser != null) {
        // Cloud Mode Search
        final user = FirebaseAuth.instance.currentUser;
        final query = await FirebaseFirestore.instance
            .collection('products')
            .where('ownerEmail', isEqualTo: user?.email)
            .where('barcode', isEqualTo: scannedCode)
            .get();

        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;
          if (mounted) _showItemForm(context, appState, itemData: doc.data(), itemId: doc.id);
        } else {
          if (mounted) _showItemForm(context, appState, initialBarcode: scannedCode);
        }
      } else {
        // Demo Mode Search
        final localMatch = _mockItems.cast<Map<String, dynamic>?>().firstWhere(
          (i) => i?['barcode'] == scannedCode,
          orElse: () => null,
        );

        if (localMatch != null) {
          if (mounted) _showItemForm(context, appState, itemData: localMatch, itemId: localMatch['id']);
        } else {
          if (mounted) _showItemForm(context, appState, initialBarcode: scannedCode);
        }
      }
    }
  }

  Widget _buildFirebaseContent(AppStateProvider appState, List<String> categories) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').where('ownerEmail', isEqualTo: user?.email).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        final allData = docs.map((d) => {...(d.data() as Map<String, dynamic>), 'id': d.id}).toList();
        return _buildMainLayout(allData, appState, categories);
      },
    );
  }

  Widget _buildDemoContent(AppStateProvider appState, List<String> categories) {
    return _buildMainLayout(_mockItems, appState, categories);
  }

  Widget _buildMainLayout(List<Map<String, dynamic>> items, AppStateProvider appState, List<String> categories) {
    int total = items.length;
    int low = items.where((i) => (i['quantity'] ?? 0) < 5 && (i['quantity'] ?? 0) > 0).length;
    int out = items.where((i) => (i['quantity'] ?? 0) == 0).length;

    var filtered = items.where((item) {
      final matchesSearch = item['name'].toString().toLowerCase().contains(_searchQuery);
      final matchesCategory = _selectedCategory == categories[0] || item['category'] == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    if (_sortBy == "Name") {
      filtered.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    } else if (_sortBy == "Quantity") {
      filtered.sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));
    }

    return Column(
      children: [
        _buildStatsSummary(total, low, out, appState),
        _buildSearchBar(appState),
        _buildCategoryFilter(categories, appState),
        Expanded(
          child: filtered.isEmpty ? _buildEmptyState(appState) : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (context, index) => _buildItemCard(filtered[index], filtered[index]['id'], appState),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSummary(int total, int low, int out, AppStateProvider appState) {
    final isDark = appState.themeMode == ThemeMode.dark;
    return Container(
      height: 100,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.only(bottom: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildMiniStat(appState.translate('total_items'), total.toString(), Icons.inventory_2_rounded, Colors.blue),
          _buildMiniStat(appState.translate('low_stock'), low.toString(), Icons.trending_down_rounded, Colors.orange),
          _buildMiniStat(appState.translate('out_stock'), out.toString(), Icons.error_rounded, Colors.red),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 0.5, color: Colors.blueGrey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppStateProvider appState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: appState.translate('search'),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                filled: true,
                fillColor: appState.themeMode == ThemeMode.dark ? const Color(0xFF1E1E1E) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: appState.translate('tooltip_scan'),
            onPressed: () => _handleBarcodeScan(appState),
            icon: const Icon(Icons.barcode_reader),
            style: IconButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(List<String> categories, AppStateProvider appState) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(cat, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedCategory = cat),
              selectedColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(AppStateProvider appState) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(appState.locale.languageCode == 'en' ? "No products found" : "Hakuna bidhaa", style: const TextStyle(color: Colors.blueGrey, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> data, String id, AppStateProvider appState) {
    int qty = data['quantity'] ?? 0;
    Color statusColor = qty == 0 ? Colors.red : (qty < 5 ? Colors.orange : Colors.green);
    final isDark = appState.themeMode == ThemeMode.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        onTap: () => _showItemForm(context, appState, itemData: data, itemId: id),
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50, height: 50,
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15)),
          child: Icon(Icons.inventory_2_rounded, color: statusColor),
        ),
        title: Text(data['name'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['category'] ?? "", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            if (data['barcode'] != null) Text("Code: ${data['barcode']}", style: const TextStyle(fontSize: 9, color: Colors.blueAccent)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Text(qty.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: statusColor)),
        ),
      ),
    );
  }

  void _showItemForm(BuildContext context, AppStateProvider appState, {Map<String, dynamic>? itemData, String? itemId, String? initialBarcode}) {
    final isEditing = itemData != null;
    final nameController = TextEditingController(text: itemData?['name'] ?? "");
    final qtyController = TextEditingController(text: itemData?['quantity']?.toString() ?? "");
    final barcodeController = TextEditingController(text: itemData?['barcode'] ?? initialBarcode ?? "");
    final categories = appState.locale.languageCode == 'sw' ? _categoriesSw : _categoriesEn;
    String selectedCat = itemData?['category'] ?? categories[categories.length - 1];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEditing ? "Edit Product" : "New Product", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: "Product Name")),
              const SizedBox(height: 16),
              TextField(controller: barcodeController, decoration: const InputDecoration(labelText: "Barcode ID (Optional)", prefixIcon: Icon(Icons.qr_code))),
              const SizedBox(height: 16),
              const Text("Category"),
              Wrap(
                spacing: 8,
                children: categories.where((c) => c != categories[0]).map((c) => ChoiceChip(
                  label: Text(c, style: const TextStyle(fontSize: 11)),
                  selected: selectedCat == c,
                  onSelected: (val) => setModalState(() => selectedCat = c),
                )).toList(),
              ),
              const SizedBox(height: 16),
              TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Quantity")),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity, height: 55,
                child: Tooltip(
                  message: appState.translate('tooltip_add'),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                    onPressed: () => _saveItem(
                      itemId: itemId, 
                      name: nameController.text, 
                      category: selectedCat, 
                      qty: int.tryParse(qtyController.text) ?? 0,
                      barcode: barcodeController.text,
                    ),
                    child: Text(isEditing ? "UPDATE" : "CREATE"),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveItemSilently({required String name, required String category, required int qty}) async {
    final data = {
      'name': name, 
      'category': category, 
      'quantity': qty, 
      'ownerEmail': FirebaseAuth.instance.currentUser?.email, 
      'updatedAt': FieldValue.serverTimestamp()
    };
    
    if (isFirebaseInitialized && FirebaseAuth.instance.currentUser != null) {
      await FirebaseFirestore.instance.collection('products').add(data);
    } else {
      // For Demo Mode, add to the local mock list
      setState(() {
        _mockItems.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          ...data,
          'updatedAt': DateTime.now(),
        });
      });
    }
  }

  void _saveItem({String? itemId, required String name, required String category, required int qty, String? barcode}) {
    if (name.isEmpty) return;
    final data = {
      'name': name, 
      'category': category, 
      'quantity': qty, 
      'barcode': barcode,
      'ownerEmail': FirebaseAuth.instance.currentUser?.email, 
      'updatedAt': FieldValue.serverTimestamp()
    };
    if (isFirebaseInitialized && FirebaseAuth.instance.currentUser != null) {
      itemId != null ? FirebaseFirestore.instance.collection('products').doc(itemId).update(data) : FirebaseFirestore.instance.collection('products').add(data);
    } else {
      // Demo Mode save
      setState(() {
        if (itemId != null) {
          int idx = _mockItems.indexWhere((i) => i['id'] == itemId);
          if (idx != -1) _mockItems[idx] = {'id': itemId, ...data, 'updatedAt': DateTime.now()};
        } else {
          _mockItems.add({'id': DateTime.now().millisecondsSinceEpoch.toString(), ...data, 'updatedAt': DateTime.now()});
        }
      });
    }
    Navigator.pop(context);
  }
}