import 'package:flutter/material.dart';
import 'package:library_booking/services/auth_service.dart'; // Import AuthService
import 'package:library_booking/pages/login_page.dart';    // For navigation
import 'package:library_booking/pages/home_page.dart';      // For navigation
import 'package:library_booking/pages/welcome_page.dart';  // For ModalRoute.withName in navigation

/// A page that allows new users to sign up for an account.
///
/// Users can enter their desired username, email, and password to create a new
/// account. Upon successful registration, they are navigated to the [UserHomePage].
/// Provides an option to navigate to the [LoginPage] if the user already has an account.
class SignUpPage extends StatefulWidget {
  /// Creates an instance of [SignUpPage].
  const SignUpPage({super.key});

  /// The named route for this page.
  static const String routeName = '/signup';

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

/// Manages the state for the [SignUpPage].
///
/// This includes handling form input for username, email, and password,
/// validating these inputs, communicating with the [AuthService] for user
/// registration, and managing loading/error states during the sign-up process.
class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  // Optional: Confirm Password Controller
  // final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  final AuthService _authService = AuthService();

  /// Attempts to register a new user with the provided details.
  ///
  /// Validates the form inputs (username, email, password). If valid, it calls the
  /// [AuthService.registerWithEmailPassword] method.
  /// On successful registration, it navigates to the [UserHomePage],
  /// clearing the navigation stack up to the [WelcomePage.routeName].
  ///
  /// Manages `_isLoading` state to show a progress indicator and updates
  /// `_errorMessage` to display feedback to the user in case of errors
  /// (e.g., email already in use, weak password).
  Future<void> _signUpUser() async {
    if (_formKey.currentState!.validate()) {
      // Optional: Check if password and confirm password match
      // if (_passwordController.text != _confirmPasswordController.text) {
      //   if (mounted) {
      //     setState(() {
      //       _errorMessage = 'Passwords do not match.';
      //     });
      //   }
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
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(UserHomePage.routeName, ModalRoute.withName(WelcomePage.routeName));
          }
        } else {
          // This case should ideally not be reached if registerWithEmailPassword throws on failure.
          if (mounted) {
            setState(() {
              _errorMessage = 'Sign up failed. Please try again.';
            });
          }
        }
      } catch (e) {
        print('SignUp error: $e');
        String displayMessage = 'An error occurred during sign up. Please try again.';
        if (e.toString().contains('email-already-in-use')) {
          displayMessage = 'This email is already registered. Please login or use a different email.';
        } else if (e.toString().contains('weak-password')) {
          displayMessage = 'The password is too weak. Please choose a stronger password.';
        }
        if (mounted) {
          setState(() {
            _errorMessage = displayMessage;
          });
        }
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

  /// Builds the UI for the Sign Up Page.
  ///
  /// Features a form for username, email, and password input, a sign-up button,
  /// and a link to the login page. Displays loading indicators
  /// and error messages as appropriate.
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
                    if (value.trim().length < 3) {
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
                    // Use popAndPushNamed if on signup, back should go to welcome, then login
                    // Or just pushNamed if standard stack behavior is fine
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
