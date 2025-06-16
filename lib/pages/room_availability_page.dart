import 'package:flutter/material.dart';
import 'date_time_selection_page.dart';

class RoomAvailabilityPage extends StatelessWidget {
  const RoomAvailabilityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Available Rooms')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _buildRoomCard(context, 'Meeting Room 1', 'Capacity: 8 people'),
          _buildRoomCard(context, 'Meeting Room 2', 'Capacity: 8 people'),
          _buildRoomCard(context, 'Conference Room 1', 'Capacity: 20 people'),
          _buildRoomCard(context, 'Conference Room 2', 'Capacity: 20 people'),
          _buildRoomCard(context, 'Computer Room 1', 'Capacity: 15 computers'),
          _buildRoomCard(context, 'Computer Room 2', 'Capacity: 15 computers'),
        ],
      ),
    );
  }

  Widget _buildRoomCard(BuildContext context, String title, String capacity) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DateTimeSelectionPage(roomName: title),
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.meeting_room, size: 48),
            const SizedBox(height: 8),
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(capacity, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            const Chip(
              label: Text('Available'),
              backgroundColor: Colors.green,
              labelStyle: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
