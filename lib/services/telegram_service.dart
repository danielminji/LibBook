import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for sending messages via the Telegram Bot API.
///
/// Requires a Telegram Bot Token for sending messages and can use a specific
/// Admin Chat ID for direct admin notifications via the [notifyAdmin] method.
///
/// Bot tokens and Admin Chat ID are initialized via the constructor. If not provided,
/// placeholders are used, and message sending capabilities will be disabled
/// (logging a message to the console instead).
class TelegramService {
  /// The Telegram Bot API token.
  /// IMPORTANT: In a real app, this should come from a secure configuration.
  final String _botToken;

  /// The chat ID for sending notifications directly to administrators.
  /// IMPORTANT: In a real app, this should come from a secure configuration.
  final String _adminChatId;

  /// Creates an instance of [TelegramService].
  ///
  /// - [botToken]: Optional. The Telegram Bot API token. If `null` or empty,
  ///   a placeholder is used, and the service will not be able to send messages.
  /// - [adminChatId]: Optional. The specific chat ID for admin notifications. If `null` or empty,
  ///   a placeholder is used, and [notifyAdmin] will not be able to send messages.
  TelegramService({String? botToken, String? adminChatId})
      : _botToken = botToken ?? 'YOUR_TELEGRAM_BOT_TOKEN_PLACEHOLDER',
        _adminChatId = adminChatId ?? 'YOUR_ADMIN_CHAT_ID_PLACEHOLDER';

  /// Sends a message to a specified Telegram chat ID using the Telegram Bot API.
  ///
  /// Messages are sent with `parse_mode: 'Markdown'` to allow for basic text formatting.
  ///
  /// Before attempting to send, it checks if the bot token and chat ID are configured
  /// (i.e., not placeholders or empty). If not configured, it prints a message to the console
  /// and returns `false`.
  ///
  /// - [chatId]: The target chat ID (user or group) to send the message to.
  /// - [message]: The text message to send. Supports Markdown formatting.
  ///
  /// Returns `true` if the message was sent successfully (HTTP status code 200),
  /// `false` otherwise (e.g., configuration issue, network error, API error).
  /// Logs details to the console in case of errors or failures.
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
          'parse_mode': 'Markdown',
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

  /// A convenience method to send a notification message to the pre-configured admin chat ID.
  ///
  /// Checks if the admin chat ID is configured before attempting to send.
  /// If not configured, it prints a message to the console and returns `false`.
  ///
  /// - [message]: The message content to send to the admin. Supports Markdown.
  ///
  /// Returns `true` if the message was sent successfully to the admin, `false` otherwise.
  Future<bool> notifyAdmin(String message) async {
    if (_adminChatId == 'YOUR_ADMIN_CHAT_ID_PLACEHOLDER' || _adminChatId.isEmpty) {
      print('Admin Chat ID is not configured. Cannot send admin notification.');
      return false;
    }
    return await sendMessage(_adminChatId, message);
  }
}
