import 'dart:io';

import 'package:autobus/barrel.dart';
import 'package:autobus/features/agent/agent_bloc.dart';
import 'package:autobus/features/agent/agent_event.dart';
import 'package:autobus/features/agent/agent_repository.dart';
import 'package:autobus/features/agent/agent_state.dart';
import 'package:autobus/features/agent/models/agent_models.dart';
import 'package:autobus/features/products/product_media.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

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
  static const _purple = Color(0xFFA855F7);
  static const _deep = Color(0xFF2A1447);
  static const _panel = Color(0xFF1A1028);

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _speech = SpeechToText();
  final _picker = ImagePicker();

  bool _speechReady = false;
  bool _listening = false;
  bool _uploading = false;
  String _partialSpeech = '';
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

  Future<void> _toggleListen() async {
    if (!_speechReady) {
      showAppSnackBar(
        context,
        'Microphone or speech recognition is not available on this device.',
      );
      return;
    }
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() {
      _listening = true;
      _partialSpeech = '';
    });
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _partialSpeech = result.recognizedWords;
          if (result.recognizedWords.trim().isNotEmpty) {
            _input.text = result.recognizedWords;
            _input.selection = TextSelection.collapsed(
              offset: _input.text.length,
            );
          }
        });
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _send();
        }
      },
    );
  }

  Future<void> _send({String? choiceText, String? askId}) async {
    if (_uploading) return;
    if (context.read<AgentBloc>().state.working) return;
    final text = (choiceText ?? _input.text).trim();
    if (text.isEmpty && _staged.isEmpty) return;

    final bloc = context.read<AgentBloc>();
    final pendingAsk = bloc.state.pendingAsk;
    final resolvedAskId = askId ?? pendingAsk?.id;

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
    setState(() {
      _staged.clear();
      _partialSpeech = '';
    });
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
      backgroundColor: const Color(0xFF160A2C),
      showDragHandle: true,
      builder: (context) {
        Widget tile(IconData icon, String label, String value) {
          return ListTile(
            leading: Icon(icon, color: Colors.white70),
            title: Text(
              label,
              style: GoogleFonts.montserrat(color: Colors.white),
            ),
            onTap: () => Navigator.pop(context, value),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(Icons.photo_camera_outlined, 'Take photo', 'photo_camera'),
              tile(Icons.photo_library_outlined, 'Photo from gallery', 'photo_gallery'),
              tile(Icons.videocam_outlined, 'Record video', 'video_camera'),
              tile(Icons.video_library_outlined, 'Video from gallery', 'video_gallery'),
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
      final file = await _picker.pickImage(
        source: source ?? ImageSource.gallery,
        imageQuality: 88,
      );
      if (file == null) return;
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
      final file = await _picker.pickVideo(
        source: source ?? ImageSource.gallery,
      );
      if (file == null) return;
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
      final video = productFileLooksLikeVideo(picked.name) ||
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
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: DecoratedBox(
          decoration: ManageScreenStyle.homeDashboardBodyDecoration,
          child: SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: BlocConsumer<AgentBloc, AgentViewState>(
                    listener: (context, state) => _scrollToEnd(),
                    builder: (context, state) {
                      return Stack(
                        children: [
                          _messageList(state),
                          if (_listening) _listeningOverlay(),
                        ],
                      );
                    },
                  ),
                ),
                _inputBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            _modeChip(
              label: 'Dashboard',
              icon: Icons.grid_view_rounded,
              onTap: widget.onExit,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Autobus',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Agent mode',
                    style: GoogleFonts.montserrat(
                      color: _purple.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const CreditAvatar(creditCategory: CreditCategory.llm),
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
          border: Border.all(color: const Color(0xFF3F1163)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.montserrat(
                color: Colors.white,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: state.bubbles.length + (state.working ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.bubbles.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Row(
              children: [
                _botAvatar(),
                const SizedBox(width: 10),
                Text(
                  _listening ? 'Listening…' : 'Working…',
                  style: GoogleFonts.montserrat(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
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
    final maxWidth = MediaQuery.sizeOf(context).width * 0.74;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[_botAvatar(), const SizedBox(width: 8)],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? _panel : _deep,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 16 : 4),
                  topRight: Radius.circular(isUser ? 4 : 16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
                border: Border.all(
                  color: const Color(0xFF3F1163).withValues(alpha: 0.7),
                ),
              ),
              child: Text(
                stripAiMarkdown(bubble.text),
                style: GoogleFonts.montserrat(
                  color: Colors.white.withValues(alpha: bubble.failed ? 0.75 : 1),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
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
            _botAvatar(),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF3F1163)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.title,
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      spec.summary,
                      style: GoogleFonts.montserrat(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
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
                          style: GoogleFonts.montserrat(
                            color: Colors.white38,
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
        _botAvatar(),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _purple.withValues(alpha: 0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.prompt,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
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
                          onTap: () => _send(
                            choiceText: choice.label,
                            askId: spec.id,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _purple),
                            ),
                            child: Text(
                              choice.label,
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (!bubble.resolved && spec.kind != 'text' && spec.kind != 'choice') ...[
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
                      style: GoogleFonts.montserrat(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
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
          color: filled ? _purple : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: filled ? null : Border.all(color: const Color(0xFF3F1163)),
        ),
        child: Text(
          label,
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _botAvatar() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _deep,
        border: Border.all(color: _purple.withValues(alpha: 0.6)),
      ),
      child: const Icon(Icons.auto_awesome, color: _purple, size: 16),
    );
  }

  Widget _listeningOverlay() {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _purple.withValues(alpha: 0.18),
                  border: Border.all(color: _purple, width: 1.4),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withValues(alpha: 0.35),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                _partialSpeech.trim().isEmpty
                    ? 'Listening…'
                    : _partialSpeech,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputBar() {
    final canSend =
        (_input.text.trim().isNotEmpty || _staged.isNotEmpty) && !_uploading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _listening ? _purple : const Color(0xFF3F1163),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_staged.isNotEmpty) ...[
              SizedBox(
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
                        color: _deep,
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
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.name ?? item.kind,
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _staged.removeAt(index)),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.close,
                                color: Colors.white54,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: _input,
                cursorColor: _purple,
                minLines: 1,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                onTapOutside: dismissAppKeyboard,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: _listening
                      ? 'Listening…'
                      : 'Tell Autobus what to do…',
                  hintStyle: GoogleFonts.montserrat(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _uploading ? null : _openAttachSheet,
                  icon: const Icon(Icons.add_rounded, color: _purple, size: 26),
                ),
                const SizedBox(width: 8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _uploading ? null : _toggleListen,
                  icon: Icon(
                    _listening ? Icons.stop_circle_outlined : Icons.mic_none,
                    color: _listening ? _purple : Colors.white70,
                    size: 24,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: canSend ? () { _send(); } : null,
                  child: Icon(
                    Icons.send_rounded,
                    color: canSend
                        ? _purple
                        : Colors.white.withValues(alpha: 0.28),
                    size: 22,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
