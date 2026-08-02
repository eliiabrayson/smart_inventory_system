import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'inventory_screen.dart';
import 'customer_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/notification_service.dart';

bool isFirebaseInitialized = false;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
  // Must be registered before the app UI starts so data messages received
  // while the app is in the background can be delivered to Dart.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
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
  
  // Activity logs
  final List<Map<String, dynamic>> _activityLogs = [];

  List<Map<String, dynamic>> get reportsList => _reports.entries.map((e) => {'id': e.key, 'content': e.value}).toList();

  List<Map<String, dynamic>> get notifications => List.unmodifiable(_notifications);
  
  List<Map<String, dynamic>> get activityLogs => List.unmodifiable(_activityLogs);

  void addNotification(String title, String body, {Map<String, dynamic>? payload, String? category}) {
    final now = DateTime.now();
    final entry = {
      'title': title ?? '', 
      'body': body ?? '', 
      'read': false, 
      'ts': now,
      'category': category ?? 'general',
    };
    if (payload != null) entry['payload'] = payload;
    _notifications.insert(0, entry);
    
    // Add to activity log
    _activityLogs.insert(0, {
      'action': 'notification',
      'title': title,
      'timestamp': now,
      'details': body,
    });
    
    notifyListeners();
  }

  void deleteNotification(int index) {
    if (index >= 0 && index < _notifications.length) {
      _notifications.removeAt(index);
      notifyListeners();
    }
  }

  String addReport(String title, String content) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _reports[id] = content;
    // also add a notification that references this report
    addNotification(title, 'Report is available', payload: {'report_id': id});
    return id;
  }

  String? getReport(String id) => _reports[id];

  void deleteReport(String id) {
    _reports.remove(id);
    
    // Add to activity log
    _activityLogs.insert(0, {
      'action': 'delete_report',
      'reportId': id,
      'timestamp': DateTime.now(),
      'details': 'Report deleted',
    });
    
    notifyListeners();
  }

  void addActivityLog(String action, String details, {Map<String, dynamic>? metadata}) {
    final entry = {
      'action': action,
      'details': details,
      'timestamp': DateTime.now(),
    };
    if (metadata != null) entry['metadata'] = metadata;
    _activityLogs.insert(0, entry);
    notifyListeners();
  }

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
      if (isFirebaseInitialized && FirebaseAuth.instance.currentUser != null) {
        await FirebaseFirestore.instance.collection('sales').add({
          'productId': productId,
          'name': name,
          'qty': qty,
          'amount': amount,
          'timestamp': FieldValue.serverTimestamp(),
          'ownerEmail': FirebaseAuth.instance.currentUser?.email ?? userEmail,
        });
      }
    } catch (e) {
      debugPrint('Failed to save sale to Firestore: $e');
    }
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

class SmartInventoryApp extends StatefulWidget {
  const SmartInventoryApp({super.key});

  @override
  State<SmartInventoryApp> createState() => _SmartInventoryAppState();
}

class _SmartInventoryAppState extends State<SmartInventoryApp> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    // Initialize notification service after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _notificationService.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Smart Inventory System',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: appState.themeMode,
          locale: appState.locale,
          home: const AuthGate(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseInitialized) {
      return const InventoryDashboard();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        if (snapshot.hasData) {
          return const UserRoleGate();
        }
        return const LoginScreen();
      },
    );
  }
}

class UserRoleGate extends StatelessWidget {
  const UserRoleGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (!isFirebaseInitialized || user == null) {
      return const InventoryDashboard(); // Fallback to admin dashboard
    }
    
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          // If user document doesn't exist, default to admin dashboard
          return const InventoryDashboard();
        }
        
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final role = userData?['role'] ?? 'admin';
        
        if (role == 'customer') {
          return const CustomerDashboard();
        }
        
        return const InventoryDashboard();
      },
    );
  }
}
