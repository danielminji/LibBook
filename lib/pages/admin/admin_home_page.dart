import 'package:flutter/material.dart';
import 'package:library_booking/services/auth_service.dart';
import 'package:library_booking/pages/welcome_page.dart'; // For logout

// Placeholders for other admin pages (these were just created)
import 'package:library_booking/pages/admin/admin_manage_bookings_page.dart';
import 'package:library_booking/pages/admin/admin_manage_rooms_page.dart';
import 'package:library_booking/pages/admin/admin_manage_announcements_page.dart';
import 'package:library_booking/pages/admin/admin_view_feedback_page.dart';


class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});
  static const String routeName = '/admin/home';

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final AuthService _authService = AuthService();

  Future<void> _logout() async {
    await _authService.signOut();
    Navigator.of(context).pushNamedAndRemoveUntil(WelcomePage.routeName, (Route<dynamic> route) => false);
  }

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
            // Placeholder for stats/overview - e.g., pending bookings count
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
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildAdminNavCard(context, Icons.book_online, 'Manage Bookings', AdminManageBookingsPage.routeName, theme),
                _buildAdminNavCard(context, Icons.room_preferences, 'Manage Rooms', AdminManageRoomsPage.routeName, theme),
                _buildAdminNavCard(context, Icons.campaign, 'Manage Announcements', AdminManageAnnouncementsPage.routeName, theme),
                _buildAdminNavCard(context, Icons.feedback_outlined, 'View Feedback', AdminViewFeedbackPage.routeName, theme),
                // _buildAdminNavCard(context, Icons.qr_code_scanner, 'Scan QR (Check-in)', '/admin/scan-qr', theme), // Placeholder
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminNavCard(BuildContext context, IconData icon, String label, String routeName, ThemeData theme) {
    return Card(
      elevation: theme.cardTheme.elevation ?? 2.0,
      shape: theme.cardTheme.shape,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, routeName),
        borderRadius: BorderRadius.circular(theme.cardTheme.shape is RoundedRectangleBorder ? (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius.resolve(Directionality.of(context)).topLeft.x : 12.0),
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
