import 'dart:io';
import 'dart:typed_data';

import 'package:autobus/barrel.dart';
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

const _kPrimary = Color(0xFF1A1A2E);
const _kHeaderPurple = Color(0xFF2A1447);
const _kHeaderBorder = Color(0xFFA92FEB);
const _kNextButtonPurple = Color(0xFF2A1447);
const _kPurple = Color(0xFF6C63FF);
const _kSelectGreen = Color(0xFF22C55E);
const _kAutobusIgPrefix = 'autobus-ig-';
const _kWhatsAppIdentifier = 'whatsapp';

enum MarketingContentType { pictures, videos, text }

enum MediaGenState { idle, generating, ready }

class MarketingContent {
  final MarketingContentType type;
  String? prompt;
  String? manualText;
  String? generatedResult;
  Uint8List? generatedBytes;
  String? localFilePath;
  MediaGenState genState = MediaGenState.idle;

  MarketingContent(this.type);

  String get label {
    switch (type) {
      case MarketingContentType.pictures:
        return 'Pictures';
      case MarketingContentType.videos:
        return 'Videos';
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
        return 'Describe the image content to generate';
      case MarketingContentType.videos:
        return 'Describe the video content to generate';
      case MarketingContentType.text:
        return 'Describe the text content to generate';
    }
  }
}

class DigitalMarketingCampaign {
  final List<MarketingContent> contents;
  DateTime? scheduledDate;
  bool postRightAway = false;
  final Set<String> selectedOutlets = {};

  /// Per-outlet supporting details (title, privacy, tags, …), keyed by integration id.
  final Map<String, PlatformPostDetails> outletDetails = {};

  DigitalMarketingCampaign(this.contents);

  String get campaignCaption {
    return contents
        .where((c) => c.type == MarketingContentType.text)
        .map((c) => c.manualText ?? c.generatedResult ?? '')
        .where((s) => s.isNotEmpty)
        .join('\n\n');
  }
}

class _MarketingScaffold extends StatelessWidget {
  final Widget child;
  final double contentHorizontalPadding;

  const _MarketingScaffold({
    required this.child,
    this.contentHorizontalPadding = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 42),

            /// Header to match Chatbot / Orders
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: SizedBox(
                height: 54,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
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
                    ),
                    Text(
                      'Digital Marketing',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: _kHeaderPurple,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: const UserAvatar(onLightBackground: true),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 26),
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

class _PromptBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onAttach;
  final VoidCallback? onGenerate;
  final IconData generateIcon;
  final int minLines;
  final int maxLines;

  const _PromptBar({
    required this.controller,
    required this.hint,
    this.onAttach,
    this.onGenerate,
    this.generateIcon = Icons.auto_awesome,
    this.minLines = 2,
    this.maxLines = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            onSubmitted: (_) => onGenerate?.call(),
            style: GoogleFonts.montserrat(fontSize: 14, height: 1.45),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.black38,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (onAttach != null)
                GestureDetector(
                  onTap: onAttach,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CustColors.logodeep.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: CustColors.logodeep,
                      size: 22,
                    ),
                  ),
                )
              else
                const SizedBox(width: 38),
              GestureDetector(
                onTap: onGenerate,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: onGenerate != null
                        ? CustColors.logodeep.withValues(alpha: 0.14)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    generateIcon,
                    color: onGenerate != null
                        ? CustColors.logodeep
                        : Colors.black38,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DigitalMarketingPage extends StatefulWidget {
  final Set<MarketingContentType> initialSelected;

  const DigitalMarketingPage({
    super.key,
    Set<MarketingContentType>? initialSelected,
  }) : initialSelected = initialSelected ?? const <MarketingContentType>{};

  @override
  State<DigitalMarketingPage> createState() => _DigitalMarketingPageState();
}

class _DigitalMarketingPageState extends State<DigitalMarketingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final selected = widget.initialSelected.isNotEmpty
          ? widget.initialSelected
          : <MarketingContentType>{MarketingContentType.pictures};

      final contents = MarketingContentType.values
          .where(selected.contains)
          .map((t) => MarketingContent(t))
          .toList();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _GenerateMediaPage(
            campaign: DigitalMarketingCampaign(contents),
            segmentStartIndex: 0,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return _MarketingScaffold(
      child: const Center(child: AutobusLoadingIndicator()),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final MarketingContentType type;
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.type,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 148,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _kPrimary : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: iconColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerateMediaPage extends StatefulWidget {
  final DigitalMarketingCampaign campaign;

  /// Index of the first item in this step’s contiguous block (pictures, videos, or text).
  final int segmentStartIndex;

  const _GenerateMediaPage({
    required this.campaign,
    required this.segmentStartIndex,
  });

  @override
  State<_GenerateMediaPage> createState() => _GenerateMediaPageState();
}

class _GenerateMediaPageState extends State<_GenerateMediaPage> {
  final TextEditingController _promptCtrl = TextEditingController();
  final TextEditingController _textBodyCtrl = TextEditingController();
  final FocusNode _textBodyFocus = FocusNode();

  final ApiService _apiService = ApiService(
    httpClient: SessionAwareHttpClient(tokenService: TokenService()),
  );

  late int _selectedSlotIndex;

  MarketingContentType get _segmentType =>
      widget.campaign.contents[widget.segmentStartIndex].type;

  MarketingContent get _activeContent =>
      widget.campaign.contents[_selectedSlotIndex];

  bool get _isText => _segmentType == MarketingContentType.text;

  List<int> _segmentIndices() {
    final t = _segmentType;
    final out = <int>[];
    for (
      var i = widget.segmentStartIndex;
      i < widget.campaign.contents.length &&
          widget.campaign.contents[i].type == t;
      i++
    ) {
      out.add(i);
    }
    return out;
  }

  /// First index after this segment’s block (pictures / videos / text).
  int _segmentEndExclusive() {
    return widget.segmentStartIndex + _segmentIndices().length;
  }

  bool get _isMultiSlotMedia =>
      !_isText &&
      (_segmentType == MarketingContentType.pictures ||
          _segmentType == MarketingContentType.videos);

  /// Text step: unchanged. Picture/video: every slot in this segment must have
  /// uploaded or generated media, and nothing may still be generating.
  bool get _canGoNext {
    if (_isText) return true;
    final indices = _segmentIndices();
    final anyGenerating = indices.any(
      (i) => widget.campaign.contents[i].genState == MediaGenState.generating,
    );
    if (anyGenerating) return false;
    for (final i in indices) {
      if (!_slotHasViewableMedia(widget.campaign.contents[i])) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _selectedSlotIndex = widget.segmentStartIndex;
    _promptCtrl.addListener(() => setState(() {}));
    _textBodyCtrl.addListener(() {
      if (_isText) _activeContent.manualText = _textBodyCtrl.text;
    });
    _textBodyFocus.addListener(() => setState(() {}));

    if (_activeContent.manualText != null) {
      _textBodyCtrl.text = _activeContent.manualText!;
    }
    if (_promptCtrl.text.isEmpty &&
        (_activeContent.prompt?.isNotEmpty ?? false)) {
      _promptCtrl.text = _activeContent.prompt!;
    }
  }

  @override
  void dispose() {
    _textBodyFocus.dispose();
    _promptCtrl.dispose();
    _textBodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;

    final slot = _activeContent;
    setState(() {
      slot.prompt = prompt;
      slot.genState = MediaGenState.generating;
      slot.generatedBytes = null;
      slot.localFilePath = null;
      if (!_isText) slot.generatedResult = null;
    });
    _promptCtrl.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      String userId = '';
      if (userJson != null) {
        final user = jsonDecode(userJson) as Map<String, dynamic>;
        userId = (user['id'] ?? user['phone'] ?? '').toString();
      }

      String result = '';

      if (slot.type == MarketingContentType.pictures) {
        final response = await _apiService.generateImageMedia(
          userId: userId,
          prompt: prompt,
        );
        final rawBase64 = (response['image_base64'] ?? '').toString().trim();
        if (rawBase64.isEmpty) {
          throw Exception('Image generation returned no image data');
        }
        final cleanedBase64 = rawBase64.contains(',')
            ? rawBase64.substring(rawBase64.indexOf(',') + 1)
            : rawBase64;
        slot.generatedBytes = await compute(base64Decode, cleanedBase64);
        slot.generatedResult = response['mime_type']?.toString();
      } else if (slot.type == MarketingContentType.videos) {
        // store=true: server saves MP4 to object storage so ExoPlayer can stream it.
        // Raw Google Veo URLs often fail on Android (ExoPlaybackException / source error).
        final response = await _apiService.generateVideoMedia(
          userId: userId,
          prompt: prompt,
          store: true,
        );
        result = (response['stored_url'] ?? response['video_url'] ?? '')
            .toString()
            .trim();
        if (result.isEmpty) {
          throw Exception('Video generation returned no video URL');
        }
        slot.generatedResult = result;
      } else {
        result = await _apiService.generateAgentContent(
          userId: userId,
          prompt: prompt,
          agentName: 'marketing',
        );
        slot.generatedResult = result;
        _textBodyCtrl.text = result;
      }

      if (!mounted) return;
      setState(() {
        slot.genState = MediaGenState.ready;
        if (_isText) _textBodyCtrl.text = result;
      });
      if (slot.type == MarketingContentType.videos) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showMediaPreview(_selectedSlotIndex);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => slot.genState = MediaGenState.idle);

      final message = e is Exception ? e.toString() : 'Media generation failed';

      // Show a friendly snackbar explaining the backend limitation.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.contains('GOOGLE_API_KEY')
                ? 'Image/Video generation is unavailable: server missing configuration.'
                : 'Media generation failed: $message',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<ImageSource?> _chooseMediaSource({required bool isPicture}) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isPicture
                    ? Icons.photo_camera_outlined
                    : Icons.videocam_outlined,
              ),
              title: Text(isPicture ? 'Take photo' : 'Record video'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  String _mediaExtension(String nameOrPath, {required String fallback}) {
    final dot = nameOrPath.lastIndexOf('.');
    if (dot <= 0 || dot == nameOrPath.length - 1) return fallback;
    final ext = nameOrPath.substring(dot).toLowerCase();
    if (ext.length > 5) return fallback;
    return ext;
  }

  /// Gallery picks can return a path before the native copy finishes. Wait for
  /// a readable file, then fall back to copying bytes into a temp file.
  Future<String?> _ensureLocalMediaFile(
    String path, {
    required String preferredName,
    required String fallbackExt,
  }) async {
    final file = File(path);
    for (var i = 0; i < 40; i++) {
      try {
        if (await file.exists() && await file.length() > 0) {
          return path;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 125));
    }

    try {
      final bytes = await XFile(path).readAsBytes();
      if (bytes.isEmpty) return null;
      final ext = _mediaExtension(preferredName, fallback: fallbackExt);
      final dest = File(
        '${Directory.systemTemp.path}/autobus_media_'
        '${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await dest.writeAsBytes(bytes, flush: true);
      if (await dest.exists() && await dest.length() > 0) {
        return dest.path;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _pickAndAttachMedia() async {
    if (_isText) return;
    if (_activeContent.genState == MediaGenState.generating) return;

    final isPicture = _activeContent.type == MarketingContentType.pictures;

    // Web has no reliable camera/gallery filesystem paths — keep FilePicker.
    if (kIsWeb) {
      await _pickAndAttachMediaWithFilePicker(isPicture: isPicture);
      return;
    }

    final source = await _chooseMediaSource(isPicture: isPicture);
    if (source == null || !mounted) return;

    final slot = _activeContent;
    final previousState = slot.genState;
    final previousBytes = slot.generatedBytes;
    final previousPath = slot.localFilePath;
    final previousResult = slot.generatedResult;

    setState(() {
      slot.genState = MediaGenState.generating;
    });

    try {
      final picker = ImagePicker();
      if (isPicture) {
        final picked = await picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: 2000,
        );
        if (picked == null) {
          if (!mounted) return;
          setState(() {
            slot.genState = previousState;
            slot.generatedBytes = previousBytes;
            slot.localFilePath = previousPath;
            slot.generatedResult = previousResult;
          });
          return;
        }

        final bytes = await picked.readAsBytes();
        if (bytes.isEmpty) {
          throw Exception('Selected image was empty.');
        }

        final stablePath = await _ensureLocalMediaFile(
          picked.path,
          preferredName: picked.name,
          fallbackExt: '.jpg',
        );

        if (!mounted) return;
        setState(() {
          slot.generatedBytes = bytes;
          slot.localFilePath = stablePath ?? picked.path;
          slot.generatedResult = picked.name;
          slot.genState = MediaGenState.ready;
        });
        return;
      }

      final picked = await picker.pickVideo(source: source);
      if (picked == null) {
        if (!mounted) return;
        setState(() {
          slot.genState = previousState;
          slot.generatedBytes = previousBytes;
          slot.localFilePath = previousPath;
          slot.generatedResult = previousResult;
        });
        return;
      }

      String? stablePath;
      final pickedPath = picked.path.trim();
      if (pickedPath.isNotEmpty) {
        stablePath = await _ensureLocalMediaFile(
          pickedPath,
          preferredName: picked.name,
          fallbackExt: '.mp4',
        );
      }
      if (stablePath == null) {
        final bytes = await picked.readAsBytes();
        if (bytes.isEmpty) {
          throw Exception('Unable to open selected video.');
        }
        final ext = _mediaExtension(picked.name, fallback: '.mp4');
        final dest = File(
          '${Directory.systemTemp.path}/autobus_media_'
          '${DateTime.now().millisecondsSinceEpoch}$ext',
        );
        await dest.writeAsBytes(bytes, flush: true);
        if (!await dest.exists() || await dest.length() == 0) {
          throw Exception('Unable to open selected video.');
        }
        stablePath = dest.path;
      }

      if (!mounted) return;
      setState(() {
        slot.generatedBytes = null;
        slot.localFilePath = stablePath;
        // Keep generatedResult for remote/AI URLs only — local path lives in
        // localFilePath so publish/view checks don't treat a path as an URL.
        slot.generatedResult = null;
        slot.genState = MediaGenState.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        slot.genState = previousState;
        slot.generatedBytes = previousBytes;
        slot.localFilePath = previousPath;
        slot.generatedResult = previousResult;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPicture
                ? 'Unable to load selected image. Please try again.'
                : 'Unable to open selected video. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _pickAndAttachMediaWithFilePicker({
    required bool isPicture,
  }) async {
    final allowedExtensions = isPicture
        ? <String>['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp']
        : <String>['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'];

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
      withData: true,
    );

    if (!mounted || result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final path = file.path?.trim();
    Uint8List? bytes = file.bytes;

    if (isPicture) {
      if ((bytes == null || bytes.isEmpty) &&
          path != null &&
          path.isNotEmpty &&
          !kIsWeb) {
        try {
          bytes = await File(path).readAsBytes();
        } catch (_) {
          bytes = null;
        }
      }

      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to load selected image. Please try again.'),
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _activeContent.generatedBytes = bytes;
        _activeContent.localFilePath = path;
        _activeContent.generatedResult = file.name;
        _activeContent.genState = MediaGenState.ready;
      });
      return;
    }

    if ((bytes == null || bytes.isEmpty) &&
        path != null &&
        path.isNotEmpty &&
        !kIsWeb) {
      final stablePath = await _ensureLocalMediaFile(
        path,
        preferredName: file.name,
        fallbackExt: '.mp4',
      );
      if (stablePath != null) {
        if (!mounted) return;
        setState(() {
          _activeContent.generatedBytes = null;
          _activeContent.localFilePath = stablePath;
          _activeContent.generatedResult = null;
          _activeContent.genState = MediaGenState.ready;
        });
        return;
      }
    }

    if (bytes != null && bytes.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _activeContent.generatedBytes = bytes;
        _activeContent.localFilePath = path;
        _activeContent.generatedResult = null;
        _activeContent.genState = MediaGenState.ready;
      });
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to open selected video. Please try again.'),
      ),
    );
  }

  void _selectSlot(int index) {
    if (!_isMultiSlotMedia) return;
    final busy = _segmentIndices().any(
      (i) => widget.campaign.contents[i].genState == MediaGenState.generating,
    );
    if (busy) return;
    setState(() {
      _selectedSlotIndex = index;
      _promptCtrl.text = _activeContent.prompt ?? '';
    });
  }

  bool _isSlotEmpty(MarketingContent content) {
    if (content.genState == MediaGenState.idle) return true;
    if (content.genState == MediaGenState.ready &&
        !_slotHasViewableMedia(content)) {
      return true;
    }
    return false;
  }

  int? _firstEmptySlotIndex() {
    for (final i in _segmentIndices()) {
      if (_isSlotEmpty(widget.campaign.contents[i])) return i;
    }
    return null;
  }

  void _addAnotherMediaSlot() {
    if (!_isMultiSlotMedia) return;
    final busy = _segmentIndices().any(
      (i) => widget.campaign.contents[i].genState == MediaGenState.generating,
    );
    if (busy) return;

    final emptyIndex = _firstEmptySlotIndex();
    if (emptyIndex != null) {
      setState(() {
        _selectedSlotIndex = emptyIndex;
        _promptCtrl.text = _activeContent.prompt ?? '';
      });
      return;
    }

    setState(() {
      final insertAt = _segmentEndExclusive();
      widget.campaign.contents.insert(insertAt, MarketingContent(_segmentType));
      _selectedSlotIndex = insertAt;
      _promptCtrl.clear();
    });
  }

  bool _isRemoteMediaUrl(String? value) {
    final v = value?.trim() ?? '';
    return v.startsWith('http://') || v.startsWith('https://');
  }

  bool _slotHasViewableMedia(MarketingContent content) {
    if (content.genState != MediaGenState.ready) return false;
    if (content.type == MarketingContentType.pictures) {
      final hasBytes = content.generatedBytes != null;
      final localPath = content.localFilePath;
      final hasLocalFile =
          !kIsWeb &&
          localPath != null &&
          localPath.isNotEmpty &&
          File(localPath).existsSync();
      return hasBytes || hasLocalFile;
    }
    if (content.type == MarketingContentType.videos) {
      final hasRemote = _isRemoteMediaUrl(content.generatedResult);
      final hasBytes =
          content.generatedBytes != null && content.generatedBytes!.isNotEmpty;
      final localPath = content.localFilePath;
      final hasLocalFile =
          !kIsWeb &&
          localPath != null &&
          localPath.isNotEmpty &&
          File(localPath).existsSync();
      return hasRemote || hasLocalFile || hasBytes;
    }
    return false;
  }

  void _onSlotTap(int index) {
    _selectSlot(index);
    if (_slotHasViewableMedia(widget.campaign.contents[index])) {
      _showMediaPreview(index);
    }
  }

  Future<void> _showMediaPreview(int index) async {
    final content = widget.campaign.contents[index];
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialogContext) => _MediaSlotPreviewDialog(
        content: content,
        onDelete: () {
          Navigator.of(dialogContext).pop();
          _deleteSlot(index);
        },
      ),
    );
  }

  void _clearSlotMedia(MarketingContent slot) {
    slot.genState = MediaGenState.idle;
    slot.generatedBytes = null;
    slot.localFilePath = null;
    slot.generatedResult = null;
    slot.prompt = null;
  }

  void _deleteSlot(int index) {
    if (!_isMultiSlotMedia) return;
    final busy = _segmentIndices().any(
      (i) => widget.campaign.contents[i].genState == MediaGenState.generating,
    );
    if (busy) return;

    final indices = _segmentIndices();
    if (!indices.contains(index)) return;

    setState(() {
      final slot = widget.campaign.contents[index];
      if (indices.length == 1 || slot.genState == MediaGenState.idle) {
        _clearSlotMedia(slot);
        if (_selectedSlotIndex == index) {
          _promptCtrl.clear();
        }
        return;
      }

      widget.campaign.contents.removeAt(index);
      final newIndices = _segmentIndices();
      if (newIndices.isEmpty) {
        _selectedSlotIndex = widget.segmentStartIndex;
      } else if (!newIndices.contains(_selectedSlotIndex)) {
        final fallback = index < _selectedSlotIndex
            ? _selectedSlotIndex - 1
            : newIndices.last;
        _selectedSlotIndex = newIndices.contains(fallback)
            ? fallback
            : newIndices.first;
      }
      _promptCtrl.text = _activeContent.prompt ?? '';
    });
  }

  void _goNext() {
    if (_isText) {
      _activeContent.manualText = _textBodyCtrl.text;
    }

    final nextStart = _segmentEndExclusive();
    if (nextStart < widget.campaign.contents.length) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _GenerateMediaPage(
            campaign: widget.campaign,
            segmentStartIndex: nextStart,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _SchedulePage(campaign: widget.campaign),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canGenerate =
        _promptCtrl.text.trim().isNotEmpty &&
        _activeContent.genState != MediaGenState.generating;
    // Keyboard shrinks the column; the tall prompt bar then crowds the body
    // field. Hide it while editing so typed text stays visible.
    final editingBodyText = _isText && _textBodyFocus.hasFocus;

    return _MarketingScaffold(
      contentHorizontalPadding: 10,
      child: Column(
        children: [
          Text(
            widget.campaign.contents[widget.segmentStartIndex].pageTitle,
            style: GoogleFonts.montserrat(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 20),

          if (_isText)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildPreviewBox(),
                ),
              ),
            )
          else
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: _buildMediaSlotsRow(),
                ),
              ),
            ),

          if (!editingBodyText) ...[
            _PromptBar(
              controller: _promptCtrl,
              hint: _activeContent.promptHint,
              onAttach: _isText ? null : _pickAndAttachMedia,
              onGenerate: canGenerate ? _generate : null,
              generateIcon: Icons.auto_awesome,
            ),
            const SizedBox(height: 16),
          ],
          _DarkButton(
            label: 'Next',
            compact: true,
            onTap: _canGoNext ? _goNext : null,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPreviewBox() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _textBodyCtrl,
            focusNode: _textBodyFocus,
            maxLines: null,
            expands: true,
            style: GoogleFonts.montserrat(fontSize: 14, color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'Type Text Here...',
              hintStyle: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.black38,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
        if (_activeContent.genState == MediaGenState.generating)
          _GeneratingOverlay(label: _activeContent.label),
      ],
    );
  }

  Widget _buildMediaSlotsRow() {
    final indices = _segmentIndices();
    final hasEmptySlot = indices.any(
      (i) => _isSlotEmpty(widget.campaign.contents[i]),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _segmentType == MarketingContentType.pictures
              ? 'Tap a slot to select. Tap an image to view or delete it.'
              : 'Tap a slot to select. Tap a video to view or delete it.',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(fontSize: 11, color: Colors.black38),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < indices.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    _MediaSlotThumbCard(
                      content: widget.campaign.contents[indices[i]],
                      selected: indices[i] == _selectedSlotIndex,
                      onTap: () => _onSlotTap(indices[i]),
                    ),
                  ],
                  if (!hasEmptySlot) ...[
                    if (indices.isNotEmpty) const SizedBox(width: 10),
                    _AddAnotherMediaSlotCard(
                      type: _segmentType,
                      onTap: _addAnotherMediaSlot,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaSlotThumbCard extends StatelessWidget {
  final MarketingContent content;
  final bool selected;
  final VoidCallback onTap;

  static const _w = 96.0;
  static const _h = 112.0;

  const _MediaSlotThumbCard({
    required this.content,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _w,
        height: _h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? _kHeaderBorder
                : CustColors.mainCol.withValues(alpha: 0.2),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: CustColors.mainCol.withValues(
                alpha: selected ? 0.12 : 0.06,
              ),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: _thumbFill(),
      ),
    );
  }

  Widget _thumbFill() {
    final isPicture = content.type == MarketingContentType.pictures;
    switch (content.genState) {
      case MediaGenState.idle:
        return ColoredBox(
          color: CustColors.mainCol.withValues(alpha: 0.06),
          child: Center(
            child: Icon(
              isPicture
                  ? Icons.add_photo_alternate_outlined
                  : Icons.video_call_outlined,
              color: CustColors.logodeep.withValues(alpha: 0.7),
              size: 34,
            ),
          ),
        );
      case MediaGenState.generating:
        return ColoredBox(
          color: CustColors.mainCol.withValues(alpha: 0.08),
          child: Center(child: const AutobusLoadingIndicator(size: 26)),
        );
      case MediaGenState.ready:
        if (isPicture) {
          final hasBytes = content.generatedBytes != null;
          final localPath = content.localFilePath;
          final hasLocalFile =
              !kIsWeb &&
              localPath != null &&
              localPath.isNotEmpty &&
              File(localPath).existsSync();
          if (hasBytes || hasLocalFile) {
            return hasBytes
                ? Image.memory(
                    content.generatedBytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                : Image.file(
                    File(localPath!),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  );
          }
        }
        if (!isPicture) {
          final remote = content.generatedResult?.trim() ?? '';
          final hasRemote =
              remote.startsWith('http://') || remote.startsWith('https://');
          final hasLocal = content.localFilePath?.trim().isNotEmpty ?? false;
          final hasBytes = content.generatedBytes?.isNotEmpty ?? false;
          if (hasRemote || hasLocal || hasBytes) {
            return ColoredBox(
              color: CustColors.logodeep.withValues(alpha: 0.1),
              child: Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 40,
                  color: CustColors.logodeep,
                ),
              ),
            );
          }
        }
        return ColoredBox(
          color: CustColors.logodeep.withValues(alpha: 0.1),
          child: Center(
            child: Icon(
              Icons.check_rounded,
              color: CustColors.logodeep,
              size: 34,
            ),
          ),
        );
    }
  }
}

/// Plays a generated (remote) or uploaded (local) video inside the app.
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
        _errorDetail = e.toString();
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
  final VoidCallback onDelete;

  const _MediaSlotPreviewDialog({
    required this.content,
    required this.onDelete,
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
      return hasBytes || hasLocalFile;
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
        SnackBar(content: Text('Download failed: $e')),
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

    final image = hasBytes
        ? Image.memory(content.generatedBytes!, fit: BoxFit.contain)
        : Image.file(File(localPath!), fit: BoxFit.contain);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: hasBytes || hasLocalFile
            ? image
            : const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
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

class _AddAnotherMediaSlotCard extends StatelessWidget {
  final MarketingContentType type;
  final VoidCallback onTap;

  const _AddAnotherMediaSlotCard({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPicture = type == MarketingContentType.pictures;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _MediaSlotThumbCard._w,
        height: _MediaSlotThumbCard._h,
        decoration: BoxDecoration(
          color: CustColors.mainCol.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CustColors.mainCol.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 36,
              color: CustColors.logodeep,
            ),
            const SizedBox(height: 6),
            Text(
              isPicture ? 'Add image' : 'Add video',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: CustColors.mainCol.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdlePreview extends StatelessWidget {
  final MarketingContent content;
  final VoidCallback? onUpload;
  final bool compact;

  const _IdlePreview({
    required this.content,
    this.onUpload,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPicture = content.type == MarketingContentType.pictures;
    final iconSize = compact ? 48.0 : 80.0;
    return GestureDetector(
      onTap: onUpload,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isPicture ? Icons.image_rounded : Icons.movie_rounded,
            size: iconSize,
            color: _kPurple,
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(
            content.label,
            style: GoogleFonts.montserrat(
              fontSize: compact ? 12 : 13,
              color: _kPurple,
            ),
          ),
          if (onUpload != null) ...[
            SizedBox(height: compact ? 6 : 10),
            Text(
              isPicture
                  ? 'Tap to upload your image'
                  : 'Tap to upload your video',
              style: GoogleFonts.montserrat(
                fontSize: compact ? 11 : 12,
                color: Colors.black45,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 4),
              Text(
                'or use + below',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  color: Colors.black26,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _GeneratingOverlay extends StatefulWidget {
  final String label;
  final bool compact;

  const _GeneratingOverlay({required this.label, this.compact = false});

  @override
  State<_GeneratingOverlay> createState() => _GeneratingOverlayState();
}

class _GeneratingOverlayState extends State<_GeneratingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _fade = Tween<double>(
    begin: 0.35,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.compact;
    return Container(
      color: Colors.white.withOpacity(0.93),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _fade,
              child: Container(
                padding: EdgeInsets.all(c ? 14 : 22),
                decoration: BoxDecoration(
                  color: _kPurple.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: c ? 30 : 44,
                  color: _kPurple,
                ),
              ),
            ),
            SizedBox(height: c ? 12 : 22),
            FadeTransition(
              opacity: _fade,
              child: Text(
                'Generating...',
                style: GoogleFonts.montserrat(
                  fontSize: c ? 15 : 18,
                  fontWeight: FontWeight.w600,
                  color: _kPrimary,
                ),
              ),
            ),
            SizedBox(height: c ? 4 : 6),
            Text(
              'Creating your ${widget.label.toLowerCase()}',
              style: GoogleFonts.montserrat(
                fontSize: c ? 11 : 13,
                color: Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyPreview extends StatelessWidget {
  final MarketingContent content;
  final bool compact;

  const _ReadyPreview({required this.content, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (content.type == MarketingContentType.pictures) {
      final hasBytes = content.generatedBytes != null;
      final localPath = content.localFilePath;
      final hasLocalFile =
          !kIsWeb &&
          localPath != null &&
          localPath.isNotEmpty &&
          File(localPath).existsSync();

      if (hasBytes || hasLocalFile) {
        final caption = (content.prompt?.trim().isNotEmpty ?? false)
            ? content.prompt!
            : (content.generatedResult ?? 'Uploaded image');

        if (compact) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Container(
                        width: double.infinity,
                        color: Colors.black,
                        child: hasBytes
                            ? Image.memory(
                                content.generatedBytes!,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              )
                            : Image.file(
                                File(localPath!),
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: hasBytes
                    ? Image.memory(
                        content.generatedBytes!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : Image.file(
                        File(localPath!),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
            ),
          ],
        );
      }
    }

    if (content.type == MarketingContentType.videos) {
      final remote = content.generatedResult?.trim() ?? '';
      final hasRemote =
          remote.startsWith('http://') || remote.startsWith('https://');
      final localPath = content.localFilePath?.trim() ?? '';
      final hasLocal = localPath.isNotEmpty;
      if (!hasRemote && !hasLocal) {
        return const SizedBox.shrink();
      }
      final videoRef = hasLocal ? localPath : remote;
      final caption = (content.prompt?.trim().isNotEmpty ?? false)
          ? content.prompt!
          : (hasRemote ? 'Generated video' : 'Uploaded video');

      if (compact) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: ColoredBox(
                      color: Colors.black,
                      child: _MarketingInlineVideoPlayer(videoRef: videoRef),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: _MarketingInlineVideoPlayer(videoRef: videoRef),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.black45,
              ),
            ),
          ),
        ],
      );
    }

    if (compact) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 32,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${content.label} ready',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              content.prompt ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: Colors.black45,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 44,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '${content.label} Ready!',
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _kPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            content.prompt ?? '',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(fontSize: 12, color: Colors.black45),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SchedulePage extends StatefulWidget {
  final DigitalMarketingCampaign campaign;
  const _SchedulePage({required this.campaign});

  @override
  State<_SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<_SchedulePage> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;
  TimeOfDay _selectedTime = TimeOfDay.now();

  DateTime? get _combinedSchedule {
    final day = _selectedDay;
    if (day == null) return null;
    return DateTime(
      day.year,
      day.month,
      day.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _kHeaderPurple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  void _proceed({bool rightAway = false}) {
    if (!rightAway && _selectedDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pick a date first, or choose Post Right Away',
            style: GoogleFonts.montserrat(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    widget.campaign.postRightAway = rightAway;
    widget.campaign.scheduledDate = rightAway ? null : _combinedSchedule;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SelectOutletPage(campaign: widget.campaign),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = _selectedTime.format(context);
    return _MarketingScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Schedule Your Post',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick a day and time, or publish immediately',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 16),
          _CompactCalendar(
            focusedMonth: _focusedMonth,
            selectedDay: _selectedDay,
            onDaySelected: (d) => setState(() => _selectedDay = d),
            onMonthChanged: (m) => setState(() => _focusedMonth = m),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F5FB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8E0F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: _kHeaderPurple,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Time  ·  $timeLabel',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      'Change',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kHeaderPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: () => _proceed(rightAway: true),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kHeaderPurple,
                side: const BorderSide(color: _kHeaderPurple, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                'Post Right Away',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _DarkButton(
            label: 'Next',
            compact: true,
            onTap: () => _proceed(),
          ),
          const SizedBox(height: 12),
        ],
      ),
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

class _SelectOutletPage extends StatefulWidget {
  final DigitalMarketingCampaign campaign;
  const _SelectOutletPage({required this.campaign});

  @override
  State<_SelectOutletPage> createState() => _SelectOutletPageState();
}

class _SelectOutletPageState extends State<_SelectOutletPage> {
  final ApiService _apiService = ApiService(
    httpClient: SessionAwareHttpClient(tokenService: TokenService()),
  );

  /// Blotato-backed accounts from `GET /social/accounts`.
  List<Map<String, dynamic>> _blotatoAccounts = [];

  /// Postiz channels + Autobus Instagram (merged for selection).
  List<PostizIntegration> _postizIntegrations = [];
  bool _loadingAccounts = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    List<PostizIntegration> postiz = [];
    List<Map<String, dynamic>> blotato = [];
    try {
      postiz = List<PostizIntegration>.from(
        await _apiService.listPostizIntegrations(),
      );
    } catch (_) {
      // Postiz-only flow: do not fail the whole screen if this call errors.
    }
    try {
      final igAccounts = await _apiService.listInstagramAccounts();
      for (final row in igAccounts) {
        final username = (row['username'] ?? '').toString().trim();
        final name = (row['name'] ?? '').toString().trim();
        final dbId = (row['id'] ?? '').toString().trim();
        final igId = (row['ig_user_id'] ?? dbId).toString();
        final label = username.isNotEmpty
            ? '@$username'
            : (name.isNotEmpty ? name : igId);
        final unlinkId = dbId.isNotEmpty ? dbId : igId;
        if (unlinkId.isEmpty) continue;
        postiz.add(
          PostizIntegration(
            id: '$_kAutobusIgPrefix$unlinkId',
            name: label.isNotEmpty ? label : 'Instagram',
            identifier: 'instagram',
            picture: (row['profile_picture_url'] ?? '').toString(),
            disabled: false,
            profile: username.isNotEmpty ? username : null,
          ),
        );
      }
    } catch (_) {
      // Autobus Instagram accounts are optional alongside Postiz.
    }
    try {
      blotato = await _apiService.getSocialAccounts();
    } catch (_) {
      // Blotato is optional when Postiz channels exist.
    }
    if (mounted) {
      setState(() {
        _postizIntegrations = postiz.where((p) => p.isActive).toList();
        _blotatoAccounts = blotato;
        _loadingAccounts = false;
      });
    }
  }

  bool get _usePostiz => _postizIntegrations.isNotEmpty;

  bool get _useBlotato => !_usePostiz && _blotatoAccounts.isNotEmpty;

  OutletOption? _outletFor(PostizIntegration p) {
    for (final o in OutletCatalog.all) {
      if (o.matchesIntegration(p)) return o;
    }
    return null;
  }

  void _goToPostDetails() {
    if (widget.campaign.selectedOutlets.isEmpty) return;
    final caption = widget.campaign.campaignCaption;
    for (final id in widget.campaign.selectedOutlets) {
      widget.campaign.outletDetails.putIfAbsent(
        id,
        () => PlatformPostDetails.fromCampaignCaption(caption),
      );
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PostDetailsPage(
          campaign: widget.campaign,
          postizIntegrations: _postizIntegrations,
          blotatoAccounts: _blotatoAccounts,
          usePostiz: _usePostiz,
          useBlotato: _useBlotato,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useConnected = !_loadingAccounts && (_usePostiz || _useBlotato);
    final gridCount =
        _usePostiz ? _postizIntegrations.length : _blotatoAccounts.length;

    return _MarketingScaffold(
      child: Column(
        children: [
          Text(
            'Select Your Digital Outlet',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose where to publish. Linked Instagram, TikTok, and YouTube appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.black45,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          if (_loadingAccounts)
            const Expanded(child: Center(child: AutobusLoadingIndicator()))
          else if (!useConnected)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.link_off,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Social Media linked yet. Use Link Social Media to connect your channels; they will appear here for publishing.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _DarkButton(
                        label: 'Open Link Social Media',
                        compact: true,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ManageOutlets(),
                            ),
                          );
                          if (mounted) {
                            setState(() => _loadingAccounts = true);
                            await _loadAccounts();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: gridCount,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final String id;
                  final String label;
                  final String? subtitle;
                  final Color color;
                  final FaIconData icon;
                  final Widget? avatar;

                  if (_usePostiz) {
                    final p = _postizIntegrations[i];
                    final outlet = _outletFor(p);
                    id = p.id;
                    label = outlet?.label ??
                        (p.identifier.isNotEmpty
                            ? p.identifier
                            : 'Channel');
                    final accountName = p.name.trim().isNotEmpty
                        ? p.name.trim()
                        : (p.profile?.trim() ?? '');
                    subtitle =
                        accountName.isNotEmpty ? accountName : null;
                    icon = outlet?.icon ?? FontAwesomeIcons.globe;
                    color = outlet?.iconColor ?? _kPurple;
                    final pic = p.picture?.trim();
                    avatar = pic != null &&
                            (pic.startsWith('http://') ||
                                pic.startsWith('https://'))
                        ? CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage(pic),
                            onBackgroundImageError: (_, __) {},
                          )
                        : null;
                  } else {
                    final acct = _blotatoAccounts[i];
                    id = acct['id'] as String? ?? '';
                    label = (acct['platform'] ?? 'Account').toString();
                    subtitle =
                        (acct['account_name'] ?? '').toString().trim();
                    icon = FontAwesomeIcons.link;
                    color = _kPurple;
                    avatar = null;
                  }

                  final sel =
                      widget.campaign.selectedOutlets.contains(id);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(
                        () => sel
                            ? widget.campaign.selectedOutlets.remove(id)
                            : widget.campaign.selectedOutlets.add(id),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 64,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? _kSelectGreen.withValues(alpha: 0.06)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel
                                ? _kSelectGreen
                                : Colors.grey.shade200,
                            width: sel ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            avatar ??
                                SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Center(
                                    child: FaIcon(
                                      icon,
                                      size: 20,
                                      color: color,
                                    ),
                                  ),
                                ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (subtitle != null &&
                                      subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 150),
                              opacity: sel ? 1 : 0,
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: _kSelectGreen,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          _DarkButton(
            label: 'Next',
            compact: true,
            onTap: widget.campaign.selectedOutlets.isNotEmpty
                ? _goToPostDetails
                : null,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Collect platform-specific supporting info, then publish.
class _PostDetailsPage extends StatefulWidget {
  final DigitalMarketingCampaign campaign;
  final List<PostizIntegration> postizIntegrations;
  final List<Map<String, dynamic>> blotatoAccounts;
  final bool usePostiz;
  final bool useBlotato;

  const _PostDetailsPage({
    required this.campaign,
    required this.postizIntegrations,
    required this.blotatoAccounts,
    required this.usePostiz,
    required this.useBlotato,
  });

  @override
  State<_PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<_PostDetailsPage> {
  final ApiService _apiService = ApiService(
    httpClient: SessionAwareHttpClient(tokenService: TokenService()),
  );

  bool _publishing = false;
  String _publishStatus = '';
  final Map<String, bool> _expanded = {};

  List<PostizIntegration> get _selectedPostiz {
    final ids = widget.campaign.selectedOutlets;
    return widget.postizIntegrations.where((p) => ids.contains(p.id)).toList();
  }

  List<Map<String, dynamic>> get _selectedBlotato {
    final ids = widget.campaign.selectedOutlets;
    return widget.blotatoAccounts
        .where((a) => ids.contains((a['id'] ?? '').toString()))
        .toList();
  }

  OutletOption? _outletFor(PostizIntegration p) {
    for (final o in OutletCatalog.all) {
      if (o.matchesIntegration(p)) return o;
    }
    return null;
  }

  PlatformPostDetails _detailsFor(String id) {
    return widget.campaign.outletDetails.putIfAbsent(
      id,
      () => PlatformPostDetails.fromCampaignCaption(
        widget.campaign.campaignCaption,
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.montserrat(fontSize: 12, color: Colors.black54),
      hintStyle: GoogleFonts.montserrat(fontSize: 12, color: Colors.black38),
      filled: true,
      fillColor: const Color(0xFFF7F5FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE8E0F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE8E0F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kHeaderPurple, width: 1.4),
      ),
    );
  }

  Widget _captionField(PlatformPostDetails d) {
    return TextFormField(
      initialValue: d.caption,
      minLines: 3,
      maxLines: 6,
      style: GoogleFonts.montserrat(fontSize: 13, height: 1.4),
      decoration: _fieldDecoration(
        'Caption',
        hint: 'Post caption / description',
      ),
      onChanged: (v) => d.caption = v,
    );
  }

  Widget _youtubeFields(PlatformPostDetails d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          initialValue: d.youtubeTitle,
          style: GoogleFonts.montserrat(fontSize: 13),
          decoration: _fieldDecoration('Title', hint: '2–100 characters'),
          onChanged: (v) => d.youtubeTitle = v,
        ),
        const SizedBox(height: 10),
        _captionField(d),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: d.youtubeVisibility,
          decoration: _fieldDecoration('Visibility'),
          style: GoogleFonts.montserrat(fontSize: 13, color: Colors.black87),
          items: const [
            DropdownMenuItem(value: 'public', child: Text('Public')),
            DropdownMenuItem(value: 'unlisted', child: Text('Unlisted')),
            DropdownMenuItem(value: 'private', child: Text('Private')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => d.youtubeVisibility = v);
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: d.youtubeTagsCsv,
          style: GoogleFonts.montserrat(fontSize: 13),
          decoration: _fieldDecoration(
            'Tags',
            hint: 'Comma-separated, e.g. marketing, tips',
          ),
          onChanged: (v) => d.youtubeTagsCsv = v,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: d.madeForKids,
          decoration: _fieldDecoration('Made for kids'),
          style: GoogleFonts.montserrat(fontSize: 13, color: Colors.black87),
          items: const [
            DropdownMenuItem(value: 'no', child: Text('No')),
            DropdownMenuItem(value: 'yes', child: Text('Yes')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => d.madeForKids = v);
          },
        ),
      ],
    );
  }

  Widget _tiktokFields(PlatformPostDetails d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          initialValue: d.tiktokTitle,
          style: GoogleFonts.montserrat(fontSize: 13),
          decoration: _fieldDecoration('Title', hint: 'Max 90 characters'),
          onChanged: (v) => d.tiktokTitle = v,
        ),
        const SizedBox(height: 10),
        _captionField(d),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: d.tiktokPrivacy,
          decoration: _fieldDecoration('Who can view'),
          style: GoogleFonts.montserrat(fontSize: 13, color: Colors.black87),
          items: const [
            DropdownMenuItem(
              value: 'PUBLIC_TO_EVERYONE',
              child: Text('Everyone'),
            ),
            DropdownMenuItem(
              value: 'FOLLOWER_OF_CREATOR',
              child: Text('Followers'),
            ),
            DropdownMenuItem(
              value: 'MUTUAL_FOLLOW_FRIENDS',
              child: Text('Friends'),
            ),
            DropdownMenuItem(
              value: 'SELF_ONLY',
              child: Text('Only me'),
            ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => d.tiktokPrivacy = v);
          },
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text('Allow comments', style: GoogleFonts.montserrat(fontSize: 13)),
          value: d.tiktokComment,
          activeColor: _kHeaderPurple,
          onChanged: (v) => setState(() => d.tiktokComment = v),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text('Allow duet', style: GoogleFonts.montserrat(fontSize: 13)),
          value: d.tiktokDuet,
          activeColor: _kHeaderPurple,
          onChanged: (v) => setState(() => d.tiktokDuet = v),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text('Allow stitch', style: GoogleFonts.montserrat(fontSize: 13)),
          value: d.tiktokStitch,
          activeColor: _kHeaderPurple,
          onChanged: (v) => setState(() => d.tiktokStitch = v),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Branded content',
            style: GoogleFonts.montserrat(fontSize: 13),
          ),
          value: d.tiktokBrandContent,
          activeColor: _kHeaderPurple,
          onChanged: (v) => setState(() => d.tiktokBrandContent = v),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Your brand',
            style: GoogleFonts.montserrat(fontSize: 13),
          ),
          value: d.tiktokBrandOrganic,
          activeColor: _kHeaderPurple,
          onChanged: (v) => setState(() => d.tiktokBrandOrganic = v),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Made with AI',
            style: GoogleFonts.montserrat(fontSize: 13),
          ),
          value: d.tiktokMadeWithAi,
          activeColor: _kHeaderPurple,
          onChanged: (v) => setState(() => d.tiktokMadeWithAi = v),
        ),
      ],
    );
  }

  Widget _instagramFields(PlatformPostDetails d, {required bool autobusOnly}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _captionField(d),
        if (!autobusOnly) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: d.instagramPostType,
            decoration: _fieldDecoration('Post type'),
            style: GoogleFonts.montserrat(fontSize: 13, color: Colors.black87),
            items: const [
              DropdownMenuItem(value: 'post', child: Text('Feed / Reel')),
              DropdownMenuItem(value: 'story', child: Text('Story')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => d.instagramPostType = v);
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: d.instagramCollaboratorsCsv,
            style: GoogleFonts.montserrat(fontSize: 13),
            decoration: _fieldDecoration(
              'Collaborators',
              hint: 'Usernames, comma-separated',
            ),
            onChanged: (v) => d.instagramCollaboratorsCsv = v,
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'Autobus Instagram publishes caption + media only.',
            style: GoogleFonts.montserrat(fontSize: 11, color: Colors.black45),
          ),
        ],
      ],
    );
  }

  Widget _genericFields(PlatformPostDetails d, {bool whatsAppStatus = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _captionField(d),
        const SizedBox(height: 8),
        Text(
          whatsAppStatus
              ? 'Autobus will open your phone share sheet so you can post this to WhatsApp Status manually.'
              : 'This channel uses caption and media. Extra options are not required.',
          style: GoogleFonts.montserrat(fontSize: 11, color: Colors.black45),
        ),
      ],
    );
  }

  Widget _outletCard({
    required String id,
    required String label,
    required String? subtitle,
    required FaIconData icon,
    required Color color,
    required PlatformDetailsKind kind,
    required bool autobusIg,
    bool whatsAppStatus = false,
  }) {
    final expanded = _expanded[id] ?? true;
    final d = _detailsFor(id);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded[id] = !expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  FaIcon(icon, size: 18, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.black45,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: kind == PlatformDetailsKind.youtube
                  ? _youtubeFields(d)
                  : kind == PlatformDetailsKind.tiktok
                      ? _tiktokFields(d)
                      : kind == PlatformDetailsKind.instagram
                          ? _instagramFields(d, autobusOnly: autobusIg)
                          : _genericFields(
                              d,
                              whatsAppStatus: whatsAppStatus,
                            ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final postizCards = <Widget>[];
    for (final p in _selectedPostiz) {
      final outlet = _outletFor(p);
      final label = outlet?.label ??
          (p.identifier.isNotEmpty ? p.identifier : 'Channel');
      final accountName = p.name.trim().isNotEmpty
          ? p.name.trim()
          : (p.profile?.trim() ?? '');
      final autobusIg = p.id.startsWith(_kAutobusIgPrefix);
      postizCards.add(
        _outletCard(
          id: p.id,
          label: label,
          subtitle: accountName.isNotEmpty ? accountName : null,
          icon: outlet?.icon ?? FontAwesomeIcons.globe,
          color: outlet?.iconColor ?? _kPurple,
          kind: platformDetailsKindFor(p.identifier),
          autobusIg: autobusIg,
          whatsAppStatus: _isWhatsAppStatusIntegration(p),
        ),
      );
    }

    final blotatoCards = <Widget>[];
    if (!widget.usePostiz) {
      for (final acct in _selectedBlotato) {
        final id = (acct['id'] ?? '').toString();
        if (id.isEmpty) continue;
        blotatoCards.add(
          _outletCard(
            id: id,
            label: (acct['platform'] ?? 'Account').toString(),
            subtitle: (acct['account_name'] ?? '').toString().trim(),
            icon: FontAwesomeIcons.link,
            color: _kPurple,
            kind: PlatformDetailsKind.generic,
            autobusIg: false,
          ),
        );
      }
    }

    final cards = [...postizCards, ...blotatoCards];

    return _MarketingScaffold(
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Post Details',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add titles, captions, and privacy settings for each platform',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.black45,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: cards.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => cards[i],
                ),
              ),
              const SizedBox(height: 12),
              _DarkButton(
                label: 'Publish',
                compact: true,
                onTap: _publishing ? null : _publish,
              ),
              const SizedBox(height: 12),
            ],
          ),
          if (_publishing)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.88),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AutobusLoadingIndicator(size: 36),
                      const SizedBox(height: 16),
                      Text(
                        _publishStatus.isEmpty
                            ? 'Publishing…'
                            : _publishStatus,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _setStatus(String status) {
    if (!mounted) return;
    setState(() => _publishStatus = status);
  }

  String _captionForOutlet(String id, String fallback) {
    final d = widget.campaign.outletDetails[id];
    final c = d?.caption.trim();
    if (c != null && c.isNotEmpty) return c;
    return fallback;
  }

  bool _isWhatsAppStatusIntegration(PostizIntegration integration) {
    return integration.identifier.toLowerCase() == _kWhatsAppIdentifier;
  }

  String _shareFileExtension(
    MarketingContent content, {
    String? sourceName,
    String? mimeType,
  }) {
    final candidate = (sourceName ?? '').trim().toLowerCase();
    final dot = candidate.lastIndexOf('.');
    if (dot >= 0 && dot < candidate.length - 1) {
      return candidate.substring(dot);
    }

    final mime = (mimeType ?? '').trim().toLowerCase();
    if (mime == 'image/png') return '.png';
    if (mime == 'image/webp') return '.webp';
    if (mime == 'image/gif') return '.gif';
    if (mime == 'video/quicktime') return '.mov';
    if (mime.startsWith('video/')) return '.mp4';
    return content.type == MarketingContentType.videos ? '.mp4' : '.jpg';
  }

  Future<XFile?> _materializeShareFile(
    MarketingContent content,
    int index,
  ) async {
    final localPath = content.localFilePath?.trim();
    if (!kIsWeb && localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (await file.exists() && await file.length() > 0) {
        return XFile(file.path);
      }
    }

    final bytes = content.generatedBytes;
    if (bytes != null && bytes.isNotEmpty) {
      final ext = _shareFileExtension(
        content,
        sourceName: content.generatedResult,
        mimeType: content.generatedResult,
      );
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}${Platform.pathSeparator}autobus-share-$index$ext';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      return XFile(file.path);
    }

    final remote = content.generatedResult?.trim() ?? '';
    if (remote.startsWith('http://') || remote.startsWith('https://')) {
      final response = await http.get(Uri.parse(remote));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Could not prepare media for WhatsApp Status (${response.statusCode}).',
        );
      }
      final remoteUri = Uri.parse(remote);
      final ext = _shareFileExtension(
        content,
        sourceName: remoteUri.pathSegments.isNotEmpty
            ? remoteUri.pathSegments.last
            : null,
        mimeType: response.headers['content-type'],
      );
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}${Platform.pathSeparator}autobus-share-$index$ext';
      final file = File(path);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return XFile(file.path);
    }

    return null;
  }

  Future<bool> _shareToWhatsAppStatus({
    required List<PostizIntegration> integrations,
    required String fallbackCaption,
  }) async {
    if (integrations.isEmpty) return false;
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      throw Exception(
        'WhatsApp Status sharing is available on Android and iPhone only.',
      );
    }

    final files = <XFile>[];
    var fileIndex = 0;
    for (final content in widget.campaign.contents) {
      if (content.type == MarketingContentType.text) continue;
      final file = await _materializeShareFile(content, fileIndex++);
      if (file != null) files.add(file);
    }

    final primary = integrations.first;
    final caption = _captionForOutlet(primary.id, fallbackCaption).trim();
    if (files.isEmpty && caption.isEmpty) {
      throw Exception('Add text, image, or video before sharing to WhatsApp Status.');
    }

    final result = await SharePlus.instance.share(
      ShareParams(
        title: 'Share to WhatsApp Status',
        text: caption.isEmpty ? null : caption,
        files: files.isEmpty ? null : files,
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }

  Future<void> _publish() async {
    final selectedIds = widget.campaign.selectedOutlets.toList();
    if (selectedIds.isEmpty || _publishing) return;

    // YouTube requires a title (2–100 chars).
    for (final p in _selectedPostiz) {
      if (p.identifier.toLowerCase() != 'youtube') continue;
      if (p.id.startsWith(_kAutobusIgPrefix)) continue;
      final d = _detailsFor(p.id);
      final title = d.youtubeTitle.trim().isNotEmpty
          ? d.youtubeTitle.trim()
          : PlatformPostDetails.fromCampaignCaption(d.caption).youtubeTitle;
      if (title.trim().length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'YouTube needs a title (at least 2 characters).',
              style: GoogleFonts.montserrat(fontSize: 13),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      d.youtubeTitle = title;
    }

    setState(() {
      _publishing = true;
      _publishStatus = 'Preparing content…';
    });

    final messenger = ScaffoldMessenger.of(context);
    final textContent = widget.campaign.campaignCaption;

    try {
      final igIds = selectedIds
          .where((id) => id.startsWith(_kAutobusIgPrefix))
          .map((id) => id.substring(_kAutobusIgPrefix.length))
          .where((id) => id.isNotEmpty)
          .toList();
      final whatsAppStatusIntegrations = _selectedPostiz
          .where(
            (p) =>
                selectedIds.contains(p.id) &&
                _isWhatsAppStatusIntegration(p),
          )
          .toList();
      final whatsAppStatusIds =
          whatsAppStatusIntegrations.map((p) => p.id).toSet();
      final postizIds = selectedIds
          .where(
            (id) =>
                !id.startsWith(_kAutobusIgPrefix) &&
                !whatsAppStatusIds.contains(id),
          )
          .toList();
      final needsUploadedMedia = igIds.isNotEmpty || postizIds.isNotEmpty;
      final mediaUrls = <String>[];
      if (needsUploadedMedia) {
        _setStatus('Uploading media…');
        for (final c in widget.campaign.contents) {
          if (c.type == MarketingContentType.text) continue;

          final existing = c.generatedResult?.trim();
          if (existing != null &&
              existing.isNotEmpty &&
              (existing.startsWith('http://') ||
                  existing.startsWith('https://'))) {
            mediaUrls.add(existing);
            continue;
          }

          final localPath = c.localFilePath?.trim();
          if (!kIsWeb && localPath != null && localPath.isNotEmpty) {
            try {
              final file = File(localPath);
              if (await file.exists() && await file.length() > 0) {
                final url = await _apiService.uploadFile(
                  file: file,
                  filename: file.uri.pathSegments.isNotEmpty
                      ? file.uri.pathSegments.last
                      : null,
                );
                mediaUrls.add(url);
                continue;
              }
            } catch (_) {
              // Fall through to bytes upload if available.
            }
          }

          final bytes = c.generatedBytes;
          if (bytes != null && bytes.isNotEmpty) {
            final filename = c.type == MarketingContentType.videos
                ? 'marketing-video.mp4'
                : (c.generatedResult?.trim().isNotEmpty == true
                      ? c.generatedResult!.trim()
                      : 'marketing-image.jpg');
            final url = await _apiService.uploadFileBytes(
              fileBytes: bytes,
              filename: filename,
            );
            mediaUrls.add(url);
          }
        }
      }

      final scheduleTime =
          widget.campaign.scheduledDate?.toUtc().toIso8601String();

      var publishedCount = 0;
      var sharedWhatsAppStatus = false;
      final errors = <String>[];

      if (igIds.isNotEmpty) {
        if (mediaUrls.isEmpty) {
          throw Exception(
            'Instagram needs at least one uploaded image or video URL.',
          );
        }
        _setStatus(
          widget.campaign.postRightAway
              ? 'Publishing to Instagram…'
              : 'Publishing to Instagram (goes live now)…',
        );
        for (final accountId in igIds) {
          final outletKey = '$_kAutobusIgPrefix$accountId';
          try {
            await _apiService.publishInstagramPost(
              accountId: accountId,
              caption: _captionForOutlet(outletKey, textContent),
              mediaUrls: mediaUrls,
            );
            publishedCount++;
          } catch (e) {
            errors.add(
              'Instagram: ${e.toString().replaceFirst('Exception: ', '')}',
            );
          }
        }
      }

      if (whatsAppStatusIntegrations.isNotEmpty) {
        _setStatus('Opening WhatsApp share sheet…');
        sharedWhatsAppStatus = await _shareToWhatsAppStatus(
          integrations: whatsAppStatusIntegrations,
          fallbackCaption: textContent,
        );
        if (!sharedWhatsAppStatus) {
          errors.add('WhatsApp Status share was dismissed.');
        }
      }

      if (postizIds.isNotEmpty && widget.usePostiz) {
        final selected = widget.postizIntegrations
            .where((p) => postizIds.contains(p.id))
            .toList();
        if (selected.isEmpty) {
          throw Exception('No matching Postiz channels for the selection.');
        }
        _setStatus(
          widget.campaign.postRightAway
              ? 'Publishing via Postiz…'
              : 'Scheduling via Postiz…',
        );
        final payload = buildPostizCreatePostPayload(
          selectedIntegrations: selected,
          content: textContent,
          mediaUrls: mediaUrls,
          postRightAway: widget.campaign.postRightAway,
          scheduledUtc: widget.campaign.scheduledDate,
          outletDetails: widget.campaign.outletDetails,
        );
        await _apiService.createPostizPost(
          payload,
          agentName: 'digital_marketing',
        );
        publishedCount += selected.length;
      } else if (postizIds.isNotEmpty && widget.useBlotato) {
        _setStatus('Publishing…');
        // Blotato has one content field — use first selected caption override if any.
        var blotatoContent = textContent;
        for (final id in postizIds) {
          final c = widget.campaign.outletDetails[id]?.caption.trim();
          if (c != null && c.isNotEmpty) {
            blotatoContent = c;
            break;
          }
        }
        await _apiService.publishSocialPost(
          accountIds: postizIds,
          content: blotatoContent.isEmpty ? ' ' : blotatoContent,
          mediaUrls: mediaUrls,
          scheduleTime: scheduleTime,
        );
        publishedCount += postizIds.length;
      } else if (igIds.isEmpty) {
        throw Exception(
          'Connect an outlet in Marketing → Link Social Media, then try again.',
        );
      }

      if (!mounted) return;

      if (publishedCount == 0 && errors.isNotEmpty) {
        throw Exception(errors.join('\n'));
      }

      final publishedMessage = widget.campaign.postRightAway
          ? 'Published to $publishedCount channel(s)'
          : 'Scheduled / published for $publishedCount channel(s)';
      final successParts = <String>[];
      if (publishedCount > 0) {
        successParts.add(publishedMessage);
      }
      if (sharedWhatsAppStatus) {
        successParts.add(
          widget.campaign.postRightAway
              ? 'Opened WhatsApp Status share'
              : 'Opened WhatsApp Status share now (manual step)',
        );
      }
      if (successParts.isEmpty && errors.isEmpty) {
        successParts.add('Opened the share flow.');
      }
      final successMsg = errors.isEmpty
          ? successParts.join('. ')
          : '${successParts.join('. ')}. Some failed: ${errors.join('; ')}';

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            successMsg,
            style: GoogleFonts.montserrat(color: Colors.white, fontSize: 13),
          ),
          backgroundColor:
              errors.isEmpty ? Colors.green : Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (errors.isEmpty && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Publish failed: ${e.toString().replaceFirst('Exception: ', '')}',
            style: GoogleFonts.montserrat(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _publishing = false;
          _publishStatus = '';
        });
      }
    }
  }
}
