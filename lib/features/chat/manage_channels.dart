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
        _loadError = e.toString().replaceFirst('Exception: ', '');
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
      _awaitingBrowserConnect = true;
      await openPlatformConnectInBrowser(
        context,
        label: channel.label,
        fetchSession: channel.apiSlug == 'whatsapp'
            ? api.getWhatsAppConnectSession
            : api.getInstagramConnectSession,
      );
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
                            onPressed: _refreshInboxes,
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
                                            onTap: () =>
                                                _linkChannel(item.channel),
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
                    'Instagram uses Meta Business Login. WhatsApp uses Meta signup. SMS opens your Sender ID page.',
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

