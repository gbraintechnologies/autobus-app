import 'package:autobus/features/home/services/api_service.dart';
import 'package:autobus/features/agent/models/agent_models.dart';

class AgentRepository {
  final ApiService api;

  AgentRepository(this.api);

  Future<AgentTurn> sendTurn({
    String? message,
    List<AgentAttachment> attachments = const [],
    String? confirmId,
    bool? confirmed,
    String? askId,
  }) async {
    final payload = attachments
        .where((a) => (a.url ?? '').trim().isNotEmpty)
        .map((a) => a.toJson())
        .toList();
    final data = await api.sendAgentTurn(
      message: message,
      attachments: payload,
      confirmId: confirmId,
      confirmed: confirmed,
      askId: askId,
    );
    return AgentTurn.fromJson(data);
  }
}
