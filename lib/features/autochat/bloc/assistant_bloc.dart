import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autobus/common_design/app_error.dart';
import 'package:autobus/common_design/plain_ai_text.dart';
import 'package:autobus/config/app_config.dart';
import 'assistant_event.dart';
import 'assistant_state.dart';

class AssistantBloc extends Bloc<AssistantEvent, AssistantState> {
  AssistantBloc() : super(AssistantInitial()) {
    on<SendCommandEvent>(_onSendCommand);
  }

  Future<void> _onSendCommand(
    SendCommandEvent event,
    Emitter<AssistantState> emit,
  ) async {
    emit(AssistantLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      String phone = '';
      if (userJson != null) {
        final user = jsonDecode(userJson) as Map<String, dynamic>;
        phone = (user['phone'] ?? user['phoneNumber'] ?? '').toString();
      }

      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/v1/nlu/process'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'message': event.command}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = (data['response'] ?? data['message'] ?? '').toString();
        emit(AssistantSuccess(response: stripAiMarkdown(reply)));
      } else {
        emit(
          AssistantError(
            message: AppException.fromResponse(
              response,
              action: 'sending your message',
            ).userMessage,
          ),
        );
      }
    } catch (e) {
      emit(
        AssistantError(
          message: userFacingError(e, action: 'sending your message'),
        ),
      );
    }
  }
}
