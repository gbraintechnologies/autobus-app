part of 'digital_marketing.dart';

class _GenerationReference {
  final String name;
  final String? path;
  final Uint8List? bytes;
  final bool isVideo;
  final String mimeType;

  const _GenerationReference({
    required this.name,
    this.path,
    this.bytes,
    required this.isVideo,
    required this.mimeType,
  });
}

String _referenceMimeType(String name, {required bool isVideo}) {
  final dot = name.lastIndexOf('.');
  final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
  if (isVideo) {
    switch (ext) {
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'avi':
        return 'video/x-msvideo';
      default:
        return 'video/mp4';
    }
  }
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'bmp':
      return 'image/bmp';
    default:
      return 'image/jpeg';
  }
}

class _MarketingChatPage extends StatefulWidget {
  final DigitalMarketingCampaign campaign;
  final bool readOnly;

  const _MarketingChatPage({
    required this.campaign,
    this.readOnly = false,
  });

  @override
  State<_MarketingChatPage> createState() => _MarketingChatPageState();
}

class _MarketingChatPageState extends State<_MarketingChatPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  final ApiService _apiService = ApiService(
    httpClient: SessionAwareHttpClient(tokenService: TokenService()),
  );

  MarketingContentType _mode = MarketingContentType.pictures;
  bool _sending = false;
  bool _archiving = false;
  final List<_GenerationReference> _references = [];
  static const int _maxReferences = 3;

  DigitalMarketingCampaign get _campaign => widget.campaign;

  bool get _canGoNext =>
      _campaign.generatedContents.isNotEmpty &&
      !_campaign.contents.any((c) => c.genState == MediaGenState.generating) &&
      !_sending;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    if (widget.readOnly && _campaign.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _newMsgId() =>
      'msg_${DateTime.now().microsecondsSinceEpoch}_${_campaign.messages.length}';

  Future<String> _userId() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson == null) return '';
    final user = jsonDecode(userJson) as Map<String, dynamic>;
    return (user['id'] ?? user['phone'] ?? '').toString();
  }

  String _followUpPrompt(String userText, MarketingContentType type) {
    final history = _campaign.conversationTranscript;
    if (history.isEmpty) return userText;
    final kind = type == MarketingContentType.pictures
        ? 'image'
        : type == MarketingContentType.videos
            ? 'video'
            : 'marketing copy';
    return 'Conversation so far:\n$history\n\n'
        'New request: $userText\n'
        'Treat this as a follow-up. If the user asked to change the previous $kind, '
        'produce an updated version that applies their request while staying consistent '
        'with the conversation.';
  }

  String? _currentNluIntent() {
    switch (_mode) {
      case MarketingContentType.pictures:
        return 'generate_image';
      case MarketingContentType.videos:
        return 'generate_video';
      case MarketingContentType.text:
        return 'generate_text';
    }
  }

  MarketingContentType _typeFromIntent(String? intent) {
    final raw = (intent ?? '').trim().toLowerCase();
    switch (raw) {
      case 'generate_image':
      case 'image_generation':
        return MarketingContentType.pictures;
      case 'generate_video':
      case 'video_generation':
        return MarketingContentType.videos;
      case 'generate_text':
      case 'text_generation':
        return MarketingContentType.text;
      default:
        return _mode;
    }
  }

  List<Map<String, String>> _nluConversation() {
    final out = <Map<String, String>>[];
    for (final m in _campaign.messages) {
      if (m.isGenerating) continue;
      final text = m.text.trim();
      if (text.isEmpty) continue;
      out.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': text,
      });
    }
    return out;
  }

  Future<MarketingContentType> _detectContentType(String userText) async {
    try {
      final result = await _apiService.detectNluIntent(
        message: userText,
        currentIntent: _campaign.messages.isEmpty ? null : _currentNluIntent(),
        conversation: _nluConversation(),
      );
      return _typeFromIntent(result['intent']?.toString());
    } catch (_) {
      return _mode;
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<({String? base64, String? url, String mime})> _referencePayload(
    _GenerationReference ref,
  ) async {
    const uploadThreshold = 8 * 1024 * 1024;
    Uint8List? bytes = ref.bytes;
    if ((bytes == null || bytes.isEmpty) &&
        !kIsWeb &&
        (ref.path ?? '').trim().isNotEmpty) {
      final file = File(ref.path!);
      if (await file.exists()) {
        final length = await file.length();
        if (ref.isVideo && length > uploadThreshold) {
          final url = await _apiService.uploadFile(
            file: file,
            filename: ref.name,
            storageFolder: 'digital-marketing',
          );
          return (base64: null, url: url, mime: ref.mimeType);
        }
        bytes = await file.readAsBytes();
      }
    }
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Could not read the reference file.');
    }
    if (ref.isVideo && bytes.length > uploadThreshold) {
      final url = await _apiService.uploadFileBytes(
        fileBytes: bytes,
        filename: ref.name,
        storageFolder: 'digital-marketing',
      );
      return (base64: null, url: url, mime: ref.mimeType);
    }
    return (base64: base64Encode(bytes), url: null, mime: ref.mimeType);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    final usedRefs = List<_GenerationReference>.from(_references);
    final firstRef = usedRefs.isEmpty ? null : usedRefs.first;
    final userMsg = MarketingChatMessage(
      id: _newMsgId(),
      role: MarketingChatRole.user,
      text: text,
      referenceBytes: firstRef?.bytes,
      referencePath: firstRef?.path,
      referenceIsVideo: firstRef?.isVideo ?? false,
    );
    final pending = MarketingChatMessage(
      id: _newMsgId(),
      role: MarketingChatRole.assistant,
      text: '',
      isGenerating: true,
    );

    setState(() {
      _sending = true;
      _references.clear();
      _campaign.messages.add(userMsg);
      _campaign.messages.add(pending);
      _input.clear();
    });
    _scrollToEnd();

    final pendingIndex = _campaign.messages.indexWhere((m) => m.id == pending.id);
    late final MarketingContent content;

    try {
      final detectedType = await _detectContentType(text);
      if (!mounted) return;
      _mode = detectedType;

      content = MarketingContent(detectedType);
      content.prompt = text;
      content.genState = MediaGenState.generating;
      _campaign.contents.add(content);

      final prompt = _followUpPrompt(text, detectedType);
      final userId = await _userId();
      String assistantText = '';
      List<Map<String, String>>? packedRefs;
      if (usedRefs.isNotEmpty && detectedType != MarketingContentType.text) {
        packedRefs = [];
        for (final ref in usedRefs) {
          final packed = await _referencePayload(ref);
          packedRefs.add({
            if (packed.base64 != null) 'base64': packed.base64!,
            if (packed.url != null) 'url': packed.url!,
            'mime_type': packed.mime,
          });
        }
      }

      if (detectedType == MarketingContentType.pictures) {
        final response = await _apiService.generateImageMedia(
          userId: userId,
          prompt: prompt,
          references: packedRefs,
        );
        final rawBase64 = (response['image_base64'] ?? '').toString().trim();
        if (rawBase64.isEmpty) {
          throw Exception('Image generation returned no image data');
        }
        final cleanedBase64 = rawBase64.contains(',')
            ? rawBase64.substring(rawBase64.indexOf(',') + 1)
            : rawBase64;
        content.generatedBytes = await compute(base64Decode, cleanedBase64);
        content.generatedResult = response['mime_type']?.toString();
        await _persistBytesToFile(content, '.jpg');
        assistantText = usedRefs.isEmpty
            ? 'Generated an image from your prompt.'
            : 'Generated an image using your reference.';
      } else if (detectedType == MarketingContentType.videos) {
        final response = await _apiService.generateVideoMedia(
          userId: userId,
          prompt: prompt,
          store: true,
          references: packedRefs,
        );
        final result = (response['stored_url'] ?? response['video_url'] ?? '')
            .toString()
            .trim();
        if (result.isEmpty) {
          throw Exception('Video generation returned no video URL');
        }
        content.generatedResult = result;
        assistantText = usedRefs.isEmpty
            ? 'Generated a video from your prompt.'
            : 'Generated a video using your reference.';
      } else {
        final result = await _apiService.generateAgentContent(
          userId: userId,
          prompt: prompt,
          agentName: 'digital_marketing',
        );
        content.generatedResult = result;
        content.manualText = result;
        assistantText = result;
      }

      content.genState = MediaGenState.ready;
      if (!mounted) return;
      setState(() {
        _campaign.messages[pendingIndex] = pending.copyWith(
          text: assistantText,
          contentId: content.id,
          isGenerating: false,
        );
        _sending = false;
      });
      _scrollToEnd();
      unawaited(_archiveCampaign());
    } catch (e) {
      if (_campaign.contents.isNotEmpty &&
          _campaign.contents.last.genState == MediaGenState.generating) {
        _campaign.contents.last.genState = MediaGenState.idle;
      }
      if (!mounted) return;
      setState(() {
        _campaign.messages[pendingIndex] = pending.copyWith(
          text: '',
          isGenerating: false,
          error: userFacingError(e, action: 'creating media'),
        );
        _sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingError(e, action: 'creating media')),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _persistBytesToFile(MarketingContent content, String ext) async {
    if (kIsWeb) return;
    final bytes = content.generatedBytes;
    if (bytes == null || bytes.isEmpty) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}campaign_${content.id}$ext',
      );
      await file.writeAsBytes(bytes, flush: true);
      content.localFilePath = file.path;
    } catch (_) {}
  }

  Future<void> _archiveCampaign() async {
    if (_archiving) return;
    _archiving = true;
    try {
      final links = <String>[];
      for (final c in _campaign.generatedContents) {
        if (c.hasRemoteUrl) {
          links.add(c.generatedResult!.trim());
          continue;
        }
        if (c.type == MarketingContentType.text) continue;
        try {
          final localPath = c.localFilePath?.trim();
          if (!kIsWeb && localPath != null && localPath.isNotEmpty) {
            final file = File(localPath);
            if (await file.exists() && await file.length() > 0) {
              final url = await _apiService.uploadFile(
                file: file,
                filename: file.uri.pathSegments.isNotEmpty
                    ? file.uri.pathSegments.last
                    : null,
                storageFolder: 'digital-marketing',
              );
              c.generatedResult = url;
              links.add(url);
              continue;
            }
          }
          final bytes = c.generatedBytes;
          if (bytes != null && bytes.isNotEmpty) {
            final filename = c.type == MarketingContentType.videos
                ? 'campaign-video.mp4'
                : 'campaign-image.jpg';
            final url = await _apiService.uploadFileBytes(
              fileBytes: bytes,
              filename: filename,
              storageFolder: 'digital-marketing',
            );
            c.generatedResult = url;
            links.add(url);
          }
        } catch (_) {}
      }

      final transcript = _campaign.conversationTranscript;
      final conversation = _campaign.messages
          .where((m) => !m.isGenerating)
          .map((m) {
            MarketingContent? content;
            final cid = m.contentId;
            if (cid != null) {
              for (final c in _campaign.contents) {
                if (c.id == cid) {
                  content = c;
                  break;
                }
              }
            }
            return m.toJson(content: content);
          })
          .toList();
      final contents = _campaign.generatedContents
          .map((c) => c.toArchiveJson())
          .toList();
      final body = await _apiService.createDigitalMarketingAsset(
        marketingText: transcript.isEmpty ? 'Campaign' : transcript,
        contentLinks: links,
        conversation: conversation,
        contents: contents,
      );
      final id = (body['id'] ?? '').toString();
      if (id.isNotEmpty) _campaign.remoteAssetId = id;
    } catch (_) {
      // Local chat still works if archive fails.
    } finally {
      _archiving = false;
    }
  }

  Future<void> _attachReference() async {
    if (_sending) return;
    if (_references.length >= _maxReferences) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can attach up to 3 references.')),
      );
      return;
    }
    try {
      final picked = await _pickMediaForComposer();
      if (picked == null || !mounted) return;
      setState(() {
        _references.add(
          _GenerationReference(
            name: picked.name,
            path: picked.path,
            bytes: picked.bytes,
            isVideo: picked.isVideo,
            mimeType: _referenceMimeType(picked.name, isVideo: picked.isVideo),
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to attach reference. Please try again.'),
        ),
      );
    }
  }

  Future<DevicePickedMedia?> _pickMediaForComposer() async {
    if (kIsWeb) {
      final isPicture = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Reference image'),
                onTap: () => Navigator.pop(context, true),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Reference video'),
                onTap: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      );
      if (isPicture == null || !mounted) return null;
      final allowedExtensions = isPicture
          ? <String>['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp']
          : <String>['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'];
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return null;
      final file = result.files.single;
      if ((file.bytes == null || file.bytes!.isEmpty) &&
          (file.path == null || file.path!.isEmpty)) {
        return null;
      }
      return DevicePickedMedia(
        name: file.name,
        path: file.path,
        bytes: file.bytes,
        isVideo: !isPicture,
      );
    }

    final target = await choosePhotoOrVideoSource(context);
    if (target == null || !mounted) return null;
    if (target.isPicture) {
      final picked = await pickDeviceImages(
        context,
        maxCount: 1,
        source: target.source,
      );
      if (picked.isEmpty) return null;
      return picked.first;
    }
    final picked = await pickDeviceVideos(
      context,
      maxCount: 1,
      source: target.source,
    );
    if (picked.isEmpty) return null;
    return picked.first;
  }

  Future<void> _attachMedia() async {
    if (_sending) return;

    if (kIsWeb) {
      final isPicture = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Upload image'),
                onTap: () => Navigator.pop(context, true),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Upload video'),
                onTap: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      );
      if (isPicture == null || !mounted) return;
      await _attachWithFilePicker(isPicture: isPicture);
      return;
    }

    final target = await choosePhotoOrVideoSource(context);
    if (target == null || !mounted) return;
    final isPicture = target.isPicture;
    final source = target.source;

    try {
      if (isPicture) {
        final picked = await pickDeviceImages(
          context,
          maxCount: 1,
          source: source,
        );
        if (!mounted || picked.isEmpty) return;
        final media = picked.first;
        _addUploadedContent(
          MarketingContentType.pictures,
          bytes: media.bytes,
          path: media.path,
          name: media.name,
        );
        return;
      }

      final picked = await pickDeviceVideos(
        context,
        maxCount: 1,
        source: source,
      );
      if (!mounted || picked.isEmpty) return;
      final media = picked.first;
      _addUploadedContent(
        MarketingContentType.videos,
        bytes: media.bytes,
        path: media.path,
        name: media.name,
      );
    } catch (_) {
      if (!mounted) return;
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

  Future<void> _attachWithFilePicker({required bool isPicture}) async {
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
    _addUploadedContent(
      isPicture ? MarketingContentType.pictures : MarketingContentType.videos,
      bytes: file.bytes,
      path: file.path,
      name: file.name,
    );
  }

  void _addUploadedContent(
    MarketingContentType type, {
    Uint8List? bytes,
    String? path,
    String? name,
  }) {
    final content = MarketingContent(type);
    content.generatedBytes = bytes;
    content.localFilePath = path;
    content.generatedResult =
        type == MarketingContentType.pictures ? name : null;
    content.genState = MediaGenState.ready;
    content.prompt = 'Uploaded from device';

    setState(() {
      _mode = type;
      _campaign.contents.add(content);
      _campaign.messages.add(
        MarketingChatMessage(
          id: _newMsgId(),
          role: MarketingChatRole.user,
          text: type == MarketingContentType.pictures
              ? 'Added an image'
              : 'Added a video',
        ),
      );
      _campaign.messages.add(
        MarketingChatMessage(
          id: _newMsgId(),
          role: MarketingChatRole.assistant,
          text: 'Added your ${content.label.toLowerCase()} to the campaign.',
          contentId: content.id,
        ),
      );
    });
    _scrollToEnd();
    unawaited(_archiveCampaign());
  }

  void _goNext() {
    if (!_canGoNext) return;
    for (final c in _campaign.generatedContents) {
      c.selectedForPost = true;
    }
    unawaited(_archiveCampaign());
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ComposePostPage(campaign: _campaign),
      ),
    );
  }

  MarketingContent? _contentFor(MarketingChatMessage msg) {
    final id = msg.contentId;
    if (id == null) return null;
    for (final c in _campaign.contents) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final canSend = !widget.readOnly && _input.text.trim().isNotEmpty && !_sending;
    return _MarketingScaffold(
      contentHorizontalPadding: 0,
      headerTrailing: widget.readOnly
          ? const UserAvatar(onLightBackground: true)
          : _ChatNextButton(
              enabled: _canGoNext,
              onTap: _canGoNext ? _goNext : null,
            ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              widget.readOnly ? 'Campaign conversation' : 'Create with Autobus',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _campaign.messages.isEmpty
                ? _emptyState()
                : ListView.builder(
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _campaign.messages.length,
                    itemBuilder: (context, index) {
                      return _messageBubble(_campaign.messages[index]);
                    },
                  ),
          ),
          if (!widget.readOnly) ...[
            _composer(canSend: canSend),
            const SizedBox(height: 8),
          ] else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 40,
                  color: _kPurple.withValues(alpha: 0.85),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.readOnly
                      ? 'No messages were saved for this campaign.'
                      : 'What would you like to create?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _kPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.readOnly
                      ? 'Generated images, videos, and captions will show here when they are part of the saved conversation.'
                      : 'Describe an image, video, or caption. Attach up to 3 references if you want the AI to follow them. Each reference uses extra credits.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black45,
                    height: 1.4,
                  ),
                ),
                if (!widget.readOnly) ...[
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _suggestionChip('Product photo for Instagram'),
                      _suggestionChip('15-second promo video'),
                      _suggestionChip('Caption for a weekend sale'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _suggestionChip(String label) {
    return ActionChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 12, color: _kHeaderPurple),
      ),
      backgroundColor: const Color(0xFFF7F5FB),
      side: const BorderSide(color: Color(0xFFE8E0F0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () {
        setState(() {
          _input.text = label;
          _input.selection = TextSelection.collapsed(offset: _input.text.length);
        });
        _focus.requestFocus();
      },
    );
  }

  Widget _messageBubble(MarketingChatMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _kHeaderPurple,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_hasReferencePreview(msg)) ...[
                _userReferenceThumb(msg),
                const SizedBox(height: 8),
              ],
              Text(
                msg.text,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final content = _contentFor(msg);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 36),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8E0F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.isGenerating)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AutobusLoadingIndicator(size: 22),
                    SizedBox(width: 10),
                    Text('Creating…'),
                  ],
                ),
              )
            else if (msg.error != null)
              Text(
                msg.error!,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: CustColors.accentRed,
                ),
              )
            else ...[
              if (content != null) _contentPreview(content),
              if (msg.text.trim().isNotEmpty &&
                  (content == null ||
                      content.type != MarketingContentType.text)) ...[
                if (content != null) const SizedBox(height: 8),
                Text(
                  msg.text,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _contentPreview(MarketingContent content) {
    if (content.type == MarketingContentType.text) {
      return Text(
        content.displayText,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.black87,
          height: 1.45,
        ),
      );
    }
    if (content.type == MarketingContentType.pictures) {
      Widget? image;
      if (content.generatedBytes != null) {
        image = Image.memory(content.generatedBytes!, fit: BoxFit.cover);
      } else if (!kIsWeb &&
          content.localFilePath != null &&
          File(content.localFilePath!).existsSync()) {
        image = Image.file(File(content.localFilePath!), fit: BoxFit.cover);
      } else if (content.hasRemoteUrl) {
        image = Image.network(content.generatedResult!, fit: BoxFit.cover);
      }
      if (image == null) return const SizedBox.shrink();
      return GestureDetector(
        onTap: () => _showPreview(content),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(aspectRatio: 4 / 5, child: image),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _showPreview(content),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: ColoredBox(
            color: Colors.black,
            child: _MarketingInlineVideoPlayer(
              videoRef: content.localFilePath ?? content.generatedResult ?? '',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPreview(MarketingContent content) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
        builder: (dialogContext) => _MediaSlotPreviewDialog(
        content: content,
        onDelete: widget.readOnly
            ? null
            : () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  _campaign.contents.removeWhere((c) => c.id == content.id);
                  _campaign.messages
                      .removeWhere((m) => m.contentId == content.id);
                });
              },
      ),
    );
  }

  bool _hasReferencePreview(MarketingChatMessage msg) {
    if (msg.referenceBytes != null && msg.referenceBytes!.isNotEmpty) {
      return true;
    }
    final path = msg.referencePath?.trim() ?? '';
    return !kIsWeb && path.isNotEmpty && File(path).existsSync();
  }

  Widget _userReferenceThumb(MarketingChatMessage msg) {
    Widget child;
    if (msg.referenceIsVideo) {
      child = const ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
        ),
      );
    } else if (msg.referenceBytes != null && msg.referenceBytes!.isNotEmpty) {
      child = Image.memory(msg.referenceBytes!, fit: BoxFit.cover);
    } else {
      child = Image.file(File(msg.referencePath!), fit: BoxFit.cover);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(width: 88, height: 88, child: child),
    );
  }

  Widget _referenceThumb(_GenerationReference ref) {
    if (!ref.isVideo && ref.bytes != null && ref.bytes!.isNotEmpty) {
      return Image.memory(ref.bytes!, fit: BoxFit.cover);
    }
    if (!ref.isVideo &&
        !kIsWeb &&
        (ref.path ?? '').isNotEmpty &&
        File(ref.path!).existsSync()) {
      return Image.file(File(ref.path!), fit: BoxFit.cover);
    }
    return ColoredBox(
      color: const Color(0xFFF3EEF8),
      child: Icon(
        ref.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
        color: _kHeaderPurple,
        size: 18,
      ),
    );
  }

  Widget _referenceChip() {
    if (_references.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          for (var i = 0; i < _references.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == _references.length - 1 ? 0 : 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: _referenceThumb(_references[i]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reference: ${_references[i].name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                  GestureDetector(
                    onTap: _sending
                        ? null
                        : () => setState(() => _references.removeAt(i)),
                    child: const Icon(Icons.close_rounded, size: 18, color: Colors.black45),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _composer({required bool canSend}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8E0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _referenceChip(),
          TextField(
            controller: _input,
            focusNode: _focus,
            minLines: 1,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            onTapOutside: dismissAppKeyboard,
            style: GoogleFonts.poppins(fontSize: 14, height: 1.4),
            decoration: InputDecoration(
              hintText: 'Describe an image, video, or caption…',
              hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.black38),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Tooltip(
                message: 'Add image or video to campaign',
                child: GestureDetector(
                  onTap: _sending ? null : _attachMedia,
                  child: Icon(
                    Icons.add_rounded,
                    color: _sending ? Colors.black26 : _kHeaderPurple,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Use as generation reference',
                child: GestureDetector(
                  onTap: _sending ? null : _attachReference,
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: _sending ? Colors.black26 : _kHeaderPurple,
                    size: 22,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: canSend ? _send : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: canSend ? _kHeaderPurple : Colors.black12,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: canSend ? Colors.white : Colors.black38,
                    size: 18,
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

class _ChatNextButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;

  const _ChatNextButton({required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : 0.38,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: enabled ? _kHeaderPurple : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: enabled ? _kHeaderBorder : Colors.transparent,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Next',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: enabled ? Colors.white : Colors.white70,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: enabled ? Colors.white : Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
