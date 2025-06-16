import 'package:flutter/material.dart';

class FeedbackPage extends StatelessWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TextField(
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Your Feedback',
                hintText: 'Please share your experience...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: const Icon(Icons.star_border),
                  onPressed: () {
                    // Add rating logic
                  },
                );
              }),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                // Add submit logic
                Navigator.pop(context);
              },
              child: const Text('Submit Feedback'),
            ),
          ],
        ),
      ),
    );
  }
}
