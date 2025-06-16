import 'package:flutter/material.dart';
import 'package:library_booking/services/auth_service.dart'; // Import AuthService
import 'package:library_booking/pages/signup_page.dart';  // For navigation
import 'package:library_booking/pages/home_page.dart';    // For UserHomePage navigation
import 'package:library_booking/pages/admin/admin_home_page.dart'; // For AdminHomePage navigation
import 'package:library_booking/pages/welcome_page.dart'; // For ModalRoute.withName

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  static const String routeName = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  final AuthService _authService = AuthService(); // Instantiate AuthService

  Future<void> _loginUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final userCredential = await _authService.signInWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (userCredential != null && userCredential.user != null) {
          // Get user role
          String? userRole = await _authService.getUserRole(userCredential.user!.uid);

          if (mounted) { // Check if widget is still in the tree
            if (userRole == 'admin') {
              Navigator.of(context).pushNamedAndRemoveUntil(AdminHomePage.routeName, ModalRoute.withName(WelcomePage.routeName));
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil(UserHomePage.routeName, ModalRoute.withName(WelcomePage.routeName));
            }
          }
        } else {
          // Should not happen if signInWithEmailPassword throws an error on failure
          setState(() {
            _errorMessage = 'Login failed. Please try again.';
          });
        }
      } catch (e) {
        // Handle Firebase Auth exceptions (e.g., user-not-found, wrong-password)
        // You might want to parse specific FirebaseException codes for better messages
        print('Login error: $e');
        setState(() {
          _errorMessage = e.toString().contains('INVALID_LOGIN_CREDENTIALS')
              ? 'Invalid email or password.'
              : 'An error occurred. Please try again.';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        automaticallyImplyLeading: true, // Show back button
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Welcome Back!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Log in to continue to Library Room Booker.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.email, color: theme.colorScheme.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: Icon(Icons.lock, color: theme.colorScheme.primary),
                     border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _loginUser,
                        child: const Text('Login'),
                      ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, SignUpPage.routeName);
                  },
                  child: Text(
                    'Don\'t have an account? Sign Up',
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
