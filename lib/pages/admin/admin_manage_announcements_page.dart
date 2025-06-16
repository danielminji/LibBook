import 'package:flutter/material.dart';

class AdminManageAnnouncementsPage extends StatelessWidget {
  const AdminManageAnnouncementsPage({super.key});
  static const String routeName = '/admin/manage-announcements';
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Manage Announcements')), body: const Center(child: Text('Admin: Manage Announcements Page')));
}
