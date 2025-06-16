import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To get current user
import 'package:cloud_firestore/cloud_firestore.dart'; // For DocumentSnapshot
import 'package:library_booking/services/auth_service.dart';
import 'package:library_booking/services/booking_service.dart';
import 'package:library_booking/services/announcement_service.dart';
import 'package:library_booking/pages/welcome_page.dart'; // For logout navigation
// Import models for type hinting
import 'package:library_booking/services/booking_service.dart' show Booking;
import 'package:library_booking/services/announcement_service.dart' show Announcement;


// Dummy placeholder pages to allow navigation to be set up
// These would be replaced by actual page implementations in later steps.
class RoomListPage extends StatelessWidget {
  const RoomListPage({super.key});
  static const String routeName = '/room-list'; // Define routeName for main.dart if needed later
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Browse Rooms')), body: const Center(child: Text('Room List Page')));
}
class MyBookingsPage extends StatelessWidget {
  const MyBookingsPage({super.key});
  static const String routeName = '/my-bookings'; // Define routeName
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('My Bookings')), body: const Center(child: Text('My Bookings Page')));
}
class FeedbackPage extends StatelessWidget {
  const FeedbackPage({super.key});
  static const String routeName = '/feedback'; // Define routeName
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Submit Feedback')), body: const Center(child: Text('Feedback Page')));
}
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  static const String routeName = '/profile'; // Define routeName
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('My Profile')), body: const Center(child: Text('Profile Page')));
}
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  static const String routeName = '/notifications'; // Define routeName
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Notifications')), body: const Center(child: Text('Notifications Page')));
}


class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});
  static const String routeName = '/home';

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final AuthService _authService = AuthService();
  final BookingService _bookingService = BookingService();
  final AnnouncementService _announcementService = AnnouncementService();

  User? _currentUser;
  String? _username;

  late Future<List<Booking>> _upcomingBookingsFuture;
  late Future<List<Announcement>> _announcementsFuture;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadUserData();
    _loadInitialData();
  }

  Future<void> _loadUserData() async {
    if (_currentUser != null) {
      DocumentSnapshot? userDoc = await _authService.getUserDocument(_currentUser!.uid);
      if (mounted && userDoc != null && userDoc.exists) {
        // Make sure to cast data to Map<String, dynamic> to use .get
        Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
        setState(() {
          _username = userData?['username'] ?? _currentUser!.email;
        });
      } else if (mounted) {
         setState(() {
          _username = _currentUser!.email; // Fallback to email
        });
      }
    }
  }

  void _loadInitialData() {
    if (_currentUser != null) {
      _upcomingBookingsFuture = _bookingService.getUserBookings(_currentUser!.uid)
          .map((bookings) => bookings.where((b) =>
              b.status == 'Approved' &&
              b.date.isAfter(DateTime.now().subtract(const Duration(days: 1)))
          ).toList()..sort((a,b) => a.date.compareTo(b.date)))
          .first;
    } else {
      _upcomingBookingsFuture = Future.value([]);
    }
    _announcementsFuture = _announcementService.getActiveAnnouncements().first;

    // Rebuild widget if data loading completes after initial build
    // This is more robustly handled by FutureBuilders checking connectionState
    // but ensures setState is called if data comes back quickly.
    Future.wait([_upcomingBookingsFuture, _announcementsFuture]).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _logout() async {
    await _authService.signOut();
    Navigator.of(context).pushNamedAndRemoveUntil(WelcomePage.routeName, (Route<dynamic> route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsPage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Implement pull-to-refresh logic
          setState(() {
            _loadInitialData(); // Reloads futures for bookings and announcements
            _loadUserData();    // Reloads user data like username
          });
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Ensures scroll even if content is small
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Welcome, ${_username ?? 'User'}!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              _buildNavigationSection(context, theme),
              const SizedBox(height: 24),
              Text(
                'Your Upcoming Bookings',
                style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary),
              ),
              const SizedBox(height: 8),
              _buildUpcomingBookingsSection(),
              const SizedBox(height: 24),
              Text(
                'Announcements',
                style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary),
              ),
              const SizedBox(height: 8),
              _buildAnnouncementsSection(),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const FeedbackPage()));
                  },
                  child: Text('Submit Feedback', style: TextStyle(color: theme.colorScheme.primary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationSection(BuildContext context, ThemeData theme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildNavCard(
          context,
          icon: Icons.search,
          label: 'Browse & Book Rooms',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RoomListPage())),
          theme: theme,
        ),
        _buildNavCard(
          context,
          icon: Icons.event_note,
          label: 'My Bookings',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyBookingsPage())),
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildNavCard(BuildContext context, {required IconData icon, required String label, ThemeData? theme, VoidCallback? onTap}) {
    return Card(
      elevation: theme?.cardTheme.elevation ?? 2.0,
      shape: theme?.cardTheme.shape,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme?.cardTheme.shape is RoundedRectangleBorder ? (theme!.cardTheme.shape as RoundedRectangleBorder).borderRadius.resolve(Directionality.of(context)).topLeft.x : 12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: theme?.colorScheme.primary ?? Colors.blue),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: theme?.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingBookingsSection() {
    return FutureBuilder<List<Booking>>(
      future: _upcomingBookingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _username == null) { // Also wait for username
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Error loading bookings: ${snapshot.error}', style: const TextStyle(color: Colors.red));
        }
        final bookings = snapshot.data;
        if (bookings == null || bookings.isEmpty) {
          return const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Center(child: Text('You have no upcoming approved bookings.'))));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: bookings.length > 2 ? 2 : bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return Card(
              child: ListTile(
                title: Text('Room: ${booking.roomId}'),
                subtitle: Text('${booking.date.toLocal().toString().split(' ')[0]} at ${booking.timeSlot}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MyBookingsPage()));
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnnouncementsSection() {
    return FutureBuilder<List<Announcement>>(
      future: _announcementsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Error loading announcements: ${snapshot.error}', style: const TextStyle(color: Colors.red));
        }
        final announcements = snapshot.data;
        if (announcements == null || announcements.isEmpty) {
          return const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Center(child: Text('No current announcements.'))));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: announcements.length > 2 ? 2 : announcements.length,
          itemBuilder: (context, index) {
            final announcement = announcements[index];
            return Card(
              child: ListTile(
                title: Text(announcement.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(announcement.message, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            );
          },
        );
      },
    );
  }
}
