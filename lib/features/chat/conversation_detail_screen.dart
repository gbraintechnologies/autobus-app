import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/icons/home_figma_icons.dart';

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
  static const _muted = Color(0xFF94A3B8);
  static const _bubbleText = Color(0xFF475569);
  static const _divider = Color(0xFFE2E8F0);
  static const _gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
  );

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

  void _setDetail(Map<String, dynamic> detail) {
    _detail = detail;
    _detailRevision++;
  }

  Future<void> _pollLiveSession() async {
    if (!mounted || _loading || _sending || _polling || _actionBusy) return;
    if (widget.mode != ConversationScreenMode.liveChat) return;
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
      if (widget.mode == ConversationScreenMode.liveChat) {
        final active = detail['intervention_active'];
        final isActive =
            active is bool ? active : active?.toString().toLowerCase() == 'true';
        if (isActive && _livePollTimer == null) {
          _startLivePolling();
        }
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
            if (!_loading && _loadError == null) _buildControls(),
            Expanded(child: _buildBody()),
            if (_showComposer) _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    if (_showComposer) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20 * scale, 12 * scale, 20 * scale, 0),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 8 * scale),
            Expanded(
              child: Text(
                "You're chatting live",
                style: GoogleFonts.poppins(
                  color: LightScreenTheme.body,
                  fontSize: LightScreenTheme.typeLabel,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              height: 34 * scale,
              child: OutlinedButton.icon(
                onPressed: _actionBusy ? null : _completeConversation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: LightScreenTheme.accent,
                  side: const BorderSide(color: LightScreenTheme.accent),
                  padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                  shape: const StadiumBorder(),
                ),
                icon: _actionBusy
                    ? const AutobusLoadingIndicator(size: 14)
                    : const Icon(Icons.check_circle_outline, size: 16),
                label: Text(
                  'Mark as completed',
                  style: GoogleFonts.poppins(
                    fontSize: LightScreenTheme.typeLabel,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isCompleted) {
      return Container(
        margin: EdgeInsets.fromLTRB(20 * scale, 12 * scale, 20 * scale, 0),
        padding: EdgeInsets.all(12 * scale),
        decoration: BoxDecoration(
          color: LightScreenTheme.surface,
          borderRadius: BorderRadius.circular(12 * scale),
        ),
        child: Text(
          'This conversation is completed. A new customer message will start a fresh assistant chat.',
          style: GoogleFonts.poppins(
            color: LightScreenTheme.muted,
            fontSize: LightScreenTheme.typeCaption,
            height: 1.4,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildComposer() {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    final iconScale = scale.clamp(0.9, 1.05);
    final canSend = _messageCtrl.text.trim().isNotEmpty && !_sending;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        12 * scale,
        0,
        12 * scale,
        12 * scale + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, thickness: 0.5, color: _divider),
          SizedBox(height: 12 * scale),
          Row(
            children: [
              SizedBox(width: 8 * scale),
              Expanded(
                child: TextField(
                  controller: _messageCtrl,
                  minLines: 1,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  cursorColor: LightScreenTheme.accent,
                  onChanged: (_) => setState(() {}),
                  onTapOutside: dismissAppKeyboard,
                  style: GoogleFonts.poppins(color: _bubbleText, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Reply as agent...',
                    hintStyle: GoogleFonts.poppins(color: _muted, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8 * scale),
                  ),
                ),
              ),
              SizedBox(width: 8 * scale),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canSend ? _sendMessage : null,
                  customBorder: const CircleBorder(),
                  child: Opacity(
                    opacity: canSend ? 1 : 0.45,
                    child: Container(
                      width: 40 * scale,
                      height: 40 * scale,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _gradient,
                      ),
                      alignment: Alignment.center,
                      child: _sending
                          ? const AutobusLoadingIndicator(size: 18)
                          : HomeSfIcon(
                              icon: HomeFigmaIcons.sendMail,
                              color: Colors.white,
                              size: 18 * iconScale,
                              fontWeight: FontWeight.w600,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
      padding: EdgeInsets.fromLTRB(16 * scale, 16 * scale, 16 * scale, 24 * scale),
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
    final isAgent = role == 'human';
    final avatarSize = 32 * scale;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: 290 * scale),
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 10 * scale),
      decoration: BoxDecoration(
        color: isCustomer
            ? Colors.white
            : isAgent
            ? LightScreenTheme.button
            : null,
        gradient: !isCustomer && !isAgent ? _gradient : null,
        borderRadius: BorderRadius.circular(16 * scale),
        border: failed
            ? Border.all(color: Colors.redAccent)
            : isCustomer
            ? Border.all(color: _divider)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCustomer)
            Padding(
              padding: EdgeInsets.only(bottom: 2 * scale),
              child: Text(
                isAgent ? 'You · Agent' : 'Autobus AI',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: LightScreenTheme.typeMicro,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Text(
            isCustomer ? text : stripAiMarkdown(text),
            style: GoogleFonts.poppins(
              color: isCustomer ? _bubbleText : Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );

    final column = Column(
      crossAxisAlignment:
          isCustomer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        bubble,
        if (footer != null) ...[
          SizedBox(height: 4 * scale),
          Text(
            footer,
            style: GoogleFonts.poppins(
              color: failed ? Colors.redAccent : _muted,
              fontSize: LightScreenTheme.typeCaption,
            ),
          ),
        ],
      ],
    );

    final avatar = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        color: isCustomer
            ? const Color(0xFFE2E8F0)
            : isAgent
            ? LightScreenTheme.button
            : LightScreenTheme.accent,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: isCustomer
          ? Icon(Icons.person_rounded, size: 18 * scale, color: _bubbleText)
          : isAgent
          ? Icon(Icons.support_agent_rounded, size: 18 * scale, color: Colors.white)
          : HomeSfIcon(
              icon: HomeFigmaIcons.ai,
              color: Colors.white,
              size: 16 * scale.clamp(0.9, 1.05),
              fontWeight: FontWeight.w500,
            ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: isCustomer
          ? [
              avatar,
              SizedBox(width: 10 * scale),
              Expanded(child: column),
            ]
          : [
              Expanded(child: column),
              SizedBox(width: 10 * scale),
              avatar,
            ],
    );
  }
}
