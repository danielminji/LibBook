import 'package:flutter/material.dart';
import 'package:library_booking/services/room_service.dart'; // Import RoomService and Room model
import 'package:library_booking/pages/room_detail_page.dart';

/// A page that displays a list of currently active and bookable library rooms.
///
/// Users can view a summary of each room (name, capacity, amenities) and tap
/// on a room to navigate to its [RoomDetailPage] for more information and booking options.
/// Data is fetched and displayed using a [StreamBuilder] connected to [RoomService.getActiveRooms].
class RoomListPage extends StatefulWidget {
  /// Creates an instance of [RoomListPage].
  const RoomListPage({super.key});

  /// The named route for this page.
  /// Used for navigation, e.g., from [UserHomePage].
  static const String routeName = '/room-list';

  @override
  State<RoomListPage> createState() => _RoomListPageState();
}

/// Manages the state for the [RoomListPage].
///
/// Initializes and holds the stream of active rooms from [RoomService].
class _RoomListPageState extends State<RoomListPage> {
  final RoomService _roomService = RoomService();
  late Stream<List<Room>> _activeRoomsStream;

  @override
  void initState() {
    super.initState();
    _activeRoomsStream = _roomService.getActiveRooms();
  }

  /// Builds the UI for the Room List Page.
  ///
  /// Displays a list of active rooms using a [StreamBuilder]. Each room is
  /// presented as a tappable [Card] showing its name, capacity, and amenities.
  /// Handles loading, error, and empty states for the room data stream.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Rooms'),
      ),
      body: StreamBuilder<List<Room>>(
        stream: _activeRoomsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('Error loading rooms: ${snapshot.error}');
            print('Stack trace: ${snapshot.stackTrace}');
            return Center(child: Text('Error loading rooms: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          final rooms = snapshot.data;
          if (rooms == null || rooms.isEmpty) {
            return const Center(child: Text('No active rooms available at the moment.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              return Card(
                elevation: theme.cardTheme.elevation,
                shape: theme.cardTheme.shape,
                margin: theme.cardTheme.margin,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoomDetailPage(roomId: room.roomId),
                      ),
                    );
                  },
                  borderRadius: theme.cardTheme.shape is RoundedRectangleBorder
                                ? (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius.resolve(Directionality.of(context))
                                : BorderRadius.circular(12.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.people_alt_outlined, size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 4),
                            Text('Capacity: ${room.capacity}', style: theme.textTheme.bodyMedium),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (room.amenities.isNotEmpty)
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: room.amenities.map((amenity) => Chip(
                              label: Text(amenity),
                              backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
                              labelStyle: TextStyle(color: theme.colorScheme.secondary),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            )).toList(),
                          ),
                        if (room.amenities.isEmpty)
                           Text('No listed amenities.', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Icon(Icons.chevron_right, color: theme.colorScheme.primary),
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
