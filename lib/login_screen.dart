import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  String _selectedRole = 'admin';

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Please fill in all fields");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } catch (e) {
      _showError("Login Failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Please fill in all fields");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // Save user role to Firestore
      if (userCredential.user != null) {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'email': _emailController.text.trim(),
          'role': _selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account created successfully!")),
        );
      }
    } catch (e) {
      _showError("Registration Failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      _showError("Enter your email first to reset password");
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password reset email sent!")),
        );
      }
    } catch (e) {
      _showError("Error: ${e.toString()}");
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
                ? [Colors.blueAccent.withOpacity(0.1), Colors.black]
                : [Colors.blueAccent.withOpacity(0.1), Colors.white],
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
                      color: Colors.blueAccent.withOpacity(0.1),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _passwordController,
                        label: appState.translate('password'),
                        icon: Icons.lock_outline_rounded,
                        isDark: isDark,
                        isPassword: true,
                      ),
                      
                      // Role Selection for Registration
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            appState.locale.languageCode == 'en' ? "Register as:" : "Jisajili kama:",
                            style: TextStyle(color: isDark ? Colors.grey : Colors.blueGrey, fontSize: 14),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'admin',
                                  label: Text('Admin'),
                                  icon: Icon(Icons.admin_panel_settings, size: 16),
                                ),
                                ButtonSegment(
                                  value: 'customer',
                                  label: Text('Customer'),
                                  icon: Icon(Icons.person, size: 16),
                                ),
                              ],
                              selected: {_selectedRole},
                              onSelectionChanged: (Set<String> newSelection) {
                                setState(() => _selectedRole = newSelection.first);
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: Text(
                            appState.translate('forgot_pw'),
                            style: const TextStyle(fontSize: 13, color: Colors.blueAccent),
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
                    TextButton(
                      onPressed: _register,
                      child: Text(
                        appState.translate('register'),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                    ),
                  ],
                ),
                
                // Language Toggle in Login
                const SizedBox(height: 20),
                ToggleButtons(
                  isSelected: [appState.locale.languageCode == 'en', appState.locale.languageCode == 'sw'],
                  onPressed: (index) {
                    appState.setLanguage(index == 0 ? 'en' : 'sw');
                  },
                  borderRadius: BorderRadius.circular(12),
                  constraints: const BoxConstraints(minHeight: 35, minWidth: 70),
                  children: const [Text("EN"), Text("SW")],
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