import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart'; // For displaying QR codes
import 'package:library_booking/services/booking_service.dart';
import 'package:library_booking/services/room_service.dart'; // To potentially fetch room names

// Placeholder for a dedicated BookingDetailPage, or expand logic here
// For now, details like QR and PDF will be shown in a dialog or expansion tile.

class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key});
  static const String routeName = '/my-bookings';

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> with SingleTickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  final RoomService _roomService = RoomService(); // Optional: for fetching room names
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  User? _currentUser;
  Stream<List<Booking>>? _bookingsStream;
  Map<String, String> _roomNamesCache = {}; // Cache for room names

  TabController? _tabController;
  final List<String> _bookingStatuses = ['All', 'Upcoming', 'Pending', 'Past', 'Cancelled', 'Rejected'];


  @override
  void initState() {
    super.initState();
    _currentUser = _firebaseAuth.currentUser;
    _tabController = TabController(length: _bookingStatuses.length, vsync: this);
    if (_currentUser != null) {
      _loadBookings();
    }
  }

  void _loadBookings() {
    if (_currentUser == null) return;
    setState(() {
      _bookingsStream = _bookingService.getUserBookings(_currentUser!.uid);
    });
  }

  Future<String> _getRoomName(String roomId) async {
    if (_roomNamesCache.containsKey(roomId)) {
      return _roomNamesCache[roomId]!;
    }
    try {
      Room? room = await _roomService.getRoom(roomId);
      if (room != null) {
        if (mounted) {
          setState(() {
            _roomNamesCache[roomId] = room.name;
          });
        }
        return room.name;
      }
    } catch (e) {
      print("Error fetching room name for $roomId: $e");
    }
    return roomId; // Fallback to roomId if name fetch fails
  }

  Future<void> _cancelBooking(Booking booking) async {
    if (_currentUser == null) return;

    bool? confirmCancel = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Cancellation'),
          content: Text('Are you sure you want to cancel your booking for room ${booking.roomId} on ${DateFormat('MMM d, yyyy').format(booking.date)} at ${booking.timeSlot}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Yes, Cancel'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmCancel == true) {
      try {
        await _bookingService.cancelBooking(booking.bookingId, _currentUser!.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking cancelled successfully.'), backgroundColor: Colors.green),
          );
          _loadBookings(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel booking: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade700;
      case 'pending':
        return Colors.orange.shade700;
      case 'rejected':
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return theme.textTheme.bodySmall?.color ?? Colors.grey;
    }
  }

  void _showBookingDetailsDialog(BuildContext context, Booking booking, String roomName) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Booking Details: $roomName', style: TextStyle(color: theme.colorScheme.primary)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Room: $roomName'),
                Text('Date: ${DateFormat('EEE, MMM d, yyyy').format(booking.date)}'),
                Text('Time: ${booking.timeSlot}'),
                Text('Status: ${booking.status}', style: TextStyle(color: _getStatusColor(booking.status, theme), fontWeight: FontWeight.bold)),
                if (booking.adminMessage != null && booking.adminMessage!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Admin Message: ${booking.adminMessage}'),
                  ),

                if (booking.status == 'Approved' && booking.qrCodeData != null && booking.qrCodeData!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Text("Scan for Check-in:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          QrImageView( // Using QrImageView from qr_flutter
                            data: booking.qrCodeData!,
                            version: QrVersions.auto,
                            size: 150.0,
                            gapless: false,
                          ),
                        ],
                      ),
                    ),
                  ),

                if (booking.status == 'Approved')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Download Confirmation PDF'),
                      onPressed: () {
                        // Actual PDF download logic would use booking.pdfConfirmationUrl
                        // For now, show a message as it's a placeholder.
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('PDF Download for ${booking.pdfConfirmationUrl ?? "N/A"} (feature pending actual storage).')),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            if ((booking.status == 'Pending' || booking.status == 'Approved') &&
                booking.date.isAfter(DateTime.now().subtract(const Duration(hours:1)))) // Allow cancellation if not too late
              TextButton(
                child: const Text('Cancel Booking', style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Close dialog first
                  _cancelBooking(booking);
                },
              ),
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_currentUser == null) {
      return Scaffold(appBar: AppBar(title: const Text('My Bookings')), body: const Center(child: Text('Please log in to see your bookings.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _bookingStatuses.map((status) => Tab(text: status)).toList(),
          onTap: (index) { // Optional: could trigger a filter reload if not handled by StreamBuilder directly
            setState(() {
              // This setState is mainly to rebuild if filtering logic is complex.
              // For simple filtering in StreamBuilder's map, it might not be strictly needed
              // unless the stream itself needs to be changed.
            });
          },
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _bookingStatuses.map((statusFilter) {
          return StreamBuilder<List<Booking>>(
            stream: _bookingsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading bookings: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              }
              List<Booking> allBookings = snapshot.data ?? [];

              // Sort all bookings by date descending (newest first)
              allBookings.sort((a, b) => b.date.compareTo(a.date));

              List<Booking> filteredBookings;
              if (statusFilter == 'All') {
                filteredBookings = allBookings;
              } else if (statusFilter == 'Upcoming') {
                filteredBookings = allBookings.where((b) =>
                    (b.status == 'Approved') &&
                    b.date.isAfter(DateTime.now().subtract(const Duration(days: 1)))
                ).toList();
              } else if (statusFilter == 'Past') {
                 filteredBookings = allBookings.where((b) =>
                    (b.status == 'Approved') &&
                    b.date.isBefore(DateTime.now().subtract(const Duration(days: 1)))
                ).toList();
              }
              else {
                filteredBookings = allBookings.where((b) => b.status.toLowerCase() == statusFilter.toLowerCase()).toList();
              }

              if (filteredBookings.isEmpty) {
                return Center(child: Text('No bookings found for "$statusFilter".'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: filteredBookings.length,
                itemBuilder: (context, index) {
                  final booking = filteredBookings[index];
                  // Use FutureBuilder for room name to avoid multiple state updates during build
                  return FutureBuilder<String>(
                    future: _getRoomName(booking.roomId), // Fetch room name
                    builder: (context, roomNameSnapshot) {
                      final roomName = roomNameSnapshot.data ?? booking.roomId; // Fallback to ID
                      return Card(
                        elevation: theme.cardTheme.elevation,
                        shape: theme.cardTheme.shape,
                        margin: theme.cardTheme.margin,
                        child: ListTile(
                          title: Text('Room: $roomName', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date: ${DateFormat('EEE, MMM d, yyyy').format(booking.date)}'),
                              Text('Time: ${booking.timeSlot}'),
                              Text(
                                'Status: ${booking.status}',
                                style: TextStyle(
                                  color: _getStatusColor(booking.status, theme),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showBookingDetailsDialog(context, booking, roomName),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }
}
