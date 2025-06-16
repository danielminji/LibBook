import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To get current user
import 'package:library_booking/services/booking_service.dart';
import 'package:library_booking/services/room_service.dart'; // To fetch room name if needed
// Import UserHomePage and MyBookingsPage for navigation
import 'package:library_booking/pages/home_page.dart'; // Contains UserHomePage
import 'package:library_booking/pages/my_bookings_page.dart'; // Placeholder for MyBookingsPage
import 'package:library_booking/pages/welcome_page.dart'; // For navigation context


class BookingRequestPage extends StatefulWidget {
  final String roomId;
  final DateTime selectedDate;
  final String selectedTimeSlot;
  // Optional: pass roomName if already fetched, otherwise fetch here
  final String? roomName;

  const BookingRequestPage({
    super.key,
    required this.roomId,
    required this.selectedDate,
    required this.selectedTimeSlot,
    this.roomName,
  });

  static const String routeName = '/request-booking';

  @override
  State<BookingRequestPage> createState() => _BookingRequestPageState();
}

class _BookingRequestPageState extends State<BookingRequestPage> {
  final BookingService _bookingService = BookingService();
  final RoomService _roomService = RoomService(); // For fetching room name if not passed
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  bool _isLoading = false;
  String? _errorMessage;
  String? _fetchedRoomName; // To store room name if fetched

  @override
  void initState() {
    super.initState();
    if (widget.roomName == null || widget.roomName!.isEmpty) {
      _fetchRoomDetails();
    } else {
      _fetchedRoomName = widget.roomName;
    }
  }

  Future<void> _fetchRoomDetails() async {
    setState(() { _isLoading = true; });
    try {
      Room? room = await _roomService.getRoom(widget.roomId);
      if (mounted && room != null) {
        setState(() {
          _fetchedRoomName = room.name;
        });
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Could not fetch room details.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error fetching room details: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _confirmBooking() async {
    final User? currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      setState(() {
        _errorMessage = 'You must be logged in to book a room.';
      });
      // Optionally navigate to login page
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _bookingService.requestBooking(
        userId: currentUser.uid,
        userEmail: currentUser.email ?? 'N/A', // Fallback for email
        roomId: widget.roomId,
        date: widget.selectedDate,
        timeSlot: widget.selectedTimeSlot,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Booking Request Submitted!'),
              content: const Text('Your booking request has been successfully submitted and is pending approval.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('View My Bookings'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pushReplacementNamed(MyBookingsPage.routeName);
                  },
                ),
                TextButton(
                  child: const Text('Go to Home'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pushNamedAndRemoveUntil(UserHomePage.routeName, ModalRoute.withName(WelcomePage.routeName));
                  },
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('Booking request error: $e');
      if (mounted) {
        setState(() {
          if (e.toString().contains('This time slot is already booked')) {
            _errorMessage = 'This time slot is no longer available. Please select another.';
          } else {
            _errorMessage = 'Failed to submit booking request: ${e.toString()}';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String displayRoomName = _fetchedRoomName ?? widget.roomName ?? widget.roomId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Your Booking'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading && _fetchedRoomName == null // Show loader if fetching room name initially
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Booking Summary',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSummaryRow(theme, 'Room:', displayRoomName),
                  _buildSummaryRow(theme, 'Date:', DateFormat('EEE, MMM d, yyyy').format(widget.selectedDate)),
                  _buildSummaryRow(theme, 'Time Slot:', widget.selectedTimeSlot),
                  const SizedBox(height: 30),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15.0),
                      child: Center( // Center the error message
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  _isLoading // Show loader when confirmBooking is in progress
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Confirm & Book Room'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          onPressed: _confirmBooking,
                        ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Cancel', style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSummaryRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
