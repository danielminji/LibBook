import 'package:flutter/material.dart';

class AdminManageRoomsPage extends StatelessWidget {
  const AdminManageRoomsPage({super.key});
  static const String routeName = '/admin/manage-rooms';
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Manage Rooms')), body: const Center(child: Text('Admin: Manage Rooms Page')));
}
