import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To get current admin's ID
import 'package:library_booking/services/booking_service.dart';
import 'package:library_booking/services/room_service.dart'; // To get room names

class AdminManageBookingsPage extends StatefulWidget {
  const AdminManageBookingsPage({super.key});
  static const String routeName = '/admin/manage-bookings';

  @override
  State<AdminManageBookingsPage> createState() => _AdminManageBookingsPageState();
}

class _AdminManageBookingsPageState extends State<AdminManageBookingsPage> with SingleTickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  final RoomService _roomService = RoomService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  TabController? _tabController;
  final List<String> _bookingStatusFilters = ['Pending', 'Approved', 'Rejected', 'Cancelled', 'All'];
  String _selectedFilter = 'Pending'; // Default filter

  Stream<List<Booking>>? _bookingsStream;
  Map<String, String> _roomNamesCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _bookingStatusFilters.length, vsync: this);
    _tabController!.addListener(() {
      if (_tabController!.indexIsChanging) {
        // Update filter and reload bookings when tab changes
        setState(() {
          _selectedFilter = _bookingStatusFilters[_tabController!.index];
          _loadBookingsForCurrentFilter();
        });
      } else {
         // Handle case where the same tab is tapped again (if needed for refresh)
        setState(() {
          _selectedFilter = _bookingStatusFilters[_tabController!.index];
          _loadBookingsForCurrentFilter();
        });
      }
    });
    _loadBookingsForCurrentFilter(); // Initial load based on default filter "Pending"
  }

  void _loadBookingsForCurrentFilter() {
    // This method will now decide which stream to load based on _selectedFilter
    // For simplicity, this example will use specific service methods if available,
    // or fall back to a general stream + client-side filtering.
    // This part assumes BookingService might need new methods like getBookingsByStatusForAdmin.

    // For this subtask, we'll keep it simple:
    // 'Pending' -> getPendingBookings()
    // Others -> getAdminAllBookingsStream() and then filter client-side.
    // Let's assume BookingService does not yet have getAdminAllBookingsStream() or getAdminBookingsByStatusStream()
    // So, we will *only* fully implement the 'Pending' tab. Other tabs will show a message.

    if (_selectedFilter == 'Pending') {
      setState(() {
        _bookingsStream = _bookingService.getPendingBookings();
      });
    } else {
      // For other filters, ideally, you'd fetch appropriately.
      // For now, show an empty stream or a message indicating it's a placeholder.
      setState(() {
        // This will effectively show "No bookings found" or an error if not handled well.
        // A better approach for non-Pending would be a dedicated stream from the service.
        _bookingsStream = Stream.value([]); // Placeholder for non-pending filters
      });
    }
  }

  Future<String> _getRoomName(String roomId) async {
    if (_roomNamesCache.containsKey(roomId)) return _roomNamesCache[roomId]!;
    try {
      Room? room = await _roomService.getRoom(roomId);
      if (room != null) {
        if (mounted) setState(() => _roomNamesCache[roomId] = room.name);
        return room.name;
      }
    } catch (e) { print("Error fetching room name for $roomId: $e"); }
    return roomId; // Fallback to roomId
  }

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
        // StreamBuilder will update the list
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to approve: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

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
                  onChanged: (value) => rejectionReason = value,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
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
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reject: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'approved': return Colors.green.shade700;
      case 'pending': return Colors.orange.shade700;
      case 'rejected': case 'cancelled': return Colors.red.shade700;
      default: return theme.textTheme.bodySmall?.color ?? Colors.grey;
    }
  }

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
          // If the current tab is not 'Pending', show a placeholder message.
          // This is because our _loadBookingsForCurrentFilter only properly loads data for 'Pending'.
          if (statusFilter != 'Pending' && _selectedFilter == statusFilter) {
             return Center(child: Padding(
               padding: const EdgeInsets.all(16.0),
               child: Text('Displaying "$statusFilter" bookings requires specific service methods (e.g., getBookingsByStatus) or a general admin booking stream in BookingService. Currently, only "Pending" tab is fully implemented for fetching data.', textAlign: TextAlign.center),
             ));
          }
          // This handles the initial state or when 'Pending' is not the explicitly selected filter for this view
          if (statusFilter == 'Pending' && _bookingsStream == null) {
             return const Center(child: CircularProgressIndicator());
          }
           if (statusFilter != 'Pending' && _selectedFilter != 'Pending') {
             // Avoid trying to build a StreamBuilder for non-Pending tabs if their stream isn't specifically loaded
             // This prevents errors if _bookingsStream is still holding pending bookings when another tab is active
             // but not yet "fully" implemented for data loading.
             if (_selectedFilter == statusFilter) { // Only show placeholder if it's the *active* non-pending tab
                return Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Displaying "$statusFilter" bookings requires specific service methods. Currently, only "Pending" tab is fully implemented for fetching data.', textAlign: TextAlign.center),
                ));
             }
             return Container(); // Return empty container for non-active, non-pending tabs
           }


          return StreamBuilder<List<Booking>>(
            stream: _bookingsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              }

              // This client-side filtering is only effective if _bookingsStream fetches ALL bookings
              // or if _bookingsStream is correctly updated by _loadBookingsForCurrentFilter for each tab.
              // Given the current _loadBookingsForCurrentFilter, this will primarily work for 'Pending'.
              final List<Booking> bookings = snapshot.data?.where((b) {
                if (statusFilter == 'All') return true;
                if (statusFilter == 'Upcoming') { // Example of a derived status, not a direct DB status
                    return b.status == 'Approved' && b.date.isAfter(DateTime.now().subtract(const Duration(days:1)));
                }
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
                        margin: theme.cardTheme.margin?.copyWith(top: 8, bottom: 0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0), // Increased padding
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Room: $roomName', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('User: ${booking.userEmail}'),
                              // Text('User ID: ${booking.userId}'), // For admin debug
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
                                        foregroundColor: Colors.white, // Ensure text is white
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
