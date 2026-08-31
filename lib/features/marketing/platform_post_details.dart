/// Per-outlet supporting details collected before publish (Postiz settings).
class PlatformPostDetails {
  /// Caption for this outlet. Empty = use campaign text.
  String caption;

  // —— YouTube ——
  String youtubeTitle;
  /// `public` | `unlisted` | `private`
  String youtubeVisibility;
  /// Comma-separated tags.
  String youtubeTagsCsv;
  /// `yes` | `no`
  String madeForKids;

  // —— TikTok ——
  String tiktokTitle;
  String tiktokPrivacy;
  bool tiktokDuet;
  bool tiktokStitch;
  bool tiktokComment;
  bool tiktokBrandContent;
  bool tiktokBrandOrganic;
  bool tiktokMadeWithAi;

  // —— Instagram ——
  /// `post` | `story`
  String instagramPostType;
  /// Comma-separated usernames (without @).
  String instagramCollaboratorsCsv;

  PlatformPostDetails({
    this.caption = '',
    this.youtubeTitle = '',
    this.youtubeVisibility = 'public',
    this.youtubeTagsCsv = '',
    this.madeForKids = 'no',
    this.tiktokTitle = '',
    this.tiktokPrivacy = 'SELF_ONLY',
    this.tiktokDuet = true,
    this.tiktokStitch = true,
    this.tiktokComment = true,
    this.tiktokBrandContent = false,
    this.tiktokBrandOrganic = false,
    this.tiktokMadeWithAi = false,
    this.instagramPostType = 'post',
    this.instagramCollaboratorsCsv = '',
  });

  factory PlatformPostDetails.fromCampaignCaption(String campaignCaption) {
    final firstLine = _firstNonEmptyLine(campaignCaption);
    return PlatformPostDetails(
      caption: campaignCaption,
      youtubeTitle: firstLine.length > 100
          ? '${firstLine.substring(0, 97)}...'
          : firstLine,
      tiktokTitle: firstLine.length > 90
          ? firstLine.substring(0, 90)
          : firstLine,
    );
  }

  static String _firstNonEmptyLine(String content) {
    for (final line in content.split(RegExp(r'[\r\n]+'))) {
      final t = line.trim();
      if (t.isNotEmpty) return t;
    }
    return 'Marketing post';
  }
}

/// Which settings sections to show for a Postiz / Autobus outlet identifier.
enum PlatformDetailsKind { youtube, tiktok, instagram, generic }

PlatformDetailsKind platformDetailsKindFor(String identifier) {
  switch (identifier.toLowerCase()) {
    case 'youtube':
      return PlatformDetailsKind.youtube;
    case 'tiktok':
      return PlatformDetailsKind.tiktok;
    case 'instagram':
    case 'instagram-standalone':
      return PlatformDetailsKind.instagram;
    default:
      return PlatformDetailsKind.generic;
  }
}

List<Map<String, String>> parsePostizTagsCsv(String? csv) {
  if (csv == null || csv.trim().isEmpty) return [];
  final out = <Map<String, String>>[];
  for (final part in csv.split(',')) {
    final t = part.trim();
    if (t.isEmpty) continue;
    out.add({'value': t, 'label': t});
  }
  return out;
}

List<Map<String, String>> parseInstagramCollaboratorsCsv(String? csv) {
  if (csv == null || csv.trim().isEmpty) return [];
  final out = <Map<String, String>>[];
  for (final part in csv.split(',')) {
    var t = part.trim();
    if (t.startsWith('@')) t = t.substring(1).trim();
    if (t.isEmpty) continue;
    out.add({'label': t});
  }
  return out;
}
