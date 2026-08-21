import 'dart:convert';

import 'package:autobus/common_design/app_error.dart';
import 'package:autobus/common_design/plain_ai_text.dart';
import 'package:autobus/config/app_config.dart';
import 'package:autobus/features/home/services/api_service.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

class AutoChatRepository {
  final http.Client client;
  final ApiService? apiService;

  AutoChatRepository({http.Client? client, this.apiService})
    : client = client ?? http.Client();

  Uri get _endpoint => Uri.parse(
        '${AppConfig.backendUrl}/api/v1/webhooks/start-dialog',
      );

  static bool isOwnerCopilotContext(String context) {
    switch (context.trim().toLowerCase()) {
      case 'interactions_agent':
      case 'my_ai_agent':
      case 'my_ai':
      case 'my ai':
        return true;
      default:
        return false;
    }
  }

  /// Sends a message and returns the bot reply as a ChatMessage.
  ///
  /// Owner copilot contexts (My AI) use the authenticated intelligence API.
  /// Other agents still use the public start-dialog webhook.
  ///
  /// [companyNumber] is the merchant ``users.id`` (`company_number` on the API).
  /// When empty, the server uses legacy ``userid``-only routing.
  Future<ChatMessage> sendMessage(
    String phone,
    String message, {
    required String companyNumber,
    required String context,
  }) async {
    if (isOwnerCopilotContext(context)) {
      return _sendOwnerCopilot(phone, message);
    }
    return _sendWebhook(phone, message, companyNumber: companyNumber, context: context);
  }

  Future<ChatMessage> _sendOwnerCopilot(String phone, String message) async {
    final api = apiService;
    if (api == null) {
      throw AppException.user(
        'Your AI is not available in this session. Please sign in again.',
      );
    }
    final replyText = await api.sendIntelligenceChat(message);
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: phone,
      text: stripAiMarkdown(replyText),
      timestamp: DateTime.now(),
      sender: Sender.bot,
      status: MessageStatus.sent,
    );
  }

  Future<ChatMessage> _sendWebhook(
    String phone,
    String message, {
    required String companyNumber,
    required String context,
  }) async {
    final trimmedCompany = companyNumber.trim();
    final body = trimmedCompany.isEmpty
        ? {
            'userid': phone,
            'message': message,
            'context': context,
          }
        : {
            'customer_number': phone,
            'company_number': trimmedCompany,
            'message': message,
            'context': context,
          };

    final res = await client.post(
      _endpoint,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw AppException.fromResponse(res, action: 'sending your message');
    }

    final data = jsonDecode(res.body);
    final replyText =
        (data['message'] ??
                data['reply'] ??
                data['response'] ??
                data['text'] ??
                '')
            .toString();

    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: phone,
      text: stripAiMarkdown(replyText),
      timestamp: DateTime.now(),
      sender: Sender.bot,
      status: MessageStatus.sent,
    );
  }
}
