import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:library_booking/services/feedback_service.dart' as app_feedback; // Aliased

/// Admin page for viewing and managing user-submitted feedback.
///
/// Displays feedback items in a tabbed interface, filtered by status:
/// 'Pending Review', 'Addressed', and 'All'. Administrators can:
/// - View details of each feedback item.
/// - Mark feedback as addressed and add administrative notes.
/// - Update existing admin notes on addressed feedback.
/// - Delete feedback items.
class AdminViewFeedbackPage extends StatefulWidget {
  /// Creates an instance of [AdminViewFeedbackPage].
  const AdminViewFeedbackPage({super.key});

  /// The named route for this page.
  static const String routeName = '/admin/view-feedback';

  @override
  State<AdminViewFeedbackPage> createState() => _AdminViewFeedbackPageState();
}

/// Manages the state for the [AdminViewFeedbackPage].
///
/// Handles fetching and displaying feedback based on selected status filters,
/// interacting with [app_feedback.FeedbackService] to update or delete feedback items,
/// and managing the [TabController] for status filtering.
class _AdminViewFeedbackPageState extends State<AdminViewFeedbackPage> with SingleTickerProviderStateMixin {
  final app_feedback.FeedbackService _feedbackService = app_feedback.FeedbackService();

  TabController? _tabController;
  final List<String> _feedbackFilters = ['Pending Review', 'Addressed', 'All'];
  // _selectedFilter is implicitly managed by _tabController.index and used in _loadFeedbackForFilter.

  Stream<List<app_feedback.Feedback>>? _feedbackStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _feedbackFilters.length, vsync: this);
    _tabController!.addListener(() {
      // Load feedback when tab selection is finalized.
      if (!_tabController!.indexIsChanging && mounted) {
        _loadFeedbackForFilter(_feedbackFilters[_tabController!.index]);
      }
    });
    _loadFeedbackForFilter(_feedbackFilters.first); // Initial load for "Pending Review"
  }

  /// Loads the stream of feedback items based on the selected [filter].
  ///
  /// Updates [_feedbackStream] by calling the appropriate method on [app_feedback.FeedbackService]:
  /// - `getFeedbackByStatus(false)` for "Pending Review".
  /// - `getFeedbackByStatus(true)` for "Addressed".
  /// - `getAllFeedback()` for "All".
  ///
  /// - [filter]: The status filter string (e.g., 'Pending Review', 'Addressed', 'All').
  void _loadFeedbackForFilter(String filter) {
    setState(() {
      if (filter == 'Pending Review') {
        _feedbackStream = _feedbackService.getFeedbackByStatus(false);
      } else if (filter == 'Addressed') {
        _feedbackStream = _feedbackService.getFeedbackByStatus(true);
      } else { // 'All'
        _feedbackStream = _feedbackService.getAllFeedback();
      }
    });
  }

  /// Shows a dialog for an admin to mark feedback as addressed or update existing admin notes.
  ///
  /// If the [feedbackItem] is not yet addressed, this action will mark it as addressed
  /// using [app_feedback.FeedbackService.markAsAddressed].
  /// If it's already addressed, it allows updating the notes via
  /// [app_feedback.FeedbackService.updateAdminNotes].
  /// Displays a [SnackBar] with the outcome of the operation.
  ///
  /// - [feedbackItem]: The [app_feedback.Feedback] object to be actioned.
  Future<void> _markAsAddressedDialog(app_feedback.Feedback feedbackItem) async {
    final notesController = TextEditingController(text: feedbackItem.adminNotes ?? '');

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(feedbackItem.isAddressed ? 'Update Admin Notes' : 'Mark as Addressed'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Feedback from: ${feedbackItem.userEmail}'),
                Text('Category: ${feedbackItem.category ?? "N/A"}'),
                const SizedBox(height: 8),
                Text('Message: "${feedbackItem.message}"'),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Admin Notes (Optional)',
                    hintText: 'Add notes for this feedback...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(feedbackItem.isAddressed ? 'Update Notes' : 'Mark Addressed'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        String finalNotes = notesController.text.trim();
        if (feedbackItem.isAddressed) {
            await _feedbackService.updateAdminNotes(feedbackItem.feedbackId, finalNotes);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin notes updated.'), backgroundColor: Colors.blue));
        } else {
            await _feedbackService.markAsAddressed(feedbackItem.feedbackId, finalNotes);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback marked as addressed.'), backgroundColor: Colors.green));
        }
        // StreamBuilder should automatically reflect changes.
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update feedback: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  /// Shows a confirmation dialog before permanently deleting a [feedbackItem].
  ///
  /// If confirmed, calls [app_feedback.FeedbackService.deleteFeedback].
  /// Displays a [SnackBar] with the outcome.
  ///
  /// - [feedbackItem]: The [app_feedback.Feedback] object to be deleted.
  Future<void> _deleteFeedbackDialog(app_feedback.Feedback feedbackItem) async {
      bool? confirmDelete = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Confirm Delete'),
            content: Text('Are you sure you want to permanently delete this feedback from ${feedbackItem.userEmail} regarding "${feedbackItem.message.substring(0, (feedbackItem.message.length > 20 ? 20 : feedbackItem.message.length))}(...)"? This action cannot be undone.'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              TextButton(
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          );
        },
      );

      if (confirmDelete == true) {
        try {
          await _feedbackService.deleteFeedback(feedbackItem.feedbackId);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback deleted successfully.'), backgroundColor: Colors.orange));
          // StreamBuilder will update the list.
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete feedback: ${e.toString()}'), backgroundColor: Colors.red));
        }
      }
  }

  /// Builds the UI for the Admin View Feedback Page.
  ///
  /// Features a [TabBar] for filtering feedback by status. Each tab displays
  /// relevant feedback items using a [StreamBuilder]. Admins can view feedback
  /// details and perform actions like marking as addressed or deleting.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('View User Feedback'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabs: _feedbackFilters.map((status) => Tab(text: status)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _feedbackFilters.map((statusFilter) {
          return StreamBuilder<List<app_feedback.Feedback>>(
            stream: _feedbackStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              }
              final feedbackList = snapshot.data ?? [];

              // The stream is already filtered by _loadFeedbackForFilter.
              // Sorting is maintained here for consistency if service doesn't guarantee it for all methods.
              feedbackList.sort((a, b) => b.timestamp.compareTo(a.timestamp));


              if (feedbackList.isEmpty) {
                // Use the currently selected tab name for the empty message.
                return Center(child: Text('No feedback items found for "${_feedbackFilters[_tabController?.index ?? 0]}".'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: feedbackList.length,
                itemBuilder: (context, index) {
                  final item = feedbackList[index];
                  return Card(
                    elevation: theme.cardTheme.elevation,
                    shape: theme.cardTheme.shape,
                    margin: const EdgeInsets.fromLTRB(8, 8, 8, 4), // Using fixed margin from previous fix
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('From: ${item.userEmail}', style: theme.textTheme.bodySmall),
                          Text('Category: ${item.category ?? "N/A"}', style: theme.textTheme.titleSmall?.copyWith(fontStyle: FontStyle.italic)),
                          const SizedBox(height: 6),
                          Text(item.message, style: theme.textTheme.bodyLarge),
                          const SizedBox(height: 6),
                          Text('Submitted: ${DateFormat('MMM d, yyyy hh:mm a').format(item.timestamp.toDate())}', style: theme.textTheme.bodySmall),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Status: ${item.isAddressed ? "Addressed" : "Pending Review"}',
                                style: TextStyle(
                                  color: item.isAddressed ? Colors.green.shade700 : Colors.orange.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (item.isAddressed && item.adminNotes != null && item.adminNotes!.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    ' - Notes: ${item.adminNotes}',
                                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
                                tooltip: 'Delete Feedback',
                                onPressed: () => _deleteFeedbackDialog(item),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                icon: Icon(item.isAddressed ? Icons.edit_note : Icons.check_circle_outline),
                                label: Text(item.isAddressed ? 'Edit Notes' : 'Address'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: item.isAddressed ? theme.colorScheme.secondary : Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _markAsAddressedDialog(item),
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
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }
}
