import 'package:flutter/material.dart';
import 'package:library_booking/pages/login_page.dart'; // For navigation

/// The initial landing page of the application.
///
/// This page provides users with a brief introduction to the app
/// and offers primary navigation options to either browse rooms (which typically
/// leads to login/signup) or directly to the login/signup flow.
class WelcomePage extends StatelessWidget {
  /// Creates an instance of [WelcomePage].
  const WelcomePage({super.key});

  /// The named route for this page, typically the root route ('/').
  static const String routeName = '/';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get theme for styling
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Placeholder for an app logo
              Icon(
                Icons.school, // Represents library/education
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Library Room Booker',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Easily find and reserve rooms in the library for your study sessions and meetings.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  // Navigates to the LoginPage. Browsing rooms might also eventually
                  // lead here if user is not authenticated.
                  Navigator.pushNamed(context, LoginPage.routeName);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50), // Full width button
                ),
                child: const Text('Browse Rooms & Book'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, LoginPage.routeName);
                },
                 style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50), // Full width button
                  side: BorderSide(color: theme.colorScheme.primary),
                ),
                child: const Text('Login / Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
