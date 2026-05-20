import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart'; // To access AppStateProvider

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Please fill in all fields");
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      _showError(_getFriendlyErrorMessage(e));
    } catch (e) {
      _showError("An unexpected error occurred. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Please fill in all fields");
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account created successfully!")),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(_getFriendlyErrorMessage(e));
    } catch (e) {
      _showError("Registration failed. Please check your connection.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      _showError("Enter your email first to reset password");
      return;
    }
    FocusScope.of(context).unfocus();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Reset link sent! Please check your inbox."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(_getFriendlyErrorMessage(e));
    } catch (e) {
      _showError("Could not send reset email. Try again later.");
    }
  }

  String _getFriendlyErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return "No account exists for this email.";
      case 'wrong-password':
        return "Incorrect password. Please try again.";
      case 'invalid-email':
        return "The email address is not valid.";
      case 'email-already-in-use':
        return "This email is already registered.";
      case 'user-disabled':
        return "This account has been disabled.";
      case 'weak-password':
        return "Password is too weak. Use at least 6 characters.";
      case 'network-request-failed':
        return "Network error. Please check your internet.";
      case 'too-many-requests':
        return "Too many attempts. Please try again later.";
      default:
        return e.message ?? "Authentication failed. Please try again.";
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
                ? [Colors.blueAccent.withValues(alpha: 0.1), Colors.black]
                : [Colors.blueAccent.withValues(alpha: 0.1), Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory_2_rounded, size: 70, color: Colors.blueAccent),
                const SizedBox(height: 12),
                Text(
                  appState.translate('app_name'),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  appState.translate('welcome'),
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.blueGrey),
                ),
                const SizedBox(height: 40),
                
                // Form Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.blueAccent.withValues(alpha: 0.1),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _emailController,
                        label: appState.translate('email'),
                        icon: Icons.alternate_email,
                        isDark: isDark,
                        appState: appState,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _passwordController,
                        label: appState.translate('password'),
                        icon: Icons.lock_outline_rounded,
                        isDark: isDark,
                        isPassword: true,
                        appState: appState,
                      ),
                      
                      Align(
                        alignment: Alignment.centerRight,
                        child: Tooltip(
                          message: appState.translate('forgot_pw'),
                          child: TextButton(
                            onPressed: _forgotPassword,
                            child: Text(
                              appState.translate('forgot_pw'),
                              style: const TextStyle(fontSize: 13, color: Colors.blueAccent),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      if (_isLoading)
                        const CircularProgressIndicator(strokeWidth: 3)
                      else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                              appState.translate('login'),
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      appState.locale.languageCode == 'en' ? "New here?" : "Hujajisajili?",
                      style: TextStyle(color: isDark ? Colors.grey : Colors.blueGrey),
                    ),
                    Tooltip(
                      message: appState.translate('register'),
                      child: TextButton(
                        onPressed: _register,
                        child: Text(
                          appState.translate('register'),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Language Toggle in Login
                const SizedBox(height: 20),
                Tooltip(
                  message: appState.translate('tooltip_settings'),
                  child: ToggleButtons(
                    isSelected: [appState.locale.languageCode == 'en', appState.locale.languageCode == 'sw'],
                    onPressed: (index) {
                      appState.setLanguage(index == 0 ? 'en' : 'sw');
                    },
                    borderRadius: BorderRadius.circular(12),
                    constraints: const BoxConstraints(minHeight: 35, minWidth: 70),
                    children: const [Text("EN"), Text("SW")],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    required AppStateProvider appState,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.blueGrey),
        prefixIcon: Icon(icon, size: 20, color: Colors.blueAccent),
        suffixIcon: isPassword ? IconButton(
          tooltip: appState.translate('tooltip_view_password'),
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20, color: Colors.grey,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ) : null,
        filled: true,
        fillColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
}