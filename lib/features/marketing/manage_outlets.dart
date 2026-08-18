import 'package:autobus/barrel.dart';
import 'package:autobus/features/marketing/outlet_catalog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ManageOutlets extends StatefulWidget {
  const ManageOutlets({super.key});

  @override
  State<ManageOutlets> createState() => _ManageOutletsState();
}

class _ManageOutletsState extends State<ManageOutlets> {
  var _loading = true;
  var _busy = false;
  String? _loadError;
  List<LinkedOutlet> _linked = [];
  List<OutletOption> _unlinked = OutletCatalog.all;

  @override
  void initState() {
    super.initState();
    _refreshIntegrations();
  }

  Future<void> _refreshIntegrations() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final api = context.read<ApiService>();
      List<PostizIntegration> integrations = [];
      try {
        integrations = List<PostizIntegration>.from(
          await api.listPostizIntegrations(),
        );
      } catch (_) {
        integrations = [];
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
          // Prefer Autobus DB id so DELETE /instagram/accounts/{id} works.
          final unlinkId = dbId.isNotEmpty ? dbId : igId;
          if (unlinkId.isEmpty) continue;
          integrations.add(
            PostizIntegration(
              id: 'autobus-ig-$unlinkId',
              name: label.isNotEmpty ? label : 'Instagram',
              identifier: 'instagram',
              picture: (row['profile_picture_url'] ?? '').toString(),
              disabled: false,
              profile: username.isNotEmpty ? username : null,
            ),
          );
        }
      } catch (_) {
        // Autobus Instagram accounts are optional alongside Postiz.
      }
      if (!mounted) return;
      final split = OutletCatalog.partition(integrations);
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
        _unlinked = OutletCatalog.all;
        _loading = false;
      });
    }
  }

  Future<void> _showDeviceShareInfo(OutletOption outlet) async {
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
            outlet.label,
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          content: Text(
            outlet.helperText ??
                'This is shared from the WhatsApp app on this phone. You do not need to link an account.',
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
                'Got it',
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

  Future<void> _linkOutlet(OutletOption outlet) async {
    if (outlet.shareOnDevice) {
      await _showDeviceShareInfo(outlet);
      return;
    }
    final api = context.read<ApiService>();
    final connectSlug = outlet.connectSlug?.trim();
    // Meta / TikTok / Google block in-app WebViews; use the device browser
    // the same way Chatwoot WhatsApp Embedded Signup does.
    await openPlatformConnectInBrowser(
      context,
      label: outlet.label,
      fetchSession: () {
        if (connectSlug == 'instagram') {
          return api.getInstagramConnectSession();
        }
        if (connectSlug != null && connectSlug.isNotEmpty) {
          return api.initiateSocialConnect(connectSlug);
        }
        return api.postizAutoLogin();
      },
    );

    if (mounted) {
      await _refreshIntegrations();
    }
  }

  Future<void> _confirmUnlink(LinkedOutlet item) async {
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
            'Unlink ${item.outlet.label}?',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          content: Text(
            item.integrations.length == 1
                ? 'This removes ${item.subtitle} from Autobus. You can link it again later.'
                : 'This removes all ${item.integrations.length} linked ${item.outlet.label} accounts. You can link again later.',
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
      await _unlinkOutlet(item);
    }
  }

  Future<void> _unlinkOutlet(LinkedOutlet item) async {
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<ApiService>();
    setState(() => _busy = true);
    try {
      for (final integration in item.integrations) {
        final id = integration.id.trim();
        if (id.startsWith('autobus-ig-')) {
          await api.deleteInstagramAccount(id.substring('autobus-ig-'.length));
        } else {
          await api.deletePostizIntegration(id);
        }
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${item.outlet.label} unlinked')),
      );
      await _refreshIntegrations();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onLinkedTap(LinkedOutlet item) async {
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
                  item.outlet.label,
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
      await _linkOutlet(item.outlet);
    } else if (action == 'unlink') {
      await _confirmUnlink(item);
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
                  Row(
                    children: [
                      const ManageScreenBackButton(),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(
                          'Link Social Media',
                          style: ManageScreenStyle.headerTitleStyle(),
                        ),
                      ),
                      if (!_loading)
                        IconButton(
                          onPressed: _busy ? null : _refreshIntegrations,
                          icon: const Icon(Icons.refresh, color: Colors.white70),
                          tooltip: 'Refresh',
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _loading
                        ? const Center(child: AutobusLoadingIndicator(size: 32))
                        : RefreshIndicator(
                            onRefresh: _refreshIntegrations,
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
                                    'Linked Outlets',
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
                                    'Tap a linked outlet to unlink or add another account.',
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
                                        'No outlets linked yet. Connect a channel below.',
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
                                    _OutletGrid(
                                      children: [
                                        for (final item in _linked)
                                          _OutletCard(
                                            label: item.outlet.label,
                                            subtitle: item.subtitle,
                                            icon: FaIcon(item.outlet.icon),
                                            iconColor: item.outlet.iconColor,
                                            isLinked: true,
                                            onTap: () => _onLinkedTap(item),
                                          ),
                                      ],
                                    ),
                                  const SizedBox(height: 28),
                                  Text(
                                    'Select to Link Social Media',
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
                                    'Instagram uses Business Login for inbox and posting. Facebook, TikTok, and YouTube open in your device browser. Finish there, then return here and pull to refresh. WhatsApp Status is shared from the WhatsApp app on this phone — no account link is needed.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.montserrat(
                                      color: Colors.white.withValues(alpha: 0.65),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w300,
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _OutletGrid(
                                    children: [
                                      for (final outlet
                                          in OutletCatalog.deviceShareOutlets)
                                        _OutletCard(
                                          label: outlet.label,
                                          subtitle: 'On this phone',
                                          icon: FaIcon(outlet.icon),
                                          iconColor: outlet.iconColor,
                                          isDeviceShare: true,
                                          onTap: _busy
                                              ? () {}
                                              : () =>
                                                    _showDeviceShareInfo(outlet),
                                        ),
                                      for (final outlet in _unlinked)
                                        _OutletCard(
                                          label: outlet.label,
                                          icon: FaIcon(outlet.icon),
                                          iconColor: outlet.iconColor,
                                          onTap: _busy
                                              ? () {}
                                              : () => _linkOutlet(outlet),
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
          if (_busy)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: AutobusLoadingIndicator(size: 32)),
            ),
        ],
      ),
    );
  }
}

class _OutletGrid extends StatelessWidget {
  final List<Widget> children;

  const _OutletGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 133 / 89,
      children: children,
    );
  }
}

class _OutletCard extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Widget icon;
  final Color iconColor;
  final bool isLinked;
  final bool isDeviceShare;
  final VoidCallback onTap;

  const _OutletCard({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.subtitle,
    this.isLinked = false,
    this.isDeviceShare = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1333).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLinked
                ? const Color(0xFF22C55E)
                : isDeviceShare
                ? const Color(0xFF25D366)
                : const Color(0xFF3F1163),
            width: isLinked || isDeviceShare ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: IconTheme(
                data: IconThemeData(color: iconColor, size: 40),
                child: icon,
              ),
            ),
            if (isLinked)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.check_circle,
                  color: Color(0xFF22C55E),
                  size: 18,
                ),
              )
            else if (isDeviceShare)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.smartphone,
                  color: Color(0xFF25D366),
                  size: 18,
                ),
              ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    const SizedBox(height: 2),
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
            ),
          ],
        ),
      ),
    );
  }
}
