import 'dart:convert';
import 'dart:typed_data'; // For Uint8List
import 'package:http/http.dart' as http;

class PdfGenerationService {
  final String _apiKey;
  static const String _pdfShiftApiUrl = 'https://api.pdfshift.io/v3/convert/pdf';

  PdfGenerationService({required String apiKey}) : _apiKey = apiKey;

  // Generates a very basic HTML template for a booking confirmation.
  // In a real app, this would be more sophisticated, perhaps loading from a template file
  // or using a templating engine.
  String getBookingConfirmationHtmlTemplate({
    required String bookingId,
    required String userName,
    required String roomName, // Or room ID
    required String date, // Formatted date string
    required String timeSlot,
    String? adminMessage,
  }) {
    String messageSection = '';
    if (adminMessage != null && adminMessage.isNotEmpty) {
      messageSection = '<p><strong>Admin Message:</strong> ${adminMessage.replaceAll("\n", "<br>")}</p>';
    }

    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Booking Confirmation</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .container { border: 1px solid #ccc; padding: 20px; width: 600px; margin: auto; }
            h1 { color: #333; }
            p { line-height: 1.6; }
            strong { color: #555; }
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
            <p><em>Thank you for using the Library Room Reservation System.</em></p>
        </div>
    </body>
    </html>
    ''';
  }

  // Converts HTML content to PDF and returns the PDF binary data (Uint8List).
  // Returns null if conversion fails.
  Future<Uint8List?> generatePdfFromHtml(String htmlContent, {bool sandbox = false}) async {
    if (_apiKey.isEmpty) {
      print('PDFShift API Key is not configured.');
      return null;
    }

    try {
      // PDFShift expects a JSON body. The HTML can be sent directly as a string.
      // For authentication, PDFShift uses Basic Auth with the API key as the username and no password,
      // or a Bearer token. The documentation implies API key can be sent as 'auth' user.
      // Let's use Basic Auth: base64Encode(utf8.encode('YOUR_API_KEY:'))
      // Or, more simply, many APIs accept it directly in an 'Authorization: Bearer YOUR_API_KEY' header
      // PDFShift docs state: "Authenticate with your API key using Basic Authentication with your key as username and an empty password."
      // OR "Alternatively, you can use Bearer authentication by passing your key in the Authorization header."
      // Let's use Bearer token as it's often simpler with http package.

      final response = await http.post(
        Uri.parse(_pdfShiftApiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'source': htmlContent,
          'sandbox': sandbox, // Set to true to not use credits, if supported/needed
          // Other options can be added here, e.g., 'landscape', 'margins', 'css', etc.
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // PDFShift returns the binary PDF data directly in the response body
        return response.bodyBytes;
      } else {
        print('PDFShift API Error. Status: ${response.statusCode}');
        try {
            // Try to parse error message if JSON
            var errorBody = jsonDecode(response.body);
            print('PDFShift Error Body: $errorBody');
        } catch(e) {
            print('PDFShift Error Body (not JSON): ${response.body}');
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
