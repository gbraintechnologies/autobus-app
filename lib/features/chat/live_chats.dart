import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_list_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';

String _liveChatTitle(Map<String, dynamic> c) {
  final last = (c['last_message'] ?? '').toString().trim();
  if (last.isNotEmpty) {
    return last.length > 48 ? '${last.substring(0, 48)}..' : last;
  }
  final intent = (c['current_intent'] ?? '').toString().trim();
  if (intent.isNotEmpty) return intent;
  return 'Live chat';
}

String _liveChatSubtitleId(Map<String, dynamic> c) {
  final cid = (c['conversation_id'] ?? '').toString().trim();
  if (cid.isNotEmpty) return cid;
  final id = c['id'];
  if (id != null) return 'Session $id';
  return '';
}

String _liveChatCustomerLabel(Map<String, dynamic> c) {
  final username = (c['customer_username'] ?? '').toString().trim();
  final phone = (c['customer_phone'] ?? '').toString().trim();
  final displayName = (c['customer_display_name'] ?? c['user_fullname'] ?? '')
      .toString()
      .trim();
  final handle = username.isEmpty
      ? ''
      : (username.startsWith('@') ? username : '@$username');
  if (handle.isNotEmpty && phone.isNotEmpty) return '$handle · $phone';
  if (handle.isNotEmpty) return handle;
  if (phone.isNotEmpty) return phone;
  if (displayName.isNotEmpty) return displayName;
  return '';
}

String _liveChatSubtitlePhoneOrId(Map<String, dynamic> c) {
  final label = _liveChatCustomerLabel(c);
  if (label.isNotEmpty) return label;
  return _liveChatSubtitleId(c);
}

String _formatLiveChatDate(Map<String, dynamic> c) {
  final raw = c['updated_at']?.toString() ?? c['conversation_date']?.toString();
  final dt = DateTime.tryParse(raw ?? '');
  if (dt == null) return '—';
  final d = dt.toLocal();
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$dd / $mm / ${d.year}';
}

class LiveChatsPage extends StatefulWidget {
  const LiveChatsPage({super.key});

  @override
  State<LiveChatsPage> createState() => _LiveChatsPageState();
}

class _LiveChatsPageState extends State<LiveChatsPage> {
  List<Map<String, dynamic>> _chats = const [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadChats());
  }

  void _openConversation(BuildContext context, Map<String, dynamic> c) {
    final sessionId = c['id'];
    final sid = sessionId is int
        ? sessionId
        : (sessionId is num ? sessionId.toInt() : null);
    if (sid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConversationDetailScreen(
          title: _liveChatCustomerLabel(c).isNotEmpty
              ? _liveChatCustomerLabel(c)
              : _liveChatTitle(c),
          mode: ConversationScreenMode.liveChat,
          sessionId: sid,
        ),
      ),
    ).then((_) {
      if (mounted) _loadChats();
    });
  }

  Future<void> _loadChats() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiService>();
      final grouped = await api.listMyConversations(skip: 0, limit: 200);
      if (!mounted) return;
      setState(() {
        _chats = grouped['intervention_active'] ?? const [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e);
        _loading = false;
        _chats = const [];
      });
    }
  }

  Widget _chatTile(double scale, Map<String, dynamic> c) {
    return LightListCard(
      scale: scale,
      onTap: () => _openConversation(context, c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _liveChatTitle(c),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: LightScreenTheme.listTitle(scale),
          ),
          SizedBox(height: 8 * scale),
          Row(
            children: [
              Expanded(
                child: Text(
                  _liveChatSubtitlePhoneOrId(c),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LightScreenTheme.listSubtitle(scale),
                ),
              ),
              SizedBox(width: 12 * scale),
              Text(
                _formatLiveChatDate(c),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LightScreenTheme.listSubtitle(scale),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    final emptyStyle = LightScreenTheme.hubBody(scale).copyWith(
      color: const Color(0xFF4E4E4E),
      fontSize: 13 * scale.clamp(0.9, 1.05),
    );

    return LightScreenScaffold(
      title: 'Live Chats',
      titleFontSize: 16,
      creditCategory: CreditCategory.llm,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: LightScreenTheme.accent))
          : _loadError != null
          ? Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28 * scale),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: emptyStyle,
                    ),
                    SizedBox(height: 16 * scale),
                    TextButton(
                      onPressed: _loadChats,
                      child: Text(
                        'Retry',
                        style: LightScreenTheme.listTitle(scale).copyWith(
                          color: LightScreenTheme.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              color: LightScreenTheme.accent,
              onRefresh: _loadChats,
              child: _chats.isEmpty
                  ? CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 29 * scale),
                              child: Text(
                                'No live chats right now',
                                textAlign: TextAlign.center,
                                style: emptyStyle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(20 * scale, 20 * scale, 20 * scale, 32 * scale),
                      itemCount: _chats.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12 * scale),
                      itemBuilder: (context, index) => _chatTile(scale, _chats[index]),
                    ),
            ),
    );
  }
}
