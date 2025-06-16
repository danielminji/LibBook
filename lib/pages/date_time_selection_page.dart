import 'package:flutter/material.dart';
import '../services/booking_service.dart';

class DateTimeSelectionPage extends StatefulWidget {
  final String roomName;

  const DateTimeSelectionPage({super.key, required this.roomName});

  @override
  State<DateTimeSelectionPage> createState() => _DateTimeSelectionPageState();
}

class _DateTimeSelectionPageState extends State<DateTimeSelectionPage> {
  DateTime selectedDate = DateTime.now();
  String? selectedTimeSlot;

  final List<String> allTimeSlots = [
    '8:00 AM - 9:00 AM',
    '9:00 AM - 10:00 AM',
    '10:00 AM - 11:00 AM',
    '11:00 AM - 12:00 PM',
    '12:00 PM - 1:00 PM',
    '1:00 PM - 2:00 PM',
    '2:00 PM - 3:00 PM',
    '3:00 PM - 4:00 PM',
    '4:00 PM - 5:00 PM',
    '5:00 PM - 6:00 PM',
    '6:00 PM - 7:00 PM',
  ];

  List<String> get availableTimeSlots {
    final bookedSlots = BookingService.getBookedTimeSlots(selectedDate);
    return allTimeSlots.where((slot) => !bookedSlots.contains(slot)).toList();
  }

  List<Booking> get bookedSlotsForDate {
    return BookingService.getBookings()
        .where((booking) =>
            booking.date.year == selectedDate.year &&
            booking.date.month == selectedDate.month &&
            booking.date.day == selectedDate.day &&
            booking.roomName == widget.roomName &&
            booking.status == 'Approved')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Book ${widget.roomName}')),
      body: StreamBuilder<List<Booking>>(
        stream: BookingService.getBookingsStream(),
        builder: (context, snapshot) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Select Date'),
                    subtitle: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                    ),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                          selectedTimeSlot = null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Available Time Slots:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: availableTimeSlots.length,
                    itemBuilder: (context, index) {
                      final timeSlot = availableTimeSlots[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.access_time,
                              color: Colors.green),
                          title: Text(timeSlot),
                          selected: timeSlot == selectedTimeSlot,
                          onTap: () {
                            setState(() {
                              selectedTimeSlot = timeSlot;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                if (bookedSlotsForDate.isNotEmpty) ...[
                  const Text(
                    'Booked Time Slots:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      itemCount: bookedSlotsForDate.length,
                      itemBuilder: (context, index) {
                        final booking = bookedSlotsForDate[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.block, color: Colors.red),
                            title: Text(booking.timeSlot),
                            subtitle: Text('Status: ${booking.status}'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedTimeSlot != null
                        ? () {
                            final booking = Booking(
                              roomName: widget.roomName,
                              date: selectedDate,
                              timeSlot: selectedTimeSlot!,
                              status: 'Pending',
                              userEmail:
                                  'user@example.com', // Replace with actual user email
                            );

                            BookingService.addBooking(booking);
                            setState(() {
                              selectedTimeSlot = null;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Booking request submitted! Waiting for approval.'),
                                backgroundColor: Colors.orange,
                              ),
                            );

                            Navigator.pop(context);
                          }
                        : null,
                    child: const Text('Request Booking'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
