import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To get current admin's ID
import 'package:cloud_firestore/cloud_firestore.dart'; // For DocumentReference
import 'package:library_booking/services/announcement_service.dart';

/// A page for administrators to create a new announcement or edit an existing one.
///
/// Accepts an optional [Announcement] object via its constructor.
/// If an [Announcement] is provided, the page operates in "edit" mode,
/// pre-filling form fields with the announcement's data.
/// If no [Announcement] is provided, it operates in "add" mode.
///
/// Uses [AnnouncementService] to persist changes to Firestore.
class AdminEditAnnouncementPage extends StatefulWidget {
  /// The announcement to be edited. If `null`, the page is for adding a new announcement.
  final Announcement? announcement;

  /// Creates an instance of [AdminEditAnnouncementPage].
  ///
  /// [announcement] is optional and determines if the page is for adding or editing.
  const AdminEditAnnouncementPage({super.key, this.announcement});

  /// The named route for this page.
  static const String routeName = '/admin/edit-announcement';

  @override
  State<AdminEditAnnouncementPage> createState() => _AdminEditAnnouncementPageState();
}

/// Manages the state for the [AdminEditAnnouncementPage].
///
/// Handles form input for announcement title, message, category, and active status.
/// Interacts with [AnnouncementService] to save new or updated announcements.
class _AdminEditAnnouncementPageState extends State<AdminEditAnnouncementPage> {
  final _formKey = GlobalKey<FormState>();
  final AnnouncementService _announcementService = AnnouncementService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  late TextEditingController _titleController;
  late TextEditingController _messageController;
  String? _selectedCategory;
  late bool _isActive;
  bool _isLoading = false;

  /// A list of predefined categories for announcements.
  final List<String> _announcementCategories = ['General', 'Maintenance', 'Event', 'Urgent', 'Library Update'];

  /// Determines if the page is in "edit" mode based on whether [widget.announcement] is provided.
  bool get _isEditing => widget.announcement != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.announcement?.title ?? '');
    _messageController = TextEditingController(text: widget.announcement?.message ?? '');
    _selectedCategory = widget.announcement?.category;
    _isActive = widget.announcement?.isActive ?? true; // New announcements default to active
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// Validates the form and saves the announcement data.
  ///
  /// If the form is valid and an admin is authenticated, it proceeds to either
  /// add a new announcement (if `_isEditing` is false) or update an existing one
  /// (if `_isEditing` is true) using the [AnnouncementService].
  ///
  /// For new announcements, if `_isActive` is set to false by the admin on the form,
  /// an additional update call is made to set the new announcement as inactive,
  /// as `postAnnouncement` defaults to active.
  ///
  /// Displays a [SnackBar] to indicate success or failure and navigates back
  /// to the previous page on successful save. Manages an `_isLoading` state.
  Future<void> _saveAnnouncement() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final User? currentAdmin = _firebaseAuth.currentUser;
    if (currentAdmin == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication error. Please log in again.'), backgroundColor: Colors.red));
      return;
    }

    setState(() { _isLoading = true; });

    final String title = _titleController.text.trim();
    final String message = _messageController.text.trim();
    // The form validator ensures _selectedCategory is not null before this point.
    final String categoryToSave = _selectedCategory!;

    try {
      if (_isEditing) {
        await _announcementService.updateAnnouncement(
          widget.announcement!.announcementId,
          title: title,
          message: message,
          category: categoryToSave,
          isActive: _isActive,
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Announcement "${widget.announcement!.title}" updated!'), backgroundColor: Colors.green));
      } else {
        DocumentReference newAnnRef = await _announcementService.postAnnouncement(
          adminId: currentAdmin.uid,
          title: title,
          message: message,
          category: categoryToSave,
        );
        // If the admin wants the new announcement to start as inactive.
        if (!_isActive) {
           await _announcementService.updateAnnouncement(newAnnRef.id, isActive: false);
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Announcement "$title" posted!'), backgroundColor: Colors.green));
      }
      if (mounted) Navigator.of(context).pop();

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save announcement: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  /// Builds the UI for the Admin Edit/Add Announcement Page.
  ///
  /// Contains a form with fields for announcement title, category (dropdown),
  /// message (multiline), and an active status switch. The submit button's
  /// label and AppBar title change based on whether adding or editing.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Announcement' : 'New Announcement'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g., Library Closure, New Book Arrivals',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: Icon(Icons.title, color: theme.colorScheme.primary),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Title is required.';
                  if (value.trim().length < 5) return 'Title must be at least 5 characters.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: Icon(Icons.category_outlined, color: theme.colorScheme.primary),
                ),
                hint: const Text('Select a category'),
                items: _announcementCategories.map((String category) {
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
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please select a category.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: 'Message',
                  hintText: 'Enter the full announcement message here...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.message_outlined, color: theme.colorScheme.primary),
                ),
                maxLines: 8,
                minLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Message is required.';
                  if (value.trim().length < 10) return 'Message must be at least 10 characters.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Announcement is Active'),
                subtitle: Text(_isActive ? 'Visible to users immediately.' : 'Hidden from users.'),
                value: _isActive,
                onChanged: (bool value) {
                  setState(() {
                    _isActive = value;
                  });
                },
                activeColor: theme.colorScheme.primary,
                secondary: Icon(Icons.power_settings_new, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.save_alt_outlined),
                      label: Text(_isEditing ? 'Save Changes' : 'Post Announcement'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _saveAnnouncement,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
