/// Inbox from Chatwoot `GET /api/v1/chatwoot/inboxes` (account inboxes list).
class ChatwootInbox {
  final int id;
  final String name;
  final String kind;

  /// Autobus WhatsApp / Instagram account id used by DELETE unlink APIs.
  final String? accountId;

  const ChatwootInbox({
    required this.id,
    required this.name,
    required this.kind,
    this.accountId,
  });

  factory ChatwootInbox.fromJson(Map<String, dynamic> json) {
    return ChatwootInbox(
      id: _parseId(json['id']),
      name: (json['name'] ?? '').toString(),
      kind: _normalizeKind(json),
    );
  }

  static int _parseId(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  /// Maps Chatwoot `channel_type` (e.g. `Channel::FacebookPage`) to a short slug.
  static String _normalizeKind(Map<String, dynamic> json) {
    final channelType = (json['channel_type'] ?? '').toString();
    var raw = channelType.replaceFirst(RegExp(r'^Channel::'), '').toLowerCase();

    if (raw.contains('facebook')) return 'facebook';
    if (raw.contains('twitter') || raw.contains('tweet')) return 'twitter';
    if (raw.contains('whatsapp')) return 'whatsapp';
    if (raw.contains('linkedin')) return 'linkedin';
    if (raw.contains('instagram')) return 'instagram';
    if (raw.contains('telegram')) return 'telegram';
    if (raw.contains('line')) return 'line';
    if (raw.contains('sms')) return 'sms';
    if (raw.contains('email')) return 'email';
    if (raw.contains('webwidget') || raw.contains('website')) return 'website';
    if (raw.contains('api')) return 'api';

    final channel = json['channel'];
    if (channel is Map) {
      final nested = Map<String, dynamic>.from(channel);
      final t = (nested['type'] ?? '').toString().toLowerCase();
      if (t.isNotEmpty) return t;
    }

    return raw;
  }

  bool get isActive =>
      id > 0 || (accountId != null && accountId!.trim().isNotEmpty);
}
