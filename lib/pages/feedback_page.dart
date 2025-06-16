import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:library_booking/services/feedback_service.dart' as app_feedback; // Aliased
import 'package:library_booking/services/auth_service.dart'; // To get user details if needed for display

/// A page where users can submit feedback about the application or services,
/// and view their previously submitted feedback items along with their status.
class FeedbackPage extends StatefulWidget {
  /// Creates an instance of [FeedbackPage].
  const FeedbackPage({super.key});

  /// The named route for this page.
  static const String routeName = '/feedback';

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

/// Manages the state for the [FeedbackPage].
///
/// This includes handling the feedback submission form, loading and displaying
/// the user's past feedback, and interacting with [app_feedback.FeedbackService].
class _FeedbackPageState extends State<FeedbackPage> {
  final app_feedback.FeedbackService _feedbackService = app_feedback.FeedbackService();
  // AuthService might be used in the future to fetch more detailed user info for display.
  // final AuthService _authService = AuthService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  User? _currentUser;
  // String? _username; // Currently not used, but could be fetched for display.

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _messageController = TextEditingController();
  String? _selectedCategory;
  final List<String> _feedbackCategories = ['General', 'Bug Report', 'Suggestion', 'Room Issue', 'Other'];

  bool _isSubmitting = false;
  Stream<List<app_feedback.Feedback>>? _userFeedbackStream;

  @override
  void initState() {
    super.initState();
    _currentUser = _firebaseAuth.currentUser;
    if (_currentUser != null) {
      _loadUserFeedback();
    }
  }

  /// Loads the stream of feedback submitted by the current user.
  ///
  /// Initializes [_userFeedbackStream] by calling
  /// [app_feedback.FeedbackService.getFeedbackByUser].
  Future<void> _loadUserFeedback() async { // Renamed for clarity
    if (_currentUser == null) return;
    setState(() {
      _userFeedbackStream = _feedbackService.getFeedbackByUser(_currentUser!.uid);
    });
  }

  /// Submits the user's feedback to the [app_feedback.FeedbackService].
  ///
  /// Validates the form. If valid, it ensures a user is logged in, then calls
  /// [app_feedback.FeedbackService.submitFeedback]. Manages `_isSubmitting` state
  /// for loading indication and shows a [SnackBar] for success or failure.
  /// Clears the form fields upon successful submission.
  Future<void> _submitFeedback() async {
    if (_currentUser == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in to submit feedback.'), backgroundColor: Colors.red));
      return;
    }
    if (_formKey.currentState!.validate()) {
      setState(() { _isSubmitting = true; });
      try {
        await _feedbackService.submitFeedback(
          userId: _currentUser!.uid,
          userEmail: _currentUser!.email ?? 'N/A',
          message: _messageController.text.trim(),
          category: _selectedCategory,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback submitted successfully!'), backgroundColor: Colors.green));
          _messageController.clear();
          setState(() { _selectedCategory = null; });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit feedback: ${e.toString()}'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) {
          setState(() { _isSubmitting = false; });
        }
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// Builds the UI for the Feedback Page.
  ///
  /// Features a form for submitting new feedback (category and message) and
  /// a list displaying the user's previously submitted feedback items with their status.
  /// Handles loading and error states for the feedback list.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_currentUser == null) {
      return Scaffold(appBar: AppBar(title: const Text('Submit Feedback')), body: const Center(child: Text('Please log in to submit feedback.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Feedback'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Send us your thoughts', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary)),
            const SizedBox(height: 8),
            Card(
              elevation: theme.cardTheme.elevation,
              shape: theme.cardTheme.shape,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category (Optional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        hint: const Text('Select a category'),
                        items: _feedbackCategories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedCategory = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          labelText: 'Your Feedback',
                          hintText: 'Enter your message here...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                        minLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your feedback message.';
                          }
                          if (value.trim().length < 10) {
                            return 'Feedback message should be at least 10 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _isSubmitting
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton.icon(
                              icon: const Icon(Icons.send),
                              label: const Text('Submit Feedback'),
                              onPressed: _submitFeedback,
                            ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            Text('Your Submitted Feedback', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary)),
            const SizedBox(height: 8),
            StreamBuilder<List<app_feedback.Feedback>>(
              stream: _userFeedbackStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _userFeedbackStream != null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error loading your feedback: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                }
                final feedbackList = snapshot.data;
                if (feedbackList == null || feedbackList.isEmpty) {
                  return const Text('You have not submitted any feedback yet.');
                }
                feedbackList.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: feedbackList.length,
                  itemBuilder: (context, index) {
                    final feedbackItem = feedbackList[index];
                    return Card(
                      elevation: theme.cardTheme.elevation,
                      shape: theme.cardTheme.shape,
                      margin: theme.cardTheme.margin?.copyWith(top: 8, bottom: 0),
                      child: ListTile(
                        title: Text(feedbackItem.category ?? 'General Feedback', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(feedbackItem.message, maxLines: 3, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text('Submitted: ${DateFormat('MMM d, yyyy hh:mm a').format(feedbackItem.timestamp.toDate())}', style: theme.textTheme.bodySmall),
                            if (feedbackItem.isAddressed)
                               Text('Status: Addressed ${feedbackItem.adminNotes != null && feedbackItem.adminNotes!.isNotEmpty ? "- Note: ${feedbackItem.adminNotes}" : ""}', style: TextStyle(color: Colors.green.shade700, fontStyle: FontStyle.italic, fontSize: 12)),
                            else
                               const Text('Status: Pending Review', style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic, fontSize: 12)),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
