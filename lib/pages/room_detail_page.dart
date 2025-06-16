import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:library_booking/services/room_service.dart';
import 'package:library_booking/services/booking_service.dart';
import 'package:library_booking/pages/booking_request_page.dart';

/// Displays detailed information about a specific room and allows users to select
/// a date and time slot for booking.
///
/// This page fetches room details using [RoomService] and available time slots
/// for a selected date using [BookingService]. Users can pick a date, view available
/// slots, and select a slot to proceed to the [BookingRequestPage].
class RoomDetailPage extends StatefulWidget {
  /// The ID of the room for which details are to be displayed.
  final String roomId;

  /// Creates an instance of [RoomDetailPage].
  ///
  /// Requires a [roomId] to fetch and display room information.
  const RoomDetailPage({super.key, required this.roomId});

  // static const String routeName = '/room-detail'; // Not strictly needed if always navigated to with arguments

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

/// Manages the state for the [RoomDetailPage].
///
/// Handles fetching room details, managing date selection, loading and displaying
/// available time slots, and user interaction for selecting a time slot.
class _RoomDetailPageState extends State<RoomDetailPage> {
  final RoomService _roomService = RoomService();
  final BookingService _bookingService = BookingService();

  late Future<Room?> _roomDetailsFuture;
  DateTime? _selectedDate;
  Stream<List<String>>? _availableSlotsStream;
  String? _selectedTimeSlot;

  @override
  void initState() {
    super.initState();
    _roomDetailsFuture = _roomService.getRoom(widget.roomId);
    _selectedDate = DateTime.now(); // Default to today
    _loadAvailableSlots(); // Load slots for default date
  }

  /// Loads the stream of available time slots for the currently selected date and room.
  ///
  /// If [_selectedDate] is not null, it updates the [_availableSlotsStream] by calling
  /// [BookingService.getAvailableTimeSlots]. It also resets [_selectedTimeSlot]
  /// whenever the date changes or slots are reloaded.
  void _loadAvailableSlots() {
    if (_selectedDate != null) {
      setState(() {
        _availableSlotsStream = _bookingService.getAvailableTimeSlots(widget.roomId, _selectedDate!);
        _selectedTimeSlot = null;
      });
    }
  }

  /// Opens a date picker dialog to allow the user to select a booking date.
  ///
  /// The date picker is limited to selecting dates from the current day up to
  /// 30 days in the future. If a new date is selected, [_selectedDate] is updated,
  /// and available slots are reloaded via [_loadAvailableSlots].
  ///
  /// - [context]: The build context from which to show the dialog.
  Future<void> _pickDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
        _loadAvailableSlots();
      });
    }
  }

  /// Handles the selection of a time slot by the user.
  ///
  /// Updates the [_selectedTimeSlot] state. This method previously showed a dialog
  /// for confirmation, but now primarily updates the state, and the actual navigation
  /// or action is triggered by the "Proceed to Book Selected Slot" button.
  ///
  /// - [timeSlot]: The time slot string selected by the user.
  void _onTimeSlotSelected(String timeSlot) {
    setState(() {
      _selectedTimeSlot = timeSlot;
    });
  }

  /// Builds the UI for the Room Detail Page.
  ///
  /// Displays room information (name, capacity, amenities), a date picker,
  /// and a list of available time slots for the selected date. A button to proceed
  /// with booking is shown when a time slot is selected.
  /// Uses [FutureBuilder] for room details and [StreamBuilder] for time slots.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Details'),
      ),
      body: FutureBuilder<Room?>(
        future: _roomDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(child: Text('Error loading room details: ${snapshot.error ?? 'Room not found.'}', style: const TextStyle(color: Colors.red)));
          }
          final room = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Room Information Section
                Text(
                  room.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people_alt_outlined, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 6),
                    Text('Capacity: ${room.capacity}', style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Amenities:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (room.amenities.isNotEmpty)
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: room.amenities.map((amenity) => Chip(
                      label: Text(amenity),
                      backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
                      labelStyle: TextStyle(color: theme.colorScheme.secondary),
                    )).toList(),
                  )
                else
                  const Text('No listed amenities.'),
                const SizedBox(height: 20),
                Divider(color: Colors.grey[300]),
                const SizedBox(height: 20),

                // Date Selection Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Date:',
                      style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary),
                    ),
                    TextButton.icon(
                      icon: Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                      label: Text(
                        _selectedDate != null ? DateFormat('EEE, MMM d, yyyy').format(_selectedDate!) : 'Choose Date',
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _pickDate(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Available Time Slots Section
                Text(
                  'Available Slots:',
                  style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary),
                ),
                const SizedBox(height: 8),
                if (_selectedDate == null)
                  const Center(child: Text('Please select a date to see available slots.'))
                else
                  StreamBuilder<List<String>>(
                    stream: _availableSlotsStream,
                    builder: (context, slotSnapshot) {
                      if (slotSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (slotSnapshot.hasError) {
                        return Center(child: Text('Error loading slots: ${slotSnapshot.error}', style: const TextStyle(color: Colors.red)));
                      }
                      final slots = slotSnapshot.data;
                      if (slots == null || slots.isEmpty) {
                        return const Center(child: Text('No available slots for this date.'));
                      }
                      return Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: slots.map((slot) {
                          final isSelected = slot == _selectedTimeSlot;
                          return ChoiceChip(
                            label: Text(slot),
                            selected: isSelected,
                            onSelected: (selected) {
                              _onTimeSlotSelected(slot);
                            },
                            selectedColor: theme.colorScheme.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color,
                            ),
                            backgroundColor: theme.chipTheme.backgroundColor ?? Colors.grey[200],
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  if (_selectedTimeSlot != null)
                    Center(
                      child: ElevatedButton(
                        onPressed: (_selectedDate == null || room == null)
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BookingRequestPage(
                                    roomId: widget.roomId,
                                    roomName: room.name,
                                    selectedDate: _selectedDate!,
                                    selectedTimeSlot: _selectedTimeSlot!,
                                  ),
                                ),
                              );
                            },
                        child: const Text('Proceed to Book Selected Slot'),
                      ),
                    )
              ],
            ),
          );
        },
      ),
    );
  }
}
