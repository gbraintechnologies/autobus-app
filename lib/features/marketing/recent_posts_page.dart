import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_list_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/features/marketing/tiktok_creator_info.dart';
import 'package:autobus/icons/home_figma_icons.dart';
import 'package:url_launcher/url_launcher.dart';

enum _RecentPostPhase { processing, success, fail }

enum _RecentPostFilter { all, tiktok, youtube, instagram, other }

class _RecentPost {
  _RecentPost({
    required this.id,
    required this.platform,
    required this.label,
    required this.accountName,
    required this.preview,
    required this.whenLabel,
    required this.phase,
    required this.message,
    this.integrationId,
    this.releaseUrl,
    this.scheduled = false,
  });

  final String id;
  final String platform;
  final String label;
  final String accountName;
  final String preview;
  final String whenLabel;
  _RecentPostPhase phase;
  String message;
  final String? integrationId;
  final String? releaseUrl;
  final bool scheduled;

  String get filterKey {
    final p = platform.toLowerCase();
    if (p.contains('tiktok')) return 'tiktok';
    if (p.contains('youtube')) return 'youtube';
    if (p.contains('instagram')) return 'instagram';
    return 'other';
  }
}

class RecentPostsPage extends StatefulWidget {
  const RecentPostsPage({super.key});

  @override
  State<RecentPostsPage> createState() => _RecentPostsPageState();
}

class _RecentPostsPageState extends State<RecentPostsPage> {
  List<_RecentPost> _items = const [];
  bool _loading = true;
  String? _loadError;
  _RecentPostFilter _filter = _RecentPostFilter.all;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiService>();
      final now = DateTime.now().toUtc();
      final raw = await api.listPostizPosts(
        startDate: now.subtract(const Duration(days: 14)).toIso8601String(),
        endDate: now.add(const Duration(minutes: 5)).toIso8601String(),
      );
      if (!mounted) return;
      final items = _postsFromRows(raw);
      setState(() {
        _items = items;
        _loading = false;
      });
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e, action: 'loading recent posts');
        _loading = false;
        _items = const [];
      });
    }
  }

  void _startPolling() {
    _timer?.cancel();
    if (!_items.any((i) => i.phase == _RecentPostPhase.processing)) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      if (!_items.any((i) => i.phase == _RecentPostPhase.processing)) {
        _timer?.cancel();
        return;
      }
      await _refreshStatuses();
    });
  }

  Future<void> _refreshStatuses() async {
    final api = context.read<ApiService>();
    var changed = false;
    for (final item in _items) {
      if (item.phase != _RecentPostPhase.processing) continue;
      if (item.filterKey != 'tiktok') continue;
      final integrationId = item.integrationId?.trim() ?? '';
      if (integrationId.isEmpty) continue;
      try {
        final status = await api.getTikTokPublishStatus(
          integrationId: integrationId,
        );
        if (status.failed) {
          item.phase = _RecentPostPhase.fail;
          item.message = status.message;
          changed = true;
        } else if (status.complete) {
          item.phase = _RecentPostPhase.success;
          item.message = status.message;
          changed = true;
        } else if (status.message.isNotEmpty && status.message != item.message) {
          item.message = status.message;
          changed = true;
        }
      } catch (_) {}
    }
    if (changed && mounted) setState(() {});
  }

  List<_RecentPost> get _visible {
    return _items.where((i) {
      switch (_filter) {
        case _RecentPostFilter.all:
          return true;
        case _RecentPostFilter.tiktok:
          return i.filterKey == 'tiktok';
        case _RecentPostFilter.youtube:
          return i.filterKey == 'youtube';
        case _RecentPostFilter.instagram:
          return i.filterKey == 'instagram';
        case _RecentPostFilter.other:
          return i.filterKey == 'other';
      }
    }).toList()
      ..sort((a, b) {
        const order = {'tiktok': 0, 'youtube': 1, 'instagram': 2, 'other': 3};
        final cmp = (order[a.filterKey] ?? 9).compareTo(order[b.filterKey] ?? 9);
        if (cmp != 0) return cmp;
        return b.whenLabel.compareTo(a.whenLabel);
      });
  }

  static const _metaGray = Color(0xFF938F8F);

  static const _filterLabels = {
    _RecentPostFilter.all: 'All platforms',
    _RecentPostFilter.tiktok: 'TikTok',
    _RecentPostFilter.youtube: 'YouTube',
    _RecentPostFilter.instagram: 'Instagram',
    _RecentPostFilter.other: 'Other',
  };

  Future<void> _showFilter() async {
    final choice = await showModalBottomSheet<_RecentPostFilter>(
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
                  'Filter posts',
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: LightScreenTheme.typeTitle,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                for (final entry in _filterLabels.entries)
                  ListTile(
                    title: Text(
                      entry.value,
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: LightScreenTheme.typeBody,
                      ),
                    ),
                    trailing: _filter == entry.key
                        ? HomeSfIcon(
                            icon: HomeFigmaIcons.check,
                            color: LightScreenTheme.accent,
                            size: 18,
                          )
                        : null,
                    onTap: () => Navigator.of(ctx).pop(entry.key),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (choice != null && mounted) setState(() => _filter = choice);
  }

  Widget _messageList(double scale, String message, {bool retry = false}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 28 * scale),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
        Text(
          message,
          textAlign: TextAlign.center,
          style: LightScreenTheme.emptyState(scale),
        ),
        if (retry)
          Center(
            child: TextButton(
              onPressed: _load,
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(
                  color: LightScreenTheme.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    final visible = _visible;

    final Widget content;
    if (_loading) {
      content = const Center(child: AutobusLoadingIndicator(size: 32));
    } else if (_loadError != null) {
      content = _messageList(scale, _loadError!, retry: true);
    } else if (visible.isEmpty) {
      content = _messageList(
        scale,
        _items.isEmpty
            ? 'No posts yet. Publish from Digital Marketing and they will show up here.'
            : 'No ${_filterLabels[_filter]} posts in the last 14 days.',
      );
    } else {
      content = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20 * scale,
          20 * scale,
          20 * scale,
          32 * scale,
        ),
        itemCount: visible.length,
        separatorBuilder: (_, __) => SizedBox(height: 8 * scale),
        itemBuilder: (_, i) => _postCard(scale, visible[i]),
      );
    }

    return LightScreenScaffold(
      title: 'Recent posts',
      trailing: IconButton(
        onPressed: _showFilter,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: 32 * scale,
          minHeight: 32 * scale,
        ),
        icon: HomeSfIcon(
          icon: HomeFigmaIcons.analyticsFilter,
          color: _filter == _RecentPostFilter.all
              ? Colors.black
              : LightScreenTheme.accent,
          size: 22 * scale.clamp(0.9, 1.0),
        ),
      ),
      body: RefreshIndicator(
        color: LightScreenTheme.accent,
        onRefresh: _load,
        child: content,
      ),
    );
  }

  Widget _postCard(double scale, _RecentPost item) {
    final statusColor = switch (item.phase) {
      _RecentPostPhase.processing => LightScreenTheme.warning,
      _RecentPostPhase.success => const Color(0xFF16A34A),
      _RecentPostPhase.fail => const Color(0xFFDC2626),
    };
    final status = switch (item.phase) {
      _RecentPostPhase.processing => 'Processing',
      _RecentPostPhase.success => item.scheduled ? 'Scheduled' : 'Published',
      _RecentPostPhase.fail => 'Failed',
    };
    final releaseUrl = item.releaseUrl;
    final metaStyle = LightScreenTheme.listSubtitle(scale).copyWith(
      color: _metaGray,
    );

    return LightListCard(
      scale: scale,
      borderColor: Colors.black,
      onTap: releaseUrl == null
          ? null
          : () {
              final uri = Uri.tryParse(releaseUrl);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${item.label}: ',
                  style: LightScreenTheme.listTitle(scale),
                ),
                TextSpan(
                  text: item.preview.isNotEmpty ? item.preview : item.message,
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
                  item.accountName.isNotEmpty ? item.accountName : item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metaStyle,
                ),
              ),
              SizedBox(width: 8 * scale),
              Text(item.whenLabel, style: metaStyle),
            ],
          ),
          if (item.phase != _RecentPostPhase.success &&
              item.message.isNotEmpty &&
              item.preview.isNotEmpty) ...[
            SizedBox(height: 6 * scale),
            Text(
              item.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: metaStyle,
            ),
          ],
          SizedBox(height: 12 * scale),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * scale,
                  vertical: 3 * scale,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.poppins(
                    color: statusColor,
                    fontSize: LightScreenTheme.typeMicro,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              if (releaseUrl != null) ...[
                Text(
                  'View post',
                  style: GoogleFonts.poppins(
                    color: LightScreenTheme.accent,
                    fontSize: LightScreenTheme.typeLabel,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 6 * scale),
                HomeSfIcon(
                  icon: HomeFigmaIcons.chevronRight,
                  color: LightScreenTheme.accent,
                  size: 16 * scale.clamp(0.9, 1.05),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

List<_RecentPost> _postsFromRows(List<Map<String, dynamic>> raw) {
  final flat = <Map<String, dynamic>>[];
  void walk(dynamic node) {
    if (node is List) {
      for (final e in node) {
        walk(e);
      }
      return;
    }
    if (node is! Map) return;
    final row = Map<String, dynamic>.from(node);
    final nested = row['posts'] ?? row['children'] ?? row['items'];
    final looksLikePost = row['integration'] != null ||
        row['state'] != null ||
        row['status'] != null ||
        row['releaseURL'] != null ||
        row['releaseUrl'] != null;
    if (nested is List && nested.isNotEmpty && !looksLikePost) {
      walk(nested);
      return;
    }
    if (looksLikePost || row['content'] != null || row['id'] != null) {
      flat.add(row);
    }
    if (nested is List && looksLikePost) {
      walk(nested);
    }
  }

  walk(raw);
  final out = <_RecentPost>[];
  final seen = <String>{};
  for (final row in flat) {
    final post = _postFromRow(row);
    if (post == null) continue;
    if (!seen.add(post.id)) continue;
    out.add(post);
  }
  return out;
}

_RecentPost? _postFromRow(Map<String, dynamic> row) {
  final integration = row['integration'];
  var platform = '';
  var account = '';
  var integrationId = '';
  if (integration is Map) {
    platform = (integration['identifier'] ?? integration['name'] ?? '')
        .toString();
    account = (integration['name'] ?? integration['profile'] ?? '')
        .toString()
        .trim();
    integrationId = (integration['id'] ?? '').toString().trim();
  }
  if (platform.isEmpty) {
    platform = (row['identifier'] ?? row['platform'] ?? '').toString();
  }
  if (account.isEmpty) {
    account = (row['name'] ?? '').toString().trim();
  }
  if (integrationId.isEmpty) {
    integrationId =
        (row['integrationId'] ?? row['integration_id'] ?? '').toString().trim();
  }
  if (platform.isEmpty && account.isEmpty && integrationId.isEmpty) {
    return null;
  }

  final id = [
    row['id'],
    row['postId'],
    row['releaseId'],
    integrationId,
    platform,
    row['publishDate'],
  ].where((e) => e != null && e.toString().trim().isNotEmpty).join(':');

  final rawState = [
    row['state'],
    row['status'],
    row['releaseState'],
  ].whereType<Object>().map((e) => e.toString().toUpperCase()).join(' ');

  final error = [
    row['error'],
    row['fail_reason'],
    row['failReason'],
  ].whereType<Object>().map((e) => e.toString().trim()).firstWhere(
        (e) => e.isNotEmpty,
        orElse: () => '',
      );

  final when = _whenLabel(
    (row['publishDate'] ??
            row['publish_date'] ??
            row['createdAt'] ??
            row['created_at'] ??
            '')
        .toString(),
  );
  final scheduled = rawState.contains('QUEUE') ||
      rawState.contains('PENDING') ||
      rawState.contains('SCHEDULE');

  late final _RecentPostPhase phase;
  late final String message;
  if (rawState.contains('ERROR') || rawState.contains('FAIL')) {
    phase = _RecentPostPhase.fail;
    message = error.isNotEmpty ? error : 'This post could not be published.';
  } else if (rawState.contains('PUBLISH') || rawState.contains('POSTED')) {
    phase = _RecentPostPhase.success;
    message = 'Published.';
  } else if (scheduled) {
    phase = _RecentPostPhase.success;
    message = 'Scheduled.';
  } else if (rawState.contains('PROCESS') || rawState.isEmpty) {
    phase = _RecentPostPhase.processing;
    message = platform.toLowerCase().contains('tiktok')
        ? kTikTokProcessingNotice
        : 'Processing…';
  } else {
    phase = _RecentPostPhase.processing;
    message = rawState.isEmpty ? 'Processing…' : rawState;
  }

  final release = (row['releaseURL'] ?? row['releaseUrl'] ?? '').toString();
  return _RecentPost(
    id: id.isEmpty ? platform + account + when : id,
    platform: platform.isEmpty ? 'other' : platform,
    label: _labelFor(platform),
    accountName: account,
    preview: _previewOf(row),
    whenLabel: when,
    phase: phase,
    message: message,
    integrationId: integrationId.isEmpty ? null : integrationId,
    releaseUrl: release.startsWith('http') ? release : null,
    scheduled: scheduled && phase != _RecentPostPhase.fail,
  );
}

String _labelFor(String identifier) {
  final key = identifier.toLowerCase();
  if (key.contains('facebook')) return 'Facebook';
  if (key.contains('tiktok')) return 'TikTok';
  if (key.contains('instagram')) return 'Instagram';
  if (key.contains('youtube')) return 'YouTube';
  if (key.isEmpty) return 'Post';
  return identifier;
}

String _previewOf(Map<String, dynamic> row) {
  final content = row['content'];
  if (content is String && content.trim().isNotEmpty) {
    final t = content.trim();
    return t.length <= 140 ? t : '${t.substring(0, 137)}…';
  }
  if (content is List) {
    final parts = <String>[];
    for (final e in content) {
      if (e is Map) {
        final text = (e['content'] ?? e['text'] ?? '').toString().trim();
        if (text.isNotEmpty) parts.add(text);
      } else {
        final text = e.toString().trim();
        if (text.isNotEmpty) parts.add(text);
      }
    }
    final joined = parts.join(' ');
    if (joined.isEmpty) return '';
    return joined.length <= 140 ? joined : '${joined.substring(0, 137)}…';
  }
  return (row['text'] ?? row['caption'] ?? '').toString().trim();
}

String _whenLabel(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw.isEmpty ? '—' : raw;
  final d = dt.toLocal();
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  final hh = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}  $hh:$min';
}
