import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To get current user
import 'package:library_booking/services/booking_service.dart';
import 'package:library_booking/services/room_service.dart'; // To fetch room name if needed
// Import UserHomePage and MyBookingsPage for navigation
import 'package:library_booking/pages/home_page.dart'; // Contains UserHomePage
import 'package:library_booking/pages/my_bookings_page.dart';
import 'package:library_booking/pages/welcome_page.dart'; // For navigation context for ModalRoute.withName

/// A page where users confirm the details of their selected room, date, and time slot
/// before submitting a booking request.
///
/// Displays a summary of the booking information. If the room name is not passed
/// directly, it attempts to fetch it using [RoomService]. On confirmation, it uses
/// [BookingService] to submit the request.
class BookingRequestPage extends StatefulWidget {
  /// The ID of the room selected for booking.
  final String roomId;
  /// The date selected for the booking.
  final DateTime selectedDate;
  /// The time slot selected for the booking.
  final String selectedTimeSlot;
  /// Optional: The name of the room. If not provided, it will be fetched.
  final String? roomName;

  /// Creates an instance of [BookingRequestPage].
  ///
  /// Requires [roomId], [selectedDate], and [selectedTimeSlot].
  /// [roomName] is optional and will be fetched if not supplied.
  const BookingRequestPage({
    super.key,
    required this.roomId,
    required this.selectedDate,
    required this.selectedTimeSlot,
    this.roomName,
  });

  /// The named route for this page.
  static const String routeName = '/request-booking';

  @override
  State<BookingRequestPage> createState() => _BookingRequestPageState();
}

/// Manages the state for the [BookingRequestPage].
///
/// Handles fetching room details (if name not provided), submitting the booking request,
/// and managing loading/error states.
class _BookingRequestPageState extends State<BookingRequestPage> {
  final BookingService _bookingService = BookingService();
  final RoomService _roomService = RoomService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  bool _isLoading = false;
  String? _errorMessage;
  String? _fetchedRoomName;

  @override
  void initState() {
    super.initState();
    if (widget.roomName == null || widget.roomName!.isEmpty) {
      _fetchRoomDetails();
    } else {
      _fetchedRoomName = widget.roomName;
    }
  }

  /// Fetches room details (specifically the name) if not provided via the constructor.
  ///
  /// Sets `_isLoading` during the fetch operation and updates `_fetchedRoomName`
  /// or `_errorMessage` based on the outcome.
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

  /// Submits the booking request to the [BookingService].
  ///
  /// Ensures a user is logged in. Sets loading state and handles potential errors,
  /// displaying messages to the user via `_errorMessage` or a success dialog.
  /// On successful submission, shows a dialog with options to navigate to
  /// "My Bookings" page or "Home" page.
  Future<void> _confirmBooking() async {
    final User? currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _errorMessage = 'You must be logged in to book a room.';
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _bookingService.requestBooking(
        userId: currentUser.uid,
        userEmail: currentUser.email ?? 'N/A',
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
                    // It's important that MyBookingsPage.routeName is correctly defined in my_bookings_page.dart
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

  /// Builds the UI for the Booking Request Page.
  ///
  /// Displays a summary of the selected booking details and provides buttons
  /// to confirm or cancel the request. Shows loading indicators or error messages
  /// as appropriate.
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
        child: (_isLoading && _fetchedRoomName == null && widget.roomName == null)
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
                      child: Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  _isLoading
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

  /// Helper widget to build a row in the booking summary.
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
