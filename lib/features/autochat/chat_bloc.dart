import 'package:autobus/common_design/app_error.dart';
import 'package:bloc/bloc.dart';
import 'package:autobus/common_design/user_facing_error.dart';
import 'chat_event.dart';
import 'chat_state.dart';
import 'services/autochat_repository.dart';
import 'models/chat_message.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final AutoChatRepository repository;

  ChatBloc(this.repository) : super(ChatInitial()) {
    on<SendMessage>(_onSendMessage);
  }

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<ChatState> emit,
  ) async {
    List<ChatMessage> current = [];
    if (state is ChatLoadSuccess) {
      current = List.from((state as ChatLoadSuccess).messages);
    }

    ChatMessage? userMsg;
    if (!event.hidden) {
      userMsg = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: event.phone,
        text: event.message,
        timestamp: DateTime.now(),
        sender: Sender.user,
        status: MessageStatus.pending,
      );
      current.add(userMsg);
      emit(ChatLoadSuccess(List.from(current)));
    } else if (current.isEmpty) {
      emit(ChatLoadInProgress());
    }

    try {
      final outbound = _webhookMessageWithOptionalImages(
        event.message,
        event.attachedProductImageUrls,
      );
      final botReply = await repository.sendMessage(
        event.phone,
        outbound,
        companyNumber: event.companyNumber,
        context: event.context,
      );

      if (event.hidden) {
        emit(ChatLoadSuccess([botReply]));
        return;
      }

      final updated = current.map((m) {
        if (m.id == userMsg!.id) return m.copyWith(status: MessageStatus.sent);
        return m;
      }).toList();

      if (botReply.text.trim().isNotEmpty) {
        updated.add(botReply);
      }
      emit(ChatLoadSuccess(updated));
    } catch (e) {
      final friendly = userFacingError(e, fallback: AppUserMessages.load);
      if (event.hidden && current.isEmpty) {
        emit(ChatLoadFailure(friendly));
        return;
      }

      final failed = current.map((m) {
        if (userMsg != null && m.id == userMsg.id) {
          return m.copyWith(status: MessageStatus.failed);
        }
        return m;
      }).toList();
      failed.add(
        ChatMessage(
          id: '${DateTime.now().millisecondsSinceEpoch}-err',
          userId: event.phone,
          text: friendly,
          timestamp: DateTime.now(),
          sender: Sender.bot,
          status: MessageStatus.sent,
        ),
      );
      emit(ChatLoadSuccess(failed));
    }
  }
}

String _webhookMessageWithOptionalImages(
  String userText,
  List<String>? imageUrls,
) {
  final trimmed = userText.trimRight();
  if (imageUrls == null || imageUrls.isEmpty) return userText;
  final cleaned = imageUrls
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (cleaned.isEmpty) return userText;
  final buf = StringBuffer(trimmed);
  buf.writeln();
  buf.writeln();
  buf.writeln('Attached media URLs (already uploaded):');
  for (final u in cleaned) {
    buf.writeln(u);
  }
  return buf.toString();
}
