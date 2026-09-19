import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_list_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/icons/home_figma_icons.dart';

/// Lists archived digital marketing payloads from
/// `GET /api/v1/social/digital-marketing/assets`.
class RecentCampaignsPage extends StatefulWidget {
  const RecentCampaignsPage({super.key});

  @override
  State<RecentCampaignsPage> createState() => _RecentCampaignsPageState();
}

class _RecentCampaignsPageState extends State<RecentCampaignsPage> {
  static const _metaGray = Color(0xFF938F8F);

  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _loadError;
  var _newestFirst = true;

  String _bodyText(Map<String, dynamic> m) {
    final t = (m['marketing_text'] ?? '').toString().trim();
    return t.isEmpty ? 'Campaign' : t;
  }

  String _createdLabel(Map<String, dynamic> m) {
    final raw = (m['created_at'] ?? '').toString();
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw.isEmpty ? '—' : raw;
    final d = dt.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$mm/$dd/${d.year}';
  }

  DateTime? _createdAt(Map<String, dynamic> m) {
    return DateTime.tryParse((m['created_at'] ?? '').toString());
  }

  List<Map<String, dynamic>> get _visibleItems {
    final list = List<Map<String, dynamic>>.from(_items);
    list.sort((a, b) {
      final da = _createdAt(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = _createdAt(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return _newestFirst ? db.compareTo(da) : da.compareTo(db);
    });
    return list;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiService>();
      final body = await api.listDigitalMarketingAssets(limit: 50, offset: 0);
      if (!mounted) return;
      final raw = body['items'];
      final list = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map<String, dynamic>) {
            list.add(e);
          } else if (e is Map) {
            list.add(Map<String, dynamic>.from(e));
          }
        }
      }
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e);
        _loading = false;
        _items = const [];
      });
    }
  }

  Future<void> _showFilter() async {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sort campaigns',
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(
                    'Newest first',
                    style: GoogleFonts.poppins(color: Colors.black87),
                  ),
                  trailing: _newestFirst
                      ? HomeSfIcon(
                          icon: HomeFigmaIcons.check,
                          color: LightScreenTheme.accent,
                          size: 18,
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
                ListTile(
                  title: Text(
                    'Oldest first',
                    style: GoogleFonts.poppins(color: Colors.black87),
                  ),
                  trailing: !_newestFirst
                      ? HomeSfIcon(
                          icon: HomeFigmaIcons.check,
                          color: LightScreenTheme.accent,
                          size: 18,
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (choice != null && mounted) {
      setState(() => _newestFirst = choice);
    }
  }

  void _openCampaign(Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString();
    if (id.isNotEmpty) {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CampaignConversationPage(assetId: id),
        ),
      );
      return;
    }
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20 * scale,
              20 * scale,
              20 * scale,
              24 * scale,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'User: ',
                          style: LightScreenTheme.listTitle(scale),
                        ),
                        TextSpan(
                          text: _bodyText(m),
                          style: LightScreenTheme.listTitle(scale).copyWith(
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16 * scale),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Digital marketing',
                          style: LightScreenTheme.listSubtitle(scale).copyWith(
                            color: _metaGray,
                          ),
                        ),
                      ),
                      Text(
                        _createdLabel(m),
                        style: LightScreenTheme.listSubtitle(scale).copyWith(
                          color: _metaGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _campaignCard(double scale, Map<String, dynamic> m) {
    return LightListCard(
      scale: scale,
      borderColor: Colors.black,
      onTap: () => _openCampaign(m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'User: ',
                  style: LightScreenTheme.listTitle(scale),
                ),
                TextSpan(
                  text: _bodyText(m),
                  style: LightScreenTheme.listTitle(scale).copyWith(
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 12 * scale),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Digital marketing',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LightScreenTheme.listSubtitle(scale).copyWith(
                    color: _metaGray,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                _createdLabel(m),
                style: LightScreenTheme.listSubtitle(scale).copyWith(
                  color: _metaGray,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * scale),
          Row(
            children: [
              Text(
                'View conversation',
                style: GoogleFonts.poppins(
                  color: LightScreenTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              HomeSfIcon(
                icon: HomeFigmaIcons.chevronRight,
                color: LightScreenTheme.accent,
                size: 16 * scale.clamp(0.9, 1.05),
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
    final items = _visibleItems;

    return LightScreenScaffold(
      title: 'Recent Campaigns',
      titleFontSize: 16,
      trailing: IconButton(
        onPressed: _showFilter,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: 32 * scale,
          minHeight: 32 * scale,
        ),
        icon: HomeSfIcon(
          icon: HomeFigmaIcons.analyticsFilter,
          color: Colors.black,
          size: 22 * scale.clamp(0.9, 1.0),
        ),
      ),
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
                        TextButton.icon(
                          onPressed: _load,
                          icon: HomeSfIcon(
                            icon: HomeFigmaIcons.refresh,
                            size: 18 * scale.clamp(0.9, 1.05),
                            color: LightScreenTheme.accent,
                          ),
                          label: Text(
                            'Retry',
                            style: GoogleFonts.poppins(
                              color: LightScreenTheme.accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
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
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.22,
                            ),
                            Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 28 * scale,
                                ),
                                child: Text(
                                  'No campaigns yet. Publish from Digital Marketing with Postiz to see them here.',
                                  textAlign: TextAlign.center,
                                  style: LightScreenTheme.emptyState(scale),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            20 * scale,
                            20 * scale,
                            20 * scale,
                            32 * scale,
                          ),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: 8 * scale),
                          itemBuilder: (context, index) {
                            return _campaignCard(scale, items[index]);
                          },
                        ),
                ),
    );
  }
}

/// Loads a saved campaign and shows the chat + media as it was created.
class CampaignConversationPage extends StatefulWidget {
  final String assetId;

  const CampaignConversationPage({super.key, required this.assetId});

  @override
  State<CampaignConversationPage> createState() =>
      _CampaignConversationPageState();
}

class _CampaignConversationPageState extends State<CampaignConversationPage> {
  DigitalMarketingCampaign? _campaign;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiService>();
      final asset = await api.getDigitalMarketingAsset(widget.assetId);
      if (!mounted) return;
      setState(() {
        _campaign = DigitalMarketingCampaign.fromAsset(asset);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e);
        _loading = false;
        _campaign = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaign = _campaign;
    if (campaign != null && !_loading && _loadError == null) {
      return DigitalMarketingPage(campaign: campaign, readOnly: true);
    }

    return LightScreenScaffold(
      title: 'Campaign conversation',
      creditCategory: CreditCategory.imageGen,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: LightScreenTheme.accent))
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _loadError ?? 'Could not open this campaign',
                      textAlign: TextAlign.center,
                      style: LightScreenTheme.emptyState(1),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _load,
                      child: Text(
                        'Retry',
                        style: GoogleFonts.poppins(
                          color: LightScreenTheme.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
