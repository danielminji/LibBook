import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

// Assuming Booking class might be needed for event details, adjust import if necessary
// import 'package:library_booking/services/booking_service.dart';

/// Service for interacting with the Cronofy Calendar API.
///
/// Manages OAuth 2.0 token flow (simplified for this application's context)
/// by storing and refreshing tokens in Firestore. Provides methods for calendar
/// operations such as listing calendars, and creating/deleting events.
///
/// This service uses specific API hosts for Cronofy (e.g., 'api-sg.cronofy.com' and 'app-sg.cronofy.com')
/// and requires client credentials ([_clientId], [_clientSecret]) and a [_redirectUri]
/// to be configured during instantiation.
class CalendarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// The base URL for Cronofy API calls. Configured for Singapore region.
  static const String _cronofyApiHost = 'api-sg.cronofy.com';

  /// The base URL for Cronofy OAuth authorization. Configured for Singapore region.
  static const String _cronofyAppHost = 'app-sg.cronofy.com';

  /// The Cronofy OAuth client ID for this application.
  final String _clientId;
  /// The Cronofy OAuth client secret for this application.
  final String _clientSecret;
  /// The redirect URI registered with Cronofy for this application.
  final String _redirectUri;

  /// Creates an instance of [CalendarService].
  ///
  /// Requires Cronofy API client credentials and a redirect URI.
  /// These should be securely managed and provided during service initialization.
  ///
  /// - [clientId]: The Cronofy OAuth client ID.
  /// - [clientSecret]: The Cronofy OAuth client secret.
  /// - [redirectUri]: The redirect URI registered with Cronofy for this application.
  CalendarService({
    required String clientId,
    required String clientSecret,
    required String redirectUri,
  })  : _clientId = clientId,
        _clientSecret = clientSecret,
        _redirectUri = redirectUri;

  // --- OAuth Token Management ---

  /// Stores the user's Cronofy OAuth tokens securely in Firestore.
  ///
  /// These tokens are associated with the user's [userId] and are stored
  /// in a subcollection named 'cronofy_tokens' under the user's document.
  /// An 'updatedAt' timestamp is also recorded.
  ///
  /// - [userId]: The unique ID of the user.
  /// - [accessToken]: The Cronofy access token.
  /// - [refreshToken]: The Cronofy refresh token.
  /// - [expiryDateTime]: The date and time when the access token expires.
  ///
  /// Rethrows any exceptions from Firestore operations.
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

  /// Retrieves the user's stored Cronofy OAuth tokens from Firestore.
  ///
  /// - [userId]: The unique ID of the user.
  ///
  /// Returns a `Future<Map<String, dynamic>?>` containing the token data
  /// (accessToken, refreshToken, expiryDateTime) if found.
  /// Returns `null` if no tokens are found for the user or if an error occurs.
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

  /// Refreshes an expired or expiring Cronofy access token using a refresh token.
  ///
  /// Makes a POST request to the Cronofy token endpoint.
  ///
  /// - [refreshToken]: The refresh token to use for obtaining a new access token.
  ///
  /// Returns a `Future<Map<String, dynamic>?>` containing the new 'accessToken',
  /// 'refreshToken' (which might be re-issued), and calculated 'expiryDateTime'.
  /// Returns `null` if the token refresh fails (e.g., invalid refresh token, API error).
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
        final DateTime newExpiry = DateTime.now().add(Duration(seconds: tokenData['expires_in']));
        return {
          'accessToken': tokenData['access_token'],
          'refreshToken': tokenData['refresh_token'] ?? refreshToken,
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

  /// Internal helper to get a valid access token for a user.
  ///
  /// Retrieves stored tokens, checks for expiry (within a 5-minute buffer),
  /// and attempts to refresh the token if necessary using [refreshAccessToken].
  /// If refreshed, the new tokens are stored using [storeUserTokens].
  ///
  /// - [userId]: The ID of the user for whom to get a valid token.
  ///
  /// Returns the valid access token as a [String?], or `null` if no valid token
  /// can be obtained (e.g., no stored tokens, refresh failed).
  Future<String?> _getValidAccessToken(String userId) async {
    Map<String, dynamic>? tokenData = await getUserTokens(userId);
    if (tokenData == null) {
      print('No Cronofy tokens found for user $userId.');
      return null;
    }

    DateTime expiryDateTime = (tokenData['expiryDateTime'] as Timestamp).toDate();
    if (DateTime.now().isAfter(expiryDateTime.subtract(const Duration(minutes: 5)))) {
      print('Cronofy token expired or nearing expiry for user $userId. Refreshing...');
      Map<String, dynamic>? refreshedTokenData = await refreshAccessToken(tokenData['refreshToken']);
      if (refreshedTokenData != null &&
          refreshedTokenData['accessToken'] != null &&
          refreshedTokenData['refreshToken'] != null &&
          refreshedTokenData['expiryDateTime'] != null) {
        await storeUserTokens(
            userId,
            refreshedTokenData['accessToken'],
            refreshedTokenData['refreshToken'],
            refreshedTokenData['expiryDateTime']
        );
        return refreshedTokenData['accessToken'];
      } else {
        print('Failed to refresh Cronofy token for user $userId.');
        return null;
      }
    }
    return tokenData['accessToken'] as String?;
  }

  // --- Calendar API Operations ---

  /// Lists the calendars accessible by the authenticated user via Cronofy.
  ///
  /// Requires a valid access token for the user, obtained via [_getValidAccessToken].
  ///
  /// - [userId]: The ID of the user whose calendars are to be listed.
  ///
  /// Returns a `Future<List<dynamic>?>` which is a list of calendar objects from Cronofy
  /// if successful. Each item in the list is typically a map representing a calendar.
  /// Returns `null` if the operation fails or no valid token is available.
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
      print('Error listing Cronofy calendars for user $userId: $e');
      return null;
    }
  }

  /// Creates an event in the specified Cronofy calendar for the user.
  ///
  /// The [eventData] map should conform to Cronofy's event structure.
  /// Example:
  /// ```json
  /// {
  ///   "event_id": "your_unique_booking_id",
  ///   "summary": "Library Room Booking: Room ABC",
  ///   "description": "Details of the booking.",
  ///   "start": "2024-08-01T10:00:00Z", // ISO8601 UTC format
  ///   "end": "2024-08-01T11:00:00Z",   // ISO8601 UTC format
  ///   "tzid": "Asia/Singapore"         // Timezone ID for the event
  /// }
  /// ```
  /// Returns `true` if the event creation was accepted by Cronofy (HTTP 202), `false` otherwise.
  /// Requires a valid access token for the user.
  ///
  /// - [userId]: The ID of the user whose calendar to access.
  /// - [calendarId]: The ID of the Cronofy calendar to create the event in.
  /// - [eventData]: A map containing the event details.
  Future<bool> createCalendarEvent(String userId, String calendarId, Map<String, dynamic> eventData) async {
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
        print('Cronofy event creation accepted for calendar $calendarId, event ${eventData['event_id']}.');
        return true;
      } else {
        print('Failed to create Cronofy event. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error creating Cronofy event for user $userId, calendar $calendarId: $e');
      return false;
    }
  }

  /// Deletes an event from the specified Cronofy calendar using the event's unique ID.
  ///
  /// The [eventId] should be the same ID that was provided when the event was created
  /// (e.g., your application's internal booking ID).
  ///
  /// Returns `true` if the event deletion was accepted by Cronofy (HTTP 202), `false` otherwise.
  /// Requires a valid access token for the user.
  ///
  /// - [userId]: The ID of the user whose calendar to access.
  /// - [calendarId]: The ID of the Cronofy calendar from which to delete the event.
  /// - [eventId]: The unique ID of the event to delete.
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
        body: jsonEncode({'event_id': eventId}),
      );
      if (response.statusCode == 202) {
        print('Cronofy event deletion accepted for event $eventId from calendar $calendarId.');
        return true;
      } else {
        print('Failed to delete Cronofy event $eventId. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error deleting Cronofy event $eventId for user $userId: $e');
      return false;
    }
  }

  // --- OAuth Helper Methods ---

  /// Constructs the Cronofy OAuth authorization URL.
  ///
  /// This URL is used to redirect the user to Cronofy to grant permission to the application.
  /// Requested scopes include: read_account, list_calendars, read_events, create_event, delete_event.
  ///
  /// - [state]: An opaque value used to maintain state between the request and callback.
  ///   Helps prevent CSRF attacks.
  ///
  /// Returns the fully constructed authorization URL as a [String].
  String getAuthorizationUrl(String state) {
    final String scopes = Uri.encodeComponent('read_account list_calendars read_events create_event delete_event');
    return 'https://$_cronofyAppHost/oauth/authorize?response_type=code&client_id=$_clientId&redirect_uri=${Uri.encodeComponent(_redirectUri)}&scope=$scopes&state=$state';
  }

  /// Exchanges an authorization code (obtained from Cronofy OAuth redirect) for access and refresh tokens.
  ///
  /// Makes a POST request to the Cronofy token endpoint.
  ///
  /// - [code]: The authorization code received from Cronofy.
  ///
  /// Returns a `Future<Map<String, dynamic>?>` containing 'accessToken', 'refreshToken',
  /// and calculated 'expiryDateTime' on success.
  /// Returns `null` if the exchange fails.
  Future<Map<String, dynamic>?> exchangeCodeForTokens(String code) async {
    final String tokenUrl = 'https://$_cronofyApiHost/oauth/token';
    try {
      final response = await http.post(
        Uri.parse(tokenUrl),
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUri,
        },
      );

      if (response.statusCode == 200) {
        final tokenData = jsonDecode(response.body);
        // Ensure all expected fields are present before calculating expiry
        if (tokenData['access_token'] != null && tokenData['refresh_token'] != null && tokenData['expires_in'] != null) {
            final DateTime expiryDateTime = DateTime.now().add(Duration(seconds: tokenData['expires_in']));
            return {
              'accessToken': tokenData['access_token'],
              'refreshToken': tokenData['refresh_token'],
              'expiryDateTime': expiryDateTime,
            };
        } else {
            print('Cronofy token response missing expected fields: $tokenData');
            return null;
        }
      } else {
        print('Failed to exchange Cronofy code for tokens. Status: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error exchanging Cronofy code for tokens: $e');
      return null;
    }
  }
}

// Example of how to instantiate:
// final calendarService = CalendarService(
//   clientId: 'cKLSwjQNympUGok21LQuEp6DRF5tDARh', // Provided by user
//   clientSecret: 'CRN_YOI66tYVtltMOkQsxzxeCdWy7i8caDq3iv0Xzd', // Provided by user
//   redirectUri: 'com.smartlibrarybooker://oauth2redirect', // Based on user feedback
// );
