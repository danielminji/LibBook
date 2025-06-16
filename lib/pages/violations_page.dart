import 'package:flutter/material.dart';

class ViolationsPage extends StatelessWidget {
  const ViolationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Room Violations')),
      body: ListView.builder(
        itemCount: 3, // Replace with actual violations data
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Violation #${index + 1}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Description of the violation. Replace with actual violation details.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Date: ${DateTime.now().subtract(Duration(days: index)).toString().split(' ')[0]}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
