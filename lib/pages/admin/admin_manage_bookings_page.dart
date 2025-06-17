import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To get current admin's ID
import 'package:library_booking/services/booking_service.dart';
import 'package:library_booking/services/room_service.dart'; // To get room names

/// Admin page for managing all user booking requests.
///
/// Displays bookings in a tabbed interface, filtered by status ('Pending',
/// 'Approved', 'Rejected', 'Cancelled', 'All'). Administrators can approve or
/// reject pending bookings. The page primarily focuses on handling 'Pending'
/// bookings in this iteration, with other tabs showing placeholder messages
/// or client-side filtered data if a general booking stream is used.
class AdminManageBookingsPage extends StatefulWidget {
  /// Creates an instance of [AdminManageBookingsPage].
  const AdminManageBookingsPage({super.key});

  /// The named route for this page.
  static const String routeName = '/admin/manage-bookings';

  @override
  State<AdminManageBookingsPage> createState() => _AdminManageBookingsPageState();
}

/// Manages the state for the [AdminManageBookingsPage].
///
/// Handles fetching and displaying bookings based on selected status filters,
/// interacting with [BookingService] to approve or reject bookings, and
/// fetching room names via [RoomService] for better display.
class _AdminManageBookingsPageState extends State<AdminManageBookingsPage> with SingleTickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  final RoomService _roomService = RoomService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  TabController? _tabController;
  final List<String> _bookingStatusFilters = ['Pending', 'Approved', 'Rejected', 'Cancelled', 'All'];
  String _selectedFilter = 'Pending'; // Default filter

  Stream<List<Booking>>? _bookingsStream;
  final Map<String, String> _roomNamesCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _bookingStatusFilters.length, vsync: this);
    _tabController!.addListener(() {
      // Ensures that the listener only acts on explicit tab selections,
      // not during programmatic index changes or initial setup.
      if (!_tabController!.indexIsChanging && mounted) {
        setState(() {
          _selectedFilter = _bookingStatusFilters[_tabController!.index];
          _loadBookingsForCurrentFilter();
        });
      }
    });
    _loadBookingsForCurrentFilter(); // Initial load for the default filter ('Pending')
  }

  /// Loads the stream of bookings based on the currently selected filter tab.
  ///
  /// For this implementation, it primarily loads pending bookings using
  /// [BookingService.getPendingBookings] when the 'Pending' tab is selected.
  /// For other tabs, it currently sets an empty stream, indicating that
  /// more specific service methods (e.g., for all bookings or by other statuses)
  /// would be needed for full functionality across all tabs.
  void _loadBookingsForCurrentFilter() {
    if (_selectedFilter == 'Pending') {
      setState(() {
        _bookingsStream = _bookingService.getPendingBookings();
      });
    } else {
      // Placeholder for other filters: shows an empty list and relies on
      // the build method to display an appropriate message for these tabs.
      // A production app would have service methods like `getAdminBookingsByStatus(status)`
      // or `getAdminAllBookings()`.
      setState(() {
        _bookingsStream = Stream.value([]);
      });
    }
  }

  /// Fetches and caches the name of a room given its [roomId].
  ///
  /// If the room name is already in [_roomNamesCache], it's returned directly.
  /// Otherwise, it fetches room details using [RoomService.getRoom],
  /// caches the name if found, and then returns it.
  /// Falls back to returning the [roomId] itself if the name cannot be fetched.
  ///
  /// - [roomId]: The ID of the room.
  ///
  /// Returns the room name as a [String], or the [roomId] as a fallback.
  Future<String> _getRoomName(String roomId) async {
    if (_roomNamesCache.containsKey(roomId)) return _roomNamesCache[roomId]!;
    try {
      Room? room = await _roomService.getRoom(roomId);
      if (room != null) {
        if (mounted) {
          // setState is called to update the cache; individual FutureBuilders
          // in the list will use the resolved name.
          setState(() => _roomNamesCache[roomId] = room.name);
        }
        return room.name;
      }
    } catch (e) { print("Error fetching room name for $roomId: $e"); }
    return roomId; // Fallback to roomId
  }

  /// Shows a dialog to confirm approval of a [booking] and allows adding an admin message.
  ///
  /// If confirmed, calls [BookingService.approveBooking].
  /// Displays a [SnackBar] for success or failure.
  ///
  /// - [booking]: The [Booking] object to be approved.
  Future<void> _approveBookingDialog(Booking booking) async {
    final adminId = _firebaseAuth.currentUser?.uid ?? 'unknown_admin';
    String? adminMessage;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final messageController = TextEditingController();
        return AlertDialog(
          title: const Text('Approve Booking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Approve booking for Room ${booking.roomId} by ${booking.userEmail}?'),
              const SizedBox(height: 10),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Optional Message to User',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => adminMessage = value,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _bookingService.approveBooking(booking.bookingId, adminId, adminMessage: adminMessage);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking approved!'), backgroundColor: Colors.green));
        // The StreamBuilder listening to pending bookings will automatically update.
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to approve: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  /// Shows a dialog to confirm rejection of a [booking] and requires a rejection reason.
  ///
  /// If confirmed and reason provided, calls [BookingService.rejectBooking].
  /// Displays a [SnackBar] for success or failure.
  ///
  /// - [booking]: The [Booking] object to be rejected.
  Future<void> _rejectBookingDialog(Booking booking) async {
    final adminId = _firebaseAuth.currentUser?.uid ?? 'unknown_admin';
    String? rejectionReason;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final reasonController = TextEditingController();
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: const Text('Reject Booking'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Reject booking for Room ${booking.roomId} by ${booking.userEmail}?'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Rejection',
                    hintText: 'Provide a reason',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Reason is required.';
                    return null;
                  },
                  onChanged: (value) => rejectionReason = value, // Update a local variable
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  // rejectionReason is already updated via onChanged
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true && rejectionReason != null) {
      try {
        await _bookingService.rejectBooking(booking.bookingId, adminId, rejectionReason!);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking rejected.'), backgroundColor: Colors.orange));
        // The StreamBuilder will update.
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reject: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  /// Returns a [Color] based on the booking [status] for UI display.
  /// Considers common booking statuses like 'Approved', 'Pending', 'Rejected', 'Cancelled'.
  Color _getStatusColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'approved': return Colors.green.shade700;
      case 'pending': return Colors.orange.shade700;
      case 'rejected': case 'cancelled': return Colors.red.shade700;
      default: return theme.textTheme.bodySmall?.color ?? Colors.grey;
    }
  }

  /// Builds the UI for the Admin Manage Bookings Page.
  ///
  /// Features a [TabBar] for filtering bookings by status. The 'Pending' tab is
  /// primarily functional, displaying pending bookings with actions to approve or reject.
  /// Other tabs currently show placeholder messages.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Bookings'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _bookingStatusFilters.map((status) => Tab(text: status)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _bookingStatusFilters.map((statusFilter) {
          // Display placeholder for non-Pending tabs if they are selected.
          if (statusFilter != 'Pending' && _bookingStatusFilters[_tabController?.index ?? 0] == statusFilter) {
             return Center(child: Padding(
               padding: const EdgeInsets.all(16.0),
               child: Text(
                'Displaying "$statusFilter" bookings requires specific service methods (e.g., getBookingsByStatus or a general admin booking stream) in BookingService. Currently, only the "Pending" tab is fully implemented for data fetching.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600])
              ),
             ));
          }
          // For the 'Pending' tab, or if a general stream was used and filtered client-side.
          // This ensures that only the actively selected 'Pending' tab tries to build the StreamBuilder with its specific stream.
          if (statusFilter == 'Pending' && _bookingsStream == null) { // Initial load state for pending
             return const Center(child: CircularProgressIndicator());
          }
          // If a tab other than 'Pending' is selected AND its stream is not specifically loaded (currently it's set to Stream.value([])),
          // we rely on the above placeholder. If it IS the pending tab, we proceed.
           if (statusFilter != 'Pending' && _bookingStatusFilters[_tabController?.index ?? 0] != 'Pending') {
                // This condition is tricky. If _selectedFilter is NOT 'Pending', and this tab (statusFilter) is ALSO NOT 'Pending',
                // it means we are building a view for a non-active, non-pending tab.
                // We show an empty container to avoid issues if _bookingsStream is still for 'Pending'.
                // The active non-pending tab is handled by the first `if` in this map.
                return Container();
           }

          return StreamBuilder<List<Booking>>(
            stream: _bookingsStream, // This stream is set by _loadBookingsForCurrentFilter
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              }

              // Client-side filtering for demonstration if _bookingsStream were to fetch all.
              // However, with current _loadBookingsForCurrentFilter, _bookingsStream is already specific for 'Pending'
              // or empty for others. This client-side filter will mostly apply to 'All' if that stream was implemented.
              final List<Booking> bookings = snapshot.data?.where((b) {
                if (statusFilter == 'All' && _selectedFilter == 'All') return true; // Requires _bookingsStream to be all bookings
                if (statusFilter == 'Upcoming' && _selectedFilter == 'Upcoming') {
                    return b.status == 'Approved' && b.date.isAfter(DateTime.now().subtract(const Duration(days:1)));
                }
                 if (statusFilter == 'Past' && _selectedFilter == 'Past') {
                    return (b.status == 'Approved' || b.status == 'Cancelled' || b.status == 'Rejected') &&
                           b.date.isBefore(DateTime.now().subtract(const Duration(days:1)));
                }
                // For the 'Pending' tab, this will correctly show pending bookings as _bookingsStream is already filtered.
                // For other specific status tabs (Approved, Rejected, Cancelled), if _bookingsStream was fetching ALL,
                // this would filter them. But currently, they get Stream.value([]).
                return b.status.toLowerCase() == statusFilter.toLowerCase();
              }).toList() ?? [];


              if (bookings.isEmpty) {
                return Center(child: Text('No $statusFilter bookings found.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: bookings.length,
                itemBuilder: (context, index) {
                  final booking = bookings[index];
                  return FutureBuilder<String>(
                    future: _getRoomName(booking.roomId),
                    builder: (context, roomNameSnapshot) {
                      final roomName = roomNameSnapshot.data ?? booking.roomId;
                      return Card(
                        elevation: theme.cardTheme.elevation,
                        shape: theme.cardTheme.shape,
                        margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Room: $roomName', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('User: ${booking.userEmail}'),
                              const SizedBox(height: 4),
                              Text('Date: ${DateFormat('EEE, MMM d, yyyy').format(booking.date)} at ${booking.timeSlot}'),
                              const SizedBox(height: 4),
                              Text('Status: ${booking.status}', style: TextStyle(color: _getStatusColor(booking.status, theme), fontWeight: FontWeight.bold)),
                              if (booking.adminMessage != null && booking.adminMessage!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text('Admin Note: ${booking.adminMessage}', style: const TextStyle(fontStyle: FontStyle.italic)),
                                ),
                              const SizedBox(height: 10),
                              if (booking.status == 'Pending')
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: Icon(Icons.cancel_outlined, color: Colors.red.shade700),
                                      label: Text('Reject', style: TextStyle(color: Colors.red.shade700)),
                                      onPressed: () => _rejectBookingDialog(booking),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.check_circle_outline),
                                      label: const Text('Approve'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => _approveBookingDialog(booking),
                                    ),
                                  ],
                                ),
                            ],
                          ),
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
