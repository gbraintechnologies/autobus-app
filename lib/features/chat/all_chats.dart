import 'package:autobus/barrel.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: ManageScreenStyle.homeDashboardBodyDecoration,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ManageScreenHeader(
                    title: 'All Chats',
                    creditCategory: CreditCategory.llm,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child:                             const AutobusLoadingIndicator(size: 32),
                          )
                        : _loadError != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    _loadError!,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: _loadChats,
                                  child: Text(
                                    'Retry',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFFA855F7),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFFA855F7),
                            onRefresh: _loadChats,
                            child: _chats.isEmpty
                                ? ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      SizedBox(
                                        height:
                                            MediaQuery.sizeOf(context).height *
                                            0.25,
                                      ),
                                      Center(
                                        child: Text(
                                          'No chats yet',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white.withValues(
                                              alpha: 0.6,
                                            ),
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemCount: _chats.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 16),
                                    itemBuilder: (context, index) {
                                      final c = _chats[index];
                                      return _AllChatTile(
                                        title: _chatListTitle(c),
                                        id: _chatListSubtitlePhoneOrId(c),
                                        date: _formatChatListDate(c),
                                        completed:
                                            (c['conversation_lifecycle'] ?? '')
                                                .toString()
                                                .toLowerCase() ==
                                            'completed',
                                        onTap: () => _openConversation(context, c),
                                      );
                                    },
                                  ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllChatTile extends StatelessWidget {
  final String title;
  final String id;
  final String date;
  final bool completed;
  final VoidCallback? onTap;

  const _AllChatTile({
    required this.title,
    required this.id,
    required this.date,
    this.completed = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 83),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF3F1163), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (completed) ...[
                Text(
                  'Completed',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFA855F7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                date,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
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
