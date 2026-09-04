import 'package:equatable/equatable.dart';
import 'package:autobus/features/agent/models/agent_models.dart';

class AgentViewState extends Equatable {
  final List<AgentBubble> bubbles;
  final bool working;
  final String? error;
  final AgentAskSpec? pendingAsk;
  final AgentConfirmSpec? pendingConfirm;

  const AgentViewState({
    this.bubbles = const [],
    this.working = false,
    this.error,
    this.pendingAsk,
    this.pendingConfirm,
  });

  AgentViewState copyWith({
    List<AgentBubble>? bubbles,
    bool? working,
    String? error,
    AgentAskSpec? pendingAsk,
    AgentConfirmSpec? pendingConfirm,
    bool clearError = false,
    bool clearAsk = false,
    bool clearConfirm = false,
  }) {
    return AgentViewState(
      bubbles: bubbles ?? this.bubbles,
      working: working ?? this.working,
      error: clearError ? null : (error ?? this.error),
      pendingAsk: clearAsk ? null : (pendingAsk ?? this.pendingAsk),
      pendingConfirm: clearConfirm
          ? null
          : (pendingConfirm ?? this.pendingConfirm),
    );
  }

  @override
  List<Object?> get props => [
    bubbles,
    working,
    error,
    pendingAsk,
    pendingConfirm,
  ];
}
