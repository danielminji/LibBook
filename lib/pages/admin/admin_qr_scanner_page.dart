import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // Import the package
import 'package:library_booking/services/booking_service.dart';
import 'package:library_booking/services/room_service.dart'; // For room name
import 'package:intl/intl.dart'; // For date formatting

/// Admin page for scanning QR codes to verify and check-in bookings.
///
/// This page utilizes the `mobile_scanner` package to access the device camera
/// and detect QR codes. Upon successful detection of a booking ID, it fetches
/// booking details and room information using [BookingService] and [RoomService].
/// It then displays these details and provides an option for admins to (simulate)
/// a check-in for "Approved" bookings.
///
/// **Note on Permissions:** Native platform setup for camera permissions is required
/// for this page to function correctly (e.g., `android.permission.CAMERA` on Android
/// and `NSCameraUsageDescription` in `Info.plist` on iOS). This setup is assumed
/// to be handled outside this Dart code.
class AdminQrScannerPage extends StatefulWidget {
  /// Creates an instance of [AdminQrScannerPage].
  const AdminQrScannerPage({super.key});

  /// The named route for this page.
  static const String routeName = '/admin/scan-qr';

  @override
  State<AdminQrScannerPage> createState() => _AdminQrScannerPageState();
}

/// Manages the state for the [AdminQrScannerPage].
///
/// This includes controlling the [MobileScannerController], handling barcode detection,
/// fetching and displaying booking details or error messages, and managing UI state
/// (e.g., loading indicators, scanned data display).
class _AdminQrScannerPageState extends State<AdminQrScannerPage> {
  final BookingService _bookingService = BookingService();
  final RoomService _roomService = RoomService();
  final MobileScannerController _scannerController = MobileScannerController();

  bool _isProcessingScan = false;
  Booking? _scannedBooking;
  String? _scannedRoomName;
  String? _scanErrorMessage;

  @override
  void initState() {
    super.initState();
    // Camera permission handling is typically done before navigating to this page
    // or using a package like `permission_handler` upon page load.
    // For this subtask, we assume permissions are granted or will be prompted by the OS.
  }

  /// Callback invoked by [MobileScanner] when one or more barcodes are detected.
  ///
  /// Processes the first valid barcode's raw value as a potential booking ID.
  /// Stops the scanner to prevent continuous scanning, sets a processing state,
  /// and then calls [_fetchBookingDetails] to retrieve information for the scanned ID.
  ///
  /// - [capture]: An object containing the list of detected [Barcode] objects and
  ///   potentially the image data from which the barcodes were detected.
  void _handleBarcodeDetect(BarcodeCapture capture) {
    if (_isProcessingScan) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String scannedBookingId = barcodes.first.rawValue!;
      print('Scanned Booking ID: $scannedBookingId');

      setState(() {
        _isProcessingScan = true;
        _scannedBooking = null;
        _scannedRoomName = null;
        _scanErrorMessage = null;
      });
      _scannerController.stop();

      _fetchBookingDetails(scannedBookingId);
    }
  }

  /// Fetches booking details based on the scanned [bookingId].
  ///
  /// Uses [BookingService.getBookingDetails] and [RoomService.getRoom] (for room name).
  /// Updates the state with the fetched [Booking] object and room name, or an error message
  /// if the booking is not found or an error occurs.
  ///
  /// - [bookingId]: The booking ID obtained from the scanned QR code.
  Future<void> _fetchBookingDetails(String bookingId) async {
    try {
      Booking? booking = await _bookingService.getBookingDetails(bookingId);
      if (mounted && booking != null) {
        String roomName = booking.roomId; // Fallback to ID
        try {
          Room? room = await _roomService.getRoom(booking.roomId);
          if (room != null) roomName = room.name;
        } catch (e) { print("Error fetching room name for ${booking.roomId}: $e"); }

        setState(() {
          _scannedBooking = booking;
          _scannedRoomName = roomName;
        });
      } else if (mounted) {
        setState(() => _scanErrorMessage = 'Booking ID "$bookingId" not found.');
      }
    } catch (e) {
      if (mounted) setState(() => _scanErrorMessage = 'Error fetching booking details: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessingScan = false);
    }
  }

  /// Resets the scanner state to allow for a new QR code scan.
  ///
  /// Clears any previously scanned booking details or error messages,
  /// sets `_isProcessingScan` to false, and restarts the camera scanner
  /// using [_scannerController.start()]. Includes error handling for camera restart.
  void _resetScanner() {
    setState(() {
        _scannedBooking = null;
        _scannedRoomName = null;
        _scanErrorMessage = null;
        _isProcessingScan = false;
    });
    if (mounted) {
      try {
        _scannerController.start();
      } catch (e) {
        print("Error restarting scanner: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error restarting camera. Please try again.'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  /// Simulates performing a check-in for the given [booking].
  ///
  /// In a real application, this would involve updating the booking status
  /// via [BookingService]. Currently, it shows a [SnackBar] message and
  /// then resets the scanner for the next scan.
  ///
  /// - [booking]: The [Booking] object for which to perform check-in.
  Future<void> _performCheckIn(Booking booking) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('User for booking ${booking.bookingId} for room $_scannedRoomName checked in (simulated).'), backgroundColor: Colors.green)
    );
    _resetScanner();
  }

  /// Builds the UI for the Admin QR Scanner Page.
  ///
  /// Conditionally displays either the camera scanner view or the details of a
  /// scanned booking (or an error message). Provides a button to rescan.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Booking QR Code')),
      body: Column(
        children: <Widget>[
          // Camera View: Shown only if no booking is scanned and no error is present.
          if (_scannedBooking == null && _scanErrorMessage == null)
            Expanded(
              flex: 2, // Give more space to the camera view initially
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _handleBarcodeDetect,
                  ),
                  // Show a loader specifically when a scan is detected but details are not yet fetched.
                  if (_isProcessingScan && _scannedBooking == null && _scanErrorMessage == null)
                    const CircularProgressIndicator(),
                ],
              ),
            ),

          // Details/Error/Prompt Area: Expands when details or error are shown.
          Expanded(
            flex: _scannedBooking != null || _scanErrorMessage != null ? 3 : 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: (_isProcessingScan && _scannedBooking == null && _scanErrorMessage == null)
                  ? const Center(child: CircularProgressIndicator()) // General processing loader
                  : _scannedBooking != null
                    ? _buildBookingDetailsCard(theme, _scannedBooking!, _scannedRoomName ?? _scannedBooking!.roomId)
                    : _scanErrorMessage != null
                        ? _buildErrorCard(theme, _scanErrorMessage!)
                        : Center(child: Text('Point camera at a booking QR code.', style: theme.textTheme.titleMedium)),
            ),
          ),

          // "Scan Another" button: Shown after a scan attempt (success or error).
          if ((_scannedBooking != null || _scanErrorMessage != null))
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan Another'),
                onPressed: _resetScanner,
              ),
            ),
        ],
      ),
    );
  }

  /// Builds a card widget to display verified booking details.
  ///
  /// - [theme]: The current application [ThemeData].
  /// - [booking]: The [Booking] object containing details to display.
  /// - [roomName]: The display name of the room.
  Widget _buildBookingDetailsCard(ThemeData theme, Booking booking, String roomName) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Booking Verification', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
            const Divider(height: 20, thickness: 1),
            _buildDetailRow(theme, Icons.meeting_room_outlined, 'Room:', roomName),
            _buildDetailRow(theme, Icons.person_outline, 'User:', booking.userEmail),
            _buildDetailRow(theme, Icons.calendar_today_outlined, 'Date:', DateFormat('EEE, MMM d, yyyy').format(booking.date)),
            _buildDetailRow(theme, Icons.access_time_outlined, 'Time:', booking.timeSlot),
            _buildDetailRow(theme, Icons.info_outline, 'Status:', booking.status, statusColor: _getStatusColor(booking.status, theme)),
            if (booking.status == 'Approved')
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Confirm Check-in'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        textStyle: const TextStyle(fontSize: 16)
                    ),
                    onPressed: () => _performCheckIn(booking),
                  ),
                ),
              )
            else if (booking.status != 'Approved')
               Padding(
                 padding: const EdgeInsets.only(top:12.0),
                 child: Center(
                   child: Text(
                    'This booking is not "Approved".\nCannot check-in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange.shade800, fontWeight:FontWeight.bold, fontSize: 15)
                   ),
                 ),
               ),
          ],
        ),
      ),
    );
  }

  /// Helper to build a styled row for displaying a piece of detail.
  Widget _buildDetailRow(ThemeData theme, IconData icon, String label, String value, {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text('$label ', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: theme.textTheme.titleSmall?.copyWith(color: statusColor))),
        ],
      ),
    );
  }

  /// Builds a card widget to display scan error messages.
  Widget _buildErrorCard(ThemeData theme, String message) {
     return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
                const SizedBox(height:12),
                Text('Scan Error', style: theme.textTheme.titleLarge?.copyWith(color: Colors.red.shade800, fontWeight: FontWeight.bold)),
                const Divider(height:24, thickness: 1),
                Text(message, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.red.shade900), textAlign: TextAlign.center),
            ]
        ),
      ),
    );
  }

  /// Returns a [Color] based on the booking [status] for UI display.
  Color _getStatusColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'approved': return Colors.green.shade700;
      case 'pending': return Colors.orange.shade700;
      case 'rejected': case 'cancelled': return Colors.red.shade700;
      default: return theme.textTheme.bodySmall?.color ?? Colors.grey;
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}
