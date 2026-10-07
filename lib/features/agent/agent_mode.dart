import 'dart:io';

import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/device_media_picker.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_chat.dart';
import 'package:autobus/features/agent/agent_bloc.dart';
import 'package:autobus/features/agent/agent_event.dart';
import 'package:autobus/features/agent/agent_repository.dart';
import 'package:autobus/features/agent/agent_state.dart';
import 'package:autobus/features/agent/models/agent_models.dart';
import 'package:autobus/features/products/product_media.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:video_player/video_player.dart';

class AgentModePage extends StatelessWidget {
  final VoidCallback onExit;

  const AgentModePage({super.key, required this.onExit});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AgentBloc(AgentRepository(context.read<ApiService>()))
            ..add(const AgentStarted()),
      child: _AgentModeView(onExit: onExit),
    );
  }
}

class _AgentModeView extends StatefulWidget {
  final VoidCallback onExit;

  const _AgentModeView({required this.onExit});

  @override
  State<_AgentModeView> createState() => _AgentModeViewState();
}

class _AgentModeViewState extends State<_AgentModeView> {
  static const _purple = LightScreenTheme.accent;
  static const _text = Color(0xFF475569);
  static const _muted = Color(0xFF94A3B8);
  static const _divider = Color(0xFFE2E8F0);
  static const _placeholder = Color(0xFFF1F5F9);
  static const _tint = Color(0xFFF3E8FF);

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _speech = SpeechToText();

  bool _speechReady = false;
  bool _listening = false;
  bool _holdingMic = false;
  bool _uploading = false;
  final List<AgentAttachment> _staged = [];

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    _initSpeech();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          final listening = status == 'listening';
          if (_listening != listening) {
            setState(() => _listening = listening);
          }
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => _listening = false);
        },
      );
      if (mounted) setState(() => _speechReady = ok);
    } catch (_) {
      if (mounted) setState(() => _speechReady = false);
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

  Future<void> _startHoldRecord() async {
    if (_holdingMic || _uploading) return;
    if (context.read<AgentBloc>().state.working) return;
    if (!_speechReady) {
      showAppSnackBar(
        context,
        'Microphone or speech recognition is not available on this device.',
      );
      return;
    }
    _holdingMic = true;
    HapticFeedback.mediumImpact();
    setState(() => _listening = true);
    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 60),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
        onResult: (result) {
          if (!mounted) return;
          if (!_holdingMic && !_listening) return;
          setState(() {
            if (result.recognizedWords.trim().isNotEmpty) {
              _input.text = result.recognizedWords;
              _input.selection = TextSelection.collapsed(
                offset: _input.text.length,
              );
            }
          });
        },
      );
      if (!_holdingMic) {
        await _speech.stop();
      }
    } catch (_) {
      if (!mounted) return;
      _holdingMic = false;
      setState(() => _listening = false);
    }
  }

  Future<void> _finishHoldRecord({required bool send}) async {
    if (!_holdingMic) return;
    _holdingMic = false;
    await _speech.stop();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() => _listening = false);
    if (send) await _send();
  }

  Future<void> _send({String? choiceText, String? askId}) async {
    if (_uploading) return;
    if (context.read<AgentBloc>().state.working) return;
    final text = (choiceText ?? _input.text).trim();
    if (text.isEmpty && _staged.isEmpty) return;

    final bloc = context.read<AgentBloc>();
    final pendingAsk = bloc.state.pendingAsk;
    final resolvedAskId = askId ?? pendingAsk?.id;

    _holdingMic = false;
    await _speech.stop();
    setState(() => _listening = false);

    List<AgentAttachment> attachments = List.of(_staged);
    if (attachments.isNotEmpty) {
      setState(() => _uploading = true);
      try {
        attachments = await _uploadStaged(attachments);
      } catch (e) {
        if (!mounted) return;
        setState(() => _uploading = false);
        showAppErrorSnackBar(context, e, action: 'uploading file');
        return;
      }
      if (!mounted) return;
      setState(() => _uploading = false);
    }

    bloc.add(
      AgentSubmit(
        message: text,
        attachments: attachments,
        askId: resolvedAskId,
      ),
    );
    _input.clear();
    setState(() => _staged.clear());
  }

  Future<List<AgentAttachment>> _uploadStaged(
    List<AgentAttachment> items,
  ) async {
    final api = context.read<ApiService>();
    final out = <AgentAttachment>[];
    for (final item in items) {
      if ((item.url ?? '').trim().isNotEmpty) {
        out.add(item);
        continue;
      }
      final path = item.localPath;
      if (path == null || path.isEmpty) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      final isVideo = item.kind == 'video' || productFileLooksLikeVideo(path);
      final folder = item.kind == 'file'
          ? ApiService.chatbotStorageFolder
          : ApiService.productImageStorageFolder;
      final url = await api.uploadFile(
        file: file,
        filename: item.name,
        storageFolder: folder,
      );
      out.add(
        AgentAttachment(
          kind: isVideo ? 'video' : item.kind,
          url: url,
          name: item.name,
          mime: item.mime,
          localPath: path,
        ),
      );
    }
    return out;
  }

  Future<void> _attachForAsk(AgentAskSpec ask) async {
    switch (ask.kind) {
      case 'image':
        await _pickImage();
        break;
      case 'video':
        await _pickVideo();
        break;
      case 'file':
        await _pickFile();
        break;
      default:
        await _openAttachSheet();
    }
    if (_staged.isNotEmpty && ask.kind != 'text' && ask.kind != 'choice') {
      await _send(askId: ask.id);
    }
  }

  Future<void> _openAttachSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        Widget tile(IconData icon, String label, String value) {
          return ListTile(
            leading: Icon(icon, color: _purple),
            title: Text(
              label,
              style: GoogleFonts.poppins(
                color: LightScreenTheme.title,
                fontSize: LightScreenTheme.typeBody,
              ),
            ),
            onTap: () => Navigator.pop(context, value),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(Icons.photo_camera_outlined, 'Take photo', 'photo_camera'),
              tile(
                Icons.photo_library_outlined,
                'Photo from gallery',
                'photo_gallery',
              ),
              tile(Icons.videocam_outlined, 'Record video', 'video_camera'),
              tile(
                Icons.video_library_outlined,
                'Video from gallery',
                'video_gallery',
              ),
              tile(Icons.attach_file, 'Document', 'file'),
            ],
          ),
        );
      },
    );
    if (choice == null) return;
    switch (choice) {
      case 'photo_camera':
        await _pickImage(source: ImageSource.camera);
        break;
      case 'photo_gallery':
        await _pickImage(source: ImageSource.gallery);
        break;
      case 'video_camera':
        await _pickVideo(source: ImageSource.camera);
        break;
      case 'video_gallery':
        await _pickVideo(source: ImageSource.gallery);
        break;
      case 'file':
        await _pickFile();
        break;
    }
  }

  Future<void> _pickImage({ImageSource? source}) async {
    try {
      final picked = await pickDeviceImages(
        context,
        maxCount: 1,
        source: source,
      );
      if (picked.isEmpty) return;
      final file = picked.first;
      setState(() {
        _staged.add(
          AgentAttachment(
            kind: 'image',
            name: file.name,
            localPath: file.path,
            mime: 'image/jpeg',
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      showAppErrorSnackBar(context, e, action: 'picking a photo');
    }
  }

  Future<void> _pickVideo({ImageSource? source}) async {
    try {
      final picked = await pickDeviceVideos(
        context,
        maxCount: 1,
        source: source,
      );
      if (picked.isEmpty) return;
      final file = picked.first;
      setState(() {
        _staged.add(
          AgentAttachment(
            kind: 'video',
            name: file.name,
            localPath: file.path,
            mime: 'video/mp4',
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      showAppErrorSnackBar(context, e, action: 'picking a video');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false);
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      final path = picked.path;
      if (path == null || path.isEmpty) return;
      final video =
          productFileLooksLikeVideo(picked.name) ||
          productFileLooksLikeVideo(path);
      setState(() {
        _staged.add(
          AgentAttachment(
            kind: video ? 'video' : 'file',
            name: picked.name,
            localPath: path,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      showAppErrorSnackBar(context, e, action: 'picking a file');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        widget.onExit();
      },
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppSystemUi.light,
          child: Scaffold(
            backgroundColor: LightScreenTheme.background,
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  _header(),
                  Expanded(
                    child: BlocConsumer<AgentBloc, AgentViewState>(
                      listener: (context, state) => _scrollToEnd(),
                      builder: (context, state) => _messageList(state),
                    ),
                  ),
                  _inputBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        16,
        8,
      ),
      child: SizedBox(
        height: 54,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _modeChip(
                label: 'Dashboard',
                icon: Icons.grid_view_rounded,
                onTap: widget.onExit,
              ),
            ),
            IgnorePointer(
              child: Text(
                'Agentic mode',
                style: GoogleFonts.poppins(
                  color: LightScreenTheme.title,
                  fontSize: LightScreenTheme.headerTitleSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _purple, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: LightScreenTheme.title,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageList(AgentViewState state) {
    if (state.bubbles.isEmpty && state.working) {
      return const Center(child: AutobusLoadingIndicator());
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: state.bubbles.length + (state.working ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.bubbles.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: Row(
              children: [
                const AutobusLoadingIndicator(size: 18),
                const SizedBox(width: 10),
                Text(
                  'Working… this can take a minute',
                  style: GoogleFonts.poppins(
                    color: _muted,
                    fontSize: LightScreenTheme.typeLabel,
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _bubble(state.bubbles[index]),
        );
      },
    );
  }

  Widget _bubble(AgentBubble bubble) {
    switch (bubble.kind) {
      case AgentBubbleKind.confirm:
        return _confirmCard(bubble);
      case AgentBubbleKind.ask:
        return _askCard(bubble);
      case AgentBubbleKind.user:
        return _textRow(bubble, isUser: true);
      case AgentBubbleKind.assistant:
        return _textRow(bubble, isUser: false);
    }
  }

  Widget _textRow(AgentBubble bubble, {required bool isUser}) {
    return AppChatBubble(
      fromUser: isUser,
      failed: bubble.failed,
      text: isUser ? bubble.text : stripAiMarkdown(bubble.text),
      child: bubble.attachments.isNotEmpty
          ? _mediaPreviews(bubble.attachments)
          : null,
    );
  }

  Widget _confirmCard(AgentBubble bubble) {
    final spec = bubble.confirm;
    if (spec == null) return _textRow(bubble, isUser: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.title,
                      style: GoogleFonts.poppins(
                        color: LightScreenTheme.title,
                        fontSize: LightScreenTheme.typeTitle,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      spec.summary,
                      style: GoogleFonts.poppins(
                        color: _text,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    if (bubble.attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _mediaPreviews(bubble.attachments),
                    ],
                    if (!bubble.resolved) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _cardButton(
                              label: 'Approve',
                              filled: true,
                              onTap: () => context.read<AgentBloc>().add(
                                AgentConfirm(
                                  confirmId: spec.id,
                                  approved: true,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _cardButton(
                              label: 'Not now',
                              filled: false,
                              onTap: () => context.read<AgentBloc>().add(
                                AgentConfirm(
                                  confirmId: spec.id,
                                  approved: false,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Decision sent',
                          style: GoogleFonts.poppins(
                            color: _muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _askCard(AgentBubble bubble) {
    final spec = bubble.ask;
    if (spec == null) return _textRow(bubble, isUser: false);
    final kindLabel = switch (spec.kind) {
      'image' => 'Add photo',
      'video' => 'Add video',
      'file' => 'Add file',
      'choice' => 'Choose',
      _ => 'Reply below',
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _purple.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.prompt,
                  style: GoogleFonts.poppins(
                    color: _text,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                if (spec.choices.isNotEmpty && !bubble.resolved) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final choice in spec.choices)
                        GestureDetector(
                          onTap: () =>
                              _send(choiceText: choice.label, askId: spec.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _tint,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _purple),
                            ),
                            child: Text(
                              choice.label,
                              style: GoogleFonts.poppins(
                                color: _purple,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (!bubble.resolved &&
                    spec.kind != 'text' &&
                    spec.kind != 'choice') ...[
                  const SizedBox(height: 12),
                  _cardButton(
                    label: kindLabel,
                    filled: true,
                    onTap: () => _attachForAsk(spec),
                  ),
                ],
                if (bubble.resolved)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Received',
                      style: GoogleFonts.poppins(color: _muted, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cardButton({
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? LightScreenTheme.button : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: filled ? null : Border.all(color: _divider),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: filled ? Colors.white : LightScreenTheme.body,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _mediaPreviews(List<AgentAttachment> items) {
    final media = items
        .where(
          (item) =>
              (item.url ?? '').trim().isNotEmpty &&
              (item.kind == 'image' || item.kind == 'video'),
        )
        .toList();
    if (media.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (var i = 0; i < media.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: media[i].kind == 'video'
                ? _AgentInlineVideo(url: media[i].url!.trim())
                : AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(
                      media[i].url!.trim(),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const ColoredBox(
                          color: _placeholder,
                          child: Center(
                            child: AutobusLoadingIndicator(size: 28),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: _placeholder,
                        child: Center(
                          child: Text(
                            'Could not load image',
                            style: GoogleFonts.poppins(
                              color: _muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  Future<void> _toggleMic() async {
    if (_holdingMic) {
      await _finishHoldRecord(send: false);
    } else {
      await _startHoldRecord();
    }
  }

  Widget _stagedChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _staged.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = _staged[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _tint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.kind == 'video'
                        ? Icons.videocam_outlined
                        : item.kind == 'file'
                        ? Icons.insert_drive_file_outlined
                        : Icons.image_outlined,
                    color: _purple,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.name ?? item.kind,
                    style: GoogleFonts.poppins(color: _text, fontSize: 11),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _staged.removeAt(index)),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.close, color: _muted, size: 14),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _inputBar() {
    final canSend =
        (_input.text.trim().isNotEmpty || _staged.isNotEmpty) && !_uploading;
    return AppChatComposer(
      controller: _input,
      canSend: canSend,
      onSend: () => _send(),
      onAttach: _openAttachSheet,
      onMic: _toggleMic,
      listening: _listening,
      busy: _uploading,
      hintText: 'Tell Autobus what to do...',
      header: _staged.isEmpty ? null : _stagedChips(),
    );
  }
}

class _AgentInlineVideo extends StatefulWidget {
  const _AgentInlineVideo({required this.url});

  final String url;

  @override
  State<_AgentInlineVideo> createState() => _AgentInlineVideoState();
}

class _AgentInlineVideoState extends State<_AgentInlineVideo> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: const {'User-Agent': 'Autobus/1.0'},
    );
    controller
        .initialize()
        .then((_) {
          if (!mounted) {
            controller.dispose();
            return;
          }
          setState(() => _controller = controller);
          controller.setLooping(true);
          controller.play();
        })
        .catchError((_) {
          controller.dispose();
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return ColoredBox(
        color: const Color(0xFFF1F5F9),
        child: SizedBox(
          height: 180,
          child: Center(
            child: Text(
              'Could not load video',
              style: GoogleFonts.poppins(
                color: const Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Color(0xFFF1F5F9),
        child: SizedBox(
          height: 180,
          child: Center(child: AutobusLoadingIndicator(size: 28)),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: controller.value.aspectRatio == 0
          ? 16 / 9
          : controller.value.aspectRatio,
      child: VideoPlayer(controller),
    );
  }
}
