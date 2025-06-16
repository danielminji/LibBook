import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:cloud_firestore/cloud_firestore.dart'; // Required for DocumentSnapshot
import 'package:library_booking/services/auth_service.dart';
import 'package:library_booking/services/calendar_service.dart'; // Import CalendarService
import 'package:library_booking/pages/welcome_page.dart'; // For logout

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  static const String routeName = '/profile';

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Added for _disconnectCronofy direct action

  // Instantiate CalendarService with credentials (these should ideally come from a config/DI)
  final CalendarService _calendarService = CalendarService(
    clientId: "cKLSwjQNympUGok21LQuEp6DRF5tDARh", // User-provided
    clientSecret: "CRN_YOI66tYVtltMOkQsxzxeCdWy7i8caDq3iv0Xzd", // User-provided
    redirectUri: "com.smartlibrarybooker://oauth2redirect", // Agreed upon
  );

  User? _currentUser;
  String? _username;
  String? _email;
  bool _isLoadingUserData = true;
  bool _isSavingTelegramId = false;
  bool _isCronofyLoading = false; // For Cronofy operations
  String? _cronofyStatus; // e.g., "Not Connected", "Connected: primary_calendar_name"
  List<dynamic>? _cronofyCalendars; // List of user's calendars from Cronofy

  final TextEditingController _telegramChatIdController = TextEditingController();
  final TextEditingController _cronofyAuthCodeController = TextEditingController();
  String? _cronofyAuthorizationUrl;


  @override
  void initState() {
    super.initState();
    _currentUser = _firebaseAuth.currentUser;
    if (_currentUser != null) {
      _loadUserData();
      _checkCronofyStatus();
    } else {
      setState(() {
        _isLoadingUserData = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    setState(() { _isLoadingUserData = true; });
    if (_currentUser == null) return;
    try {
      DocumentSnapshot? userDoc = await _authService.getUserDocument(_currentUser!.uid);
      if (mounted && userDoc != null && userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _username = data['username'];
          _email = data['email'];
          _telegramChatIdController.text = data['telegram_chat_id'] ?? '';
        });
      } else if (mounted) {
         _email = _currentUser!.email; // Fallback
      }
    } catch (e) {
      print("Error loading user data: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading profile: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isLoadingUserData = false; });
    }
  }

  Future<void> _updateTelegramChatId() async {
    if (_currentUser == null) return;
    setState(() { _isSavingTelegramId = true; });
    try {
      await _authService.updateTelegramChatId(_currentUser!.uid, _telegramChatIdController.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Telegram Chat ID updated!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isSavingTelegramId = false; });
    }
  }

  Future<void> _checkCronofyStatus() async {
    if (_currentUser == null) return;
    setState(() { _isCronofyLoading = true; });
    try {
      Map<String, dynamic>? tokens = await _calendarService.getUserTokens(_currentUser!.uid);
      if (tokens != null && tokens['accessToken'] != null) {
        _cronofyCalendars = await _calendarService.listCalendars(_currentUser!.uid);
        if (_cronofyCalendars != null && _cronofyCalendars!.isNotEmpty) {
          var primaryCal = _cronofyCalendars!.firstWhere((cal) => cal['calendar_primary'] == true && cal['calendar_readonly'] == false && cal['calendar_deleted'] == false, orElse: () => _cronofyCalendars!.firstWhere((cal) => cal['calendar_readonly'] == false && cal['calendar_deleted'] == false, orElse: () => null));
          setState(() {
            _cronofyStatus = primaryCal != null ? "Connected: ${primaryCal['calendar_name']}" : "Connected (No suitable calendar found)";
          });
        } else {
           setState(() { _cronofyStatus = "Connected (No calendars found or error)"; });
        }
      } else {
        setState(() { _cronofyStatus = "Not Connected"; _cronofyCalendars = null; });
      }
    } catch (e) {
      print("Error checking Cronofy status: $e");
      if (mounted) setState(() { _cronofyStatus = "Error checking status"; });
    } finally {
      if (mounted) setState(() { _isCronofyLoading = false; });
    }
  }

  void _initiateCronofyOAuth() {
    if (_currentUser == null) return;
    String state = DateTime.now().millisecondsSinceEpoch.toString();
    String authUrl = _calendarService.getAuthorizationUrl(state);
    setState(() {
      _cronofyAuthorizationUrl = authUrl;
    });
  }

  Future<void> _submitCronofyAuthCode() async {
    if (_currentUser == null || _cronofyAuthCodeController.text.isEmpty) return;
    setState(() { _isCronofyLoading = true; });
    try {
      Map<String, dynamic>? tokenData = await _calendarService.exchangeCodeForTokens(_cronofyAuthCodeController.text.trim());
      if (tokenData != null && tokenData['accessToken'] != null && tokenData['refreshToken'] != null && tokenData['expiryDateTime'] != null) {
        await _calendarService.storeUserTokens(
          _currentUser!.uid,
          tokenData['accessToken'],
          tokenData['refreshToken'],
          tokenData['expiryDateTime'],
        );
        _cronofyAuthCodeController.clear();
        setState(() { _cronofyAuthorizationUrl = null; });
        await _checkCronofyStatus();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calendar connected successfully!'), backgroundColor: Colors.green));
      } else {
        throw Exception("Failed to exchange code for tokens or token data incomplete.");
      }
    } catch (e) {
      print("Error submitting Cronofy auth code: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to connect calendar: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isCronofyLoading = false; });
    }
  }

  Future<void> _disconnectCronofy() async {
     if (_currentUser == null) return;
      // For Cronofy, true disconnection involves revoking the token via their API.
      // This is an advanced step not covered by the current CalendarService.
      // For now, we just delete local tokens. A 'real' app should call Cronofy's revoke endpoint.
      print("Attempting to delete local Cronofy tokens for user ${_currentUser!.uid}");
      try {
        await _firestore.collection('users').doc(_currentUser!.uid).collection('cronofy_tokens').doc('user_token').delete();
        print("Local Cronofy tokens deleted for user ${_currentUser!.uid}");
        await _checkCronofyStatus();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calendar disconnected.'), backgroundColor: Colors.orange));
      } catch (e) {
        print("Error deleting local Cronofy tokens: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error disconnecting calendar: ${e.toString()}'), backgroundColor: Colors.red));
      }
  }


  Future<void> _logout() async {
    await _authService.signOut();
    Navigator.of(context).pushNamedAndRemoveUntil(WelcomePage.routeName, (Route<dynamic> route) => false);
  }

  @override
  void dispose() {
    _telegramChatIdController.dispose();
    _cronofyAuthCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoadingUserData) {
      return Scaffold(appBar: AppBar(title: const Text('My Profile')), body: const Center(child: CircularProgressIndicator()));
    }
    if (_currentUser == null) {
      return Scaffold(appBar: AppBar(title: const Text('My Profile')), body: const Center(child: Text('Please log in.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildSectionTitle(theme, 'User Information'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoRow(theme, Icons.person, 'Username:', _username ?? 'N/A'),
                    _buildInfoRow(theme, Icons.email, 'Email:', _email ?? 'N/A'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(theme, 'Telegram Notifications'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _telegramChatIdController,
                      decoration: const InputDecoration(
                        labelText: 'Your Telegram Chat ID',
                        hintText: 'Enter your numeric Chat ID',
                        helperText: 'Get this from bots like @userinfobot on Telegram',
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 12),
                    _isSavingTelegramId
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _updateTelegramChatId,
                            child: const Text('Save Telegram ID'),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(theme, 'Calendar Sync (Cronofy)'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: Text('Status: ${_isCronofyLoading ? "Loading..." : (_cronofyStatus ?? "Unknown")}', style: theme.textTheme.titleMedium)),
                        if (_cronofyStatus != null && _cronofyStatus != "Not Connected" && _cronofyStatus != "Error checking status" && !_isCronofyLoading)
                           TextButton(onPressed: _disconnectCronofy, child: const Text('Disconnect', style: TextStyle(color: Colors.red)))
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_cronofyStatus == "Not Connected" && _cronofyAuthorizationUrl == null && !_isCronofyLoading)
                      ElevatedButton(
                        onPressed: _initiateCronofyOAuth,
                        child: const Text('Connect to Calendar'),
                      ),
                    if (_cronofyAuthorizationUrl != null) ...[
                      const Text('1. Open this URL in your browser to authorize:'),
                      InkWell(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(_cronofyAuthorizationUrl!, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                        ),
                        onTap: () async {
                           await Clipboard.setData(ClipboardData(text: _cronofyAuthorizationUrl!));
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authorization URL copied to clipboard!')));
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _cronofyAuthCodeController,
                        decoration: const InputDecoration(
                          labelText: '2. Paste Authorization Code here',
                          hintText: 'Code from redirect URL after authorizing',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _isCronofyLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _submitCronofyAuthCode,
                              child: const Text('Submit Code & Connect'),
                            ),
                    ],
                    if (_cronofyCalendars != null && _cronofyCalendars!.isNotEmpty && (_cronofyStatus?.startsWith("Connected") ?? false) ) ...[
                        const SizedBox(height: 10),
                        Text("Synced Calendars:", style: theme.textTheme.titleSmall),
                        for (var cal in _cronofyCalendars!) Text("- ${cal['calendar_name']} (${cal['profile_name']})"),
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary)),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Text('$label ', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: theme.textTheme.titleSmall)),
        ],
      ),
    );
  }
}
