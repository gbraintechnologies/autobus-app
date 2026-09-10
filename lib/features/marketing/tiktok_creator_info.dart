import 'package:autobus/features/marketing/platform_post_details.dart';

const kTikTokMusicUsageUrl =
    'https://www.tiktok.com/legal/page/global/music-usage-confirmation/en';
const kTikTokBrandedContentPolicyUrl =
    'https://www.tiktok.com/legal/page/global/bc-policy/en';

const kTikTokConsentMusic =
    "By posting, you agree to TikTok's Music Usage Confirmation";
const kTikTokConsentBranded =
    "By posting, you agree to TikTok's Branded Content Policy and Music Usage Confirmation";
const kTikTokProcessingNotice =
    'After you finish publishing, it may take a few minutes for the content to process and be visible on your TikTok profile.';
const kTikTokDisclosureHint =
    'You need to indicate if your content promotes yourself, a third party, or both.';
const kTikTokBrandedPrivateHint =
    'Branded content visibility cannot be set to private.';

const kTikTokPrivacyLabels = <String, String>{
  'PUBLIC_TO_EVERYONE': 'Everyone',
  'MUTUAL_FOLLOW_FRIENDS': 'Friends',
  'FOLLOWER_OF_CREATOR': 'Followers',
  'SELF_ONLY': 'Only me',
};

class TikTokCreatorInfo {
  final String nickname;
  final String username;
  final String avatarUrl;
  final List<String> privacyLevelOptions;
  final bool commentDisabled;
  final bool duetDisabled;
  final bool stitchDisabled;
  final int? maxVideoPostDurationSec;
  final bool canPost;
  final String cannotPostReason;

  const TikTokCreatorInfo({
    required this.nickname,
    required this.username,
    required this.avatarUrl,
    required this.privacyLevelOptions,
    required this.commentDisabled,
    required this.duetDisabled,
    required this.stitchDisabled,
    required this.canPost,
    this.maxVideoPostDurationSec,
    this.cannotPostReason = '',
  });

  String get displayName {
    if (nickname.trim().isNotEmpty) return nickname.trim();
    if (username.trim().isNotEmpty) return username.trim();
    return 'TikTok';
  }

  String get handle {
    final u = username.trim();
    if (u.isEmpty) return '';
    return u.startsWith('@') ? u : '@$u';
  }

  factory TikTokCreatorInfo.fromJson(Map<String, dynamic> json) {
    final options = <String>[];
    final raw = json['privacy_level_options'];
    if (raw is List) {
      for (final item in raw) {
        final key = item.toString().trim();
        if (key.isNotEmpty && !options.contains(key)) options.add(key);
      }
    }
    return TikTokCreatorInfo(
      nickname: (json['creator_nickname'] ?? '').toString(),
      username: (json['creator_username'] ?? '').toString(),
      avatarUrl: (json['creator_avatar_url'] ?? '').toString(),
      privacyLevelOptions: options,
      commentDisabled: json['comment_disabled'] == true,
      duetDisabled: json['duet_disabled'] == true,
      stitchDisabled: json['stitch_disabled'] == true,
      maxVideoPostDurationSec: json['max_video_post_duration_sec'] is num
          ? (json['max_video_post_duration_sec'] as num).toInt()
          : int.tryParse('${json['max_video_post_duration_sec'] ?? ''}'),
      canPost: json['can_post'] != false,
      cannotPostReason: (json['cannot_post_reason'] ?? '').toString(),
    );
  }
}

class TikTokPublishStatus {
  final String status;
  final bool processing;
  final bool complete;
  final bool failed;
  final String message;

  const TikTokPublishStatus({
    required this.status,
    required this.processing,
    required this.complete,
    required this.failed,
    required this.message,
  });

  factory TikTokPublishStatus.fromJson(Map<String, dynamic> json) {
    return TikTokPublishStatus(
      status: (json['status'] ?? '').toString(),
      processing: json['processing'] == true,
      complete: json['complete'] == true,
      failed: json['failed'] == true,
      message: (json['message'] ?? kTikTokProcessingNotice).toString(),
    );
  }
}

String tiktokConsentText(PlatformPostDetails d) {
  return d.tiktokBrandContent ? kTikTokConsentBranded : kTikTokConsentMusic;
}

String? tiktokDirectPostBlockReason({
  required PlatformPostDetails details,
  TikTokCreatorInfo? info,
  required bool isPhotoPost,
  Duration? videoDuration,
  bool creatorInfoLoading = false,
}) {
  if (creatorInfoLoading) {
    return 'Loading TikTok account info…';
  }
  if (info == null) {
    return 'Could not load TikTok account info. Reconnect TikTok and try again.';
  }
  if (!info.canPost) {
    return info.cannotPostReason.isNotEmpty
        ? info.cannotPostReason
        : 'This TikTok account cannot post right now. Try again later.';
  }
  if (details.tiktokPrivacy.trim().isEmpty ||
      (info.privacyLevelOptions.isNotEmpty &&
          !info.privacyLevelOptions.contains(details.tiktokPrivacy))) {
    return 'Select a privacy status';
  }
  if (!isPhotoPost &&
      info.maxVideoPostDurationSec != null &&
      videoDuration != null &&
      videoDuration.inSeconds > info.maxVideoPostDurationSec!) {
    return 'This video is longer than TikTok allows '
        '(${info.maxVideoPostDurationSec} seconds). Choose a shorter clip.';
  }
  if (details.tiktokDiscloseCommercial &&
      !details.tiktokBrandOrganic &&
      !details.tiktokBrandContent) {
    return kTikTokDisclosureHint;
  }
  if (details.tiktokBrandContent && details.tiktokPrivacy == 'SELF_ONLY') {
    return kTikTokBrandedPrivateHint;
  }
  return null;
}

String commercialLabelPrompt(PlatformPostDetails d) {
  if (d.tiktokBrandContent) {
    return "Your photo/video will be labeled as 'Paid partnership'";
  }
  if (d.tiktokBrandOrganic) {
    return "Your photo/video will be labeled as 'Promotional content'";
  }
  return '';
}
