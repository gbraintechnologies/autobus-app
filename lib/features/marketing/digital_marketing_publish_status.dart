part of 'digital_marketing.dart';

enum _PublishPhase { processing, success, fail }

enum _PublishFilter { all, tiktok, youtube, instagram, other }

class _TrackedPublish {
  _TrackedPublish({
    required this.id,
    required this.platform,
    required this.label,
    required this.accountName,
    required this.phase,
    required this.message,
    this.integrationId,
    this.publishId,
    this.pollable = false,
    this.scheduled = false,
  });

  final String id;
  final String platform;
  final String label;
  final String accountName;
  _PublishPhase phase;
  String message;
  final String? integrationId;
  String? publishId;
  final bool pollable;
  final bool scheduled;

  String get filterKey {
    final p = platform.toLowerCase();
    if (p.contains('tiktok')) return 'tiktok';
    if (p.contains('youtube')) return 'youtube';
    if (p.contains('instagram')) return 'instagram';
    return 'other';
  }
}

class _PublishStatusPage extends StatefulWidget {
  final List<_TrackedPublish> items;
  final bool scheduled;

  const _PublishStatusPage({
    required this.items,
    this.scheduled = false,
  });

  @override
  State<_PublishStatusPage> createState() => _PublishStatusPageState();
}

class _PublishStatusPageState extends State<_PublishStatusPage> {
  final ApiService _apiService = ApiService(
    httpClient: SessionAwareHttpClient(tokenService: TokenService()),
  );

  _PublishFilter _filter = _PublishFilter.all;
  var _polling = false;
  Timer? _timer;
  late final DateTime _deadline;

  List<_TrackedPublish> get _items => widget.items;

  bool get _anyProcessing =>
      _items.any((i) => i.phase == _PublishPhase.processing);

  @override
  void initState() {
    super.initState();
    _deadline = DateTime.now().add(const Duration(minutes: 4));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _poll();
    });
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_anyProcessing || DateTime.now().isAfter(_deadline)) {
        _timer?.cancel();
        return;
      }
      _poll();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling || !mounted) return;
    final pending = _items
        .where((i) => i.pollable && i.phase == _PublishPhase.processing)
        .toList();
    if (pending.isEmpty) return;
    _polling = true;
    try {
      final tiktoks = pending.where((i) => i.filterKey == 'tiktok').toList();
      final others = pending.where((i) => i.filterKey != 'tiktok').toList();

      for (final item in tiktoks) {
        final integrationId = item.integrationId;
        if (integrationId == null || integrationId.isEmpty) continue;
        try {
          final status = await _apiService.getTikTokPublishStatus(
            integrationId: integrationId,
            publishId: item.publishId,
          );
          if (!mounted) return;
          _applyTikTok(item, status);
        } catch (_) {}
      }

      if (others.isNotEmpty) {
        try {
          final posts = await _apiService.listPostizPosts();
          if (!mounted) return;
          for (final item in others) {
            _applyPostiz(item, posts);
          }
        } catch (_) {}
      }
    } finally {
      _polling = false;
      if (mounted) setState(() {});
    }
  }

  void _applyTikTok(_TrackedPublish item, TikTokPublishStatus status) {
    if (status.failed) {
      item.phase = _PublishPhase.fail;
      item.message = status.message;
    } else if (status.complete) {
      item.phase = _PublishPhase.success;
      item.message = status.message;
    } else if (item.scheduled || widget.scheduled) {
      item.phase = _PublishPhase.success;
      item.message = 'Scheduled.';
    } else {
      item.phase = _PublishPhase.processing;
      item.message = status.message;
    }
  }

  void _applyPostiz(_TrackedPublish item, List<Map<String, dynamic>> posts) {
    final iid = item.integrationId?.trim() ?? '';
    if (iid.isEmpty) return;
    Map<String, dynamic>? match;
    for (final row in posts) {
      final rowId = _postizIntegrationId(row);
      if (rowId.isNotEmpty && rowId == iid) {
        match = row;
        break;
      }
    }
    if (match == null) return;
    final raw = [
      match['state'],
      match['status'],
      match['releaseState'],
    ].whereType<Object>().map((e) => e.toString().toUpperCase()).join(' ');
    final error = [
      match['error'],
      match['fail_reason'],
      match['failReason'],
    ].whereType<Object>().map((e) => e.toString().trim()).firstWhere(
          (e) => e.isNotEmpty,
          orElse: () => '',
        );
    if (raw.contains('ERROR') || raw.contains('FAIL')) {
      item.phase = _PublishPhase.fail;
      item.message = error.isNotEmpty ? error : 'This post could not be published.';
    } else if (raw.contains('PUBLISH') || raw.contains('POSTED')) {
      item.phase = _PublishPhase.success;
      item.message = item.scheduled || widget.scheduled
          ? 'Scheduled and queued.'
          : 'Published.';
    } else if (item.scheduled || widget.scheduled) {
      item.phase = _PublishPhase.success;
      item.message = 'Scheduled.';
    } else {
      item.phase = _PublishPhase.processing;
      item.message = 'Processing…';
    }
  }

  String _postizIntegrationId(Map<String, dynamic> row) {
    final integration = row['integration'];
    if (integration is Map) {
      return (integration['id'] ?? '').toString().trim();
    }
    return (row['integrationId'] ?? row['integration_id'] ?? '')
        .toString()
        .trim();
  }

  List<_TrackedPublish> get _visible {
    return _items.where((i) {
      switch (_filter) {
        case _PublishFilter.all:
          return true;
        case _PublishFilter.tiktok:
          return i.filterKey == 'tiktok';
        case _PublishFilter.youtube:
          return i.filterKey == 'youtube';
        case _PublishFilter.instagram:
          return i.filterKey == 'instagram';
        case _PublishFilter.other:
          return i.filterKey == 'other';
      }
    }).toList()
      ..sort((a, b) {
        const order = {'tiktok': 0, 'youtube': 1, 'instagram': 2, 'other': 3};
        final cmp = (order[a.filterKey] ?? 9).compareTo(order[b.filterKey] ?? 9);
        if (cmp != 0) return cmp;
        return a.label.compareTo(b.label);
      });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return _MarketingScaffold(
      child: Column(
        children: [
          Text(
            'Publish status',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _anyProcessing
                ? 'We’re checking each platform. This can take a few minutes.'
                : 'Here’s how each post finished.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.black45,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All', _PublishFilter.all),
                const SizedBox(width: 8),
                _filterChip('TikTok', _PublishFilter.tiktok),
                const SizedBox(width: 8),
                _filterChip('YouTube', _PublishFilter.youtube),
                const SizedBox(width: 8),
                _filterChip('Instagram', _PublishFilter.instagram),
                const SizedBox(width: 8),
                _filterChip('Other', _PublishFilter.other),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      'No posts in this filter.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.black45,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _statusCard(visible[i]),
                  ),
          ),
          const SizedBox(height: 12),
          _DarkButton(
            label: 'Done',
            compact: true,
            onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _PublishFilter value) {
    final selected = _filter == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _filter = value),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _kHeaderPurple : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? _kHeaderPurple : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusCard(_TrackedPublish item) {
    final color = switch (item.phase) {
      _PublishPhase.processing => const Color(0xFFD97706),
      _PublishPhase.success => const Color(0xFF16A34A),
      _PublishPhase.fail => const Color(0xFFDC2626),
    };
    final badge = switch (item.phase) {
      _PublishPhase.processing => 'Processing',
      _PublishPhase.success => item.scheduled ? 'Scheduled' : 'Success',
      _PublishPhase.fail => 'Failed',
    };
    final icon = switch (item.filterKey) {
      'tiktok' => FontAwesomeIcons.tiktok,
      'youtube' => FontAwesomeIcons.youtube,
      'instagram' => FontAwesomeIcons.instagram,
      _ => item.platform.toLowerCase().contains('facebook')
          ? FontAwesomeIcons.facebook
          : FontAwesomeIcons.globe,
    };
    final iconColor = switch (item.filterKey) {
      'tiktok' => const Color(0xFF69C9D0),
      'youtube' => const Color(0xFFFF0000),
      'instagram' => const Color(0xFFDD2A7B),
      _ => item.platform.toLowerCase().contains('facebook')
          ? const Color(0xFF1877F2)
          : _kPurple,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Center(child: FaIcon(icon, size: 18, color: iconColor)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.accountName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.accountName,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.black45,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  item.message,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
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
              if (item.phase == _PublishPhase.processing) ...[
                const SizedBox(height: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
