import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
// Assuming Booking class might be needed for event details, adjust import if necessary
// import 'package:library_booking/services/booking_service.dart';

class CalendarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _cronofyApiHost = 'api-sg.cronofy.com'; // As provided by user
  static const String _cronofyAppHost = 'app-sg.cronofy.com'; // For authorization URL

  final String _clientId;
  final String _clientSecret;
  final String _redirectUri;

  // Constructor to initialize with credentials
  CalendarService({
    required String clientId,
    required String clientSecret,
    required String redirectUri,
  })  : _clientId = clientId,
        _clientSecret = clientSecret,
        _redirectUri = redirectUri;

  // --- OAuth Token Management (Conceptual - to be stored per user) ---

  // Stores user's Cronofy tokens in Firestore
  Future<void> storeUserTokens(String userId, String accessToken, String refreshToken, DateTime expiryDateTime) async {
    try {
      await _firestore.collection('users').doc(userId).collection('cronofy_tokens').doc('user_token').set({
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiryDateTime': Timestamp.fromDate(expiryDateTime),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error storing Cronofy tokens for user $userId: $e');
      rethrow;
    }
  }

  // Retrieves user's Cronofy tokens from Firestore
  Future<Map<String, dynamic>?> getUserTokens(String userId) async {
    try {
      DocumentSnapshot tokenDoc = await _firestore.collection('users').doc(userId).collection('cronofy_tokens').doc('user_token').get();
      if (tokenDoc.exists) {
        return tokenDoc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error retrieving Cronofy tokens for user $userId: $e');
      return null;
    }
  }

  // Refreshes an access token using a refresh token
  // Returns new token data map or null if failed
  Future<Map<String, dynamic>?> refreshAccessToken(String refreshToken) async {
    final String tokenUrl = 'https://$_cronofyApiHost/oauth/token';
    try {
      final response = await http.post(
        Uri.parse(tokenUrl),
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final tokenData = jsonDecode(response.body);
        // Calculate new expiry (e.g., tokenData['expires_in'] seconds from now)
        final DateTime newExpiry = DateTime.now().add(Duration(seconds: tokenData['expires_in']));
        return {
          'accessToken': tokenData['access_token'],
          'refreshToken': tokenData['refresh_token'] ?? refreshToken, // Sometimes refresh token is re-issued
          'expiryDateTime': newExpiry,
        };
      } else {
        print('Failed to refresh Cronofy token. Status: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error refreshing Cronofy token: $e');
      return null;
    }
  }


  // --- Calendar API Operations ---

  Future<String?> _getValidAccessToken(String userId) async {
    Map<String, dynamic>? tokenData = await getUserTokens(userId);
    if (tokenData == null) {
      print('No Cronofy tokens found for user $userId.');
      return null;
    }

    DateTime expiryDateTime = (tokenData['expiryDateTime'] as Timestamp).toDate();
    if (DateTime.now().isAfter(expiryDateTime.subtract(Duration(minutes: 5)))) { // Refresh if within 5 mins of expiry
      print('Cronofy token expired or nearing expiry for user $userId. Refreshing...');
      Map<String, dynamic>? refreshedTokenData = await refreshAccessToken(tokenData['refreshToken']);
      if (refreshedTokenData != null) {
        await storeUserTokens(
            userId,
            refreshedTokenData['accessToken'],
            refreshedTokenData['refreshToken'],
            refreshedTokenData['expiryDateTime']
        );
        return refreshedTokenData['accessToken'];
      } else {
        print('Failed to refresh Cronofy token for user $userId.');
        return null; // Or trigger re-authentication
      }
    }
    return tokenData['accessToken'] as String?;
  }

  // Example: List Calendars
  Future<List<dynamic>?> listCalendars(String userId) async {
    String? accessToken = await _getValidAccessToken(userId);
    if (accessToken == null) return null;

    final String url = 'https://$_cronofyApiHost/v1/calendars';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['calendars'];
      } else {
        print('Failed to list Cronofy calendars. Status: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error listing Cronofy calendars: $e');
      return null;
    }
  }

  // Create Event
  // `booking` parameter is a placeholder for whatever details are needed from the booking object
  Future<bool> createCalendarEvent(String userId, String calendarId, Map<String, dynamic> eventData
      // Example eventData structure for Cronofy:
      // {
      //   "event_id": "uniq_event_id_from_your_system_booking_id",
      //   "summary": "Library Room Booking: Room X",
      //   "description": "Booking for discussion room X.",
      //   "start": "2024-07-20T10:00:00Z", // ISO8601 format
      //   "end": "2024-07-20T11:00:00Z",   // ISO8601 format
      //   "tzid": "Asia/Singapore" // User's timezone
      // }
  ) async {
    String? accessToken = await _getValidAccessToken(userId);
    if (accessToken == null) return false;

    final String url = 'https://$_cronofyApiHost/v1/calendars/$calendarId/events';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(eventData),
      );
      if (response.statusCode == 202) { // 202 Accepted for event creation
        print('Cronofy event creation accepted for calendar $calendarId.');
        return true;
      } else {
        print('Failed to create Cronofy event. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error creating Cronofy event: $e');
      return false;
    }
  }

  // Delete Event (using the event_id you provided when creating)
  Future<bool> deleteCalendarEvent(String userId, String calendarId, String eventId) async {
    String? accessToken = await _getValidAccessToken(userId);
    if (accessToken == null) return false;

    final String url = 'https://$_cronofyApiHost/v1/calendars/$calendarId/events';
    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        // Cronofy API for deleting events requires event_id in the body
        body: jsonEncode({'event_id': eventId}),
      );
      if (response.statusCode == 202) { // 202 Accepted for event deletion
        print('Cronofy event deletion accepted for event $eventId.');
        return true;
      } else {
        print('Failed to delete Cronofy event. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error deleting Cronofy event: $e');
      return false;
    }
  }

  // Note: Update event is similar to create, but uses HTTP PUT/PATCH and targets a specific event_id.
  // For simplicity, only create and delete are scaffolded here.
  // The OAuth authorization URL can be constructed using _appHost, _clientId, _redirectUri, and scopes.
  // e.g., 'https://$_cronofyAppHost/oauth/authorize?client_id=$_clientId&redirect_uri=$_redirectUri&response_type=code&scope=read_calendar create_event ...'
}

// Example of how to instantiate:
// final calendarService = CalendarService(
//   clientId: 'cKLSwjQNympUGok21LQuEp6DRF5tDARh', // Provided by user
//   clientSecret: 'CRN_YOI66tYVtltMOkQsxzxeCdWy7i8caDq3iv0Xzd', // Provided by user
//   redirectUri: 'com.smartlibrarybooker://oauth2redirect', // Based on user feedback
// );
