import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:library_booking/services/feedback_service.dart' as app_feedback; // Aliased

class AdminViewFeedbackPage extends StatefulWidget {
  const AdminViewFeedbackPage({super.key});
  static const String routeName = '/admin/view-feedback'; // Already defined

  @override
  State<AdminViewFeedbackPage> createState() => _AdminViewFeedbackPageState();
}

class _AdminViewFeedbackPageState extends State<AdminViewFeedbackPage> with SingleTickerProviderStateMixin {
  final app_feedback.FeedbackService _feedbackService = app_feedback.FeedbackService();

  TabController? _tabController;
  final List<String> _feedbackFilters = ['Pending Review', 'Addressed', 'All'];
  // _selectedFilter is implicitly managed by TabController's index.

  Stream<List<app_feedback.Feedback>>? _feedbackStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _feedbackFilters.length, vsync: this);
    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
         // Triggered when tab selection is finalized
        _loadFeedbackForFilter(_feedbackFilters[_tabController!.index]);
      }
    });
    _loadFeedbackForFilter(_feedbackFilters.first); // Initial load for "Pending Review"
  }

  void _loadFeedbackForFilter(String filter) {
    setState(() {
      // _selectedFilter = filter; // Not strictly needed if using tabController.index to determine current filter
      if (filter == 'Pending Review') {
        _feedbackStream = _feedbackService.getFeedbackByStatus(false); // isAddressed = false
      } else if (filter == 'Addressed') {
        _feedbackStream = _feedbackService.getFeedbackByStatus(true); // isAddressed = true
      } else { // 'All'
        _feedbackStream = _feedbackService.getAllFeedback();
      }
    });
  }

  Future<void> _markAsAddressedDialog(app_feedback.Feedback feedbackItem) async {
    String? adminNotes = feedbackItem.adminNotes;
    final notesController = TextEditingController(text: adminNotes);

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(feedbackItem.isAddressed ? 'Update Admin Notes' : 'Mark as Addressed'),
          content: SingleChildScrollView( // Added SingleChildScrollView for potentially long content
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
                  onChanged: (value) => adminNotes = value, // adminNotes will be updated if dialog is confirmed
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
        String finalNotes = notesController.text.trim(); // Use controller's final text
        if (feedbackItem.isAddressed) {
            await _feedbackService.updateAdminNotes(feedbackItem.feedbackId, finalNotes);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin notes updated.'), backgroundColor: Colors.blue));
        } else {
            await _feedbackService.markAsAddressed(feedbackItem.feedbackId, finalNotes);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback marked as addressed.'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update feedback: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

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
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete feedback: ${e.toString()}'), backgroundColor: Colors.red));
        }
      }
  }


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

              // Note: The stream is already filtered by _loadFeedbackForFilter.
              // No additional client-side filtering needed here for statusFilter.
              // Sorting is good to keep if service doesn't guarantee it or for consistency.
              feedbackList.sort((a, b) => b.timestamp.compareTo(a.timestamp));


              if (feedbackList.isEmpty) {
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
                    margin: theme.cardTheme.margin?.copyWith(top: 8, bottom: 0),
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
                                  foregroundColor: Colors.white, // Ensure text contrast
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
