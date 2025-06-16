import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:library_booking/services/announcement_service.dart'; // Import AnnouncementService and Announcement model
import 'package:library_booking/pages/admin/admin_edit_announcement_page.dart';

/// Admin page for managing system-wide announcements.
///
/// Displays a list of all announcements (both active and inactive) fetched from
/// [AnnouncementService]. Administrators can:
/// - View announcement details (title, category, message, post date, status).
/// - Toggle the active status of an announcement (activate/deactivate).
/// - Navigate to add a new announcement ([AdminEditAnnouncementPage]).
/// - Navigate to edit an existing announcement ([AdminEditAnnouncementPage]).
class AdminManageAnnouncementsPage extends StatefulWidget {
  /// Creates an instance of [AdminManageAnnouncementsPage].
  const AdminManageAnnouncementsPage({super.key});

  /// The named route for this page.
  static const String routeName = '/admin/manage-announcements';

  @override
  State<AdminManageAnnouncementsPage> createState() => _AdminManageAnnouncementsPageState();
}

/// Manages the state for the [AdminManageAnnouncementsPage].
///
/// Initializes and holds the stream of all announcements from [AnnouncementService].
/// Handles actions like toggling announcement status and navigating to add/edit pages.
class _AdminManageAnnouncementsPageState extends State<AdminManageAnnouncementsPage> {
  final AnnouncementService _announcementService = AnnouncementService();
  late Stream<List<Announcement>> _allAnnouncementsStream;

  @override
  void initState() {
    super.initState();
    // Fetches all announcements, including active and inactive, for comprehensive admin view.
    // The service method already orders them by timestamp descending.
    _allAnnouncementsStream = _announcementService.getAllAnnouncementsForAdmin();
  }

  /// Toggles the active status of the given [announcement].
  ///
  /// Calls [AnnouncementService.deactivateAnnouncement] if the announcement is currently active,
  /// or [AnnouncementService.activateAnnouncement] if it is inactive.
  /// Displays a [SnackBar] to provide feedback on the action's outcome.
  /// The UI is expected to update automatically via the [StreamBuilder] listening to changes.
  ///
  /// - [announcement]: The [Announcement] object whose status is to be toggled.
  Future<void> _toggleAnnouncementStatus(Announcement announcement) async {
    try {
      if (announcement.isActive) {
        await _announcementService.deactivateAnnouncement(announcement.announcementId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Announcement "${announcement.title}" deactivated.'), backgroundColor: Colors.orange));
      } else {
        await _announcementService.activateAnnouncement(announcement.announcementId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Announcement "${announcement.title}" activated.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update announcement status: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  /// Navigates to the [AdminEditAnnouncementPage] for adding a new announcement.
  ///
  /// Passes no `announcement` argument to [AdminEditAnnouncementPage], indicating "add" mode.
  void _navigateToAddAnnouncementPage() {
    Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AdminEditAnnouncementPage())
    );
  }

  /// Navigates to the [AdminEditAnnouncementPage] for editing an existing [announcement].
  ///
  /// Passes the selected [announcement] object to [AdminEditAnnouncementPage] to populate
  /// the form for editing.
  ///
  /// - [announcement]: The [Announcement] object to be edited.
  void _navigateToEditAnnouncementPage(Announcement announcement) {
     Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AdminEditAnnouncementPage(announcement: announcement))
    );
  }

  /// Builds the UI for the Admin Manage Announcements Page.
  ///
  /// Displays a list of all announcements using a [StreamBuilder]. Each announcement
  /// is presented in a [Card] with its details and action buttons for editing
  /// or toggling its active status. A [FloatingActionButton] allows creating new announcements.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Announcements'),
      ),
      body: StreamBuilder<List<Announcement>>(
        stream: _allAnnouncementsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading announcements: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          final announcements = snapshot.data;
          if (announcements == null || announcements.isEmpty) {
            return const Center(child: Text('No announcements found. Create one!'));
          }

          // The stream from getAllAnnouncementsForAdmin is already sorted by timestamp descending.

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              return Card(
                elevation: theme.cardTheme.elevation,
                shape: theme.cardTheme.shape,
                margin: theme.cardTheme.margin?.copyWith(top: 8, bottom: 0),
                color: announcement.isActive ? theme.cardColor : Colors.grey[300],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: announcement.isActive ? theme.colorScheme.primary : Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Category: ${announcement.category}',
                        style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)
                      ),
                      const SizedBox(height: 6),
                      Text(
                        announcement.message,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                       Text(
                        'Posted: ${DateFormat('MMM d, yyyy hh:mm a').format(announcement.timestamp.toDate())}',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        'Status: ${announcement.isActive ? "Active" : "Inactive"}',
                        style: TextStyle(
                          color: announcement.isActive ? Colors.green.shade700 : Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            color: theme.colorScheme.primary,
                            tooltip: 'Edit Announcement',
                            onPressed: () => _navigateToEditAnnouncementPage(announcement),
                          ),
                          IconButton(
                            icon: Icon(announcement.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            color: announcement.isActive ? Colors.orange.shade700 : Colors.green.shade700,
                            tooltip: announcement.isActive ? 'Deactivate' : 'Activate',
                            onPressed: () => _toggleAnnouncementStatus(announcement),
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
        onPressed: _navigateToAddAnnouncementPage,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New Announcement'),
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
      ),
    );
  }
}
