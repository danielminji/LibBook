import 'package:flutter/material.dart';
import 'package:library_booking/services/auth_service.dart'; // Import AuthService
import 'package:library_booking/pages/login_page.dart';    // For navigation
import 'package:library_booking/pages/home_page.dart';      // For navigation

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  static const String routeName = '/signup';

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  // Optional: Confirm Password Controller
  // final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  final AuthService _authService = AuthService(); // Instantiate AuthService

  Future<void> _signUpUser() async {
    if (_formKey.currentState!.validate()) {
      // Optional: Check if password and confirm password match
      // if (_passwordController.text != _confirmPasswordController.text) {
      //   setState(() {
      //     _errorMessage = 'Passwords do not match.';
      //   });
      //   return;
      // }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final userCredential = await _authService.registerWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          username: _usernameController.text.trim(),
        );

        if (userCredential != null && userCredential.user != null) {
          // Navigate to home page on successful signup
          // Replace all routes below WelcomePage with UserHomePage
          Navigator.of(context).pushNamedAndRemoveUntil(UserHomePage.routeName, ModalRoute.withName('/'));
        } else {
          // This case should ideally not be reached if registerWithEmailPassword throws on failure.
          setState(() {
            _errorMessage = 'Sign up failed. Please try again.';
          });
        }
      } catch (e) {
        // Handle Firebase Auth exceptions (e.g., email-already-in-use, weak-password)
        print('SignUp error: $e');
        String displayMessage = 'An error occurred. Please try again.';
        if (e.toString().contains('email-already-in-use')) {
          displayMessage = 'This email is already registered. Please login.';
        } else if (e.toString().contains('weak-password')) {
          displayMessage = 'The password is too weak.';
        }
        setState(() {
          _errorMessage = displayMessage;
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
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    // _confirmPasswordController.dispose(); // if used
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
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
                  'Create Account',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Join us to start booking library rooms.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    hintText: 'Choose a username',
                    prefixIcon: Icon(Icons.person, color: theme.colorScheme.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    if (value.length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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
                    hintText: 'Create a password',
                    prefixIcon: Icon(Icons.lock, color: theme.colorScheme.primary),
                     border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                // Optional: Confirm Password Field
                // const SizedBox(height: 16),
                // TextFormField(
                //   controller: _confirmPasswordController,
                //   decoration: InputDecoration(
                //     labelText: 'Confirm Password',
                //     hintText: 'Re-enter your password',
                //     prefixIcon: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                //     border: OutlineInputBorder(
                //       borderRadius: BorderRadius.circular(8),
                //     ),
                //   ),
                //   obscureText: true,
                //   validator: (value) {
                //     if (value == null || value.isEmpty) {
                //       return 'Please confirm your password';
                //     }
                //     if (value != _passwordController.text) {
                //       return 'Passwords do not match';
                //     }
                //     return null;
                //   },
                // ),
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
                        onPressed: _signUpUser,
                        child: const Text('Sign Up'),
                      ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, LoginPage.routeName);
                  },
                  child: Text(
                    'Already have an account? Login',
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
