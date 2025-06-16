import 'package:flutter/material.dart';

class AdminViewFeedbackPage extends StatelessWidget {
  const AdminViewFeedbackPage({super.key});
  static const String routeName = '/admin/view-feedback';
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('View User Feedback')), body: const Center(child: Text('Admin: View Feedback Page')));
}
