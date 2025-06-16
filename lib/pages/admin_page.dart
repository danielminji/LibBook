import 'package:flutter/material.dart';
import '../services/booking_service.dart';
import './login_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginPage()),
                          (route) => false,
                        );
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildPendingBookings(),
          _buildAllBookings(),
          _buildAnnouncements(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.pending_actions),
            label: 'Pending',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'All Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.announcement),
            label: 'Announcements',
          ),
        ],
      ),
    );
  }

  Widget _buildPendingBookings() {
    final pendingBookings = BookingService.getPendingBookings();
    return pendingBookings.isEmpty
        ? const Center(child: Text('No pending bookings'))
        : ListView.builder(
            itemCount: pendingBookings.length,
            itemBuilder: (context, index) {
              final booking = pendingBookings[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text('${booking.roomName} - ${booking.timeSlot}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Date: ${booking.date.day}/${booking.date.month}/${booking.date.year}'),
                      Text('User: ${booking.userEmail}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () {
                          _showApprovalDialog(booking);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          _showRejectionDialog(booking);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget _buildAllBookings() {
    final allBookings = BookingService.getBookings();
    return allBookings.isEmpty
        ? const Center(child: Text('No bookings'))
        : ListView.builder(
            itemCount: allBookings.length,
            itemBuilder: (context, index) {
              final booking = allBookings[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text('${booking.roomName} - ${booking.timeSlot}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Date: ${booking.date.day}/${booking.date.month}/${booking.date.year}'),
                      Text('User: ${booking.userEmail}'),
                      Text('Status: ${booking.status}'),
                      if (booking.adminMessage != null)
                        Text('Message: ${booking.adminMessage}'),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget _buildAnnouncements() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: () => _showCreateAnnouncementDialog(),
            child: const Text('Create Announcement'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Announcement>>(
              stream: BookingService.getGeneralAnnouncementsStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No announcements'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final announcement = snapshot.data![index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(announcement.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(announcement.message),
                            Text(
                              'Posted: ${announcement.date.day}/${announcement.date.month}/${announcement.date.year}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        trailing: Text(
                          announcement.type,
                          style: TextStyle(
                            color: _getAnnouncementColor(announcement.type),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showApprovalDialog(Booking booking) {
    final messageController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Booking'),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(
            labelText: 'Message (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              BookingService.approveBooking(booking, messageController.text);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectionDialog(Booking booking) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Booking'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              BookingService.rejectBooking(booking, reasonController.text);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showCreateAnnouncementDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Announcement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (titleController.text.isNotEmpty &&
                  messageController.text.isNotEmpty) {
                BookingService.createGeneralAnnouncement(
                  title: titleController.text,
                  message: messageController.text,
                );
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Color _getAnnouncementColor(String type) {
    switch (type.toLowerCase()) {
      case 'approval':
        return Colors.green;
      case 'rejection':
        return Colors.red;
      case 'violation':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}
