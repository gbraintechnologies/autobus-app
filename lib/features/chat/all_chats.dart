import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_list_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';

String _chatListTitle(Map<String, dynamic> c) {
  final last = (c['last_message'] ?? '').toString().trim();
  if (last.isNotEmpty) {
    return last.length > 48 ? '${last.substring(0, 48)}..' : last;
  }
  final intent = (c['current_intent'] ?? '').toString().trim();
  if (intent.isNotEmpty) return intent;
  return 'Chat';
}

String _chatListSubtitleId(Map<String, dynamic> c) {
  final cid = (c['conversation_id'] ?? '').toString().trim();
  if (cid.isNotEmpty) return cid;
  final id = c['id'];
  if (id != null) return 'Session $id';
  return '';
}

/// Customer phone when provided by API; otherwise conversation / session id.
String _chatListSubtitlePhoneOrId(Map<String, dynamic> c) {
  final phone = (c['customer_phone'] ?? '').toString().trim();
  if (phone.isNotEmpty) return phone;
  return _chatListSubtitleId(c);
}

String _formatChatListDate(Map<String, dynamic> c) {
  final raw = c['updated_at']?.toString() ?? c['conversation_date']?.toString();
  final dt = DateTime.tryParse(raw ?? '');
  if (dt == null) return '—';
  final d = dt.toLocal();
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$dd / $mm / ${d.year}';
}

class AllChatsPage extends StatefulWidget {
  const AllChatsPage({super.key});

  @override
  State<AllChatsPage> createState() => _AllChatsPageState();
}

class _AllChatsPageState extends State<AllChatsPage> {
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
          title: _chatListTitle(c),
          mode: ConversationScreenMode.historyOnly,
          sessionId: sid,
        ),
      ),
    );
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
        _chats = grouped['completed'] ?? const [];
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
            _chatListTitle(c),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: LightScreenTheme.listTitle(scale),
          ),
          SizedBox(height: 8 * scale),
          Row(
            children: [
              Expanded(
                child: Text(
                  _chatListSubtitlePhoneOrId(c),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LightScreenTheme.listSubtitle(scale),
                ),
              ),
              SizedBox(width: 12 * scale),
              if ((c['conversation_lifecycle'] ?? '')
                      .toString()
                      .toLowerCase() ==
                  'completed') ...[
                Text(
                  'Completed',
                  style: LightScreenTheme.listSubtitle(scale).copyWith(
                    color: LightScreenTheme.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 8 * scale),
              ],
              Text(
                _formatChatListDate(c),
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

    return LightScreenScaffold(
      title: 'All Chats',
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
                      style: LightScreenTheme.emptyState(scale),
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
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.sizeOf(context).height * 0.32),
                        Center(
                          child: Text(
                            'No chats yet',
                            style: LightScreenTheme.emptyState(scale),
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
