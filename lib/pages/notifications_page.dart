import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:library_booking/services/notification_service.dart' as app_notification; // Aliased to avoid conflict with Flutter's Notification
// Import MyBookingsPage or other relevant pages for navigation if needed
// import 'package:library_booking/pages/my_bookings_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  static const String routeName = '/notifications';

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

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

  void _loadNotifications() {
    if (_currentUser == null) return;
    // Get all notifications, read and unread, ordered by timestamp
    // The UI will differentiate them.
    setState(() {
      _notificationsStream = _notificationService.getUserNotifications(_currentUser!.uid);
    });
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
      // StreamBuilder will rebuild, no explicit setState needed here to refresh list UI for this item.
      // However, if you have local state like an unread count badge elsewhere, update it.
    } catch (e) {
      print("Error marking notification as read: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to mark as read: ${e.toString()}"), backgroundColor: Colors.red));
    }
  }

  Future<void> _markAllAsRead() async {
    if (_currentUser == null) return;
    try {
      await _notificationService.markAllAsRead(_currentUser!.uid);
      // StreamBuilder will update the list.
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All notifications marked as read.'), backgroundColor: Colors.green));
    } catch (e) {
      print("Error marking all as read: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to mark all as read: ${e.toString()}"), backgroundColor: Colors.red));
    }
  }

  void _handleNotificationTap(app_notification.Notification notification) {
    // Mark as read when tapped
    if (!notification.isRead) {
      _markAsRead(notification.notificationId);
    }

    // Optional: Navigate if relatedEntityId exists
    if (notification.relatedEntityId != null && notification.relatedEntityId!.isNotEmpty) {
      if (notification.type == 'booking_status_update' || notification.type == 'new_booking_admin') { // Assuming types
        // Potentially navigate to MyBookingsPage and perhaps highlight the specific booking
        // For now, just show a message.
        // Navigator.pushNamed(context, MyBookingsPage.routeName, arguments: {'bookingId': notification.relatedEntityId});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tapped notification related to booking ID: ${notification.relatedEntityId}. Navigation pending.')),
        );
      }
      // Add other navigation logic based on notification.type
    }
  }

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
          // Check if there are any unread notifications to enable the button
          // This requires a separate stream or check, or iterating through current snapshot.
          // For simplicity in this step, always show. Can be enhanced.
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
                margin: theme.cardTheme.margin?.copyWith(top: 8, bottom: 0), // Add top margin
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
