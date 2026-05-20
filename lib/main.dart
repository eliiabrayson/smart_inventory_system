import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'inventory_screen.dart';

bool isFirebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SharedPreferencesWithCache prefs =
      await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: <String>{'isDarkMode', 'languageCode'},
        ),
      );

  bool savedTheme = prefs.getBool('isDarkMode') ?? false;
  String savedLang = prefs.getString('languageCode') ?? 'en';
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
      create: (_) => AppStateProvider(
        prefs: prefs,
        isDarkMode: savedTheme,
        languageCode: savedLang,
      ),
      child: const SmartInventoryApp(),
    ),
  );
}

// Global state for Theme and Language
class AppStateProvider extends ChangeNotifier {
  final SharedPreferencesWithCache _prefs;
  ThemeMode _themeMode;
  Locale _locale = const Locale('en');

  AppStateProvider({
    required SharedPreferencesWithCache prefs,
    bool isDarkMode = false,
    String languageCode = 'en',
  }) : _prefs = prefs,
       _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light,
       _locale = Locale(languageCode);

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    _prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
    notifyListeners();
  }

  void setLanguage(String langCode) {
    _locale = Locale(langCode);
    _prefs.setString('languageCode', langCode);
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
        'tooltip_sort': 'Sort Inventory',
        'tooltip_add': 'Add New Product',
        'tooltip_settings': 'App Settings',
        'tooltip_logout': 'Sign Out',
        'tooltip_scan': 'Scan Barcode',
        'tooltip_switch_camera': 'Switch Camera',
        'tooltip_close': 'Close Scanner',
        'tooltip_view_password': 'Show/Hide Password',
        'scan_title': 'Scan Product Barcode',
        'bulk_import': 'Bulk Import (CSV)',
        'bulk_import_subtitle': 'Upload multiple products at once',
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
        'tooltip_sort': 'Panga Ghala',
        'tooltip_add': 'Ongeza Bidhaa Mpya',
        'tooltip_settings': 'Mipangilio ya Programu',
        'tooltip_logout': 'Ondoka',
        'tooltip_scan': 'Skena Msimbo',
        'tooltip_switch_camera': 'Badilisha Kamera',
        'tooltip_close': 'Funga Skena',
        'tooltip_view_password': 'Onyesha/Ficha Nenosiri',
        'scan_title': 'Skena Msimbo wa Bidhaa',
        'bulk_import': 'Ingiza kwa Wingi (CSV)',
        'bulk_import_subtitle': 'Pakia bidhaa nyingi kwa pamoja',
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const InventoryDashboard();
        }
        return const LoginScreen();
      },
    );
  }
}
