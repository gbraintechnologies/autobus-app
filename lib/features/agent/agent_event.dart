import 'package:equatable/equatable.dart';
import 'package:autobus/features/agent/models/agent_models.dart';

abstract class AgentEvent extends Equatable {
  const AgentEvent();
  @override
  List<Object?> get props => [];
}

class AgentStarted extends AgentEvent {
  const AgentStarted();
}

class AgentSubmit extends AgentEvent {
  final String message;
  final List<AgentAttachment> attachments;
  final String? askId;

  const AgentSubmit({
    this.message = '',
    this.attachments = const [],
    this.askId,
  });

  @override
  List<Object?> get props => [message, attachments, askId];
}

class AgentConfirm extends AgentEvent {
  final String confirmId;
  final bool approved;

  const AgentConfirm({required this.confirmId, required this.approved});

  @override
  List<Object?> get props => [confirmId, approved];
}
