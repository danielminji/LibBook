import 'package:flutter/material.dart';
import '../services/booking_service.dart';

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Announcements'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Notifications'),
              Tab(text: 'General Announcements'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMyNotifications(),
            _buildGeneralAnnouncements(),
          ],
        ),
      ),
    );
  }

  Widget _buildMyNotifications() {
    return StreamBuilder<List<Announcement>>(
      stream: BookingService.getMyNotificationsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No notifications yet'));
        }

        final notifications = snapshot.data!;
        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: Icon(
                  _getNotificationIcon(notification.type),
                  color: _getNotificationColor(notification.type),
                  size: 28,
                ),
                title: Text(
                  notification.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(notification.message),
                    const SizedBox(height: 4),
                    Text(
                      'Posted: ${_formatDate(notification.date)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGeneralAnnouncements() {
    return StreamBuilder<List<Announcement>>(
      stream: BookingService.getGeneralAnnouncementsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No announcements yet'));
        }

        final announcements = snapshot.data!;
        return ListView.builder(
          itemCount: announcements.length,
          itemBuilder: (context, index) {
            final announcement = announcements[index];
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: const Icon(
                  Icons.campaign,
                  color: Colors.blue,
                  size: 28,
                ),
                title: Text(
                  announcement.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(announcement.message),
                    const SizedBox(height: 4),
                    Text(
                      'Posted: ${_formatDate(announcement.date)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'approval':
        return Icons.check_circle;
      case 'rejection':
        return Icons.cancel;
      case 'violation':
        return Icons.warning;
      case 'booking':
        return Icons.pending;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'approval':
        return Colors.green;
      case 'rejection':
        return Colors.red;
      case 'violation':
        return Colors.orange;
      case 'booking':
        return Colors.blue;
      default:
        return Colors.purple;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
