import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_hub_card.dart';
import 'package:autobus/common_design/widgets/light_list_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/icons/figma_icons.dart';
import 'package:autobus/icons/home_figma_icons.dart';

class ManageChannels extends StatefulWidget {
  const ManageChannels({super.key});

  @override
  State<ManageChannels> createState() => _ManageChannelsState();
}

class _ManageChannelsState extends State<ManageChannels>
    with WidgetsBindingObserver {
  var _loading = true;
  var _busy = false;
  var _awaitingBrowserConnect = false;
  var _finalizingConnect = false;
  var _sawBrowserBackground = false;
  DateTime? _browserOpenedAt;
  String? _pendingConnectSlug;
  String? _linkingStatus;
  Set<String> _idsBeforeConnect = {};
  String? _loadError;
  List<LinkedChannel> _linked = [];
  List<ChannelOption> _unlinked = ChannelCatalog.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshInboxes();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_awaitingBrowserConnect) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _sawBrowserBackground = true;
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final opened = _browserOpenedAt;
    // Custom Tabs often bounce resumed as soon as they open.
    if (opened != null &&
        DateTime.now().difference(opened) < const Duration(seconds: 2)) {
      return;
    }
    if (!_sawBrowserBackground) return;
    _finalizeBrowserConnect();
  }

  Set<String> _accountKeysFor(String apiSlug) {
    final keys = <String>{};
    for (final item in _linked) {
      if (item.channel.apiSlug != apiSlug) continue;
      for (final inbox in item.inboxes) {
        final id = (inbox.accountId ?? '').trim();
        final name = inbox.name.trim();
        if (id.isNotEmpty) keys.add(id);
        if (name.isNotEmpty) keys.add(name);
      }
    }
    return keys;
  }

  bool _hasNewAccount(String apiSlug) {
    final now = _accountKeysFor(apiSlug);
    if (now.isEmpty) return false;
    if (_idsBeforeConnect.isEmpty) return now.isNotEmpty;
    return now.difference(_idsBeforeConnect).isNotEmpty;
  }

  Future<void> _finalizeBrowserConnect() async {
    if (_finalizingConnect) return;
    final slug = _pendingConnectSlug;
    final label = slug == 'instagram' ? 'Instagram' : 'WhatsApp';
    _finalizingConnect = true;
    _awaitingBrowserConnect = false;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _linkingStatus = 'Linking channel…';
    });

    var linked = false;
    try {
      for (var i = 0; i < 12; i++) {
        await _refreshInboxes(showLoader: false);
        if (!mounted) return;
        if (slug != null && _hasNewAccount(slug)) {
          linked = true;
          break;
        }
        if (i < 11) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _linkingStatus = null;
          _pendingConnectSlug = null;
          _finalizingConnect = false;
        });
      } else {
        _finalizingConnect = false;
      }
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (linked) {
      messenger.showSnackBar(
        SnackBar(content: Text('$label connected')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$label is not linked yet. Wait until the page says connected, then tap X.',
          ),
        ),
      );
    }
  }

  Future<void> _refreshInboxes({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final api = context.read<ApiService>();
      List<ChatwootInbox> inboxes = [];
      try {
        inboxes = await api.listChatwootInboxes();
      } catch (_) {
        inboxes = [];
      }
      try {
        final waAccounts = await api.listWhatsAppAccounts();
        for (final row in waAccounts) {
          final phone =
              (row['display_phone_number'] ?? row['phone_number_id'] ?? '')
                  .toString();
          final name = (row['verified_name'] ?? '').toString().trim();
          inboxes.add(
            ChatwootInbox(
              id: (row['phone_number_id'] ?? row['id'] ?? phone).hashCode.abs(),
              name: name.isNotEmpty ? '$name ($phone)' : phone,
              kind: 'whatsapp',
            ),
          );
        }
      } catch (_) {
        // Autobus Meta WhatsApp accounts are the chat WhatsApp source of truth.
      }
      try {
        final igAccounts = await api.listInstagramAccounts();
        for (final row in igAccounts) {
          final username = (row['username'] ?? '').toString().trim();
          final name = (row['name'] ?? '').toString().trim();
          final igId = (row['ig_user_id'] ?? row['id'] ?? '').toString();
          final label = username.isNotEmpty
              ? '@$username'
              : (name.isNotEmpty ? name : igId);
          if (label.isEmpty) continue;
          inboxes.add(
            ChatwootInbox(
              id: igId.hashCode.abs(),
              name: label,
              kind: 'instagram',
            ),
          );
        }
      } catch (_) {
        // Autobus Instagram Business Login accounts are the chat IG source of truth.
      }
      try {
        final smsRows = await api.listSmsSenderIds();
        for (final row in smsRows) {
          final senderId = (row['sender_id'] ?? '').toString().trim();
          if (senderId.isEmpty) continue;
          final status = (row['status'] ?? 'pending').toString().toLowerCase();
          final statusLabel = switch (status) {
            'approved' => 'Approved',
            'rejected' => 'Rejected',
            _ => 'Pending approval',
          };
          inboxes.add(
            ChatwootInbox(
              id: (row['id'] ?? senderId).hashCode.abs(),
              name: '$senderId · $statusLabel',
              kind: 'sms',
            ),
          );
        }
      } catch (_) {
        // SMS registrations are optional for the channel list.
      }
      if (!mounted) return;
      final split = ChannelCatalog.partition(inboxes);
      setState(() {
        _linked = split.linked;
        _unlinked = split.unlinked;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e);
        _linked = [];
        _unlinked = ChannelCatalog.all;
        _loading = false;
      });
    }
  }

  Future<void> _showComingSoon(ChannelOption channel) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: LightScreenTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: LightScreenTheme.hint.withValues(alpha: 0.5)),
          ),
          title: Text(
            'Coming Soon',
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          content: Text(
            '${channel.label} messaging will be available soon.',
            style: GoogleFonts.poppins(
              color: LightScreenTheme.body,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(
                  color: LightScreenTheme.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openSmsSenderIds() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const ManageSmsSenderIds()),
    );
    if (mounted) await _refreshInboxes();
  }

  Future<void> _linkChannel(ChannelOption channel) async {
    if (channel.comingSoon) {
      await _showComingSoon(channel);
      return;
    }

    if (channel.apiSlug == 'sms') {
      await _openSmsSenderIds();
      return;
    }

    if (channel.apiSlug == 'whatsapp' || channel.apiSlug == 'instagram') {
      final api = context.read<ApiService>();
      _pendingConnectSlug = channel.apiSlug;
      _idsBeforeConnect = _accountKeysFor(channel.apiSlug);
      _browserOpenedAt = DateTime.now();
      _sawBrowserBackground = false;
      _awaitingBrowserConnect = true;
      final closed = await openPlatformConnectInBrowser(
        context,
        label: channel.label,
        fetchSession: channel.apiSlug == 'whatsapp'
            ? api.getWhatsAppConnectSession
            : api.getInstagramConnectSession,
      );
      if (closed && mounted) {
        await _finalizeBrowserConnect();
      }
      return;
    }

    await openEmbeddedPlatformSession(
      context,
      title: 'Link ${channel.label}',
      fetchSession: () =>
          context.read<ApiService>().getChatwootChannelLink(channel.apiSlug),
    );

    if (mounted) {
      await _refreshInboxes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    final extraLinkChannels = _unlinked
        .where((c) => c.apiSlug != 'instagram' && c.apiSlug != 'whatsapp')
        .toList();

    return LightScreenScaffold(
      title: 'Link Channel',
      creditCategory: CreditCategory.llm,
      body: Stack(
        children: [
          _loading
          ? Center(child: CircularProgressIndicator(color: LightScreenTheme.accent))
          : RefreshIndicator(
              onRefresh: () => _refreshInboxes(),
              color: LightScreenTheme.accent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: LightScreenTheme.hubPagePadding(scale),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loadError != null) ...[
                      Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: LightScreenTheme.emptyState(scale).copyWith(
                          color: LightScreenTheme.warning,
                        ),
                      ),
                      SizedBox(height: 16 * scale),
                    ],
                    Text(
                      'Select to Link a Channel',
                      textAlign: TextAlign.center,
                      style: LightScreenTheme.hubTitle(scale),
                    ),
                    SizedBox(height: 16 * scale),
                    Text(
                      'Connect Instagram or WhatsApp so customers can reach you in Autobus.',
                      textAlign: TextAlign.center,
                      style: LightScreenTheme.hubBody(scale).copyWith(
                        color: const Color(0xFF4E4E4E),
                      ),
                    ),
                    SizedBox(height: 30 * scale),
                    _ChannelGrid(
                      scale: scale,
                      children: [
                        for (final channel in ChannelCatalog.all.where(
                          (c) =>
                              c.apiSlug == 'instagram' ||
                              c.apiSlug == 'whatsapp',
                        ))
                          _brandHubCard(scale, channel),
                        for (final channel in extraLinkChannels)
                          _brandHubCard(scale, channel),
                      ],
                    ),
                    SizedBox(height: 40 * scale),
                    Text(
                      'Linked Channels',
                      style: LightScreenTheme.hubTitle(scale),
                    ),
                    SizedBox(height: 8 * scale),
                    Text(
                      'Accounts already connected to this workspace.',
                      style: LightScreenTheme.hubBody(scale).copyWith(
                        color: const Color(0xFF4E4E4E),
                      ),
                    ),
                    if (_linked.isNotEmpty) ...[
                      SizedBox(height: 16 * scale),
                      for (final item in _linked) ...[
                        LightListCard(
                          scale: scale,
                          onTap: () => _linkChannel(item.channel),
                          child: Row(
                            children: [
                              Container(
                                width: 44 * scale,
                                height: 44 * scale,
                                decoration: BoxDecoration(
                                  color: item.channel.tileColor,
                                  borderRadius: BorderRadius.circular(12 * scale),
                                ),
                                alignment: Alignment.center,
                                child: FigmaBrandIcon(
                                  asset: item.channel.iconAsset,
                                  fallback: item.channel.icon,
                                  color: Colors.white,
                                  size: 22 * scale,
                                ),
                              ),
                              SizedBox(width: 12 * scale),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.channel.label,
                                      style: LightScreenTheme.listTitle(scale),
                                    ),
                                    SizedBox(height: 4 * scale),
                                    Text(
                                      item.subtitle,
                                      style: LightScreenTheme.listSubtitle(scale),
                                    ),
                                  ],
                                ),
                              ),
                              HomeSfIcon(
                                icon: HomeFigmaIcons.check,
                                color: const Color(0xFF22C55E),
                                size: 18 * scale,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12 * scale),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0x99F3F3F7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: LightScreenTheme.accent),
                      SizedBox(height: 16 * scale),
                      Text(
                        _linkingStatus ?? 'Please wait…',
                        style: LightScreenTheme.hubTitle(scale),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _brandHubCard(double scale, ChannelOption channel) {
    return LightHubCard(
      scale: scale,
      title: channel.label,
      subtitle: channel.linkSubtitle,
      icon: HomeFigmaIcons.linkChannel,
      iconTileColor: channel.tileColor,
      iconWidget: FigmaBrandIcon(
        asset: channel.iconAsset,
        fallback: channel.icon,
        color: Colors.white,
        size: 22 * scale,
      ),
      onTap: () => _linkChannel(channel),
    );
  }
}
class _ChannelGrid extends StatelessWidget {
  final double scale;
  final List<Widget> children;

  const _ChannelGrid({required this.scale, required this.children});

  @override
  Widget build(BuildContext context) {
    return LightHubGrid(scale: scale, children: children);
  }
}

