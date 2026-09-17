import 'package:autobus/common_design/app_error.dart';
import 'package:autobus/features/agent/agent_event.dart';
import 'package:autobus/features/agent/agent_repository.dart';
import 'package:autobus/features/agent/agent_state.dart';
import 'package:autobus/features/agent/models/agent_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AgentBloc extends Bloc<AgentEvent, AgentViewState> {
  final AgentRepository repository;

  AgentBloc(this.repository) : super(const AgentViewState()) {
    on<AgentStarted>(_onStarted);
    on<AgentSubmit>(_onSubmit);
    on<AgentConfirm>(_onConfirm);
  }

  Future<void> _onStarted(
    AgentStarted event,
    Emitter<AgentViewState> emit,
  ) async {
    if (state.bubbles.isNotEmpty) return;
    emit(
      AgentViewState(
        bubbles: [
          AgentBubble(
            id: 'welcome',
            kind: AgentBubbleKind.assistant,
            text:
                'I am the AI running your business. Speak or type what you want done — I will ask when I need a photo, a video, or your go-ahead.',
            timestamp: DateTime.now(),
          ),
        ],
      ),
    );
  }

  Future<void> _onSubmit(
    AgentSubmit event,
    Emitter<AgentViewState> emit,
  ) async {
    final text = event.message.trim();
    if (text.isEmpty && event.attachments.isEmpty) return;

    final userBubble = AgentBubble(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: AgentBubbleKind.user,
      text: text.isEmpty ? _attachmentLabel(event.attachments) : text,
      timestamp: DateTime.now(),
      attachments: event.attachments,
    );
    final bubbles = _resolveAsks([
      ...state.bubbles,
      userBubble,
    ], event.askId);
    emit(
      state.copyWith(
        bubbles: bubbles,
        working: true,
        clearError: true,
        clearAsk: event.askId != null,
      ),
    );

    try {
      final turn = await repository.sendTurn(
        message: text.isEmpty ? null : text,
        attachments: event.attachments,
        askId: event.askId,
      );
      emit(_applyTurn(state.copyWith(bubbles: bubbles, working: false), turn));
    } catch (e) {
      emit(
        state.copyWith(
          bubbles: [
            ...bubbles,
            AgentBubble(
              id: '${userBubble.id}-err',
              kind: AgentBubbleKind.assistant,
              text: userFacingError(e, action: 'talking to your AI'),
              timestamp: DateTime.now(),
              failed: true,
            ),
          ],
          working: false,
          error: userFacingError(e, action: 'talking to your AI'),
        ),
      );
    }
  }

  Future<void> _onConfirm(
    AgentConfirm event,
    Emitter<AgentViewState> emit,
  ) async {
    final bubbles = [
      for (final b in state.bubbles)
        if (b.confirm?.id == event.confirmId) b.copyWith(resolved: true) else b,
    ];
    emit(
      state.copyWith(
        bubbles: bubbles,
        working: true,
        clearError: true,
        clearConfirm: true,
      ),
    );
    try {
      final turn = await repository.sendTurn(
        confirmId: event.confirmId,
        confirmed: event.approved,
      );
      emit(_applyTurn(state.copyWith(bubbles: bubbles, working: false), turn));
    } catch (e) {
      emit(
        state.copyWith(
          bubbles: [
            ...bubbles,
            AgentBubble(
              id: '${event.confirmId}-err',
              kind: AgentBubbleKind.assistant,
              text: userFacingError(e, action: 'talking to your AI'),
              timestamp: DateTime.now(),
              failed: true,
            ),
          ],
          working: false,
        ),
      );
    }
  }

  AgentViewState _applyTurn(AgentViewState current, AgentTurn turn) {
    final bubbles = [...current.bubbles];
    if (turn.message.trim().isNotEmpty ||
        (turn.attachments.isNotEmpty && turn.confirm == null)) {
      bubbles.add(
        AgentBubble(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          kind: AgentBubbleKind.assistant,
          text: turn.message.trim(),
          timestamp: DateTime.now(),
          attachments: turn.confirm == null ? turn.attachments : const [],
        ),
      );
    }
    AgentAskSpec? ask;
    AgentConfirmSpec? confirm;
    if (turn.ask != null) {
      ask = turn.ask;
      bubbles.add(
        AgentBubble(
          id: 'ask-${turn.ask!.id}',
          kind: AgentBubbleKind.ask,
          text: turn.ask!.prompt,
          timestamp: DateTime.now(),
          ask: turn.ask,
        ),
      );
    }
    if (turn.confirm != null) {
      confirm = turn.confirm;
      bubbles.add(
        AgentBubble(
          id: 'confirm-${turn.confirm!.id}',
          kind: AgentBubbleKind.confirm,
          text: turn.confirm!.summary,
          timestamp: DateTime.now(),
          confirm: turn.confirm,
          attachments: turn.attachments,
        ),
      );
    }
    return current.copyWith(
      bubbles: bubbles,
      working: false,
      pendingAsk: ask,
      pendingConfirm: confirm,
      clearAsk: ask == null,
      clearConfirm: confirm == null,
      clearError: true,
    );
  }

  List<AgentBubble> _resolveAsks(List<AgentBubble> bubbles, String? askId) {
    if (askId == null) return bubbles;
    return [
      for (final b in bubbles)
        if (b.ask?.id == askId) b.copyWith(resolved: true) else b,
    ];
  }

  String _attachmentLabel(List<AgentAttachment> items) {
    if (items.isEmpty) return 'Attachment';
    if (items.length == 1) {
      final item = items.first;
      return item.name?.trim().isNotEmpty == true
          ? item.name!
          : 'Attached ${item.kind}';
    }
    return 'Attached ${items.length} files';
  }
}
