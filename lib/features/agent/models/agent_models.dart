class AgentAttachment {
  final String kind;
  final String? url;
  final String? name;
  final String? mime;
  final String? localPath;

  const AgentAttachment({
    required this.kind,
    this.url,
    this.name,
    this.mime,
    this.localPath,
  });

  Map<String, dynamic> toJson() => {
    'kind': kind,
    if (url != null && url!.isNotEmpty) 'url': url,
    if (name != null && name!.isNotEmpty) 'name': name,
    if (mime != null && mime!.isNotEmpty) 'mime': mime,
  };

  AgentAttachment copyWith({String? url}) => AgentAttachment(
    kind: kind,
    url: url ?? this.url,
    name: name,
    mime: mime,
    localPath: localPath,
  );

  factory AgentAttachment.fromJson(Map<String, dynamic> json) => AgentAttachment(
    kind: (json['kind'] ?? 'file').toString(),
    url: json['url']?.toString(),
    name: json['name']?.toString(),
    mime: json['mime']?.toString(),
  );
}

class AgentAskChoice {
  final String id;
  final String label;

  const AgentAskChoice({required this.id, required this.label});

  factory AgentAskChoice.fromJson(Map<String, dynamic> json) => AgentAskChoice(
    id: (json['id'] ?? '').toString(),
    label: (json['label'] ?? json['id'] ?? '').toString(),
  );
}

class AgentAskSpec {
  final String id;
  final String kind;
  final String prompt;
  final List<String> accept;
  final List<AgentAskChoice> choices;

  const AgentAskSpec({
    required this.id,
    required this.kind,
    required this.prompt,
    this.accept = const [],
    this.choices = const [],
  });

  factory AgentAskSpec.fromJson(Map<String, dynamic> json) {
    final rawChoices = json['choices'];
    final rawAccept = json['accept'];
    return AgentAskSpec(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? 'text').toString(),
      prompt: (json['prompt'] ?? '').toString(),
      accept: [
        if (rawAccept is List)
          for (final item in rawAccept)
            item.toString(),
      ],
      choices: [
        if (rawChoices is List)
          for (final item in rawChoices)
            if (item is Map)
              AgentAskChoice.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

class AgentConfirmSpec {
  final String id;
  final String title;
  final String summary;
  final String tool;
  final Map<String, dynamic> payload;

  const AgentConfirmSpec({
    required this.id,
    required this.title,
    required this.summary,
    required this.tool,
    this.payload = const {},
  });

  factory AgentConfirmSpec.fromJson(Map<String, dynamic> json) {
    final raw = json['payload'];
    return AgentConfirmSpec(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Go ahead?').toString(),
      summary: (json['summary'] ?? '').toString(),
      tool: (json['tool'] ?? '').toString(),
      payload: raw is Map ? Map<String, dynamic>.from(raw) : const {},
    );
  }
}

class AgentTurn {
  final String message;
  final String turnType;
  final bool usedLlm;
  final AgentAskSpec? ask;
  final AgentConfirmSpec? confirm;
  final List<AgentAttachment> attachments;

  const AgentTurn({
    required this.message,
    this.turnType = 'reply',
    this.usedLlm = false,
    this.ask,
    this.confirm,
    this.attachments = const [],
  });

  factory AgentTurn.fromJson(Map<String, dynamic> json) {
    final askRaw = json['ask'];
    final confirmRaw = json['confirm'];
    final attachRaw = json['attachments'];
    return AgentTurn(
      message: (json['message'] ?? json['reply'] ?? json['text'] ?? '')
          .toString(),
      turnType: (json['turn_type'] ?? 'reply').toString(),
      usedLlm: json['used_llm'] == true,
      ask: askRaw is Map
          ? AgentAskSpec.fromJson(Map<String, dynamic>.from(askRaw))
          : null,
      confirm: confirmRaw is Map
          ? AgentConfirmSpec.fromJson(Map<String, dynamic>.from(confirmRaw))
          : null,
      attachments: [
        if (attachRaw is List)
          for (final item in attachRaw)
            if (item is Map)
              AgentAttachment.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

enum AgentBubbleKind { user, assistant, confirm, ask }

class AgentBubble {
  final String id;
  final AgentBubbleKind kind;
  final String text;
  final DateTime timestamp;
  final List<AgentAttachment> attachments;
  final AgentAskSpec? ask;
  final AgentConfirmSpec? confirm;
  final bool resolved;
  final bool failed;

  const AgentBubble({
    required this.id,
    required this.kind,
    required this.text,
    required this.timestamp,
    this.attachments = const [],
    this.ask,
    this.confirm,
    this.resolved = false,
    this.failed = false,
  });

  AgentBubble copyWith({bool? resolved, bool? failed}) => AgentBubble(
    id: id,
    kind: kind,
    text: text,
    timestamp: timestamp,
    attachments: attachments,
    ask: ask,
    confirm: confirm,
    resolved: resolved ?? this.resolved,
    failed: failed ?? this.failed,
  );
}
