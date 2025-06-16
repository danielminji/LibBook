import 'package:flutter/material.dart';
import 'package:library_booking/services/auth_service.dart';
import 'package:library_booking/pages/welcome_page.dart'; // For logout

import 'package:library_booking/pages/admin/admin_manage_bookings_page.dart';
import 'package:library_booking/pages/admin/admin_manage_rooms_page.dart';
import 'package:library_booking/pages/admin/admin_manage_announcements_page.dart';
import 'package:library_booking/pages/admin/admin_view_feedback_page.dart';
import 'package:library_booking/pages/admin/admin_qr_scanner_page.dart';

/// The main dashboard page for administrator users.
///
/// Provides navigation to various administrative functions such as managing bookings,
/// rooms, announcements, viewing feedback, and scanning QR codes for check-ins.
/// Also includes a logout option.
class AdminHomePage extends StatefulWidget {
  /// Creates an instance of [AdminHomePage].
  const AdminHomePage({super.key});

  /// The named route for this page.
  static const String routeName = '/admin/home';

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

/// Manages the state for the [AdminHomePage].
///
/// Handles admin logout functionality and builds the UI for the admin dashboard.
class _AdminHomePageState extends State<AdminHomePage> {
  final AuthService _authService = AuthService();

  /// Logs out the current admin user and navigates to the [WelcomePage].
  ///
  /// Clears the navigation stack to prevent returning to admin pages.
  Future<void> _logout() async {
    await _authService.signOut();
    if (mounted) { // Ensure widget is still in the tree before navigating
      Navigator.of(context).pushNamedAndRemoveUntil(WelcomePage.routeName, (Route<dynamic> route) => false);
    }
  }

  /// Builds the UI for the Admin Home Page (Dashboard).
  ///
  /// Displays a welcome message and a grid of navigation cards for accessing
  /// different admin functionalities. Includes an AppBar with a logout action.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Welcome, Admin!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage library resources and user interactions.',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            // TODO: Consider adding a quick stats/overview section here.
            // Example:
            // Card(
            //   child: Padding(
            //     padding: const EdgeInsets.all(16.0),
            //     child: Column(
            //       children: [
            //         Text("Quick Stats", style: theme.textTheme.titleLarge),
            //         // Add FutureBuilder here for pending bookings count from BookingService
            //         ListTile(leading: Icon(Icons.hourglass_empty), title: Text("Pending Bookings: X")),
            //       ],
            //     ),
            //   ),
            // ),
            // const SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), // To disable GridView's own scrolling
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildAdminNavCard(context, Icons.book_online, 'Manage Bookings', AdminManageBookingsPage.routeName, theme),
                _buildAdminNavCard(context, Icons.room_preferences, 'Manage Rooms', AdminManageRoomsPage.routeName, theme),
                _buildAdminNavCard(context, Icons.campaign, 'Manage Announcements', AdminManageAnnouncementsPage.routeName, theme),
                _buildAdminNavCard(context, Icons.feedback_outlined, 'View Feedback', AdminViewFeedbackPage.routeName, theme),
                _buildAdminNavCard(context, Icons.qr_code_scanner, 'Scan QR (Check-in)', AdminQrScannerPage.routeName, theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Helper widget to build a tappable navigation card for the admin dashboard.
  ///
  /// - [context]: The build context.
  /// - [icon]: The [IconData] to display on the card.
  /// - [label]: The text label for the card.
  /// - [routeName]: The named route to navigate to when the card is tapped.
  /// - [theme]: The current application [ThemeData] for styling.
  Widget _buildAdminNavCard(BuildContext context, IconData icon, String label, String routeName, ThemeData theme) {
    return Card(
      elevation: theme.cardTheme.elevation ?? 2.0,
      shape: theme.cardTheme.shape,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, routeName),
        borderRadius: BorderRadius.circular(
          theme.cardTheme.shape is RoundedRectangleBorder
              ? (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius.resolve(Directionality.of(context)).topLeft.x
              : 12.0 // Default fallback if shape is not RoundedRectangleBorder
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}
