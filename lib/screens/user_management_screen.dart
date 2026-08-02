import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../main.dart';

enum UserRole { admin, manager, cashier, customer }

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _users = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    
    try {
      if (isFirebaseInitialized && FirebaseAuth.instance.currentUser != null) {
        final snapshot = await FirebaseFirestore.instance.collection('users').get();
        
        setState(() {
          _users = snapshot.docs.map((doc) => {
            'id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          }).toList();
          _isLoading = false;
        });
      } else {
        // Demo mode
        setState(() {
          _users = [
            {'id': '1', 'email': 'admin@example.com', 'role': 'admin', 'name': 'Admin User', 'createdAt': DateTime.now()},
            {'id': '2', 'email': 'manager@example.com', 'role': 'manager', 'name': 'Manager User', 'createdAt': DateTime.now()},
            {'id': '3', 'email': 'cashier@example.com', 'role': 'cashier', 'name': 'Cashier User', 'createdAt': DateTime.now()},
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      if (isFirebaseInitialized) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'role': newRole,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        appState.addActivityLog('update_user_role', 'User role updated to $newRole', metadata: {'userId': userId});
      }
      
      await _loadUsers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User role updated successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating role: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteUser(String userId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete user $email?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      if (isFirebaseInitialized) {
        await FirebaseFirestore.instance.collection('users').doc(userId).delete();
        
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        appState.addActivityLog('delete_user', 'User deleted', metadata: {'userId': userId, 'email': email});
      }
      
      await _loadUsers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting user: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddUserDialog() {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    String selectedRole = 'cashier';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'manager', child: Text('Manager')),
                DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                DropdownMenuItem(value: 'customer', child: Text('Customer')),
              ],
              onChanged: (value) {
                if (value != null) selectedRole = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isEmpty || nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields'), backgroundColor: Colors.red),
                );
                return;
              }
              
              try {
                if (isFirebaseInitialized) {
                  await FirebaseFirestore.instance.collection('users').add({
                    'email': emailController.text,
                    'name': nameController.text,
                    'role': selectedRole,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  
                  final appState = Provider.of<AppStateProvider>(context, listen: false);
                  appState.addActivityLog('add_user', 'New user added', metadata: {
                    'email': emailController.text,
                    'role': selectedRole,
                  });
                }
                
                Navigator.pop(context);
                await _loadUsers();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User added successfully'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding user: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.themeMode == ThemeMode.dark;
    
    final filteredUsers = _users.where((user) {
      final email = user['email']?.toString().toLowerCase() ?? '';
      final name = user['name']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return email.contains(query) || name.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                Expanded(
                  child: filteredUsers.isEmpty
                      ? Center(
                          child: Text(
                            'No users found',
                            style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final role = user['role']?.toString() ?? 'customer';
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getRoleColor(role),
                                  child: Text(
                                    user['name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(
                                  user['name']?.toString() ?? 'Unknown',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                                ),
                                subtitle: Text(
                                  user['email']?.toString() ?? '',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getRoleColor(role).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        role.toUpperCase(),
                                        style: TextStyle(
                                          color: _getRoleColor(role),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (value) {
                                        if (value == 'edit_role') {
                                          _showRoleEditDialog(user['id']?.toString() ?? '', role);
                                        } else if (value == 'delete') {
                                          _deleteUser(user['id']?.toString() ?? '', user['email']?.toString() ?? '');
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'edit_role', child: Text('Edit Role')),
                                        const PopupMenuItem(value: 'delete', child: Text('Delete User', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueAccent,
        onPressed: _showAddUserDialog,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add User', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.purple;
      case 'cashier':
        return Colors.blue;
      case 'customer':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showRoleEditDialog(String userId, String currentRole) {
    String selectedRole = currentRole;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User Role'),
        content: DropdownButtonFormField<String>(
          value: selectedRole,
          decoration: const InputDecoration(labelText: 'Role'),
          items: const [
            DropdownMenuItem(value: 'admin', child: Text('Admin')),
            DropdownMenuItem(value: 'manager', child: Text('Manager')),
            DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
            DropdownMenuItem(value: 'customer', child: Text('Customer')),
          ],
          onChanged: (value) {
            if (value != null) selectedRole = value;
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _updateUserRole(userId, selectedRole);
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
