import 'package:flutter/material.dart';
import 'package:library_booking/services/room_service.dart'; // Import RoomService and Room model
import 'package:library_booking/pages/admin/admin_edit_room_page.dart';

/// Admin page for managing library rooms.
///
/// Displays a list of all rooms (both active and inactive) fetched from [RoomService].
/// Allows administrators to:
/// - View room details (name, capacity, status, amenities).
/// - Toggle the active status of a room (activate/deactivate).
/// - Navigate to add a new room ([AdminEditRoomPage]).
/// - Navigate to edit an existing room ([AdminEditRoomPage]).
class AdminManageRoomsPage extends StatefulWidget {
  /// Creates an instance of [AdminManageRoomsPage].
  const AdminManageRoomsPage({super.key});

  /// The named route for this page.
  static const String routeName = '/admin/manage-rooms';

  @override
  State<AdminManageRoomsPage> createState() => _AdminManageRoomsPageState();
}

/// Manages the state for the [AdminManageRoomsPage].
///
/// Initializes and holds the stream of all rooms from [RoomService].
/// Handles actions like toggling room status and navigating to add/edit room pages.
class _AdminManageRoomsPageState extends State<AdminManageRoomsPage> {
  final RoomService _roomService = RoomService();
  late Stream<List<Room>> _allRoomsStream;

  @override
  void initState() {
    super.initState();
    // Fetches all rooms, including active and inactive, for comprehensive admin view.
    _allRoomsStream = _roomService.getAllRooms();
  }

  /// Toggles the active status of the given [room].
  ///
  /// Calls [RoomService.deactivateRoom] if the room is currently active,
  /// or [RoomService.activateRoom] if it is inactive.
  /// Displays a [SnackBar] to provide feedback on the action's outcome.
  /// The UI is expected to update automatically via the [StreamBuilder] listening to room changes.
  ///
  /// - [room]: The [Room] object whose status is to be toggled.
  Future<void> _toggleRoomStatus(Room room) async {
    try {
      if (room.isActive) {
        await _roomService.deactivateRoom(room.roomId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${room.name} deactivated.'), backgroundColor: Colors.orange));
      } else {
        await _roomService.activateRoom(room.roomId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${room.name} activated.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update room status: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  /// Navigates to the [AdminEditRoomPage] for adding a new room.
  ///
  /// Passes no `room` argument to [AdminEditRoomPage], indicating "add" mode.
  void _navigateToAddRoomPage() {
    Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AdminEditRoomPage())
    );
  }

  /// Navigates to the [AdminEditRoomPage] for editing an existing [room].
  ///
  /// Passes the selected [room] object to [AdminEditRoomPage] to populate
  /// the form for editing.
  ///
  /// - [room]: The [Room] object to be edited.
  void _navigateToEditRoomPage(Room room) {
     Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AdminEditRoomPage(room: room))
    );
  }

  /// Builds the UI for the Admin Manage Rooms Page.
  ///
  /// Displays a list of all rooms using a [StreamBuilder]. Each room is
  /// presented in a [Card] with its details and action buttons for editing
  /// or toggling its active status. A [FloatingActionButton] allows adding new rooms.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Rooms'),
      ),
      body: StreamBuilder<List<Room>>(
        stream: _allRoomsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading rooms: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          final rooms = snapshot.data;
          if (rooms == null || rooms.isEmpty) {
            return const Center(child: Text('No rooms found. Add some!'));
          }

          // Sort rooms: active first, then by name for consistent display.
          rooms.sort((a, b) {
            if (a.isActive && !b.isActive) return -1;
            if (!a.isActive && b.isActive) return 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              return Card(
                elevation: theme.cardTheme.elevation,
                shape: theme.cardTheme.shape,
                margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                color: room.isActive ? theme.cardColor : Colors.grey[300],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: room.isActive ? theme.colorScheme.primary : Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Capacity: ${room.capacity}', style: theme.textTheme.bodyMedium),
                      Text('Status: ${room.isActive ? "Active" : "Inactive"}',
                           style: TextStyle(color: room.isActive ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      if (room.amenities.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                          child: Text('Amenities: ${room.amenities.join(", ")}', style: theme.textTheme.bodySmall),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                          child: Text('No listed amenities.', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            color: theme.colorScheme.primary,
                            tooltip: 'Edit Room',
                            onPressed: () => _navigateToEditRoomPage(room),
                          ),
                          IconButton(
                            icon: Icon(room.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            color: room.isActive ? Colors.orange.shade700 : Colors.green.shade700,
                            tooltip: room.isActive ? 'Deactivate Room' : 'Activate Room',
                            onPressed: () => _toggleRoomStatus(room),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddRoomPage,
        icon: const Icon(Icons.add),
        label: const Text('Add Room'),
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
      ),
    );
  }
}
