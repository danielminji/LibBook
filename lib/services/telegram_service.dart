import 'dart:convert';
import 'package:http/http.dart' as http;

class TelegramService {
  // IMPORTANT: In a real app, BOT_TOKEN should come from a secure configuration.
  // For this subtask, we'll use a placeholder.
  final String _botToken;
  // Placeholder for Admin Chat ID for new booking notifications
  final String _adminChatId;

  TelegramService({String? botToken, String? adminChatId})
      : _botToken = botToken ?? 'YOUR_TELEGRAM_BOT_TOKEN_PLACEHOLDER',
        _adminChatId = adminChatId ?? 'YOUR_ADMIN_CHAT_ID_PLACEHOLDER';

  Future<bool> sendMessage(String chatId, String message) async {
    if (_botToken == 'YOUR_TELEGRAM_BOT_TOKEN_PLACEHOLDER' || _botToken.isEmpty) {
      print('Telegram Bot Token is not configured. Cannot send message.');
      return false;
    }
    if (chatId.isEmpty) {
      print('Chat ID is empty. Cannot send message.');
      return false;
    }

    final String url = 'https://api.telegram.org/bot$_botToken/sendMessage';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'chat_id': chatId,
          'text': message,
          'parse_mode': 'Markdown', // Optional: for Markdown formatting
        }),
      );

      if (response.statusCode == 200) {
        print('Telegram message sent successfully to $chatId.');
        return true;
      } else {
        print('Failed to send Telegram message to $chatId. Status: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending Telegram message to $chatId: $e');
      return false;
    }
  }

  // Convenience method to notify admin (uses the pre-configured admin chat ID)
  Future<bool> notifyAdmin(String message) async {
    if (_adminChatId == 'YOUR_ADMIN_CHAT_ID_PLACEHOLDER' || _adminChatId.isEmpty) {
      print('Admin Chat ID is not configured. Cannot send admin notification.');
      return false;
    }
    return await sendMessage(_adminChatId, message);
  }
}
