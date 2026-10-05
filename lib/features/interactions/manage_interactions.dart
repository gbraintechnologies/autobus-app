import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_hub_card.dart';
import 'package:autobus/common_design/widgets/light_list_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/icons/home_figma_icons.dart';

class ManageInteractions extends StatelessWidget {
  const ManageInteractions({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Manage Interactions',
      creditCategory: CreditCategory.llm,
      body: SingleChildScrollView(
        padding: LightScreenTheme.hubPagePadding(scale),
        child: Column(
          children: [
            Text(
              'Welcome to Interactions',
              textAlign: TextAlign.center,
              style: LightScreenTheme.hubTitle(scale),
            ),
            SizedBox(height: LightScreenTheme.hubTitleGap * scale),
            Text(
              'Interact with AI-driven analytics to gain insights, monitor performance, and support decision-making.',
              textAlign: TextAlign.center,
              style: LightScreenTheme.hubBody(scale),
            ),
            SizedBox(height: LightScreenTheme.hubToCards * scale),
            LightHubGrid(
              scale: scale,
              children: [
                LightHubCard(
                  scale: scale,
                  title: 'Start Interaction',
                  icon: HomeFigmaIcons.startInteraction,
                  iconGradient: HomeFigmaIcons.interactionsGradient,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const AutoBus(
                          title: 'My Ai',
                          webhookContext: 'interactions_agent',
                        ),
                      ),
                    );
                  },
                ),
                LightHubCard(
                  scale: scale,
                  title: 'View Interactions',
                  icon: HomeFigmaIcons.viewInteractions,
                  iconGradient: HomeFigmaIcons.interactionsGradient,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const InteractionHistoryPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InteractionHistoryPage extends StatefulWidget {
  const InteractionHistoryPage({super.key});

  @override
  State<InteractionHistoryPage> createState() => _InteractionHistoryPageState();
}

class _InteractionHistoryPageState extends State<InteractionHistoryPage> {
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _title(Map<String, dynamic> row) {
    for (final key in [
      'title',
      'last_message',
      'current_intent',
      'summary',
      'product_name',
      'item_name',
    ]) {
      final value = (row[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value.length > 48 ? '${value.substring(0, 48)}..' : value;
      }
    }
    return 'Interaction';
  }

  String _idLabel(Map<String, dynamic> row) {
    for (final key in [
      'conversation_id',
      'session_id',
      'id',
      'reference',
    ]) {
      final value = (row[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _dateLabel(Map<String, dynamic> row) {
    final raw =
        row['updated_at']?.toString() ??
        row['created_at']?.toString() ??
        row['conversation_date']?.toString();
    final dt = DateTime.tryParse(raw ?? '');
    if (dt == null) return '—';
    final d = dt.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd / $mm / ${d.year}';
  }

  int? _sessionId(Map<String, dynamic> row) {
    for (final key in ['session_id', 'daily_conversation_id', 'id']) {
      final raw = row[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      final parsed = int.tryParse(raw?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiService>();
      var list = await api.listInterventions(limit: 100);
      if (list.isEmpty) {
        final grouped = await api.listMyConversations(skip: 0, limit: 100);
        list = [
          ...?grouped['intervention_active'],
          ...?grouped['completed'],
        ];
      }
      if (!mounted) return;
      setState(() {
        _rows = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e);
        _loading = false;
        _rows = const [];
      });
    }
  }

  void _open(Map<String, dynamic> row) {
    final sid = _sessionId(row);
    if (sid == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ConversationDetailScreen(
          title: _title(row),
          mode: ConversationScreenMode.historyOnly,
          sessionId: sid,
        ),
      ),
    );
  }

  Widget _tile(double scale, Map<String, dynamic> row) {
    return LightListCard(
      scale: scale,
      onTap: () => _open(row),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_title(row), style: LightScreenTheme.listTitle(scale)),
          SizedBox(height: 12 * scale),
          Row(
            children: [
              Expanded(
                child: Text(
                  _idLabel(row),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LightScreenTheme.listSubtitle(scale),
                ),
              ),
              SizedBox(width: 12 * scale),
              Text(_dateLabel(row), style: LightScreenTheme.listSubtitle(scale)),
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
      title: 'Interaction History',
      creditCategory: CreditCategory.llm,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: LightScreenTheme.accent),
            )
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
                      onPressed: _load,
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
              onRefresh: _load,
              child: _rows.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.32,
                        ),
                        Center(
                          child: Text(
                            'No interactions yet',
                            style: LightScreenTheme.emptyState(scale),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: LightScreenTheme.listPagePadding(scale),
                      itemCount: _rows.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(height: LightScreenTheme.gridGap * scale),
                      itemBuilder: (context, index) =>
                          _tile(scale, _rows[index]),
                    ),
            ),
    );
  }
}
