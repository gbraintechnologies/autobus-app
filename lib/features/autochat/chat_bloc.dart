import 'package:bloc/bloc.dart';
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
      if (event.hidden && current.isEmpty) {
        emit(ChatLoadFailure(e.toString()));
        return;
      }

      final failed = current.map((m) {
        if (userMsg != null && m.id == userMsg.id) {
          return m.copyWith(status: MessageStatus.failed);
        }
        return m;
      }).toList();
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
  buf.writeln(
    'Product image URLs (already uploaded; use these for photos / primary image when adding or updating a product):',
  );
  for (final u in cleaned) {
    buf.writeln(u);
  }
  return buf.toString();
}
