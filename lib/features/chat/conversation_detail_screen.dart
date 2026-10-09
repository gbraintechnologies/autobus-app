import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/app_chat.dart';
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

class _PendingMessage {
  _PendingMessage(this.text);

  final String text;
  bool failed = false;
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _loadError;
  bool _actionBusy = false;
  bool _sending = false;
  final List<_PendingMessage> _pending = [];
  int _detailRevision = 0;
  Timer? _livePollTimer;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _messageCtrl.addListener(() {
      if (mounted) setState(() {});
    });
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
    _livePollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_pollLiveSession());
    });
  }

  void _stopLivePolling() {
    _livePollTimer?.cancel();
    _livePollTimer = null;
  }

  void _setDetail(Map<String, dynamic> detail) {
    _detail = detail;
    _detailRevision++;
  }

  Future<void> _pollLiveSession() async {
    if (!mounted || _loading || _sending || _polling || _actionBusy) return;
    if (_isCompleted) return;
    final sid = _resolvedSessionId;
    if (sid == null) return;

    _polling = true;
    final revision = _detailRevision;
    try {
      final api = context.read<ApiService>();
      final detail = await api.getConversationSession(sid);
      if (!mounted || _sending || revision != _detailRevision) return;

      final prevLen = _history.length;
      final raw = detail['conversation_history'];
      final nextLen = raw is List ? raw.length : 0;
      if (nextLen < prevLen) return;

      setState(() => _setDetail(detail));

      final lifecycle = (detail['conversation_lifecycle'] ?? '')
          .toString()
          .toLowerCase();
      if (lifecycle == 'completed') {
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

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final api = context.read<ApiService>();
      final sid = widget.sessionId;
      if (sid == null) {
        throw Exception('Missing conversation session');
      }
      final detail = await api.getConversationSession(sid);
      if (!mounted) return;
      setState(() {
        _setDetail(detail);
        _loading = false;
      });
      _scrollToBottom();
      final lifecycle = (detail['conversation_lifecycle'] ?? '')
          .toString()
          .toLowerCase();
      if (lifecycle != 'completed' && _livePollTimer == null) {
        _startLivePolling();
      }
    } catch (e) {
      if (!mounted) return;
      if (!showSpinner) return;
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
    final v = (_detail?['conversation_lifecycle'] ?? '')
        .toString()
        .toLowerCase();
    return v == 'completed';
  }

  bool get _showComposer => _interventionActive && !_isCompleted;

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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Mark as completed?',
          style: GoogleFonts.poppins(
            color: LightScreenTheme.title,
            fontSize: LightScreenTheme.typeTitle,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Text(
          'This ends the intervention. The next customer message will start a new conversation with the assistant.',
          style: GoogleFonts.poppins(
            color: LightScreenTheme.muted,
            fontSize: LightScreenTheme.typeBody,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: LightScreenTheme.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Complete',
              style: GoogleFonts.poppins(
                color: LightScreenTheme.accent,
                fontWeight: FontWeight.w500,
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
        _setDetail(updated);
        _actionBusy = false;
      });
      _stopLivePolling();
      showAppSnackBar(context, 'Conversation marked as completed');
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      showAppSnackBar(context, userFacingError(e, action: 'completing chat'));
    }
  }

  Future<void> _intervene() async {
    final sid = _resolvedSessionId;
    if (sid == null || _interventionActive || _isCompleted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Intervene in this chat?',
          style: GoogleFonts.poppins(
            color: LightScreenTheme.title,
            fontSize: LightScreenTheme.typeTitle,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Text(
          'The assistant will stop replying. You can answer the customer until you mark this chat completed.',
          style: GoogleFonts.poppins(
            color: LightScreenTheme.muted,
            fontSize: LightScreenTheme.typeBody,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: LightScreenTheme.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Intervene',
              style: GoogleFonts.poppins(
                color: LightScreenTheme.accent,
                fontWeight: FontWeight.w500,
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
      final updated = await api.activateConversationIntervention(sid);
      if (!mounted) return;
      setState(() {
        _setDetail(updated);
        _actionBusy = false;
      });
      _startLivePolling();
      showAppSnackBar(
        context,
        'You are intervening. The assistant will not reply.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      showAppSnackBar(context, userFacingError(e, action: 'intervening'));
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _messageCtrl.clear();
    await _deliver(_PendingMessage(text), isNew: true);
  }

  Future<void> _deliver(_PendingMessage msg, {bool isNew = false}) async {
    final sid = _resolvedSessionId;
    if (sid == null || _sending) return;

    setState(() {
      if (isNew) _pending.add(msg);
      msg.failed = false;
      _sending = true;
    });
    _scrollToBottom();

    try {
      final api = context.read<ApiService>();
      final updated = await api.sendInterventionHumanMessage(
        msg.text,
        sessionId: sid,
      );
      if (!mounted) return;
      final hasHistory = updated['conversation_history'] is List;
      setState(() {
        if (hasHistory) _setDetail(updated);
        _pending.remove(msg);
        _sending = false;
      });
      if (!hasHistory) {
        await _load(showSpinner: false);
      }
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        msg.failed = true;
        _sending = false;
      });
      showAppSnackBar(context, userFacingError(e, action: 'sending message'));
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
            if (!_loading && _loadError == null) _buildStatus(),
            Expanded(
              child: Stack(
                children: [
                  _buildBody(),
                  if (!_isCompleted)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: _buildFloatingActions(),
                    ),
                ],
              ),
            ),
            if (_showComposer) _buildComposer(),
          ],
        ),
      ),
    );
  }

  String get _cycleHint {
    if (_isCompleted) {
      return 'Completed. The next customer message starts a new assistant chat.';
    }
    if (_interventionActive) {
      return 'Intervening. The assistant will not reply until this chat is completed.';
    }
    return 'Open. The assistant is replying and can complete this chat on its own.';
  }

  Widget _buildStatus() {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    return Padding(
      padding: EdgeInsets.fromLTRB(20 * scale, 12 * scale, 20 * scale, 0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _isCompleted
                  ? LightScreenTheme.muted
                  : _interventionActive
                      ? LightScreenTheme.warning
                      : const Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: Text(
              _cycleHint,
              style: GoogleFonts.poppins(
                color: LightScreenTheme.muted,
                fontSize: LightScreenTheme.typeCaption,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActions() {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _floatingAction(
          scale,
          label: _interventionActive ? 'Intervening' : 'Intervene',
          icon: Icons.support_agent_rounded,
          filled: _interventionActive,
          fillColor: LightScreenTheme.accent,
          onTap: (_actionBusy || _interventionActive) ? null : _intervene,
        ),
        SizedBox(height: 10 * scale),
        _floatingAction(
          scale,
          label: 'Completed',
          icon: Icons.check_rounded,
          filled: true,
          fillColor: LightScreenTheme.button,
          onTap: _actionBusy ? null : _completeConversation,
        ),
      ],
    );
  }

  Widget _floatingAction(
    double scale, {
    required String label,
    required IconData icon,
    required bool filled,
    required Color fillColor,
    required VoidCallback? onTap,
  }) {
    final foreground = filled ? Colors.white : LightScreenTheme.button;
    final background = filled ? fillColor : Colors.white;
    return Opacity(
      opacity: onTap == null && !_interventionActive ? 0.55 : 1,
      child: Material(
        color: background,
        elevation: 6,
        shadowColor: const Color(0x402D0C51),
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12 * scale, 8 * scale, 8 * scale, 8 * scale),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: foreground,
                    fontSize: LightScreenTheme.typeLabel,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 8 * scale),
                Container(
                  width: 36 * scale,
                  height: 36 * scale,
                  decoration: BoxDecoration(
                    color: filled ? Colors.white.withValues(alpha: 0.16) : LightScreenTheme.field,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18 * scale, color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return AppChatComposer(
      controller: _messageCtrl,
      canSend: _messageCtrl.text.trim().isNotEmpty && !_sending,
      onSend: _sendMessage,
      hintText: 'Reply as agent...',
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
                style: GoogleFonts.poppins(
                  color: LightScreenTheme.muted,
                  fontSize: LightScreenTheme.typeBody,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _load,
                child: Text(
                  'Retry',
                  style: GoogleFonts.poppins(color: LightScreenTheme.accent),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final history = _history;
    if (history.isEmpty && _pending.isEmpty) {
      return Center(
        child: Text(
          _showComposer
              ? 'No messages yet — send a reply below'
              : 'No messages in this conversation',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: LightScreenTheme.muted,
            fontSize: LightScreenTheme.typeBody,
          ),
        ),
      );
    }

    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    final itemCount = history.length + _pending.length;
    return ListView.builder(
      controller: _scrollCtrl,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        16 * scale,
        16 * scale,
        16 * scale,
        (_isCompleted ? 24 : 120) * scale,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= history.length) {
          final p = _pending[index - history.length];
          return Padding(
            padding: EdgeInsets.only(bottom: 16 * scale),
            child: GestureDetector(
              onTap: p.failed ? () => _deliver(p) : null,
              child: _messageRow(
                scale,
                p.text,
                role: 'human',
                footer: p.failed ? "Couldn't send · Tap to retry" : 'Sending…',
                failed: p.failed,
              ),
            ),
          );
        }
        final msg = history[index];
        final role = (msg['role'] ?? '').toString().toLowerCase();
        final content = (msg['content'] ?? '').toString();
        return Padding(
          padding: EdgeInsets.only(bottom: 16 * scale),
          child: _messageRow(
            scale,
            content,
            role: role,
            footer: _formatTime(msg['timestamp'] ?? msg['created_at']),
          ),
        );
      },
    );
  }

  String? _formatTime(dynamic raw) {
    if (raw == null) return null;
    final dt = DateTime.tryParse(raw.toString())?.toLocal();
    if (dt == null) return null;
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }

  Widget _messageRow(
    double scale,
    String text, {
    required String role,
    String? footer,
    bool failed = false,
  }) {
    final isCustomer = role == 'user';
    return AppChatBubble(
      fromUser: isCustomer,
      alignRight: !isCustomer,
      label: isCustomer
          ? null
          : (role == 'human' ? 'You · Agent' : 'Autobus AI'),
      text: isCustomer ? text : stripAiMarkdown(text),
      footer: footer,
      failed: failed,
    );
  }
}
