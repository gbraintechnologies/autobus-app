import 'package:autobus/barrel.dart';
import 'package:autobus/features/chat/channel_catalog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
    if (state == AppLifecycleState.resumed && _awaitingBrowserConnect) {
      _awaitingBrowserConnect = false;
      _refreshInboxes();
    }
  }

  Future<void> _refreshInboxes() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

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
          final accountId = (row['id'] ?? '').toString().trim();
          inboxes.add(
            ChatwootInbox(
              id: (row['phone_number_id'] ?? row['id'] ?? phone).hashCode.abs(),
              name: name.isNotEmpty ? '$name ($phone)' : phone,
              kind: 'whatsapp',
              accountId: accountId.isNotEmpty ? accountId : null,
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
          final dbId = (row['id'] ?? '').toString().trim();
          final igId = (row['ig_user_id'] ?? dbId).toString();
          final label = username.isNotEmpty
              ? '@$username'
              : (name.isNotEmpty ? name : igId);
          final unlinkId = dbId.isNotEmpty ? dbId : igId;
          if (label.isEmpty || unlinkId.isEmpty) continue;
          inboxes.add(
            ChatwootInbox(
              id: igId.hashCode.abs(),
              name: label,
              kind: 'instagram',
              accountId: unlinkId,
            ),
          );
        }
      } catch (_) {
        // Autobus Instagram Business Login accounts are the chat IG source of truth.
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
          backgroundColor: const Color(0xFF1A1333),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF3F1163)),
          ),
          title: Text(
            'Coming Soon',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          content: Text(
            '${channel.label} messaging will be available soon.',
            style: GoogleFonts.montserrat(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _linkChannel(ChannelOption channel) async {
    if (channel.comingSoon) {
      await _showComingSoon(channel);
      return;
    }

    if (channel.apiSlug == 'whatsapp' || channel.apiSlug == 'instagram') {
      final api = context.read<ApiService>();
      _awaitingBrowserConnect = true;
      final closed = await openPlatformConnectInBrowser(
        context,
        label: channel.label,
        fetchSession: channel.apiSlug == 'whatsapp'
            ? api.getWhatsAppConnectSession
            : api.getInstagramConnectSession,
      );
      if (closed && mounted) {
        _awaitingBrowserConnect = false;
        await _refreshInboxes();
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

  Future<void> _onLinkedTap(LinkedChannel item) async {
    if (_busy) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1333),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF3F1163)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.channel.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.link, color: Colors.white70),
                  title: Text(
                    'Link another account',
                    style: GoogleFonts.montserrat(color: Colors.white),
                  ),
                  onTap: () => Navigator.of(ctx).pop('link'),
                ),
                ListTile(
                  leading: const Icon(Icons.link_off, color: Color(0xFFEF4444)),
                  title: Text(
                    'Unlink',
                    style: GoogleFonts.montserrat(
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop('unlink'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    if (action == 'link') {
      await _linkChannel(item.channel);
    } else if (action == 'unlink') {
      await _confirmUnlink(item);
    }
  }

  Future<void> _confirmUnlink(LinkedChannel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1333),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF3F1163)),
          ),
          title: Text(
            'Unlink ${item.channel.label}?',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          content: Text(
            item.inboxes.length == 1
                ? 'This removes ${item.subtitle} from Autobus. You can link it again later.'
                : 'This removes all ${item.inboxes.length} linked ${item.channel.label} accounts. You can link again later.',
            style: GoogleFonts.montserrat(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.montserrat(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Unlink',
                style: GoogleFonts.montserrat(
                  color: const Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      await _unlinkChannel(item);
    }
  }

  Future<void> _unlinkChannel(LinkedChannel item) async {
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<ApiService>();
    final ids = item.inboxes
        .map((inbox) => (inbox.accountId ?? '').trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not unlink ${item.channel.label}. Pull to refresh and try again.',
          ),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      for (final id in ids) {
        if (item.channel.apiSlug == 'whatsapp') {
          await api.deleteWhatsAppAccount(id);
        } else if (item.channel.apiSlug == 'instagram') {
          await api.deleteInstagramAccount(id);
        } else {
          throw Exception('${item.channel.label} cannot be unlinked from here.');
        }
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${item.channel.label} unlinked')),
      );
      await _refreshInboxes();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(userFacingError(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
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
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ManageScreenHeader(
                    title: 'Manage Channels',
                    padding: EdgeInsets.zero,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_loading)
                          IconButton(
                            onPressed: _busy ? null : _refreshInboxes,
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white70,
                            ),
                            tooltip: 'Refresh',
                          ),
                        const CreditAvatar(creditCategory: CreditCategory.llm),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _loading
                        ? const Center(child: AutobusLoadingIndicator(size: 32))
                        : RefreshIndicator(
                            onRefresh: _refreshInboxes,
                            color: Colors.white,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_loadError != null) ...[
                                    Text(
                                      _loadError!,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.montserrat(
                                        color: Colors.amber.shade200,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  Text(
                                    'Linked Channels',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.montserrat(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap a linked channel to unlink or add another account.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.montserrat(
                                      color: Colors.white.withValues(alpha: 0.55),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  if (_linked.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        'No channels linked yet. Add a messaging inbox below.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.montserrat(
                                          color: Colors.white.withValues(
                                            alpha: 0.55,
                                          ),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w300,
                                          height: 1.45,
                                        ),
                                      ),
                                    )
                                  else
                                    _ChannelGrid(
                                      children: [
                                        for (final item in _linked)
                                          _ChannelCard(
                                            label: item.channel.label,
                                            subtitle: item.subtitle,
                                            icon: FaIcon(item.channel.icon),
                                            iconColor: item.channel.iconColor,
                                            isLinked: true,
                                            onTap: () => _onLinkedTap(item),
                                          ),
                                      ],
                                    ),
                                  const SizedBox(height: 28),
                                  Text(
                                    'Select to Link Channel',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.montserrat(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                  Text(
                    'Instagram uses Meta Business Login. WhatsApp uses Meta signup. Both open in a lightweight in-app browser — tap X when you are done.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      height: 1.45,
                    ),
                  ),
                                  const SizedBox(height: 20),
                                  if (_unlinked.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        'All available channels are linked.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.montserrat(
                                          color: Colors.white.withValues(
                                            alpha: 0.55,
                                          ),
                                          fontSize: 13,
                                        ),
                                      ),
                                    )
                                  else
                                    _ChannelGrid(
                                      children: [
                                        for (final channel in _unlinked)
                                          _ChannelCard(
                                            label: channel.label,
                                            icon: FaIcon(channel.icon),
                                            iconColor: channel.iconColor,
                                            onTap: () =>
                                                _linkChannel(channel),
                                          ),
                                      ],
                                    ),
                                  const SizedBox(height: 24),
                                ],
                              ),
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

class _ChannelGrid extends StatelessWidget {
  final List<Widget> children;

  const _ChannelGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.12,
      children: children,
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Widget icon;
  final Color iconColor;
  final bool isLinked;
  final VoidCallback onTap;

  const _ChannelCard({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.subtitle,
    this.isLinked = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1333).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLinked ? const Color(0xFF22C55E) : const Color(0xFF3F1163),
            width: isLinked ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Center(
                    child: IconTheme(
                      data: IconThemeData(color: iconColor, size: 28),
                      child: icon,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
            if (isLinked)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.check_circle,
                  color: Color(0xFF22C55E),
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

