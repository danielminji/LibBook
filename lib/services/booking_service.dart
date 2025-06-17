import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Added for DateFormat
import 'package:library_booking/services/telegram_service.dart';
import 'package:library_booking/services/auth_service.dart';
import 'package:library_booking/services/calendar_service.dart';
import 'package:library_booking/services/pdf_generation_service.dart';
import 'dart:typed_data'; // For Uint8List

/// Represents a single booking made by a user for a library room.
///
/// This class serves as the data model for booking information stored in Firestore
/// and handled by the [BookingService].
class Booking {
  /// The unique identifier for the booking (Firestore document ID).
  final String bookingId;

  /// The ID of the user who made the booking. Corresponds to a user ID in Firebase Auth and Firestore 'users' collection.
  final String userId;

  /// The email of the user who made the booking. Denormalized for convenience in displaying booking lists.
  final String userEmail;

  /// The ID of the room that was booked. Corresponds to a room ID in the 'rooms' collection.
  final String roomId;
  // String roomName; // Consider removing or denormalizing if essential for lists and fetched separately.

  /// The date for which the room is booked. Stored as a Firestore Timestamp, converted to DateTime in the model.
  final DateTime date;

  /// The specific time slot for the booking (e.g., "09:00-10:00").
  final String timeSlot;

  /// The current status of the booking (e.g., 'Pending', 'Approved', 'Rejected', 'Cancelled').
  String status;

  /// An optional message from an admin regarding the booking (e.g., reason for rejection).
  String? adminMessage;

  /// The timestamp when the booking was created in Firestore.
  final DateTime createdAt;

  /// The timestamp of the last update to the booking details in Firestore.
  DateTime updatedAt;

  /// A list of violation identifiers associated with this booking (e.g., for rule breaches).
  /// Kept for future use.
  List<String> violations;

  /// Data to be encoded into a QR code, typically the [bookingId], used for check-in or verification.
  String? qrCodeData;

  /// URL pointing to a generated PDF confirmation for this booking.
  String? pdfConfirmationUrl;

  /// Identifier for an event created in an external calendar system (e.g., Cronofy event ID).
  String? calendarEventId;

  /// The ID of the admin user who last processed (approved/rejected) this booking.
  String? bookedByAdminId;

  /// Creates a [Booking] instance.
  Booking({
    required this.bookingId,
    required this.userId,
    required this.userEmail,
    required this.roomId,
    required this.date,
    required this.timeSlot,
    this.status = 'Pending',
    this.adminMessage,
    required this.createdAt,
    required this.updatedAt,
    this.violations = const [],
    this.qrCodeData,
    this.pdfConfirmationUrl,
    this.calendarEventId,
    this.bookedByAdminId,
  });

  /// Creates a [Booking] instance from a Firestore document snapshot.
  ///
  /// This factory constructor handles the conversion of Firestore data (including Timestamps)
  /// into a Dart [Booking] object, providing default values for fields that might be null.
  ///
  /// - [doc]: The [DocumentSnapshot] from Firestore.
  factory Booking.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Booking(
      bookingId: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      roomId: data['roomId'] ?? '',
      date: (data['date'] as Timestamp).toDate(), // Assumes 'date' is always a Timestamp
      timeSlot: data['timeSlot'] ?? '',
      status: data['status'] ?? 'Pending',
      adminMessage: data['adminMessage'],
      createdAt: (data['createdAt'] as Timestamp).toDate(), // Assumes 'createdAt' is always a Timestamp
      updatedAt: (data['updatedAt'] as Timestamp).toDate(), // Assumes 'updatedAt' is always a Timestamp
      violations: List<String>.from(data['violations'] ?? []),
      qrCodeData: data['qrCodeData'],
      pdfConfirmationUrl: data['pdfConfirmationUrl'],
      calendarEventId: data['calendarEventId'],
      bookedByAdminId: data['bookedByAdminId'],
    );
  }

  /// Converts this [Booking] object to a [Map] suitable for storage in Firestore.
  ///
  /// Dates are converted to Firestore [Timestamp] objects.
  /// The `bookingId` is not included as it's the document ID.
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'roomId': roomId,
      'date': Timestamp.fromDate(date),
      'timeSlot': timeSlot,
      'status': status,
      'adminMessage': adminMessage,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'violations': violations,
      'qrCodeData': qrCodeData,
      'pdfConfirmationUrl': pdfConfirmationUrl,
      'calendarEventId': calendarEventId,
      'bookedByAdminId': bookedByAdminId,
    };
  }
}

/// Service responsible for managing room bookings in Firestore.
///
/// This service handles operations such as creating booking requests,
/// canceling bookings, retrieving booking details and lists, and admin
/// actions like approving or rejecting bookings. It also integrates with
/// other services for notifications and calendar events.
class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'bookings';

  /// Provides a predefined list of time slots available for booking.
  ///
  /// Example: Generates 1-hour slots from 9 AM to 5 PM.
  /// This could be made configurable based on library hours or room availability rules.
  ///
  /// Returns a [List<String>] of time slots in "HH:00-HH+1:00" format.
  static List<String> getPredefinedTimeSlots() {
    return List.generate(8, (index) {
      int hour = 9 + index;
      return '${hour.toString().padLeft(2, '0')}:00-${(hour + 1).toString().padLeft(2, '0')}:00';
    });
  }

  /// Attempts to create a new booking request in Firestore.
  ///
  /// Before creating, it checks for conflicting bookings (same room, date, and time slot
  /// that are already 'Pending' or 'Approved'). The date part of [date] is normalized
  /// (time component is ignored) for storage and conflict checking.
  /// A Telegram notification is sent to an admin upon a new request.
  ///
  /// - [userId]: The ID of the user making the request.
  /// - [userEmail]: The email of the user (denormalized for convenience).
  /// - [roomId]: The ID of the room being booked.
  /// - [date]: The desired date for the booking.
  /// - [timeSlot]: The desired time slot (e.g., "09:00-10:00").
  ///
  /// Returns a [Future<DocumentReference>] to the newly created booking document in Firestore.
  /// Throws an [Exception] if the time slot is already booked or pending for the given room and date.
  /// Rethrows other [FirebaseException]s or errors encountered during Firestore operations.
  Future<DocumentReference> requestBooking({
    required String userId,
    required String userEmail,
    required String roomId,
    required DateTime date,
    required String timeSlot,
  }) async {
    try {
      Timestamp now = Timestamp.now();
      DateTime dateOnly = DateTime(date.year, date.month, date.day);

      QuerySnapshot conflictingBookings = await _firestore
          .collection(_collectionPath)
          .where('roomId', isEqualTo: roomId)
          .where('date', isEqualTo: Timestamp.fromDate(dateOnly))
          .where('timeSlot', isEqualTo: timeSlot)
          .where('status', whereIn: ['Pending', 'Approved'])
          .get();

      if (conflictingBookings.docs.isNotEmpty) {
        throw Exception('This time slot is already booked or pending for this room.');
      }

      DocumentReference bookingRef = await _firestore.collection(_collectionPath).add({
        'userId': userId,
        'userEmail': userEmail,
        'roomId': roomId,
        'date': Timestamp.fromDate(dateOnly),
        'timeSlot': timeSlot,
        'status': 'Pending',
        'createdAt': now,
        'updatedAt': now,
        'violations': [],
      });

      try {
        final TelegramService telegramService = TelegramService();
        String adminNotificationMessage = """New booking request:
User: $userEmail
Room ID: $roomId
Date: ${date.toIso8601String().split('T').first}
Time: $timeSlot""";
        await telegramService.notifyAdmin(adminNotificationMessage);
      } catch (e) {
        print('Failed to send Telegram admin notification for new booking: $e');
      }
      return bookingRef;
    } catch (e) {
      print('Error requesting booking: $e');
      rethrow;
    }
  }

  /// Cancels a booking if authorized.
  ///
  /// Checks if the [currentUserId] matches the `userId` of the booking.
  /// If a `calendarEventId` exists for the booking, it attempts to delete the corresponding calendar event.
  ///
  /// - [bookingId]: The ID of the booking to cancel.
  /// - [currentUserId]: The ID of the user attempting to cancel the booking.
  ///
  /// Throws an [Exception] if the booking is not found or if the user is not authorized.
  /// Rethrows other Firestore or CalendarService exceptions.
  Future<void> cancelBooking(String bookingId, String currentUserId) async {
    try {
      DocumentSnapshot bookingDoc = await _firestore.collection(_collectionPath).doc(bookingId).get();
      if (!bookingDoc.exists) {
        throw Exception("Booking not found.");
      }
      Booking booking = Booking.fromFirestore(bookingDoc);
      if (booking.userId != currentUserId) {
        throw Exception("You are not authorized to cancel this booking.");
      }

      await _firestore.collection(_collectionPath).doc(bookingId).update({
        'status': 'Cancelled',
        'updatedAt': Timestamp.now(),
      });

      if (booking.calendarEventId != null && booking.calendarEventId!.isNotEmpty) {
        try {
          final CalendarService calendarService = CalendarService(
            clientId: "cKLSwjQNympUGok21LQuEp6DRF5tDARh", // Replace with actual config
            clientSecret: "CRN_YOI66tYVtltMOkQsxzxeCdWy7i8caDq3iv0Xzd", // Replace with actual config
            redirectUri: "com.smartlibrarybooker://oauth2redirect", // Replace with actual config
          );
          List<dynamic>? calendars = await calendarService.listCalendars(booking.userId);
          if (calendars != null && calendars.isNotEmpty) {
             Map<String, dynamic>? targetCalendar = calendars.firstWhere(
              (cal) => cal['calendar_readonly'] == false && cal['calendar_deleted'] == false,
              orElse: () => null,
            );
            if (targetCalendar != null) {
              String calendarId = targetCalendar['calendar_id'];
              bool eventDeleted = await calendarService.deleteCalendarEvent(booking.userId, calendarId, booking.calendarEventId!);
              if (eventDeleted) {
                print('Calendar event ${booking.calendarEventId} deleted for cancelled booking $bookingId.');
                await _firestore.collection(_collectionPath).doc(bookingId).update({'calendarEventId': null});
              }
            }
          }
        } catch (e) {
          print('Error deleting calendar event for cancelled booking $bookingId: $e');
        }
      }
    } catch (e) {
      print('Error cancelling booking $bookingId: $e');
      rethrow;
    }
  }

  /// Retrieves details for a specific booking.
  ///
  /// - [bookingId]: The ID of the booking to fetch.
  ///
  /// Returns a [Future<Booking?>]. If the booking document exists, it's converted
  /// to a [Booking] object. Returns `null` if the document does not exist.
  /// Rethrows Firestore exceptions on failure.
  Future<Booking?> getBookingDetails(String bookingId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collectionPath).doc(bookingId).get();
      if (doc.exists) {
        return Booking.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting booking details for $bookingId: $e');
      rethrow;
    }
  }

  /// Retrieves a stream of bookings for a specific user, ordered by date descending.
  ///
  /// - [userId]: The ID of the user whose bookings are to be fetched.
  ///
  /// Returns a [Stream<List<Booking>>] that emits a list of [Booking] objects.
  Stream<List<Booking>> getUserBookings(String userId) {
    return _firestore
        .collection(_collectionPath)
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  }

  /// Retrieves a stream of bookings for a specific room on a given date.
  ///
  /// Shows 'Approved' and 'Pending' bookings for availability checks.
  /// The date comparison is normalized to the start and end of the given [date].
  ///
  /// - [roomId]: The ID of the room.
  /// - [date]: The date for which to fetch bookings.
  ///
  /// Returns a [Stream<List<Booking>>].
  Stream<List<Booking>> getRoomBookingsForDate(String roomId, DateTime date) {
    DateTime dayStart = DateTime(date.year, date.month, date.day);
    DateTime dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);
    return _firestore
        .collection(_collectionPath)
        .where('roomId', isEqualTo: roomId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
        .where('status', whereIn: ['Approved', 'Pending'])
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  }

  /// Retrieves a stream of available time slots for a given room and date.
  ///
  /// It fetches all 'Approved' and 'Pending' bookings for the room on that date
  /// and then calculates the remaining slots from [getPredefinedTimeSlots].
  /// The date comparison is normalized to the date part only.
  ///
  /// - [roomId]: The ID of the room.
  /// - [date]: The date for which to check availability.
  ///
  /// Returns a [Stream<List<String>>] of available time slot strings.
  Stream<List<String>> getAvailableTimeSlots(String roomId, DateTime date) {
     DateTime dayStart = DateTime(date.year, date.month, date.day);
     return _firestore
         .collection(_collectionPath)
         .where('roomId', isEqualTo: roomId)
         .where('date', isEqualTo: Timestamp.fromDate(dayStart))
         .where('status', whereIn: ['Approved', 'Pending'])
         .snapshots()
         .map((snapshot) {
             Set<String> bookedSlots = snapshot.docs.map((doc) => doc.data()['timeSlot'] as String).toSet();
             List<String> allPossibleSlots = getPredefinedTimeSlots();
             return allPossibleSlots.where((slot) => !bookedSlots.contains(slot)).toList();
         });
  }

  /// Retrieves a stream of all bookings with 'Pending' status, ordered by creation date ascending.
  ///
  /// This is typically used by admins to see new booking requests.
  ///
  /// Returns a [Stream<List<Booking>>].
  Stream<List<Booking>> getPendingBookings() {
    return _firestore
        .collection(_collectionPath)
        .where('status', isEqualTo: 'Pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  }

  /// Approves a pending booking.
  ///
  /// Updates the booking status to 'Approved', records the admin's ID and an optional message.
  /// Also triggers Telegram notification to the user, creates a calendar event,
  /// generates a PDF confirmation (URL stored), and sets QR code data.
  ///
  /// - [bookingId]: The ID of the booking to approve.
  /// - [adminId]: The ID of the admin approving the booking.
  /// - [adminMessage]: An optional message from the admin to the user.
  ///
  /// Rethrows Firestore or other service exceptions on failure of the primary update.
  /// Other integration failures (Telegram, Calendar, PDF, QR) are caught and logged.
  Future<void> approveBooking(String bookingId, String adminId, {String? adminMessage}) async {
    try {
      await _firestore.collection(_collectionPath).doc(bookingId).update({
        'status': 'Approved',
        'bookedByAdminId': adminId,
        'adminMessage': adminMessage,
        'updatedAt': Timestamp.now(),
      });

      Booking? bookingDetails = await getBookingDetails(bookingId);
      if (bookingDetails == null) {
        print('Failed to retrieve booking details after approval for $bookingId. Skipping post-approval actions.');
        return;
      }

      // Telegram Notification
      try {
        final AuthService authService = AuthService();
        String? userTelegramChatId = await authService.getUserTelegramChatId(bookingDetails.userId);
        if (userTelegramChatId != null && userTelegramChatId.isNotEmpty) {
          final TelegramService telegramService = TelegramService();
          String userNotificationMessage = "Your booking for Room ${bookingDetails.roomId} on ${bookingDetails.date.toIso8601String().split('T').first} at ${bookingDetails.timeSlot} has been APPROVED.";
          if (adminMessage != null && adminMessage.isNotEmpty) {
            userNotificationMessage += "\nAdmin message: $adminMessage";
          }
          await telegramService.sendMessage(userTelegramChatId, userNotificationMessage);
        }
      } catch (e) {
        print('Failed to send Telegram approval notification for $bookingId: $e');
      }

      // Calendar Event Creation
      try {
        final CalendarService calendarService = CalendarService(
          clientId: "cKLSwjQNympUGok21LQuEp6DRF5tDARh", // Replace with actual config
          clientSecret: "CRN_YOI66tYVtltMOkQsxzxeCdWy7i8caDq3iv0Xzd", // Replace with actual config
          redirectUri: "com.smartlibrarybooker://oauth2redirect", // Replace with actual config
        );
        List<dynamic>? calendars = await calendarService.listCalendars(bookingDetails.userId);
        if (calendars != null && calendars.isNotEmpty) {
          Map<String, dynamic>? targetCalendar = calendars.firstWhere(
            (cal) => cal['calendar_readonly'] == false && cal['calendar_deleted'] == false, orElse: () => null);
          if (targetCalendar != null) {
            String calendarId = targetCalendar['calendar_id'];
            String eventSummary = 'Library Booking: Room ${bookingDetails.roomId}'; // Consider fetching actual room name
            String eventDescription = 'Booking for room ${bookingDetails.roomId} from ${bookingDetails.timeSlot}. User: ${bookingDetails.userEmail}.';
            if (adminMessage != null && adminMessage.isNotEmpty) eventDescription += '\nAdmin Message: $adminMessage';
            List<String> times = bookingDetails.timeSlot.split('-');
            String startTimeStr = times[0].split(':')[0];
            DateTime startDateTime = DateTime(bookingDetails.date.year, bookingDetails.date.month, bookingDetails.date.day, int.parse(startTimeStr), 00);
            DateTime endDateTime = startDateTime.add(const Duration(hours: 1));
            Map<String, dynamic> eventData = {
              'event_id': bookingDetails.bookingId, 'summary': eventSummary, 'description': eventDescription,
              'start': startDateTime.toUtc().toIso8601String(), 'end': endDateTime.toUtc().toIso8601String(),
              'tzid': 'Asia/Singapore', // Consider making this dynamic
            };
            bool eventCreated = await calendarService.createCalendarEvent(bookingDetails.userId, calendarId, eventData);
            if (eventCreated) await updateBookingWithCalendarEventId(bookingId, bookingDetails.bookingId);
          }
        }
      } catch (e) {
        print('Error during calendar event creation for $bookingId: $e');
      }

      // PDF Generation and QR Code
      try {
        final PdfGenerationService pdfService = PdfGenerationService(apiKey: "sk_e15c28cb8e85ed5e9d10c0dd7c13732416496c2f"); // Replace with actual config
        String roomNameToDisplay = bookingDetails.roomId; // Placeholder, fetch actual name if needed
        String formattedDate = DateFormat('dd/MM/yyyy').format(bookingDetails.date);
        String htmlContent = pdfService.getBookingConfirmationHtmlTemplate(
          bookingId: bookingDetails.bookingId, userName: bookingDetails.userEmail, roomName: roomNameToDisplay,
          date: formattedDate, timeSlot: bookingDetails.timeSlot, adminMessage: bookingDetails.adminMessage,
        );
        Uint8List? pdfData = await pdfService.generatePdfFromHtml(htmlContent);
        if (pdfData != null) {
          String placeholderPdfUrl = 'placeholder_pdf_url_for_booking_$bookingId.pdf'; // Actual upload and URL needed
          await updateBookingWithPdfUrl(bookingId, placeholderPdfUrl);
        }
        await updateBookingWithQrCode(bookingId, bookingId); // Use bookingId as QR data
      } catch (e) {
        print('Error during PDF/QR generation for $bookingId: $e');
      }
    } catch (e) {
      print('Error approving booking $bookingId: $e');
      rethrow;
    }
  }

  /// Rejects a pending booking.
  ///
  /// Updates the booking status to 'Rejected', records the admin's ID and the reason for rejection.
  /// Also triggers a Telegram notification to the user and attempts to delete any associated calendar event.
  ///
  /// - [bookingId]: The ID of the booking to reject.
  /// - [adminId]: The ID of the admin rejecting the booking.
  /// - [reason]: The reason for rejecting the booking.
  ///
  /// Rethrows Firestore or other service exceptions on failure of the primary update.
  Future<void> rejectBooking(String bookingId, String adminId, String reason) async {
    try {
      await _firestore.collection(_collectionPath).doc(bookingId).update({
        'status': 'Rejected',
        'bookedByAdminId': adminId,
        'adminMessage': reason,
        'updatedAt': Timestamp.now(),
      });

      Booking? bookingDetails = await getBookingDetails(bookingId);
      if (bookingDetails == null) {
        print('Failed to retrieve booking details after rejection for $bookingId. Skipping post-rejection actions.');
        return;
      }

      // Telegram Notification
      try {
        final AuthService authService = AuthService();
        String? userTelegramChatId = await authService.getUserTelegramChatId(bookingDetails.userId);
        if (userTelegramChatId != null && userTelegramChatId.isNotEmpty) {
          final TelegramService telegramService = TelegramService();
          String userNotificationMessage = "Your booking for Room ${bookingDetails.roomId} on ${bookingDetails.date.toIso8601String().split('T').first} at ${bookingDetails.timeSlot} has been REJECTED.\nReason: $reason";
          await telegramService.sendMessage(userTelegramChatId, userNotificationMessage);
        }
      } catch (e) {
        print('Failed to send Telegram rejection notification for $bookingId: $e');
      }

      // Calendar Event Deletion
      if (bookingDetails.calendarEventId != null && bookingDetails.calendarEventId!.isNotEmpty) {
        try {
          final CalendarService calendarService = CalendarService(
            clientId: "cKLSwjQNympUGok21LQuEp6DRF5tDARh", // Replace with actual config
            clientSecret: "CRN_YOI66tYVtltMOkQsxzxeCdWy7i8caDq3iv0Xzd", // Replace with actual config
            redirectUri: "com.smartlibrarybooker://oauth2redirect", // Replace with actual config
          );
          List<dynamic>? calendars = await calendarService.listCalendars(bookingDetails.userId);
          if (calendars != null && calendars.isNotEmpty) {
            Map<String, dynamic>? targetCalendar = calendars.firstWhere(
                (cal) => cal['calendar_readonly'] == false && cal['calendar_deleted'] == false, orElse: () => null);
            if (targetCalendar != null) {
              String calendarId = targetCalendar['calendar_id'];
              bool eventDeleted = await calendarService.deleteCalendarEvent(bookingDetails.userId, calendarId, bookingDetails.calendarEventId!);
              if (eventDeleted) {
                 print('Calendar event ${bookingDetails.calendarEventId} deleted for rejected booking $bookingId.');
                await _firestore.collection(_collectionPath).doc(bookingId).update({'calendarEventId': null});
              }
            }
          }
        } catch (e) {
          print('Error deleting calendar event for rejected booking $bookingId: $e');
        }
      }
    } catch (e) {
      print('Error rejecting booking $bookingId: $e');
      rethrow;
    }
  }

  /// Updates the status of a booking and optionally the admin ID and message.
  ///
  /// This is a more generic method for status updates that might not fit
  /// the specific approve/reject flows.
  ///
  /// - [bookingId]: The ID of the booking to update.
  /// - [status]: The new status string.
  /// - [adminId]: Optional ID of the admin performing the update.
  /// - [message]: Optional message related to this status update.
  ///
  /// Rethrows Firestore exceptions on failure.
  Future<void> updateBookingStatus(String bookingId, String status, {String? adminId, String? message}) async {
     try {
         Map<String, dynamic> updateData = {
             'status': status,
             'updatedAt': Timestamp.now(),
         };
         if (adminId != null) updateData['bookedByAdminId'] = adminId;
         if (message != null) updateData['adminMessage'] = message;

         await _firestore.collection(_collectionPath).doc(bookingId).update(updateData);
     } catch (e) {
         print('Error updating booking status for $bookingId: $e');
         rethrow;
     }
  }

  /// Updates a booking document with QR code data.
  ///
  /// - [bookingId]: The ID of the booking to update.
  /// - [qrData]: The string data to be stored for QR code generation (typically the bookingId itself).
  ///
  /// Rethrows Firestore exceptions on failure.
  Future<void> updateBookingWithQrCode(String bookingId, String qrData) async {
    try {
      await _firestore.collection(_collectionPath).doc(bookingId).update({
        'qrCodeData': qrData,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating booking $bookingId with QR code: $e');
      rethrow;
    }
  }

  /// Updates a booking document with a URL to its PDF confirmation.
  ///
  /// - [bookingId]: The ID of the booking to update.
  /// - [pdfUrl]: The URL of the stored PDF confirmation.
  ///
  /// Rethrows Firestore exceptions on failure.
  Future<void> updateBookingWithPdfUrl(String bookingId, String pdfUrl) async {
    try {
      await _firestore.collection(_collectionPath).doc(bookingId).update({
        'pdfConfirmationUrl': pdfUrl,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating booking $bookingId with PDF URL: $e');
      rethrow;
    }
  }

  /// Updates a booking document with an external calendar event ID.
  ///
  /// - [bookingId]: The ID of the booking to update.
  /// - [eventId]: The ID of the event from the external calendar system (e.g., Cronofy).
  ///
  /// Rethrows Firestore exceptions on failure.
  Future<void> updateBookingWithCalendarEventId(String bookingId, String eventId) async {
    try {
      await _firestore.collection(_collectionPath).doc(bookingId).update({
        'calendarEventId': eventId,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating booking $bookingId with Calendar Event ID: $e');
      rethrow;
    }
  }

  // Method to fetch all bookings for admin (example, might need pagination in a real app)
  // Stream<List<Booking>> getAdminAllBookingsStream() {
  //   return _firestore
  //       .collection(_collectionPath)
  //       .orderBy('createdAt', descending: true)
  //       .snapshots()
  //       .map((snapshot) => snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  // }

  // Method to fetch bookings by status for admin (example)
  // Stream<List<Booking>> getAdminBookingsByStatusStream(String status) {
  //   return _firestore
  //       .collection(_collectionPath)
  //       .where('status', isEqualTo: status)
  //       .orderBy('createdAt', descending: true)
  //       .snapshots()
  //       .map((snapshot) => snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  // }
}
