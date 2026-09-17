import 'package:autobus/features/marketing/models/postiz_integration.dart';
import 'package:autobus/features/marketing/platform_post_details.dart';

String _titleFromContent(String content) {
  final lines = content.split(RegExp(r'[\r\n]+'));
  for (final line in lines) {
    final t = line.trim();
    if (t.isNotEmpty) {
      return t.length > 100 ? '${t.substring(0, 97)}...' : t;
    }
  }
  return 'Marketing post';
}

String _clampTitle(String title, int max) {
  final t = title.trim();
  if (t.isEmpty) return '';
  return t.length > max ? t.substring(0, max) : t;
}

/// Postiz YouTube `checkValidity` only accepts a path containing `mp4`.
bool postizMediaLooksLikeVideo(String url) {
  final path = url.split('?').first.toLowerCase();
  return path.endsWith('.mp4') ||
      path.endsWith('.mov') ||
      path.endsWith('.m4v') ||
      path.endsWith('.webm') ||
      path.contains('.mp4');
}

String postizDateIso(DateTime utc) {
  final s = utc.toUtc().toIso8601String();
  final match = RegExp(r'^(.+\.\d{3})\d*(Z)?$').firstMatch(s);
  if (match != null) {
    return '${match.group(1)}${match.group(2) ?? 'Z'}';
  }
  return s.endsWith('Z') ? s : '${s}Z';
}

/// `settings` for Postiz Public API `POST /api/public/v1/posts`.
/// See https://docs.postiz.com/public-api/posts/create
Map<String, dynamic> postizSettingsForIntegration(
  PostizIntegration integration,
  String titleFallback, {
  PlatformPostDetails? details,
}) {
  final t = integration.identifier.toLowerCase();
  switch (t) {
    case 'instagram':
    case 'instagram-standalone':
      return {
        '__type': t,
        'post_type': details?.instagramPostType == 'story' ? 'story' : 'post',
        'is_trial_reel': false,
        'collaborators': parseInstagramCollaboratorsCsv(
          details?.instagramCollaboratorsCsv,
        ),
      };
    case 'x':
      return {
        '__type': 'x',
        'who_can_reply_post': 'everyone',
        'community': '',
      };
    case 'youtube':
      final rawTitle = details?.youtubeTitle.trim().isNotEmpty == true
          ? details!.youtubeTitle
          : titleFallback;
      final title = _clampTitle(rawTitle, 100);
      final visibility = details?.youtubeVisibility ?? 'public';
      final allowed = {'public', 'unlisted', 'private'};
      return {
        '__type': 'youtube',
        'title': title.isEmpty ? titleFallback : title,
        'type': allowed.contains(visibility) ? visibility : 'public',
        'selfDeclaredMadeForKids':
            details?.madeForKids == 'yes' ? 'yes' : 'no',
        'tags': parsePostizTagsCsv(details?.youtubeTagsCsv),
      };
    case 'tiktok':
      final rawTitle = details?.tiktokTitle.trim().isNotEmpty == true
          ? details!.tiktokTitle
          : titleFallback;
      final privacy = details?.tiktokPrivacy ?? '';
      const allowedPrivacy = {
        'PUBLIC_TO_EVERYONE',
        'MUTUAL_FOLLOW_FRIENDS',
        'FOLLOWER_OF_CREATOR',
        'SELF_ONLY',
      };
      final disclose = details?.tiktokDiscloseCommercial == true;
      return {
        '__type': 'tiktok',
        'title': _clampTitle(rawTitle, 90),
        'privacy_level':
            allowedPrivacy.contains(privacy) ? privacy : 'SELF_ONLY',
        'duet': details?.tiktokDuet ?? false,
        'stitch': details?.tiktokStitch ?? false,
        'comment': details?.tiktokComment ?? false,
        'autoAddMusic': 'no',
        'brand_content_toggle': disclose && (details?.tiktokBrandContent ?? false),
        'brand_organic_toggle': disclose && (details?.tiktokBrandOrganic ?? false),
        'video_made_with_ai': details?.tiktokMadeWithAi ?? false,
        'content_posting_method': 'DIRECT_POST',
      };
    case 'medium':
      return {
        '__type': 'medium',
        'title': titleFallback,
        'subtitle': '',
        'tags': <Map<String, dynamic>>[],
      };
    case 'devto':
      return {
        '__type': 'devto',
        'title': titleFallback,
        'tags': <Map<String, dynamic>>[],
      };
    case 'hashnode':
      return {
        '__type': 'hashnode',
        'title': titleFallback,
        'subtitle': '',
        'publication': '',
        'tags': <Map<String, dynamic>>[],
      };
    case 'wordpress':
      return {
        '__type': 'wordpress',
        'title': titleFallback,
        'type': 'post',
      };
    default:
      return {'__type': t};
  }
}

/// Body for Autobus `POST /api/v1/social/postiz/posts` (passthrough to Postiz).
Map<String, dynamic> buildPostizCreatePostPayload({
  required Iterable<PostizIntegration> selectedIntegrations,
  required String content,
  required List<String> mediaUrls,
  required bool postRightAway,
  DateTime? scheduledUtc,
  Map<String, PlatformPostDetails>? outletDetails,
}) {
  final trimmed = content.trim();
  final bodyText = trimmed.isEmpty ? ' ' : trimmed;

  final scheduleMode = !postRightAway && scheduledUtc != null;
  final type = scheduleMode ? 'schedule' : 'now';
  final DateTime dateUtc;
  if (scheduleMode) {
    dateUtc = scheduledUtc.toUtc();
  } else {
    dateUtc = DateTime.now().toUtc();
  }
  final dateIso = postizDateIso(dateUtc);

  final imageBlocks = <Map<String, dynamic>>[
    for (var i = 0; i < mediaUrls.length; i++)
      {'id': 'media_$i', 'path': mediaUrls[i]},
  ];

  final posts = <Map<String, dynamic>>[];
  for (final integration in selectedIntegrations) {
    final details = outletDetails?[integration.id];
    final perCaption = details?.caption.trim();
    final postContent =
        (perCaption != null && perCaption.isNotEmpty) ? perCaption : bodyText;
    final titleFallback = _titleFromContent(postContent);
    posts.add({
      'integration': {'id': integration.id},
      'value': [
        {
          'content': postContent,
          'image': imageBlocks,
        },
      ],
      'settings': postizSettingsForIntegration(
        integration,
        titleFallback,
        details: details,
      ),
    });
  }

  return {
    'type': type,
    'date': dateIso,
    'shortLink': false,
    'tags': <Map<String, dynamic>>[],
    'posts': posts,
  };
}
