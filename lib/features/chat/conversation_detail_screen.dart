import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';

/// How the conversation screen was opened (controls which actions appear).
enum ConversationScreenMode {
  /// Completed / all chats — history only.
  historyOnly,

  /// Live chat with active intervention — history + agent messaging.
  liveChat,
}

class ConversationDetailScreen extends StatefulWidget {
  final String title;
  final ConversationScreenMode mode;

  /// Daily conversation session id (`DailyConversation.id` from list API).
  final int? sessionId;

  const ConversationDetailScreen({
    super.key,
    required this.title,
    required this.mode,
    this.sessionId,
  });

  @override
  State<ConversationDetailScreen> createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  static const Color _bubbleUser = Color(0xFF3F1163);
  static const Color _bubbleOther = Color(0xFF1E0A32);

  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _loadError;
  bool _actionBusy = false;
  bool _sending = false;
  Timer? _livePollTimer;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _stopLivePolling();
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _startLivePolling() {
    _stopLivePolling();
    if (widget.mode != ConversationScreenMode.liveChat) return;
    _livePollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_pollLiveSession());
    });
  }

  void _stopLivePolling() {
    _livePollTimer?.cancel();
    _livePollTimer = null;
  }

  Future<void> _pollLiveSession() async {
    if (!mounted || _loading || _sending || _polling || _actionBusy) return;
    if (widget.mode != ConversationScreenMode.liveChat) return;
    final sid = _resolvedSessionId;
    if (sid == null) return;

    _polling = true;
    try {
      final api = context.read<ApiService>();
      final detail = await api.getConversationSession(sid);
      if (!mounted) return;

      final prevLen = _history.length;
      final raw = detail['conversation_history'];
      final nextLen = raw is List ? raw.length : 0;

      setState(() => _detail = detail);

      final active = detail['intervention_active'];
      final isActive =
          active is bool ? active : active?.toString().toLowerCase() == 'true';
      final lifecycle =
          (detail['conversation_lifecycle'] ?? '').toString().toLowerCase();
      if (!isActive || lifecycle == 'completed') {
        _stopLivePolling();
      } else if (nextLen > prevLen) {
        _scrollToBottom();
      }
    } catch (_) {
      // Polling is best-effort; ignore transient errors.
    } finally {
      _polling = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiService>();
      final sid = widget.sessionId;
      if (sid == null) {
        throw Exception('Missing conversation session');
      }
      final detail = await api.getConversationSession(sid);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
      _scrollToBottom();
      if (widget.mode == ConversationScreenMode.liveChat) {
        final active = detail['intervention_active'];
        final isActive =
            active is bool ? active : active?.toString().toLowerCase() == 'true';
        if (isActive) {
          _startLivePolling();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e);
        _loading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  List<Map<String, dynamic>> get _history {
    final raw = _detail?['conversation_history'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  int? get _resolvedSessionId {
    final fromDetail = _detail?['id'];
    if (fromDetail is int) return fromDetail;
    if (fromDetail is num) return fromDetail.toInt();
    return widget.sessionId;
  }

  bool get _interventionActive {
    final v = _detail?['intervention_active'];
    if (v is bool) return v;
    return v?.toString().toLowerCase() == 'true';
  }

  bool get _isCompleted {
    final v = (_detail?['conversation_lifecycle'] ?? '').toString().toLowerCase();
    return v == 'completed';
  }

  bool get _showComposer =>
      widget.mode == ConversationScreenMode.liveChat &&
      _interventionActive &&
      !_isCompleted;

  String get _headerTitle {
    final detail = _detail;
    if (detail != null) {
      final username = (detail['customer_username'] ?? '').toString().trim();
      final phone = (detail['customer_phone'] ?? '').toString().trim();
      final displayName =
          (detail['customer_display_name'] ?? detail['user_fullname'] ?? '')
              .toString()
              .trim();
      final handle = username.isEmpty
          ? ''
          : (username.startsWith('@') ? username : '@$username');
      if (handle.isNotEmpty && phone.isNotEmpty) return '$handle · $phone';
      if (handle.isNotEmpty) return handle;
      if (phone.isNotEmpty) return phone;
      if (displayName.isNotEmpty) return displayName;
    }
    return widget.title;
  }

  Future<void> _completeConversation() async {
    final sid = _resolvedSessionId;
    if (sid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E0A32),
        title: Text(
          'Mark as completed?',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This ends the intervention. The next customer message will start a new conversation with the assistant.',
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Complete',
              style: GoogleFonts.outfit(
                color: const Color(0xFFA855F7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _actionBusy = true);
    try {
      final api = context.read<ApiService>();
      final updated = await api.completeConversationSession(sid);
      if (!mounted) return;
      setState(() {
        _detail = updated;
        _actionBusy = false;
      });
      _stopLivePolling();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation marked as completed')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    final sid = _resolvedSessionId;
    if (text.isEmpty || sid == null || _sending) return;

    setState(() => _sending = true);
    try {
      final api = context.read<ApiService>();
      final updated = await api.sendInterventionHumanMessage(
        text,
        sessionId: sid,
      );
      if (!mounted) return;
      _messageCtrl.clear();
      final hasHistory = updated.containsKey('conversation_history');
      setState(() {
        if (hasHistory || updated.containsKey('id')) {
          _detail = updated;
        }
        _sending = false;
      });
      if (hasHistory) {
        _scrollToBottom();
      } else {
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: LightScreenScaffold(
        title: _headerTitle,
        creditCategory: CreditCategory.llm,
        resizeToAvoidBottomInset: true,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_loading && _loadError == null) _buildControls(),
            Expanded(child: _buildBody()),
            if (_showComposer) _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    if (widget.mode == ConversationScreenMode.liveChat &&
        _interventionActive &&
        !_isCompleted) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _actionBusy ? null : _completeConversation,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFA855F7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: _actionBusy
                ? const AutobusLoadingIndicator(size: 18)
                : const Icon(Icons.check_circle_outline, size: 20),
            label: Text(
              'Mark as completed',
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      );
    }

    if (_isCompleted) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Text(
          'This conversation is completed. A new customer message will start a fresh assistant chat.',
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildComposer() {
    final canSend = _messageCtrl.text.trim().isNotEmpty && !_sending;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF3F1163)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _messageCtrl,
              enabled: !_sending,
              cursorColor: const Color(0xFFA855F7),
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: 1,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              onSubmitted: canSend ? (_) => _sendMessage() : null,
              onTapOutside: dismissAppKeyboard,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Reply as agent…',
                hintStyle: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Row(
              children: [
                const Spacer(),
                IconButton(
                  onPressed: canSend ? _sendMessage : null,
                  icon: _sending
                      ? const AutobusLoadingIndicator(size: 22)
                      : Icon(
                          Icons.send_rounded,
                          color: canSend
                              ? const Color(0xFFA855F7)
                              : Colors.white.withValues(alpha: 0.25),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: AutobusLoadingIndicator(size: 32));
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _load,
                child: Text(
                  'Retry',
                  style: GoogleFonts.outfit(color: const Color(0xFFA855F7)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final history = _history;
    if (history.isEmpty) {
      return GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Text(
            _showComposer
                ? 'No messages yet — send a reply below'
                : 'No messages in this conversation',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final msg = history[index];
        final role = (msg['role'] ?? '').toString().toLowerCase();
        final content = (msg['content'] ?? '').toString();
        final isUser = role == 'user';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: _messageBubble(content, isUser: isUser, role: role),
          ),
        );
      },
    );
  }

  Widget _messageBubble(String text, {required bool isUser, required String role}) {
    final bg = isUser ? _bubbleUser : _bubbleOther;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isUser ? 16 : 4),
            topRight: Radius.circular(isUser ? 4 : 16),
            bottomLeft: const Radius.circular(16),
            bottomRight: const Radius.circular(16),
          ),
          border: Border.all(
            color: const Color(0xFF3F1163).withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (role == 'human')
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Agent',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFA855F7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Text(
              isUser ? text : stripAiMarkdown(text),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
