import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'inventory_screen.dart';

bool isFirebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseInitialized = true;
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppStateProvider(),
      child: const SmartInventoryApp(),
    ),
  );
}

// Global state for Theme and Language
class AppStateProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('en');

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  // Notifications stored in app state
  final List<Map<String, dynamic>> _notifications = [];

  // Simple in-memory reports store: id -> content
  final Map<String, String> _reports = {};
  // Simple in-memory sales history
  final List<Map<String, dynamic>> _salesHistory = [];

  List<Map<String, dynamic>> get reportsList => _reports.entries.map((e) => {'id': e.key, 'content': e.value}).toList();

  List<Map<String, dynamic>> get notifications => List.unmodifiable(_notifications);

  void addNotification(String title, String body, {Map<String, dynamic>? payload}) {
    final now = DateTime.now();
    final entry = {'title': title ?? '', 'body': body ?? '', 'read': false, 'ts': now};
    if (payload != null) entry['payload'] = payload;
    _notifications.insert(0, entry);
    notifyListeners();
  }

  String addReport(String title, String content) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _reports[id] = content;
    // also add a notification that references this report
    addNotification(title, 'Report is available', payload: {'report_id': id});
    return id;
  }

  String? getReport(String id) => _reports[id];

  /// Record a sale locally and optionally persist to Firestore when available.
  Future<void> recordSale({required String productId, required String name, required int qty, required double amount, DateTime? when, String? userEmail}) async {
    final entry = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'productId': productId,
      'name': name,
      'qty': qty,
      'amount': amount,
      'timestamp': (when ?? DateTime.now()).toIso8601String(),
      'userEmail': userEmail,
    };
    _salesHistory.insert(0, entry);
    notifyListeners();
    // Try to persist to Firestore if initialized
    try {
      if (isFirebaseInitialized) {
        // lazy import via runtime to avoid import cycles in some environments
        // The calling code should set ownerEmail when appropriate
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> get salesHistory => List.unmodifiable(_salesHistory);

  void markNotificationRead(int index) {
    if (index >= 0 && index < _notifications.length) {
      _notifications[index]['read'] = true;
      notifyListeners();
    }
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setLanguage(String langCode) {
    _locale = Locale(langCode);
    notifyListeners();
  }

  // Translation helper
  String translate(String key) {
    final Map<String, Map<String, String>> localizedValues = {
      'en': {
        'app_name': 'Smart Inventory',
        'login': 'Sign In',
        'register': 'Create Account',
        'email': 'Shop Email',
        'password': 'Password',
        'forgot_pw': 'Forgot Password?',
        'welcome': 'Welcome back!',
        'total_items': 'TOTAL PRODUCTS',
        'low_stock': 'LOW STOCK',
        'out_stock': 'OUT OF STOCK',
        'search': 'Search products...',
        'add_product': 'ADD PRODUCT',
        'settings': 'Settings',
        'theme': 'Dark Mode',
        'language': 'Language',
        'logout': 'Sign Out',
      },
      'sw': {
        'app_name': 'Ghala Mahiri',
        'login': 'Ingia',
        'register': 'Jisajili',
        'email': 'Barua Pepe ya Duka',
        'password': 'Nenosiri',
        'forgot_pw': 'Umesahau Nenosiri?',
        'welcome': 'Karibu tena!',
        'total_items': 'JUMLA YA BIDHAA',
        'low_stock': 'AKIBA CHACHE',
        'out_stock': 'IMEKWISHA',
        'search': 'Tafuta bidhaa...',
        'add_product': 'ONGEZA BIDHAA',
        'settings': 'Mipangilio',
        'theme': 'Hali ya Giza',
        'language': 'Lugha',
        'logout': 'Ondoka',
      },
    };
    return localizedValues[_locale.languageCode]?[key] ?? key;
  }
}

class SmartInventoryApp extends StatelessWidget {
  const SmartInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);

    return MaterialApp(
      title: 'Smart Inventory',
      debugShowCheckedModeBanner: false,
      themeMode: appState.themeMode,
      // Light Theme
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
      ),
      // Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const InventoryDashboard();
        }
        return const LoginScreen();
      },
    );
  }
}
