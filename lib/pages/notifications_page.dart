import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:library_booking/services/notification_service.dart' as app_notification; // Aliased to avoid conflict with Flutter's Notification

// Import MyBookingsPage or other relevant pages for navigation if needed
// import 'package:library_booking/pages/my_bookings_page.dart';

/// A page that displays a list of notifications for the currently logged-in user.
///
/// Notifications are fetched using [app_notification.NotificationService] and displayed
/// in a list, with unread notifications visually distinguished. Users can mark
/// individual notifications as read by tapping them, or mark all as read using an
/// AppBar action.
class NotificationsPage extends StatefulWidget {
  /// Creates an instance of [NotificationsPage].
  const NotificationsPage({super.key});

  /// The named route for this page.
  static const String routeName = '/notifications';

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

/// Manages the state for the [NotificationsPage].
///
/// This includes initializing and holding the stream of user notifications,
/// and handling actions such as marking notifications as read.
class _NotificationsPageState extends State<NotificationsPage> {
  final app_notification.NotificationService _notificationService = app_notification.NotificationService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  User? _currentUser;
  Stream<List<app_notification.Notification>>? _notificationsStream;

  @override
  void initState() {
    super.initState();
    _currentUser = _firebaseAuth.currentUser;
    if (_currentUser != null) {
      _loadNotifications();
    }
  }

  /// Loads the stream of notifications for the current user.
  ///
  /// Initializes [_notificationsStream] by calling
  /// [app_notification.NotificationService.getUserNotifications].
  /// This stream provides all notifications (read and unread) for the user,
  /// ordered by timestamp.
  void _loadNotifications() {
    if (_currentUser == null) return;
    setState(() {
      _notificationsStream = _notificationService.getUserNotifications(_currentUser!.uid);
    });
  }

  /// Marks a specific notification as read.
  ///
  /// Calls [app_notification.NotificationService.markAsRead] for the given [notificationId].
  /// Displays a [SnackBar] if an error occurs. The UI updates via the [StreamBuilder].
  ///
  /// - [notificationId]: The ID of the notification to mark as read.
  Future<void> _markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
    } catch (e) {
      print("Error marking notification $notificationId as read: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to mark as read: ${e.toString()}"), backgroundColor: Colors.red));
    }
  }

  /// Marks all unread notifications for the current user as read.
  ///
  /// Calls [app_notification.NotificationService.markAllAsRead].
  /// Displays a [SnackBar] for feedback or errors.
  Future<void> _markAllAsRead() async {
    if (_currentUser == null) return;
    try {
      await _notificationService.markAllAsRead(_currentUser!.uid);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All notifications marked as read.'), backgroundColor: Colors.green));
    } catch (e) {
      print("Error marking all notifications as read: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to mark all as read: ${e.toString()}"), backgroundColor: Colors.red));
    }
  }

  /// Handles the tap action on a notification list item.
  ///
  /// If the tapped [notification] is unread, it calls [_markAsRead].
  /// Includes placeholder logic for potential navigation based on `notification.type`
  /// and `notification.relatedEntityId` (e.g., navigating to a specific booking).
  ///
  /// - [notification]: The [app_notification.Notification] object that was tapped.
  void _handleNotificationTap(app_notification.Notification notification) {
    if (!notification.isRead) {
      _markAsRead(notification.notificationId);
    }

    if (notification.relatedEntityId != null && notification.relatedEntityId!.isNotEmpty) {
      if (notification.type == 'booking_status_update' || notification.type == 'new_booking_admin') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tapped notification related to booking ID: ${notification.relatedEntityId}. Navigation pending.')),
        );
        // Example navigation (if MyBookingsPage and arguments are set up):
        // Navigator.pushNamed(context, MyBookingsPage.routeName, arguments: {'bookingId': notification.relatedEntityId});
      }
      // TODO: Add other navigation logic based on notification.type if necessary
    }
  }

  /// Builds the UI for the Notifications Page.
  ///
  /// Displays a list of user notifications using a [StreamBuilder].
  /// Each notification is presented in a [Card] with visual cues for read/unread status.
  /// An AppBar action allows marking all notifications as read.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_currentUser == null) {
      return Scaffold(appBar: AppBar(title: const Text('Notifications')), body: const Center(child: Text('Please log in to see notifications.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: StreamBuilder<List<app_notification.Notification>>(
        stream: _notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading notifications: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          final notifications = snapshot.data;
          if (notifications == null || notifications.isEmpty) {
            return const Center(child: Text('You have no notifications.'));
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final bool isUnread = !notification.isRead;
              return Card(
                elevation: theme.cardTheme.elevation,
                shape: theme.cardTheme.shape,
                margin: theme.cardTheme.margin?.copyWith(top: 8, bottom: 0),
                color: isUnread ? theme.primaryColor.withOpacity(0.05) : theme.cardColor,
                child: ListTile(
                  leading: Icon(
                    isUnread ? Icons.mark_email_unread_rounded : Icons.mark_email_read_rounded,
                    color: isUnread ? theme.colorScheme.primary : Colors.grey,
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                      color: isUnread ? theme.colorScheme.primary : theme.textTheme.titleMedium?.color,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notification.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, yyyy hh:mm a').format(notification.timestamp.toDate()),
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () => _handleNotificationTap(notification),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
