import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:library_booking/services/telegram_service.dart';
import 'package:library_booking/services/auth_service.dart';

class Booking {
  final String bookingId; // Firestore document ID
  final String userId;
  final String userEmail; // Kept for convenience
  final String roomId;
  // String roomName; // Consider removing or denormalizing if essential for lists
  final DateTime date; // Store as Timestamp in Firestore, convert to DateTime
  final String timeSlot; // e.g., "09:00-10:00"
  String status; // 'Pending', 'Approved', 'Rejected', 'Cancelled'
  String? adminMessage;
  final DateTime createdAt;
  DateTime updatedAt;
  List<String> violations; // Keep for future use

  // Fields for integrations
  String? qrCodeData;
  String? pdfConfirmationUrl;
  String? calendarEventId;
  String? bookedByAdminId; // ID of admin who approved/rejected

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

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Booking(
      bookingId: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      roomId: data['roomId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      timeSlot: data['timeSlot'] ?? '',
      status: data['status'] ?? 'Pending',
      adminMessage: data['adminMessage'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      violations: List<String>.from(data['violations'] ?? []),
      qrCodeData: data['qrCodeData'],
      pdfConfirmationUrl: data['pdfConfirmationUrl'],
      calendarEventId: data['calendarEventId'],
      bookedByAdminId: data['bookedByAdminId'],
    );
  }

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

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'bookings';

  // Helper for predefined time slots (example, this could be configurable elsewhere)
  static List<String> getPredefinedTimeSlots() {
    // Example: 1-hour slots from 9 AM to 5 PM
    return List.generate(8, (index) {
      int hour = 9 + index;
      return '${hour.toString().padLeft(2, '0')}:00-${(hour + 1).toString().padLeft(2, '0')}:00';
    });
  }

  Future<DocumentReference> requestBooking({
    required String userId,
    required String userEmail,
    required String roomId,
    required DateTime date,
    required String timeSlot,
  }) async {
    try {
      Timestamp now = Timestamp.now();
      // Check for conflicts before adding
      QuerySnapshot conflictingBookings = await _firestore
          .collection(_collectionPath)
          .where('roomId', isEqualTo: roomId)
          .where('date', isEqualTo: Timestamp.fromDate(DateTime(date.year, date.month, date.day))) // Compare date part only
          .where('timeSlot', isEqualTo: timeSlot)
          .where('status', whereIn: ['Pending', 'Approved']) // Check against pending and approved
          .get();

      if (conflictingBookings.docs.isNotEmpty) {
        throw Exception('This time slot is already booked or pending for this room.');
      }

      DocumentReference bookingRef = await _firestore.collection(_collectionPath).add({
        'userId': userId,
        'userEmail': userEmail,
        'roomId': roomId,
        'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)), // Store date part only
        'timeSlot': timeSlot,
        'status': 'Pending',
        'createdAt': now,
        'updatedAt': now,
        'violations': [],
        // other fields will be null by default
      });

      // Add this block for Telegram Admin Notification:
      try {
        final TelegramService telegramService = TelegramService();
        // Use the parameters directly available in the method scope
        String adminNotificationMessage = """New booking request:
User: $userEmail
Room ID: $roomId
Date: ${date.toIso8601String().split('T').first}
Time: $timeSlot""";
        await telegramService.notifyAdmin(adminNotificationMessage);
      } catch (e) {
        print('Failed to send Telegram admin notification for new booking: $e');
        // Do not rethrow, as booking itself was successful.
      }
      return bookingRef;
    } catch (e) {
      print('Error requesting booking: $e');
      rethrow;
    }
  }

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
      // Optionally, add rules like cannot cancel if booking is in the past or too close
      await _firestore.collection(_collectionPath).doc(bookingId).update({
        'status': 'Cancelled',
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error cancelling booking: $e');
      rethrow;
    }
  }

  Future<Booking?> getBookingDetails(String bookingId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collectionPath).doc(bookingId).get();
      if (doc.exists) {
        return Booking.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting booking details: $e');
      rethrow;
    }
  }

  Stream<List<Booking>> getUserBookings(String userId) {
    return _firestore
        .collection(_collectionPath)
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  }

  Stream<List<Booking>> getRoomBookingsForDate(String roomId, DateTime date) {
    DateTime dayStart = DateTime(date.year, date.month, date.day);
    DateTime dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);
    return _firestore
        .collection(_collectionPath)
        .where('roomId', isEqualTo: roomId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
        .where('status', whereIn: ['Approved', 'Pending']) // Show approved and pending for availability checks
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  }

  Stream<List<String>> getAvailableTimeSlots(String roomId, DateTime date) {
     DateTime dayStart = DateTime(date.year, date.month, date.day);
     return _firestore
         .collection(_collectionPath)
         .where('roomId', isEqualTo: roomId)
         .where('date', isEqualTo: Timestamp.fromDate(dayStart))
         .where('status', whereIn: ['Approved', 'Pending']) // Consider both approved and pending as unavailable
         .snapshots()
         .map((snapshot) {
             Set<String> bookedSlots = snapshot.docs.map((doc) => doc.data()['timeSlot'] as String).toSet();
             List<String> allPossibleSlots = getPredefinedTimeSlots(); // Using the static helper
             return allPossibleSlots.where((slot) => !bookedSlots.contains(slot)).toList();
         });
  }

  Stream<List<Booking>> getPendingBookings() {
    return _firestore
        .collection(_collectionPath)
        .where('status', isEqualTo: 'Pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  }

  Future<void> approveBooking(String bookingId, String adminId, {String? adminMessage}) async {
    try {
      await _firestore.collection(_collectionPath).doc(bookingId).update({
        'status': 'Approved',
        'bookedByAdminId': adminId,
        'adminMessage': adminMessage,
        'updatedAt': Timestamp.now(),
      });

      // Add this block for Telegram User Notification:
      try {
        Booking? bookingDetails = await getBookingDetails(bookingId); // Assuming this method fetches the full Booking object
        if (bookingDetails != null) {
          final AuthService authService = AuthService();
          String? userTelegramChatId = await authService.getUserTelegramChatId(bookingDetails.userId);

          if (userTelegramChatId != null && userTelegramChatId.isNotEmpty) {
            final TelegramService telegramService = TelegramService();
            String userNotificationMessage = "Your booking for Room ${bookingDetails.roomId} on ${bookingDetails.date.toIso8601String().split('T').first} at ${bookingDetails.timeSlot} has been APPROVED.";
            // 'adminMessage' is a parameter of approveBooking method
            if (adminMessage != null && adminMessage.isNotEmpty) {
              userNotificationMessage += "\nAdmin message: $adminMessage";
            }
            await telegramService.sendMessage(userTelegramChatId, userNotificationMessage);
          }
        }
      } catch (e) {
        print('Failed to send Telegram approval notification to user: $e');
        // Do not rethrow, as approval itself was successful.
      }
    } catch (e) {
      print('Error approving booking: $e');
      rethrow;
    }
  }

  Future<void> rejectBooking(String bookingId, String adminId, String reason) async {
    try {
      await _firestore.collection(_collectionPath).doc(bookingId).update({
        'status': 'Rejected',
        'bookedByAdminId': adminId,
        'adminMessage': reason,
        'updatedAt': Timestamp.now(),
      });

      // Add this block for Telegram User Notification:
      try {
        Booking? bookingDetails = await getBookingDetails(bookingId); // Assuming this method fetches the full Booking object
        if (bookingDetails != null) {
          final AuthService authService = AuthService();
          String? userTelegramChatId = await authService.getUserTelegramChatId(bookingDetails.userId);

          if (userTelegramChatId != null && userTelegramChatId.isNotEmpty) {
            final TelegramService telegramService = TelegramService();
            // 'reason' is a parameter of rejectBooking method
            String userNotificationMessage = "Your booking for Room ${bookingDetails.roomId} on ${bookingDetails.date.toIso8601String().split('T').first} at ${bookingDetails.timeSlot} has been REJECTED.\nReason: $reason";
            await telegramService.sendMessage(userTelegramChatId, userNotificationMessage);
          }
        }
      } catch (e) {
        print('Failed to send Telegram rejection notification to user: $e');
        // Do not rethrow, as rejection itself was successful.
      }
    } catch (e) {
      print('Error rejecting booking: $e');
      rethrow;
    }
  }

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
         print('Error updating booking status: $e');
         rethrow;
     }
 }

  Future<void> updateBookingWithQrCode(String bookingId, String qrData) async {
    try {
      await _firestore.collection(_collectionPath).doc(bookingId).update({
        'qrCodeData': qrData,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating booking with QR code: $e');
      rethrow;
    }
  }

  Future<void> updateBookingWithPdfUrl(String bookingId, String pdfUrl) async {
    try {
      await _firestore.collection(_collectionPath).doc(bookingId).update({
        'pdfConfirmationUrl': pdfUrl,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating booking with PDF URL: $e');
      rethrow;
    }
  }

  Future<void> updateBookingWithCalendarEventId(String bookingId, String eventId) async {
    try {
      await _firestore.collection(_collectionPath).doc(bookingId).update({
        'calendarEventId': eventId,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating booking with Calendar Event ID: $e');
      rethrow;
    }
  }

  // Clean up method if needed (not strictly necessary for this service type)
  // static void dispose() {}
}
