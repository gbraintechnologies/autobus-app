class OwnerResource {
  final String id;
  final String kind;
  final String title;
  final String summary;
  final String url;
  final String youtubeId;
  final String thumbnailUrl;
  final String industry;
  final String sourceName;
  final String body;

  const OwnerResource({
    required this.id,
    required this.kind,
    required this.title,
    this.summary = '',
    this.url = '',
    this.youtubeId = '',
    this.thumbnailUrl = '',
    this.industry = '',
    this.sourceName = '',
    this.body = '',
  });

  bool get isVideo => kind == 'video';

  String get watchUrl {
    if (url.startsWith('http')) return url;
    if (youtubeId.isNotEmpty) return 'https://www.youtube.com/watch?v=$youtubeId';
    return url;
  }

  factory OwnerResource.fromJson(Map<String, dynamic> json) {
    final url = (json['url'] ?? '').toString();
    var youtubeId = (json['youtubeId'] ?? '').toString();
    if (youtubeId.isEmpty) {
      youtubeId = youtubeIdFrom(url) ?? '';
    }
    var thumbnail = (json['thumbnailUrl'] ?? '').toString();
    if (thumbnail.isEmpty && youtubeId.isNotEmpty) {
      thumbnail = 'https://i.ytimg.com/vi/$youtubeId/hqdefault.jpg';
    }
    return OwnerResource(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      url: url,
      youtubeId: youtubeId,
      thumbnailUrl: thumbnail,
      industry: (json['industry'] ?? '').toString(),
      sourceName: (json['sourceName'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
    );
  }
}

class OwnerFeed {
  final String industry;
  final List<OwnerResource> videos;
  final List<OwnerResource> news;
  final List<OwnerResource> guides;
  final List<OwnerResource> others;

  const OwnerFeed({
    this.industry = '',
    this.videos = const [],
    this.news = const [],
    this.guides = const [],
    this.others = const [],
  });

  factory OwnerFeed.fromJson(Map<String, dynamic> json) {
    return OwnerFeed(
      industry: (json['industry'] ?? '').toString(),
      videos: _list(json['videos']),
      news: _list(json['news']),
      guides: _list(json['guides']),
      others: _list(json['others']),
    );
  }

  static List<OwnerResource> _list(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => OwnerResource.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.title.trim().isNotEmpty)
        .toList();
  }
}

String? youtubeIdFrom(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  if (RegExp(r'^[\w-]{11}$').hasMatch(value)) return value;

  final uri = Uri.tryParse(value);
  if (uri == null) return null;

  if (uri.host.contains('youtu.be')) {
    final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    return id.length == 11 ? id : null;
  }

  final queryId = uri.queryParameters['v'];
  if (queryId != null && queryId.length == 11) return queryId;

  for (final marker in ['embed', 'shorts', 'live']) {
    final index = uri.pathSegments.indexOf(marker);
    if (index >= 0 && index + 1 < uri.pathSegments.length) {
      final id = uri.pathSegments[index + 1];
      if (id.length == 11) return id;
    }
  }
  return null;
}
