import 'package:flutter/material.dart';
import 'package:library_booking/pages/login_page.dart'; // For navigation

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  static const String routeName = '/'; // Or '/welcome'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Replace with a logo if available
              Icon(
                Icons.school, // Placeholder icon (library/education related)
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Library Room Booker',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
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
                  // For now, let's assume browsing rooms might also require login,
                  // or it could navigate to a read-only room list page.
                  // To keep it simple, direct to login, which then leads to browsing.
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
                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
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
