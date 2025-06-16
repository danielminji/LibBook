import 'dart:async';
import 'package:flutter/material.dart';

class Booking {
  final String roomName;
  final DateTime date;
  final String timeSlot;
  String status;
  String? adminMessage;
  final String userEmail;
  List<String> violations;

  Booking({
    required this.roomName,
    required this.date,
    required this.timeSlot,
    required this.userEmail,
    this.status = 'Pending',
    this.adminMessage,
    List<String>? violations,
  }) : violations = violations ?? [];
}

class Announcement {
  final String title;
  final String message;
  final DateTime date;
  final String type;
  final String? targetUserEmail;

  Announcement({
    required this.title,
    required this.message,
    required this.date,
    required this.type,
    this.targetUserEmail,
  });
}

class BookingService {
  static final List<Booking> _bookings = [];
  static final List<Announcement> _announcements = [];
  static final Map<String, Set<String>> _bookedTimeSlots = {};

  static final _myNotificationsController =
      StreamController<List<Announcement>>.broadcast();
  static final _generalAnnouncementsController =
      StreamController<List<Announcement>>.broadcast();
  static final _bookingsController =
      StreamController<List<Booking>>.broadcast();

  // Helper method to convert DateTime to string key
  static String _dateToKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  // Booking methods
  static void addBooking(Booking booking) {
    _bookings.add(booking);

    // Create a booking notification announcement that will appear in My Notifications
    addAnnouncement(
      Announcement(
        title: 'Booking Request Submitted',
        message: 'Your booking request details:\n\n'
            'Room: ${booking.roomName}\n'
            'Date: ${_formatDate(booking.date)}\n'
            'Time: ${booking.timeSlot}\n'
            'Status: ${booking.status}',
        date: DateTime.now(),
        type: 'Booking',
        targetUserEmail: booking.userEmail,
      ),
    );

    _updateBookingsStream();
  }

  static List<Booking> getBookings() {
    return List.from(_bookings);
  }

  static List<Booking> getPendingBookings() {
    return _bookings.where((booking) => booking.status == 'Pending').toList();
  }

  static Set<String> getBookedTimeSlots(DateTime date) {
    final approvedBookings = _bookings
        .where((booking) =>
            booking.status == 'Approved' &&
            booking.date.year == date.year &&
            booking.date.month == date.month &&
            booking.date.day == date.day)
        .map((booking) => booking.timeSlot)
        .toSet();

    return approvedBookings;
  }

  static void approveBooking(Booking booking, String message) {
    booking.status = 'Approved';
    booking.adminMessage = message;

    final dateKey = _dateToKey(booking.date);
    _bookedTimeSlots.putIfAbsent(dateKey, () => {});
    _bookedTimeSlots[dateKey]!.add(booking.timeSlot);

    // Create approval notification that will appear in My Notifications
    addAnnouncement(
      Announcement(
        title: 'Booking Approved! 🎉',
        message: 'Your booking has been approved!\n\n'
            'Room: ${booking.roomName}\n'
            'Date: ${_formatDate(booking.date)}\n'
            'Time: ${booking.timeSlot}\n'
            'Status: Approved'
            '${message.isNotEmpty ? '\nAdmin Message: $message' : ''}',
        date: DateTime.now(),
        type: 'Approval',
        targetUserEmail: booking.userEmail,
      ),
    );

    _updateBookingsStream();
  }

  static void rejectBooking(Booking booking, String reason) {
    booking.status = 'Rejected';
    booking.adminMessage = reason;

    addAnnouncement(
      Announcement(
        title: 'Booking Rejected',
        message: 'Your booking request has been rejected.\n\n'
            'Room: ${booking.roomName}\n'
            'Date: ${_formatDate(booking.date)}\n'
            'Time: ${booking.timeSlot}\n'
            'Reason: $reason',
        date: DateTime.now(),
        type: 'Rejection',
        targetUserEmail: booking.userEmail,
      ),
    );

    _updateBookingsStream();
  }

  // Announcement methods
  static void addAnnouncement(Announcement announcement) {
    _announcements.add(announcement);
    _updateAnnouncementStreams();
  }

  static List<Announcement> getAnnouncements() {
    return List.from(_announcements);
  }

  // Stream getters
  static Stream<List<Announcement>> getMyNotificationsStream() {
    return _myNotificationsController.stream;
  }

  static Stream<List<Announcement>> getGeneralAnnouncementsStream() {
    return _generalAnnouncementsController.stream;
  }

  static Stream<List<Booking>> getBookingsStream() {
    return _bookingsController.stream;
  }

  // Stream update methods
  static void _updateAnnouncementStreams() {
    // Personal notifications (includes bookings and approvals)
    final notifications = _announcements
        .where((a) =>
            a.targetUserEmail ==
                'user@example.com' || // Show user-specific notifications
            a.type.toLowerCase() == 'booking' ||
            a.type.toLowerCase() == 'approval' ||
            a.type.toLowerCase() == 'rejection')
        .toList();
    _myNotificationsController.add(notifications);

    // General announcements (includes announcements from admin)
    final generalAnnouncements = _announcements
        .where((a) =>
                a.type.toLowerCase() ==
                    'general' || // Show general announcements
                a.targetUserEmail ==
                    null // Show announcements without specific target
            )
        .toList();
    _generalAnnouncementsController.add(generalAnnouncements);
  }

  static void _updateBookingsStream() {
    _bookingsController.add(List.from(_bookings));
  }

  // Helper method for date formatting
  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Admin methods
  static void createGeneralAnnouncement({
    required String title,
    required String message,
  }) {
    final announcement = Announcement(
      title: title,
      message: message,
      date: DateTime.now(),
      type: 'General',
      targetUserEmail: null, // null means visible to all users
    );

    _announcements.add(announcement);
    _updateAnnouncementStreams();
  }

  static void addViolation(Booking booking, String violation) {
    booking.violations.add(violation);

    addAnnouncement(
      Announcement(
        title: 'Violation Reported',
        message:
            'A violation has been reported for your booking of ${booking.roomName}.\n'
            'Date: ${_formatDate(booking.date)}\n'
            'Time: ${booking.timeSlot}\n'
            'Violation: $violation',
        date: DateTime.now(),
        type: 'Violation',
        targetUserEmail: booking.userEmail,
      ),
    );

    _updateBookingsStream();
  }

  // Cleanup method
  static void dispose() {
    _myNotificationsController.close();
    _generalAnnouncementsController.close();
    _bookingsController.close();
  }
}
