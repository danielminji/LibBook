import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart'; // For displaying QR codes
import 'package:library_booking/services/booking_service.dart';
import 'package:library_booking/services/room_service.dart'; // To potentially fetch room names

/// A page that displays a list of the current user's bookings.
///
/// Users can view their bookings filtered by status (e.g., All, Upcoming, Pending, Past).
/// It provides options to view booking details (including QR codes for approved bookings)
/// and to cancel upcoming or pending bookings.
class MyBookingsPage extends StatefulWidget {
  /// Creates an instance of [MyBookingsPage].
  const MyBookingsPage({super.key});

  /// The named route for this page.
  static const String routeName = '/my-bookings';

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

/// Manages the state for the [MyBookingsPage].
///
/// This includes fetching the user's bookings, handling tab-based filtering,
/// displaying booking details in a dialog, and processing booking cancellations.
class _MyBookingsPageState extends State<MyBookingsPage> with SingleTickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  final RoomService _roomService = RoomService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  User? _currentUser;
  Stream<List<Booking>>? _bookingsStream;
  final Map<String, String> _roomNamesCache = {}; // Cache for room names to reduce Firestore reads

  TabController? _tabController;
  final List<String> _bookingStatuses = ['All', 'Upcoming', 'Pending', 'Past', 'Cancelled', 'Rejected'];
  // _selectedFilter is implicitly managed by _tabController.index

  @override
  void initState() {
    super.initState();
    _currentUser = _firebaseAuth.currentUser;
    _tabController = TabController(length: _bookingStatuses.length, vsync: this);
    // Add listener to TabController to update state or reload data if necessary,
    // though StreamBuilder handles UI updates when _bookingsStream changes.
    // The primary role of this listener could be to change the stream itself if
    // different service methods were used per tab. For client-side filtering,
    // a simple setState might be needed if the filter logic is outside StreamBuilder's map.
    _tabController!.addListener(() {
      if (mounted && !_tabController!.indexIsChanging) {
         setState(() {
           // The StreamBuilder's filter logic will use the new tab index.
           // No need to change _bookingsStream if it fetches all user bookings.
         });
      }
    });
    if (_currentUser != null) {
      _loadBookings();
    }
  }

  /// Loads the stream of bookings for the current user.
  ///
  /// Initializes [_bookingsStream] by calling [BookingService.getUserBookings].
  /// This stream will provide all bookings for the user, which are then
  /// filtered client-side by the [TabBarView] and [StreamBuilder].
  void _loadBookings() {
    if (_currentUser == null) return;
    setState(() {
      _bookingsStream = _bookingService.getUserBookings(_currentUser!.uid);
    });
  }

  /// Fetches and caches the name of a room given its [roomId].
  ///
  /// If the room name is already in [_roomNamesCache], it's returned directly.
  /// Otherwise, it fetches the room details using [RoomService.getRoom],
  /// caches the name, and then returns it.
  /// Falls back to returning the [roomId] if the name cannot be fetched.
  ///
  /// - [roomId]: The ID of the room whose name is to be fetched.
  ///
  /// Returns the room name as a [String], or the [roomId] as a fallback.
  Future<String> _getRoomName(String roomId) async {
    if (_roomNamesCache.containsKey(roomId)) {
      return _roomNamesCache[roomId]!;
    }
    try {
      Room? room = await _roomService.getRoom(roomId);
      if (room != null) {
        if (mounted) {
          // setState is used here to update the cache, which might trigger
          // a rebuild if a FutureBuilder directly depends on a map derived from this.
          // However, individual ListTiles use FutureBuilder for _getRoomName,
          // so this setState primarily populates the cache for future direct lookups.
          setState(() {
            _roomNamesCache[roomId] = room.name;
          });
        }
        return room.name;
      }
    } catch (e) {
      print("Error fetching room name for $roomId: $e");
    }
    return roomId; // Fallback to roomId
  }

  /// Prompts the user for confirmation and then attempts to cancel the specified [booking].
  ///
  /// Shows a confirmation dialog. If confirmed by the user, it calls
  /// [BookingService.cancelBooking]. Displays a [SnackBar] to indicate
  /// the success or failure of the cancellation and refreshes the booking list.
  /// Requires [_currentUser] to be non-null.
  ///
  /// - [booking]: The [Booking] object to be cancelled.
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
          // _loadBookings(); // Refresh the list - StreamBuilder should handle this automatically if stream changes or items are updated.
                           // If the stream source itself doesn't change (e.g. status update on existing items),
                           // this manual refresh might be needed if not using a more reactive stream from service.
                           // Given getUserBookings is a stream of List<Booking>, Firestore updates should trigger it.
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

  /// Returns a [Color] based on the booking [status] string for UI display.
  Color _getStatusColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade700;
      case 'pending':
        return Colors.orange.shade700;
      case 'rejected':
      case 'cancelled':
        return Colors.red.shade700;
      default: // For 'Past' or any other statuses
        return theme.textTheme.bodySmall?.color ?? Colors.grey;
    }
  }

  /// Shows a dialog displaying detailed information about a [booking].
  ///
  /// Includes room name, date, time, status, admin messages, and for "Approved"
  /// bookings, a QR code for check-in and a button to (simulate) PDF download.
  /// Also provides an option to cancel the booking from within the dialog if applicable.
  ///
  /// - [context]: The build context for showing the dialog.
  /// - [booking]: The [Booking] object whose details are to be displayed.
  /// - [roomName]: The display name of the room, fetched by [_getRoomName].
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
                          QrImageView(
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
                booking.date.isAfter(DateTime.now().subtract(const Duration(hours:1))))
              TextButton(
                child: const Text('Cancel Booking', style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
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

  /// Builds the UI for the My Bookings Page.
  ///
  /// Features a [TabBar] to filter bookings by status and a [TabBarView]
  /// that uses a [StreamBuilder] to display the list of relevant bookings.
  /// Each booking is shown in a [Card] and is tappable to view details.
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
          // onTap listener in initState handles tab changes for filtering if needed,
          // but client-side filtering in StreamBuilder's map is primary here.
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

              allBookings.sort((a, b) => b.date.compareTo(a.date)); // Sort all by date first

              List<Booking> filteredBookings;
              if (statusFilter == 'All') {
                filteredBookings = allBookings;
              } else if (statusFilter == 'Upcoming') {
                filteredBookings = allBookings.where((b) =>
                    (b.status == 'Approved') &&
                    b.date.isAfter(DateTime.now().subtract(const Duration(days: 1))) // Today or future
                ).toList();
              } else if (statusFilter == 'Past') {
                 filteredBookings = allBookings.where((b) =>
                    (b.status == 'Approved' || b.status == 'Cancelled' || b.status == 'Rejected') && // Include relevant past statuses
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
                  return FutureBuilder<String>(
                    future: _getRoomName(booking.roomId),
                    builder: (context, roomNameSnapshot) {
                      final roomName = roomNameSnapshot.data ?? booking.roomId;
                      return Card(
                        elevation: theme.cardTheme.elevation,
                        shape: theme.cardTheme.shape,
                        margin: theme.cardTheme.margin?.copyWith(top:8, bottom:0), // Consistent margin
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
