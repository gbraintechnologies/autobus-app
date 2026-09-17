import 'package:autobus/barrel.dart';
import 'package:autobus/features/marketing/tiktok_creator_info.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ManageScreenBackButton(),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(
                          'Recent posts',
                          style: ManageScreenStyle.headerTitleStyle(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _loading ? ' ' : '${_items.length} in the last 14 days',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('All', _RecentPostFilter.all),
                        const SizedBox(width: 8),
                        _chip('TikTok', _RecentPostFilter.tiktok),
                        const SizedBox(width: 8),
                        _chip('YouTube', _RecentPostFilter.youtube),
                        const SizedBox(width: 8),
                        _chip('Instagram', _RecentPostFilter.instagram),
                        const SizedBox(width: 8),
                        _chip('Other', _RecentPostFilter.other),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _loading
                        ? const Center(child: AutobusLoadingIndicator(size: 32))
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
                                      onPressed: _load,
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
                                onRefresh: _load,
                                child: visible.isEmpty
                                    ? ListView(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        children: [
                                          SizedBox(
                                            height:
                                                MediaQuery.sizeOf(context)
                                                        .height *
                                                    0.22,
                                          ),
                                          Center(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 20,
                                              ),
                                              child: Text(
                                                _items.isEmpty
                                                    ? 'No posts yet. Publish from Digital Marketing and they will show up here.'
                                                    : 'No posts in this filter.',
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.6),
                                                  fontSize: 15,
                                                  height: 1.45,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : ListView.separated(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        itemCount: visible.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 16),
                                        itemBuilder: (_, i) =>
                                            _postCard(visible[i]),
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

  Widget _chip(String label, _RecentPostFilter value) {
    final selected = _filter == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _filter = value),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFA855F7) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? const Color(0xFFA855F7)
                  : const Color(0xFF3F1163),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: selected ? 1 : 0.75),
            ),
          ),
        ),
      ),
    );
  }

  Widget _postCard(_RecentPost item) {
    final color = switch (item.phase) {
      _RecentPostPhase.processing => const Color(0xFFFBBF24),
      _RecentPostPhase.success => const Color(0xFF4ADE80),
      _RecentPostPhase.fail => const Color(0xFFF87171),
    };
    final badge = switch (item.phase) {
      _RecentPostPhase.processing => 'Processing',
      _RecentPostPhase.success => item.scheduled ? 'Scheduled' : 'Success',
      _RecentPostPhase.fail => 'Failed',
    };
    final icon = switch (item.filterKey) {
      'tiktok' => FontAwesomeIcons.tiktok,
      'youtube' => FontAwesomeIcons.youtube,
      'instagram' => FontAwesomeIcons.instagram,
      _ => item.platform.toLowerCase().contains('facebook')
          ? FontAwesomeIcons.facebook
          : FontAwesomeIcons.globe,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.releaseUrl == null
            ? null
            : () {
                final uri = Uri.tryParse(item.releaseUrl!);
                if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
              },
        borderRadius: BorderRadius.circular(28),
        child: Ink(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF3F1163), width: 1),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (item.accountName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.accountName,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
          if (item.preview.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.preview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            item.message,
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.whenLabel,
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
        ),
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
  return '$dd / $mm / ${d.year}  $hh:$min';
}
