import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // Import the package
import 'package:library_booking/services/booking_service.dart';
import 'package:library_booking/services/room_service.dart'; // For room name
import 'package:intl/intl.dart';

class AdminQrScannerPage extends StatefulWidget {
  const AdminQrScannerPage({super.key});
  static const String routeName = '/admin/scan-qr';

  @override
  State<AdminQrScannerPage> createState() => _AdminQrScannerPageState();
}

class _AdminQrScannerPageState extends State<AdminQrScannerPage> {
  final BookingService _bookingService = BookingService();
  final RoomService _roomService = RoomService(); // For fetching room name
  MobileScannerController _scannerController = MobileScannerController(
    // Facing can be front or back, default is back
    // detectionSpeed: DetectionSpeed.normal, // default
    // detectionTimeoutMs: 250, // default
  );
  bool _isProcessingScan = false;
  Booking? _scannedBooking;
  String? _scannedRoomName;
  String? _scanErrorMessage;

  @override
  void initState() {
    super.initState();
    // Optionally, request camera permission here using a package like permission_handler
    // For this subtask, we assume permissions are handled or will be added by the developer.
  }

  void _handleBarcodeDetect(BarcodeCapture capture) {
    if (_isProcessingScan) return; // Don't process multiple times quickly

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
      // It's important to stop the camera *before* potentially showing dialogs or navigating
      // to prevent issues if the camera is still active in the background.
      _scannerController.stop();

      _fetchBookingDetails(scannedBookingId);
    }
  }

  Future<void> _fetchBookingDetails(String bookingId) async {
    try {
      Booking? booking = await _bookingService.getBookingDetails(bookingId);
      if (booking != null) {
        String roomName = booking.roomId; // Fallback
        try {
          Room? room = await _roomService.getRoom(booking.roomId);
          if (room != null) roomName = room.name;
        } catch (e) { /* ignore room name fetch error, use ID */ }

        if (mounted) {
          setState(() {
            _scannedBooking = booking;
            _scannedRoomName = roomName;
          });
        }
      } else {
        if (mounted) setState(() => _scanErrorMessage = 'Booking ID "$bookingId" not found.');
      }
    } catch (e) {
      if (mounted) setState(() => _scanErrorMessage = 'Error fetching booking: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessingScan = false);
      // Camera is stopped, user can choose to rescan.
    }
  }

  void _resetScanner() {
    setState(() {
        _scannedBooking = null;
        _scannedRoomName = null;
        _scanErrorMessage = null;
        _isProcessingScan = false; // Allow new scans
    });
    // Check if controller is disposed or camera is already active before starting
    if (_scannerController.isStarting || mounted == false) return;

    // Re-initialize controller if it was disposed or to ensure fresh state
    // However, mobile_scanner typically handles restart well.
    // If issues occur, full re-initialization might be needed:
    // _scannerController.dispose();
    // _scannerController = MobileScannerController();

    _scannerController.start();
  }

  Future<void> _performCheckIn(Booking booking) async {
    // Placeholder for actual check-in logic
    // e.g., await _bookingService.updateBookingStatus(booking.bookingId, 'CheckedInByAdmin', adminId: _adminId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('User for booking ${booking.bookingId} for room $_scannedRoomName checked in (simulated).'), backgroundColor: Colors.green)
    );
    _resetScanner(); // Reset for next scan
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Booking QR Code')),
      body: Column(
        children: <Widget>[
          if (_scannedBooking == null && _scanErrorMessage == null)
            Expanded(
              flex: 2,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _handleBarcodeDetect,
                    // fit: BoxFit.cover,
                  ),
                  if (_isProcessingScan && _scannedBooking == null && _scanErrorMessage == null)
                    const CircularProgressIndicator(), // Show loader only during initial processing before details/error
                ],
              ),
            ),

          Expanded(
            flex: _scannedBooking != null || _scanErrorMessage != null ? 3 : 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isProcessingScan && _scannedBooking == null && _scanErrorMessage == null
                  ? const Center(child: CircularProgressIndicator()) // Also show loader here if processing takes time after scan detection UI part
                  : _scannedBooking != null
                    ? _buildBookingDetailsCard(theme, _scannedBooking!, _scannedRoomName ?? _scannedBooking!.roomId)
                    : _scanErrorMessage != null
                        ? _buildErrorCard(theme, _scanErrorMessage!)
                        : Center(child: Text('Point camera at a booking QR code.', style: theme.textTheme.titleMedium)),
            ),
          ),

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
