import 'package:flutter/material.dart';
import 'package:library_booking/services/room_service.dart'; // Import RoomService and Room model

/// A page for administrators to add a new library room or edit an existing one.
///
/// Accepts an optional [Room] object via its constructor. If a [Room] is provided,
/// the page operates in "edit" mode, pre-filling form fields with the room's data.
/// If no [Room] is provided, it operates in "add" mode for creating a new room.
///
/// Uses [RoomService] to persist changes to Firestore.
class AdminEditRoomPage extends StatefulWidget {
  /// The room to be edited. If `null`, the page is for adding a new room.
  final Room? room;

  /// Creates an instance of [AdminEditRoomPage].
  ///
  /// [room] is optional and determines if the page is for adding or editing.
  const AdminEditRoomPage({super.key, this.room});

  /// The named route for this page.
  static const String routeName = '/admin/edit-room';

  @override
  State<AdminEditRoomPage> createState() => _AdminEditRoomPageState();
}

/// Manages the state for the [AdminEditRoomPage].
///
/// Handles form input, validation, and interaction with [RoomService]
/// to either add a new room or update an existing one.
class _AdminEditRoomPageState extends State<AdminEditRoomPage> {
  final _formKey = GlobalKey<FormState>();
  final RoomService _roomService = RoomService();

  late TextEditingController _nameController;
  late TextEditingController _capacityController;
  late TextEditingController _amenitiesController; // For comma-separated amenities
  late bool _isActive;
  bool _isLoading = false;

  /// Determines if the page is in "edit" mode (i.e., a [widget.room] was provided).
  bool get _isEditing => widget.room != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room?.name ?? '');
    _capacityController = TextEditingController(text: widget.room?.capacity.toString() ?? '');
    _amenitiesController = TextEditingController(text: widget.room?.amenities.join(', ') ?? '');
    _isActive = widget.room?.isActive ?? true; // Defaults to active for new rooms
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    _amenitiesController.dispose();
    super.dispose();
  }

  /// Parses a comma-separated string of amenities into a list of trimmed strings.
  /// Empty strings resulting from multiple commas are filtered out.
  ///
  /// - [amenitiesString]: The comma-separated string of amenities.
  /// Returns a `List<String>` of amenities.
  List<String> _parseAmenities(String amenitiesString) {
    if (amenitiesString.trim().isEmpty) return [];
    return amenitiesString.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  /// Validates the form and saves the room data.
  ///
  /// If the form is valid, it proceeds to either add a new room (if `_isEditing` is false)
  /// or update an existing room (if `_isEditing` is true) using the [RoomService].
  /// Displays a [SnackBar] to indicate success or failure and navigates back
  /// to the previous page on successful save. Manages an `_isLoading` state.
  Future<void> _saveRoom() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() { _isLoading = true; });

    final String name = _nameController.text.trim();
    final int? capacity = int.tryParse(_capacityController.text.trim());
    final List<String> amenities = _parseAmenities(_amenitiesController.text);

    if (capacity == null) { // Should be caught by validator, but good for safety
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Capacity must be a valid number.'), backgroundColor: Colors.red));
      setState(() { _isLoading = false; });
      return;
    }

    try {
      if (_isEditing) {
        Map<String, dynamic> dataToUpdate = {
          'name': name,
          'capacity': capacity,
          'amenities': amenities,
          'isActive': _isActive,
        };
        await _roomService.updateRoom(widget.room!.roomId, dataToUpdate);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.room!.name} updated successfully!'), backgroundColor: Colors.green));
      } else {
        await _roomService.addRoom(
          name: name,
          capacity: capacity,
          amenities: amenities,
          isActive: _isActive,
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Room "$name" added successfully!'), backgroundColor: Colors.green));
      }
      if (mounted) Navigator.of(context).pop();

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save room: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  /// Builds the UI for the Admin Edit/Add Room Page.
  ///
  /// Contains a form with fields for room name, capacity, amenities (as a
  /// comma-separated string), and an active status switch. The submit button's
  /// label and AppBar title change based on whether adding or editing a room.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Room: ${widget.room!.name}' : 'Add New Room'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Room Name',
                  hintText: 'e.g., Discussion Room A, Study Carrel 101',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: Icon(Icons.meeting_room_outlined, color: theme.colorScheme.primary),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Room name is required.';
                  if (value.trim().length < 3) return 'Room name must be at least 3 characters.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                decoration: InputDecoration(
                  labelText: 'Capacity',
                  hintText: 'e.g., 4',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: Icon(Icons.people_alt_outlined, color: theme.colorScheme.primary),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Capacity is required.';
                  if (int.tryParse(value.trim()) == null) return 'Capacity must be a number.';
                  if (int.parse(value.trim()) <= 0) return 'Capacity must be greater than 0.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amenitiesController,
                decoration: InputDecoration(
                  labelText: 'Amenities (comma-separated)',
                  hintText: 'e.g., Whiteboard, Projector, Power Outlet',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: Icon(Icons.widgets_outlined, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Room is Active'),
                subtitle: Text(_isActive ? 'Visible and bookable by users.' : 'Hidden and not bookable.'),
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
                      label: Text(_isEditing ? 'Save Changes' : 'Add Room'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _saveRoom,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
