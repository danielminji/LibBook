import 'package:flutter/material.dart';
import 'package:library_booking/services/room_service.dart'; // Import RoomService and Room model
import 'package:library_booking/pages/room_detail_page.dart';


class RoomListPage extends StatefulWidget {
  const RoomListPage({super.key});
  // Ensure routeName matches what's used in UserHomePage or other navigation points
  static const String routeName = '/room-list';

  @override
  State<RoomListPage> createState() => _RoomListPageState();
}

class _RoomListPageState extends State<RoomListPage> {
  final RoomService _roomService = RoomService();
  late Stream<List<Room>> _activeRoomsStream;

  @override
  void initState() {
    super.initState();
    _activeRoomsStream = _roomService.getActiveRooms();
  }

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
                // Using theme.cardTheme for consistency
                elevation: theme.cardTheme.elevation,
                shape: theme.cardTheme.shape,
                margin: theme.cardTheme.margin,
                child: InkWell(
                  onTap: () {
                    // Ensure RoomDetailPage exists and can accept roomId
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoomDetailPage(roomId: room.roomId),
                      ),
                    );
                  },
                  borderRadius: theme.cardTheme.shape is RoundedRectangleBorder
                                ? (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius.resolve(Directionality.of(context))
                                : BorderRadius.circular(12.0), // Default if not RoundedRectangleBorder
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
