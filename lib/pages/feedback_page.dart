import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:library_booking/services/feedback_service.dart' as app_feedback; // Aliased
import 'package:library_booking/services/auth_service.dart'; // To get user details if needed for display

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});
  static const String routeName = '/feedback';

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final app_feedback.FeedbackService _feedbackService = app_feedback.FeedbackService();
  final AuthService _authService = AuthService(); // If we need to display username from Firestore doc
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  User? _currentUser;
  // String? _username; // For display purposes if fetched - Not used in this version

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _messageController = TextEditingController();
  String? _selectedCategory; // Can be null if no category is chosen
  final List<String> _feedbackCategories = ['General', 'Bug Report', 'Suggestion', 'Room Issue', 'Other'];

  bool _isSubmitting = false;
  Stream<List<app_feedback.Feedback>>? _userFeedbackStream;

  @override
  void initState() {
    super.initState();
    _currentUser = _firebaseAuth.currentUser;
    if (_currentUser != null) {
      _loadUserDataAndFeedback();
    }
  }

  Future<void> _loadUserDataAndFeedback() async {
    if (_currentUser == null) return;
    // Optionally load username if you want to display it or ensure it's up-to-date
    // DocumentSnapshot? userDoc = await _authService.getUserDocument(_currentUser!.uid);
    // if (mounted && userDoc != null && userDoc.exists) {
    //   setState(() { _username = userDoc.get('username'); });
    // }
    setState(() {
      _userFeedbackStream = _feedbackService.getFeedbackByUser(_currentUser!.uid);
    });
  }

  Future<void> _submitFeedback() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in to submit feedback.'), backgroundColor: Colors.red));
      return;
    }
    if (_formKey.currentState!.validate()) {
      setState(() { _isSubmitting = true; });
      try {
        await _feedbackService.submitFeedback(
          userId: _currentUser!.uid,
          userEmail: _currentUser!.email ?? 'N/A', // Firebase Auth email
          message: _messageController.text.trim(),
          category: _selectedCategory,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback submitted successfully!'), backgroundColor: Colors.green));
          _messageController.clear();
          setState(() { _selectedCategory = null; });
          // No explicit refresh of _userFeedbackStream needed due to StreamBuilder
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
            // Feedback Submission Form
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

            // User's Past Feedback Section
            Text('Your Submitted Feedback', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary)),
            const SizedBox(height: 8),
            StreamBuilder<List<app_feedback.Feedback>>(
              stream: _userFeedbackStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _userFeedbackStream != null) {
                  // Show loader only if stream is initialized and waiting
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error loading your feedback: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                }
                final feedbackList = snapshot.data;
                if (feedbackList == null || feedbackList.isEmpty) {
                  return const Text('You have not submitted any feedback yet.');
                }
                // Sort by timestamp descending (newest first)
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
                        isThreeLine: true, // Adjust based on content
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
