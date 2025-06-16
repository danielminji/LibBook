import 'package:flutter/material.dart';

class BookingHistoryPage extends StatelessWidget {
  const BookingHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking History')),
      body: ListView.builder(
        itemCount: 10, // Replace with actual booking history data
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.history),
              title: Text('Room ${index + 1}'),
              subtitle: Text(
                  'Date: ${DateTime.now().subtract(Duration(days: index)).toString().split(' ')[0]}'),
              trailing: Chip(
                label: Text(
                  index % 2 == 0 ? 'Completed' : 'Cancelled',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: index % 2 == 0 ? Colors.green : Colors.red,
              ),
            ),
          );
        },
      ),
    );
  }
}
