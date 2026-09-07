import 'dart:io';
import 'dart:typed_data';

import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/device_media_picker.dart';
import 'package:autobus/features/marketing/marketing_media_download.dart';
import 'package:autobus/features/marketing/platform_post_details.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

part 'digital_marketing_chat.dart';
part 'digital_marketing_compose.dart';
part 'digital_marketing_finalize.dart';

const _kPrimary = Color(0xFF1A1A2E);
const _kHeaderPurple = Color(0xFF2A1447);
const _kHeaderBorder = Color(0xFFA92FEB);
const _kNextButtonPurple = Color(0xFF2A1447);
const _kPurple = Color(0xFF6C63FF);
const _kSelectGreen = Color(0xFF22C55E);
const _kAutobusIgPrefix = 'autobus-ig-';
const _kWhatsAppStatusOutletId = 'autobus-wa-status';
const _kWhatsAppStatusGreen = Color(0xFF25D366);
const _kShareFacebookId = 'autobus-share-facebook';
const _kShareInstagramId = 'autobus-share-instagram';
const _kShareYoutubeId = 'autobus-share-youtube';
const _kShareTiktokId = 'autobus-share-tiktok';

bool _isPhoneShareOutlet(String id) {
  return id == _kWhatsAppStatusOutletId ||
      id == _kShareFacebookId ||
      id == _kShareInstagramId ||
      id == _kShareYoutubeId ||
      id == _kShareTiktokId;
}

String _phoneShareLabel(String id) {
  switch (id) {
    case _kShareFacebookId:
      return 'Facebook';
    case _kShareInstagramId:
      return 'Instagram';
    case _kShareYoutubeId:
      return 'YouTube';
    case _kShareTiktokId:
      return 'TikTok';
    case _kWhatsAppStatusOutletId:
      return 'WhatsApp Status';
    default:
      return 'Share';
  }
}

List<String> _httpLinksFrom(dynamic raw) {
  final links = <String>[];
  if (raw is! List) return links;
  for (final e in raw) {
    final s = e.toString().trim();
    if (s.startsWith('http://') || s.startsWith('https://')) {
      links.add(s);
    }
  }
  return links;
}

MarketingContentType? _marketingContentTypeFromName(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'pictures':
    case 'picture':
    case 'image':
    case 'images':
      return MarketingContentType.pictures;
    case 'videos':
    case 'video':
      return MarketingContentType.videos;
    case 'text':
    case 'caption':
    case 'copy':
      return MarketingContentType.text;
    default:
      return null;
  }
}

MarketingContentType? _marketingContentTypeFromUrl(String url) {
  final u = url.trim().toLowerCase();
  if (u.isEmpty) return null;
  if (!u.startsWith('http://') && !u.startsWith('https://')) return null;
  if (u.contains('.mp4') ||
      u.contains('.mov') ||
      u.contains('.webm') ||
      u.contains('.m4v') ||
      u.contains('.avi') ||
      u.contains('video')) {
    return MarketingContentType.videos;
  }
  if (u.contains('.jpg') ||
      u.contains('.jpeg') ||
      u.contains('.png') ||
      u.contains('.webp') ||
      u.contains('.gif') ||
      u.contains('image')) {
    return MarketingContentType.pictures;
  }
  return MarketingContentType.pictures;
}

MarketingContentType? _marketingContentTypeFromMessage(
  Map<String, dynamic> json,
  MarketingChatMessage msg,
) {
  final named = _marketingContentTypeFromName(
    (json['contentType'] ?? json['type'] ?? '').toString(),
  );
  if (named != null) return named;
  final url = (json['mediaUrl'] ?? json['generatedResult'] ?? '').toString();
  final fromUrl = _marketingContentTypeFromUrl(url);
  if (fromUrl != null) return fromUrl;
  final text = msg.text.trim().toLowerCase();
  if (text.contains('generated an image') || text.contains('added an image')) {
    return MarketingContentType.pictures;
  }
  if (text.contains('generated a video') || text.contains('added a video')) {
    return MarketingContentType.videos;
  }
  if (text.contains('added your image') ||
      text.contains('added your video')) {
    return text.contains('video')
        ? MarketingContentType.videos
        : MarketingContentType.pictures;
  }
  if (msg.contentId != null && text.isNotEmpty) {
    return MarketingContentType.text;
  }
  return null;
}

enum MarketingContentType { pictures, videos, text }

enum MediaGenState { idle, generating, ready }

enum MarketingChatRole { user, assistant }

class MarketingChatMessage {
  final String id;
  final MarketingChatRole role;
  final String text;
  final String? contentId;
  final DateTime createdAt;
  final bool isGenerating;
  final String? error;

  MarketingChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.contentId,
    DateTime? createdAt,
    this.isGenerating = false,
    this.error,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isUser => role == MarketingChatRole.user;

  MarketingChatMessage copyWith({
    String? text,
    String? contentId,
    bool? isGenerating,
    String? error,
  }) {
    return MarketingChatMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      contentId: contentId ?? this.contentId,
      createdAt: createdAt,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error,
    );
  }

  factory MarketingChatMessage.fromJson(Map<String, dynamic> json) {
    final roleRaw = (json['role'] ?? '').toString().toLowerCase();
    final cid = (json['contentId'] ?? json['content_id'] ?? '').toString();
    return MarketingChatMessage(
      id: (json['id'] ?? 'msg_${DateTime.now().microsecondsSinceEpoch}')
          .toString(),
      role: roleRaw == 'user'
          ? MarketingChatRole.user
          : MarketingChatRole.assistant,
      text: (json['text'] ?? json['content'] ?? '').toString(),
      contentId: cid.isEmpty ? null : cid,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson({MarketingContent? content}) => {
        'id': id,
        'role': isUser ? 'user' : 'assistant',
        'text': text,
        'contentId': contentId ?? content?.id,
        'createdAt': createdAt.toIso8601String(),
        if (content != null) 'contentType': content.type.name,
        if (content != null && content.hasRemoteUrl)
          'mediaUrl': content.generatedResult,
        if (content != null && content.type == MarketingContentType.text)
          'generatedText': content.displayText,
      };
}

class MarketingContent {
  static int _seq = 0;

  final String id;
  final MarketingContentType type;
  String? prompt;
  String? manualText;
  String? generatedResult;
  Uint8List? generatedBytes;
  String? localFilePath;
  MediaGenState genState = MediaGenState.idle;
  bool selectedForPost = true;

  MarketingContent(this.type, {String? id})
      : id = id ?? 'mc_${_seq++}_${DateTime.now().microsecondsSinceEpoch}';

  String get label {
    switch (type) {
      case MarketingContentType.pictures:
        return 'Image';
      case MarketingContentType.videos:
        return 'Video';
      case MarketingContentType.text:
        return 'Text';
    }
  }

  String get pageTitle {
    switch (type) {
      case MarketingContentType.pictures:
        return 'Generate or Add Image';
      case MarketingContentType.videos:
        return 'Generate or Add Video';
      case MarketingContentType.text:
        return 'Generate or Add Text';
    }
  }

  String get promptHint {
    switch (type) {
      case MarketingContentType.pictures:
        return 'Describe an image to generate';
      case MarketingContentType.videos:
        return 'Describe a video to generate';
      case MarketingContentType.text:
        return 'Describe the copy to generate';
    }
  }

  bool get hasRemoteUrl {
    final v = generatedResult?.trim() ?? '';
    return v.startsWith('http://') || v.startsWith('https://');
  }

  bool get isPostable {
    if (type == MarketingContentType.text) {
      return displayText.isNotEmpty;
    }
    if (genState != MediaGenState.ready) return false;
    if (type == MarketingContentType.pictures) {
      final hasBytes = generatedBytes != null && generatedBytes!.isNotEmpty;
      final localPath = localFilePath;
      final hasLocalFile = !kIsWeb &&
          localPath != null &&
          localPath.isNotEmpty &&
          File(localPath).existsSync();
      return hasBytes || hasLocalFile || hasRemoteUrl;
    }
    if (type == MarketingContentType.videos) {
      final hasBytes = generatedBytes != null && generatedBytes!.isNotEmpty;
      final localPath = localFilePath;
      final hasLocalFile = !kIsWeb &&
          localPath != null &&
          localPath.isNotEmpty &&
          File(localPath).existsSync();
      return hasRemoteUrl || hasLocalFile || hasBytes;
    }
    return false;
  }

  String get displayText =>
      stripAiMarkdown((manualText ?? generatedResult ?? prompt ?? '').trim());

  Map<String, dynamic> toArchiveJson() => {
        'id': id,
        'type': type.name,
        'prompt': prompt,
        'generatedResult': generatedResult,
        'manualText': manualText,
      };

  static MarketingContent? fromArchive(Map<String, dynamic> json) {
    final type = _marketingContentTypeFromName(
          (json['type'] ?? json['contentType'] ?? '').toString(),
        ) ??
        _marketingContentTypeFromUrl(
          (json['mediaUrl'] ?? json['generatedResult'] ?? '').toString(),
        );
    if (type == null) return null;
    final rawId = (json['id'] ?? json['contentId'] ?? '').toString();
    final content = MarketingContent(
      type,
      id: rawId.isEmpty ? null : rawId,
    );
    final prompt = (json['prompt'] ?? '').toString().trim();
    if (prompt.isNotEmpty) content.prompt = prompt;
    final mediaUrl =
        (json['mediaUrl'] ?? json['generatedResult'] ?? '').toString().trim();
    if (type == MarketingContentType.text) {
      final text = (json['manualText'] ??
              json['generatedText'] ??
              json['generatedResult'] ??
              '')
          .toString()
          .trim();
      if (text.isNotEmpty) {
        content.manualText = text;
        content.generatedResult = text;
      }
    } else if (mediaUrl.startsWith('http://') ||
        mediaUrl.startsWith('https://')) {
      content.generatedResult = mediaUrl;
    }
    content.genState = MediaGenState.ready;
    return content;
  }
}

class DigitalMarketingCampaign {
  String? remoteAssetId;
  final List<MarketingContent> contents;
  final List<MarketingChatMessage> messages;
  DateTime? scheduledDate;
  bool postRightAway = true;
  bool aiGenerateMetadata = true;
  final Set<String> selectedOutlets = {};

  /// Per-outlet supporting details (title, privacy, tags, …), keyed by integration id.
  final Map<String, PlatformPostDetails> outletDetails = {};

  DigitalMarketingCampaign({List<MarketingContent>? contents})
      : contents = contents ?? <MarketingContent>[],
        messages = <MarketingChatMessage>[];

  /// Rebuilds the chat + media so a saved campaign can be reviewed as it was.
  factory DigitalMarketingCampaign.fromAsset(Map<String, dynamic> asset) {
    final campaign = DigitalMarketingCampaign();
    final id = (asset['id'] ?? '').toString();
    if (id.isNotEmpty) campaign.remoteAssetId = id;

    final postiz = asset['postiz_response'];
    final postizMap = postiz is Map
        ? Map<String, dynamic>.from(postiz)
        : const <String, dynamic>{};

    final rawConv = asset['conversation'] ?? postizMap['conversation'];
    final rawContents = asset['contents'] ?? postizMap['contents'];
    final links = _httpLinksFrom(asset['content_links']);
    final usedLinks = <String>{};
    var linkCursor = 0;

    void attachUnusedLink(MarketingContent content) {
      if (content.type == MarketingContentType.text) return;
      if (content.hasRemoteUrl) {
        usedLinks.add(content.generatedResult!.trim());
        return;
      }
      while (linkCursor < links.length) {
        final url = links[linkCursor++];
        if (usedLinks.contains(url)) continue;
        usedLinks.add(url);
        content.generatedResult = url;
        content.genState = MediaGenState.ready;
        return;
      }
    }

    final contentsById = <String, MarketingContent>{};
    if (rawContents is List) {
      for (final e in rawContents) {
        if (e is! Map) continue;
        final content =
            MarketingContent.fromArchive(Map<String, dynamic>.from(e));
        if (content == null) continue;
        contentsById[content.id] = content;
        campaign.contents.add(content);
        attachUnusedLink(content);
      }
    }

    if (rawConv is List && rawConv.isNotEmpty) {
      for (final e in rawConv) {
        if (e is! Map) continue;
        final map = Map<String, dynamic>.from(e);
        var msg = MarketingChatMessage.fromJson(map);
        if (msg.isGenerating) continue;

        MarketingContent? content =
            msg.contentId != null ? contentsById[msg.contentId!] : null;
        if (content == null && !msg.isUser) {
          content = MarketingContent.fromArchive(map);
          final inferred = _marketingContentTypeFromMessage(map, msg);
          if (content == null && inferred != null) {
            content = MarketingContent(inferred, id: msg.contentId);
            if (inferred == MarketingContentType.text) {
              final text = (map['generatedText'] ?? msg.text).toString().trim();
              content.generatedResult = text;
              content.manualText = text;
            } else {
              final url = (map['mediaUrl'] ?? map['generatedResult'] ?? '')
                  .toString()
                  .trim();
              if (url.startsWith('http://') || url.startsWith('https://')) {
                content.generatedResult = url;
              }
            }
            content.genState = MediaGenState.ready;
          }
          if (content != null) {
            contentsById[content.id] = content;
            campaign.contents.add(content);
            attachUnusedLink(content);
            if (msg.contentId != content.id) {
              msg = msg.copyWith(contentId: content.id);
            }
          }
        } else if (content != null) {
          attachUnusedLink(content);
        }
        campaign.messages.add(msg);
      }
    } else {
      final caption = (asset['marketing_text'] ?? '').toString().trim();
      if (caption.isNotEmpty) {
        final textContent = MarketingContent(MarketingContentType.text);
        textContent.generatedResult = caption;
        textContent.manualText = caption;
        textContent.genState = MediaGenState.ready;
        campaign.contents.add(textContent);
        campaign.messages.add(
          MarketingChatMessage(
            id: 'archived_caption',
            role: MarketingChatRole.assistant,
            text: caption,
            contentId: textContent.id,
          ),
        );
      }
    }

    for (final url in links) {
      if (usedLinks.contains(url)) continue;
      usedLinks.add(url);
      final type = _marketingContentTypeFromUrl(url) ??
          MarketingContentType.pictures;
      final content = MarketingContent(type);
      content.generatedResult = url;
      content.genState = MediaGenState.ready;
      campaign.contents.add(content);
      campaign.messages.add(
        MarketingChatMessage(
          id: 'archived_${content.id}',
          role: MarketingChatRole.assistant,
          text: type == MarketingContentType.videos
              ? 'Generated a video from your prompt.'
              : 'Generated an image from your prompt.',
          contentId: content.id,
        ),
      );
    }

    return campaign;
  }

  List<MarketingContent> get generatedContents =>
      contents.where((c) => c.isPostable).toList();

  List<MarketingContent> get selectedContents =>
      contents.where((c) => c.selectedForPost && c.isPostable).toList();

  String get campaignCaption {
    final selectedText = selectedContents
        .where((c) => c.type == MarketingContentType.text)
        .map((c) => c.displayText)
        .where((s) => s.isNotEmpty)
        .join('\n\n');
    if (selectedText.isNotEmpty) return selectedText;
    return contents
        .where((c) => c.type == MarketingContentType.text)
        .map((c) => c.displayText)
        .where((s) => s.isNotEmpty)
        .join('\n\n');
  }

  /// Text-only transcript of the chat (user prompts + assistant copy).
  String get conversationTranscript {
    final buf = StringBuffer();
    for (final m in messages) {
      if (m.isGenerating) continue;
      if (m.isUser) {
        final t = m.text.trim();
        if (t.isNotEmpty) buf.writeln('User: $t');
        continue;
      }
      MarketingContent? content;
      if (m.contentId != null) {
        for (final c in contents) {
          if (c.id == m.contentId) {
            content = c;
            break;
          }
        }
      }
      if (content != null && content.type == MarketingContentType.text) {
        final t = content.displayText;
        if (t.isNotEmpty) buf.writeln('Assistant: $t');
      } else if (m.text.trim().isNotEmpty) {
        buf.writeln('Assistant: ${m.text.trim()}');
      }
    }
    return buf.toString().trim();
  }
}

class _MarketingScaffold extends StatelessWidget {
  final Widget child;
  final double contentHorizontalPadding;
  final Widget? headerTrailing;

  const _MarketingScaffold({
    required this.child,
    this.contentHorizontalPadding = 18,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 54,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _kHeaderPurple,
                            border: Border.all(
                              color: _kHeaderBorder,
                              width: 0.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Digital Marketing',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: _kHeaderPurple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      headerTrailing ??
                          const UserAvatar(onLightBackground: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: contentHorizontalPadding,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  /// Narrower pill used on the generate-media step.
  final bool compact;

  const _DarkButton({required this.label, this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final height = compact ? 48.0 : 74.0;
    final fontSize = compact ? 14.0 : 16.0;
    final arrowSize = compact ? 11.0 : 14.0;
    final arrowGap = compact ? 7.0 : 10.0;
    final labelArrowGap = compact ? 8.0 : 12.0;
    final hPad = compact ? 18.0 : 22.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: height,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        decoration: BoxDecoration(
          color: enabled ? _kNextButtonPurple : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(compact ? 36 : 50),
          border: Border.all(
            color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.0),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: enabled ? Colors.white : Colors.white70,
              ),
            ),
            SizedBox(width: labelArrowGap),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_forward_ios,
                  size: arrowSize,
                  color: Colors.white.withValues(alpha: enabled ? 1.0 : 0.7),
                ),
                SizedBox(width: arrowGap),
                Icon(
                  Icons.arrow_forward_ios,
                  size: arrowSize,
                  color: Colors.white.withValues(alpha: enabled ? 0.8 : 0.55),
                ),
                SizedBox(width: arrowGap),
                Icon(
                  Icons.arrow_forward_ios,
                  size: arrowSize,
                  color: Colors.white.withValues(alpha: enabled ? 0.6 : 0.4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DigitalMarketingPage extends StatelessWidget {
  final Set<MarketingContentType> initialSelected;
  final DigitalMarketingCampaign? campaign;
  final bool readOnly;

  const DigitalMarketingPage({
    super.key,
    Set<MarketingContentType>? initialSelected,
    this.campaign,
    this.readOnly = false,
  }) : initialSelected = initialSelected ?? const <MarketingContentType>{};

  @override
  Widget build(BuildContext context) {
    return _MarketingChatPage(
      campaign: campaign ?? DigitalMarketingCampaign(),
      readOnly: readOnly,
    );
  }
}

class _MarketingInlineVideoPlayer extends StatefulWidget {
  final String videoRef;

  const _MarketingInlineVideoPlayer({required this.videoRef});

  @override
  State<_MarketingInlineVideoPlayer> createState() =>
      _MarketingInlineVideoPlayerState();
}

class _MarketingInlineVideoPlayerState
    extends State<_MarketingInlineVideoPlayer> {
  VideoPlayerController? _controller;
  bool _failed = false;
  String _errorDetail = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ref = widget.videoRef.trim();
    if (ref.isEmpty) {
      if (mounted) {
        setState(() {
          _failed = true;
          _errorDetail = 'No video reference.';
        });
      }
      return;
    }

    final isNetwork = ref.startsWith('http://') || ref.startsWith('https://');

    late final VideoPlayerController c;
    if (isNetwork) {
      c = VideoPlayerController.networkUrl(
        Uri.parse(ref),
        httpHeaders: const {
          // Some CDNs / storage endpoints reject requests with no User-Agent.
          'User-Agent': 'Autobus/1.0',
        },
      );
    } else {
      if (kIsWeb) {
        if (mounted) {
          setState(() {
            _failed = true;
            _errorDetail = 'Local file playback is not supported on web.';
          });
        }
        return;
      }
      c = VideoPlayerController.file(File(ref));
    }

    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
      await c.setLooping(true);
      await c.play();
    } catch (e) {
      await c.dispose();
      if (!mounted) return;
      setState(() {
        _failed = true;
        _errorDetail = userFacingError(e);
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Could not load video.\n$_errorDetail',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 13),
          ),
        ),
      );
    }

    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      );
    }

    final ar = c.value.aspectRatio;
    final ratio = ar > 0 ? ar : 16 / 9;

    return LayoutBuilder(
      builder: (context, constraints) {
        var maxW = constraints.maxWidth;
        var maxH = constraints.maxHeight;
        if (!maxW.isFinite || maxW <= 0) maxW = 320;
        final hasBoundedH = maxH.isFinite && maxH > 0 && maxH < double.infinity;
        if (!hasBoundedH) maxH = maxW / ratio;

        var w = maxW;
        var h = w / ratio;
        if (h > maxH) {
          h = maxH;
          w = h * ratio;
        }

        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(c),
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: c,
                  builder: (context, value, _) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (value.isPlaying) {
                          c.pause();
                        } else {
                          c.play();
                        }
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(
                                alpha: value.isPlaying ? 0.0 : 0.35,
                              ),
                              Colors.black.withValues(
                                alpha: value.isPlaying ? 0.0 : 0.45,
                              ),
                            ],
                          ),
                        ),
                        child: value.isPlaying
                            ? const SizedBox.expand()
                            : const Icon(
                                Icons.play_circle_fill_rounded,
                                size: 72,
                                color: Colors.white,
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MediaSlotPreviewDialog extends StatefulWidget {
  final MarketingContent content;
  final VoidCallback? onDelete;

  const _MediaSlotPreviewDialog({
    required this.content,
    this.onDelete,
  });

  @override
  State<_MediaSlotPreviewDialog> createState() =>
      _MediaSlotPreviewDialogState();
}

class _MediaSlotPreviewDialogState extends State<_MediaSlotPreviewDialog> {
  bool _downloading = false;

  MarketingContent get content => widget.content;

  bool get _canDownload {
    if (content.genState != MediaGenState.ready) return false;
    if (content.type == MarketingContentType.pictures) {
      final hasBytes = content.generatedBytes != null;
      final localPath = content.localFilePath;
      final hasLocalFile = !kIsWeb &&
          localPath != null &&
          localPath.isNotEmpty &&
          File(localPath).existsSync();
      return hasBytes || hasLocalFile || content.hasRemoteUrl;
    }
    if (content.type == MarketingContentType.videos) {
      final remote = content.generatedResult?.trim() ?? '';
      final hasRemote =
          remote.startsWith('http://') || remote.startsWith('https://');
      final localPath = content.localFilePath;
      final hasLocalFile = !kIsWeb &&
          localPath != null &&
          localPath.isNotEmpty &&
          File(localPath).existsSync();
      final hasBytes = content.generatedBytes?.isNotEmpty ?? false;
      return hasRemote || hasLocalFile || hasBytes;
    }
    return false;
  }

  Future<void> _download() async {
    if (_downloading || !_canDownload) return;
    setState(() => _downloading = true);
    try {
      final isPicture = content.type == MarketingContentType.pictures;
      final mimeType = isPicture &&
              (content.generatedResult?.startsWith('image/') ?? false)
          ? content.generatedResult
          : null;
      final suggestedName = isPicture
          ? (content.localFilePath ?? content.generatedResult)
          : null;
      final ok = isPicture
          ? await MarketingMediaDownloader.downloadPicture(
              bytes: content.generatedBytes,
              localPath: content.localFilePath,
              mimeType: mimeType,
              suggestedName: suggestedName,
            )
          : await MarketingMediaDownloader.downloadVideo(
              remoteUrl: content.generatedResult,
              localPath: content.localFilePath,
            );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? (kIsWeb
                    ? 'Download started'
                    : 'Saved to your device')
                : 'Could not download file',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e, action: 'downloading file'))),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPicture = content.type == MarketingContentType.pictures;
    final deleteLabel = isPicture ? 'Delete image' : 'Delete video';
    final downloadLabel = isPicture ? 'Download image' : 'Download video';

    final maxPreviewHeight = MediaQuery.sizeOf(context).height * 0.55;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxPreviewHeight),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Material(
                color: Colors.black,
                child: isPicture
                    ? _buildImagePreview()
                    : _buildVideoPreview(context),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_canDownload) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _downloading ? null : _download,
                icon: _downloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(
                  downloadLabel,
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _kHeaderPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (widget.onDelete != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  color: CustColors.accentRed,
                ),
                label: Text(
                  deleteLabel,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    color: CustColors.accentRed,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: CustColors.accentRed),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    final hasBytes = content.generatedBytes != null;
    final localPath = content.localFilePath;
    final hasLocalFile =
        !kIsWeb &&
        localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync();

    final Widget image;
    if (hasBytes) {
      image = Image.memory(content.generatedBytes!, fit: BoxFit.contain);
    } else if (hasLocalFile) {
      image = Image.file(File(localPath), fit: BoxFit.contain);
    } else if (content.hasRemoteUrl) {
      image = Image.network(content.generatedResult!, fit: BoxFit.contain);
    } else {
      image = const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 48,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: image,
      ),
    );
  }

  Widget _buildVideoPreview(BuildContext context) {
    final videoRef = content.localFilePath ?? content.generatedResult ?? '';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420, minWidth: 280),
      child: _MarketingInlineVideoPlayer(videoRef: videoRef),
    );
  }
}

class _CompactCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;

  const _CompactCalendar({
    required this.focusedMonth,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onMonthChanged,
  });

  static const _months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final y = focusedMonth.year;
    final m = focusedMonth.month;
    final daysInMonth = DateUtils.getDaysInMonth(y, m);
    final firstWeekday = DateTime(y, m, 1).weekday % 7;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E0F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${_months[m]} $y',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              _CalNavBtn(
                icon: Icons.chevron_left_rounded,
                onTap: () => onMonthChanged(DateTime(y, m - 1)),
              ),
              const SizedBox(width: 4),
              _CalNavBtn(
                icon: Icons.chevron_right_rounded,
                onTap: () => onMonthChanged(DateTime(y, m + 1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final d in _days)
                Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.black38,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.15,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (_, i) {
              if (i < firstWeekday) return const SizedBox.shrink();
              final day = i - firstWeekday + 1;
              final date = DateTime(y, m, day);
              final isPast = date.isBefore(todayDate);
              final isToday = DateUtils.isSameDay(date, today);
              final isSel = selectedDay != null &&
                  DateUtils.isSameDay(date, selectedDay!);

              return GestureDetector(
                onTap: isPast ? null : () => onDaySelected(date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSel
                        ? _kSelectGreen
                        : isToday
                            ? _kSelectGreen.withValues(alpha: 0.12)
                            : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight:
                          isToday || isSel ? FontWeight.w700 : FontWeight.w500,
                      color: isSel
                          ? Colors.white
                          : isPast
                              ? Colors.black26
                              : isToday
                                  ? _kSelectGreen
                                  : Colors.black87,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CalNavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 18, color: _kHeaderPurple),
        ),
      ),
    );
  }
}

