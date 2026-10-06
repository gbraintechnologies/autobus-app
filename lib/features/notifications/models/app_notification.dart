class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool read;

  /// Target screen from backend `data.flutterpage` (e.g. Profile, Security).
  final String? flutterPage;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.flutterPage,
  });

  String get displayText {
    if (body.trim().isNotEmpty) return body.trim();
    if (title.trim().isNotEmpty && title != 'Notification') return title.trim();
    return '';
  }

  static bool _truthy(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes' || s == 'read';
    }
    return false;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final nested = json['data'];
    final Map<String, dynamic> data = nested is Map
        ? Map<String, dynamic>.from(nested)
        : <String, dynamic>{};

    final id =
        (json['id'] ??
                json['_id'] ??
                json['notification_id'] ??
                json['notificationId'] ??
                '')
            .toString();

    final typeStr = (json['type'] ?? data['type'] ?? '').toString();
    final title =
        (data['title'] ??
                data['subject'] ??
                json['title'] ??
                json['subject'] ??
                (typeStr.isNotEmpty ? typeStr : null) ??
                'Notification')
            .toString();

    final body =
        (data['description'] ??
                data['body'] ??
                data['message'] ??
                data['content'] ??
                json['body'] ??
                json['message'] ??
                json['content'] ??
                json['detail'] ??
                '')
            .toString();

    final flutterPage =
        (data['flutterpage'] ??
                data['flutter_page'] ??
                data['flutterPage'] ??
                '')
            .toString()
            .trim();

    final createdAt = _parseDate(
      json['created_at'] ??
          json['createdAt'] ??
          json['timestamp'] ??
          json['time'] ??
          data['created_at'],
    );

    final status = (json['status'] ?? data['status'] ?? '')
        .toString()
        .toUpperCase();
    final readAt = _parseDate(json['read_at'] ?? json['readAt']);
    final read =
        status == 'READ' ||
        readAt != null ||
        _truthy(json['read'] ?? json['is_read'] ?? json['isRead']);

    return AppNotification(
      id: id.isEmpty ? title.hashCode.toString() : id,
      title: title,
      body: body,
      createdAt: createdAt,
      read: read,
      flutterPage: flutterPage.isEmpty ? null : flutterPage,
    );
  }

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      read: read ?? this.read,
      flutterPage: flutterPage,
    );
  }
}
