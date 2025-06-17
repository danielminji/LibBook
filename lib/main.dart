import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:library_booking/firebase_options.dart'; // Assuming this is correctly configured

// Page imports
import 'package:library_booking/pages/welcome_page.dart';
import 'package:library_booking/pages/login_page.dart';
import 'package:library_booking/pages/signup_page.dart';
import 'package:library_booking/pages/home_page.dart'; // Contains UserHomePage class
// Admin page imports
import 'package:library_booking/pages/admin/admin_home_page.dart';
import 'package:library_booking/pages/admin/admin_manage_bookings_page.dart';
import 'package:library_booking/pages/admin/admin_manage_rooms_page.dart';
import 'package:library_booking/pages/admin/admin_manage_announcements_page.dart';
import 'package:library_booking/pages/admin/admin_view_feedback_page.dart';
import 'package:library_booking/pages/admin/admin_qr_scanner_page.dart'; // Import the new page

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Library Room Booker',
      theme: ThemeData(
        primarySwatch: Colors.blue, // Base blue color
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF2563eb), // Modern blue from user
          secondary: const Color(0xFF1e40af), // Darker blue for accents
          onPrimary: Colors.white, // Text on primary color
          // Ensure other colors like surface, background, error, onSecondary, onSurface, etc. are defined if needed
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2563eb),
          foregroundColor: Colors.white,
          elevation: 4.0, // Subtle shadow
          iconTheme: IconThemeData(color: Colors.white), // Ensure icons on AppBar are white
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600), // AppBar title style
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563eb),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8), // Rounded corners for buttons
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2563eb), // Text/icon color
            side: const BorderSide(color: Color(0xFF2563eb), width: 1.5), // Border color and width
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2.0, // Subtle shadow for cards
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Rounded corners for cards
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2563eb), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF2563eb)),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF2563eb), // Default icon color
        ),
        // Define other theme properties as needed
      ),
      debugShowCheckedModeBanner: false, // Optional: remove debug banner
      initialRoute: WelcomePage.routeName, // Use static routeName for WelcomePage
      routes: {
        WelcomePage.routeName: (context) => const WelcomePage(),
        LoginPage.routeName: (context) => const LoginPage(),
        SignUpPage.routeName: (context) => const SignUpPage(),
        UserHomePage.routeName: (context) => const UserHomePage(),
        // Admin routes
        AdminHomePage.routeName: (context) => const AdminHomePage(),
        AdminManageBookingsPage.routeName: (context) => const AdminManageBookingsPage(),
        AdminManageRoomsPage.routeName: (context) => const AdminManageRoomsPage(),
        AdminManageAnnouncementsPage.routeName: (context) => const AdminManageAnnouncementsPage(),
        AdminViewFeedbackPage.routeName: (context) => const AdminViewFeedbackPage(),
        AdminQrScannerPage.routeName: (context) => const AdminQrScannerPage(),
      },
    );
  }
}
