import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import './admin_page.dart';
import './home_page.dart';
import './create_account_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String _selectedRole = 'user'; // Default role

  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        throw 'Please enter email and password';
      }

      final userCredential = await _authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (userCredential?.user != null) {
        final userRole = await _authService.getUserRole(userCredential!.user!.uid);
        
        // Verify if user has permission for selected role
        if (userRole != _selectedRole) {
          throw 'You do not have permission to login as ${_selectedRole}';
        }

        if (_selectedRole == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminPage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Role Selection
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'user',
                  label: Text('User'),
                  icon: Icon(Icons.person),
                ),
                ButtonSegment(
                  value: 'admin',
                  label: Text('Admin'),
                  icon: Icon(Icons.admin_panel_settings),
                ),
              ],
              selected: {_selectedRole},
              onSelectionChanged: (Set<String> selection) {
                setState(() {
                  _selectedRole = selection.first;
                });
              },
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Login'),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateAccountPage()),
                );
              },
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
