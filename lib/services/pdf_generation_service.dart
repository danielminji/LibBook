import 'dart:convert';
import 'dart:typed_data'; // For Uint8List
import 'package:http/http.dart' as http;

/// Service for generating PDF documents from HTML content using the PDFShift API.
///
/// Requires a PDFShift API key for authentication, which should be provided
/// during instantiation. This service provides methods to create HTML content
/// (e.g., for booking confirmations) and convert that HTML to a PDF binary.
class PdfGenerationService {
  /// The API key for accessing the PDFShift service.
  /// This should be kept confidential and ideally loaded from a secure configuration.
  final String _apiKey;

  /// The base URL for the PDFShift PDF conversion endpoint (v3).
  static const String _pdfShiftApiUrl = 'https://api.pdfshift.io/v3/convert/pdf';

  /// Creates an instance of [PdfGenerationService].
  ///
  /// - [apiKey]: The PDFShift API key required for authenticating requests.
  PdfGenerationService({required String apiKey}) : _apiKey = apiKey;

  /// Generates a basic HTML string template for a booking confirmation.
  ///
  /// This template includes placeholders for booking-specific details such as
  /// booking ID, user name, room name, date, time slot, and any admin messages.
  /// The HTML includes basic styling for presentation.
  /// In a production application, this might involve more sophisticated templating
  /// engines or loading templates from files.
  ///
  /// - [bookingId]: The ID of the booking.
  /// - [userName]: The name or email of the user who made the booking.
  /// - [roomName]: The name or ID of the booked room.
  /// - [date]: The formatted date string of the booking (e.g., "DD/MM/YYYY").
  /// - [timeSlot]: The booked time slot (e.g., "09:00-10:00").
  /// - [adminMessage]: Optional message from an admin regarding the booking.
  ///   If provided, it will be included in the PDF. Newlines in the admin message
  ///   are converted to `<br>` tags for HTML display.
  ///
  /// Returns an HTML [String] formatted as a booking confirmation.
  String getBookingConfirmationHtmlTemplate({
    required String bookingId,
    required String userName,
    required String roomName,
    required String date,
    required String timeSlot,
    String? adminMessage,
  }) {
    String messageSection = '';
    if (adminMessage != null && adminMessage.isNotEmpty) {
      // Basic HTML escaping for adminMessage could be considered here if it might contain HTML special chars.
      // For now, just replacing newlines.
      messageSection = '<p><strong>Admin Message:</strong> ${adminMessage.replaceAll("\n", "<br>")}</p>';
    }

    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Booking Confirmation</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; color: #333; }
            .container { border: 1px solid #ccc; padding: 20px; width: 600px; margin: auto; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
            h1 { color: #2563eb; } /* Theme primary color */
            p { line-height: 1.6; }
            strong { color: #1e40af; } /* Theme secondary color */
            hr { border: 0; border-top: 1px solid #eee; margin: 20px 0; }
            .footer { font-size: 0.9em; color: #777; text-align: center; margin-top: 20px; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Booking Confirmation</h1>
            <p><strong>Booking ID:</strong> $bookingId</p>
            <p><strong>Name:</strong> $userName</p>
            <p><strong>Room:</strong> $roomName</p>
            <p><strong>Date:</strong> $date</p>
            <p><strong>Time:</strong> $timeSlot</p>
            $messageSection
            <hr>
            <p class="footer"><em>Thank you for using the Library Room Reservation System.</em></p>
        </div>
    </body>
    </html>
    ''';
  }

  /// Converts the given HTML content to a PDF using the PDFShift API.
  ///
  /// Authenticates using a Bearer token with the provided API key.
  /// The PDFShift API expects a JSON body with the HTML content under the 'source' key.
  ///
  /// - [htmlContent]: The HTML string to convert to PDF.
  /// - [sandbox]: Optional. If `true`, attempts to use PDFShift's sandbox mode
  ///   (if supported by the API key/plan) to avoid using conversion credits. Defaults to `false`.
  ///
  /// Returns the binary PDF data as a [Uint8List] on successful conversion
  /// (HTTP status code 200 or 201).
  /// Returns `null` if the API key is not configured, if the conversion fails,
  /// or if any other error occurs during the API call.
  /// Errors from the PDFShift API (including JSON error responses) are logged to the console.
  Future<Uint8List?> generatePdfFromHtml(String htmlContent, {bool sandbox = false}) async {
    if (_apiKey.isEmpty || _apiKey == "YOUR_PDFSHIFT_API_KEY_PLACEHOLDER") { // Added placeholder check
      print('PDFShift API Key is not configured properly. Please provide a valid API key.');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(_pdfShiftApiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'source': htmlContent,
          'sandbox': sandbox,
          // Other PDFShift options can be added here, e.g.:
          // 'landscape': false,
          // 'use_print': false, // Use screen media type
          // 'margins': {'top': '10mm', 'bottom': '10mm', 'left': '10mm', 'right': '10mm'}
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // PDFShift API typically returns 200 for successful synchronous conversion
        // or 201 if it's a webhook/asynchronous job (though for direct conversion, 200 is common).
        return response.bodyBytes;
      } else {
        print('PDFShift API Error. Status: ${response.statusCode}');
        try {
            // Attempt to parse error message if PDFShift returns a JSON error
            var errorBody = jsonDecode(response.body);
            print('PDFShift Error Body (JSON): $errorBody');
        } catch(e) {
            // If error response is not JSON, print as plain text
            print('PDFShift Error Body (Non-JSON): ${response.body}');
        }
        return null;
      }
    } catch (e) {
      print('Error calling PDFShift API: $e');
      return null;
    }
  }
}

// Example of how to instantiate:
// final pdfService = PdfGenerationService(apiKey: "sk_e15c28cb8e85ed5e9d10c0dd7c13732416496c2f"); // User-provided
