import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/icons/figma_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ManageOutlets extends StatefulWidget {
  const ManageOutlets({super.key});

  @override
  State<ManageOutlets> createState() => _ManageOutletsState();
}

class _ManageOutletsState extends State<ManageOutlets>
    with WidgetsBindingObserver {
  var _loading = true;
  var _busy = false;
  var _awaitingBrowserConnect = false;
  String? _loadError;
  List<LinkedOutlet> _linked = [];
  List<OutletOption> _unlinked = OutletCatalog.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshIntegrations();
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
      _refreshIntegrations();
    }
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
        _loadError = userFacingError(e);
        _linked = [];
        _unlinked = OutletCatalog.all;
        _loading = false;
      });
    }
  }

  Future<void> _linkOutlet(OutletOption outlet) async {
    final api = context.read<ApiService>();
    final connectSlug = outlet.connectSlug?.trim();
    // Meta / TikTok / Google block WKWebView; Safari View / Custom Tabs
    // (YouTube-style in-app browser with an X) is allowed and stays in-app.
    _awaitingBrowserConnect = true;
    final closed = await openPlatformConnectInBrowser(
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
    if (closed && mounted) {
      _awaitingBrowserConnect = false;
      await _refreshIntegrations();
    }
  }

  Future<void> _confirmUnlink(LinkedOutlet item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Unlink ${item.outlet.label}?',
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontWeight: FontWeight.w500,
              fontSize: LightScreenTheme.typeTitle,
            ),
          ),
          content: Text(
            item.integrations.length == 1
                ? 'This removes ${item.subtitle} from Autobus. You can link it again later.'
                : 'This removes all ${item.integrations.length} linked ${item.outlet.label} accounts. You can link again later.',
            style: GoogleFonts.poppins(
              color: LightScreenTheme.body,
              fontSize: LightScreenTheme.typeBody,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: LightScreenTheme.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Unlink',
                style: GoogleFonts.poppins(
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
      messenger.showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onLinkedTap(LinkedOutlet item) async {
    if (_busy) return;
    final action = await showModalBottomSheet<String>(
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.outlet.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: LightScreenTheme.typeTitle,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: LightScreenTheme.muted,
                      fontSize: LightScreenTheme.typeLabel,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ListTile(
                  leading: FigmaSvgIcon(
                    FigmaIcons.link,
                    size: 22,
                    color: LightScreenTheme.accent,
                  ),
                  title: Text(
                    'Link another account',
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: LightScreenTheme.typeBody,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop('link'),
                ),
                ListTile(
                  leading: const Icon(Icons.link_off, color: Color(0xFFEF4444)),
                  title: Text(
                    'Unlink',
                    style: GoogleFonts.poppins(
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
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Link Channel',
      trailing: IconButton(
        onPressed: _loading || _busy ? null : _refreshIntegrations,
        tooltip: 'Refresh',
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: 32 * scale,
          minHeight: 32 * scale,
        ),
        icon: FigmaSvgIcon(
          FigmaIcons.refresh,
          size: 24 * scale.clamp(0.9, 1.0),
          color: Colors.black,
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_loading)
            const Center(child: AutobusLoadingIndicator(size: 32))
          else
            RefreshIndicator(
              onRefresh: _refreshIntegrations,
              color: LightScreenTheme.accent,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  20 * scale,
                  30 * scale,
                  20 * scale,
                  32 * scale,
                ),
                children: [
                  if (_loadError != null) ...[
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFDC2626),
                        fontSize: LightScreenTheme.typeLabel,
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                  ],
                  Text(
                    'Select to Link a Channel',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: LightScreenTheme.typeTitle,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 16 * scale),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 9 * scale),
                    child: Text(
                      'Instagram uses Business Login for inbox and posting. TikTok, YouTube, and Facebook Page open in an in-app browser — tap X when you are done.',
                      textAlign: TextAlign.center,
                      style: LightScreenTheme.hubBody(
                        scale,
                      ).copyWith(fontSize: LightScreenTheme.typeBody),
                    ),
                  ),
                  SizedBox(height: 30 * scale),
                  if (_unlinked.isEmpty)
                    Text(
                      'All available channels are linked.',
                      textAlign: TextAlign.center,
                      style: LightScreenTheme.emptyState(scale),
                    )
                  else
                    _OutletGrid(
                      scale: scale,
                      children: [
                        for (final outlet in _unlinked)
                          _OutletCard(
                            scale: scale,
                            outlet: outlet,
                            subtitle: outlet.linkSubtitle,
                            onTap: _busy ? null : () => _linkOutlet(outlet),
                          ),
                      ],
                    ),
                  SizedBox(height: 30 * scale),
                  Padding(
                    padding: EdgeInsets.only(left: 10 * scale),
                    child: Text(
                      'Linked Outlets',
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: LightScreenTheme.typeTitle,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: 16 * scale),
                  if (_linked.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                      child: Text(
                        'No channels linked yet. Tap a channel above to connect it.',
                        style: LightScreenTheme.emptyState(scale),
                      ),
                    )
                  else
                    _OutletGrid(
                      scale: scale,
                      children: [
                        for (final item in _linked)
                          _OutletCard(
                            scale: scale,
                            outlet: item.outlet,
                            subtitle: item.integrations.length > 1
                                ? '${item.integrations.length} accounts linked'
                                : 'Linked successfully',
                            linked: true,
                            onTap: () => _onLinkedTap(item),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          if (_busy)
            const ColoredBox(
              color: Color(0x33000000),
              child: Center(child: AutobusLoadingIndicator(size: 32)),
            ),
        ],
      ),
    );
  }
}

class _OutletGrid extends StatelessWidget {
  final double scale;
  final List<Widget> children;

  const _OutletGrid({required this.scale, required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12 * scale,
      mainAxisSpacing: 8 * scale,
      childAspectRatio: 175 / 146,
      children: children,
    );
  }
}

/// Figma `3399:3342` — channel tile on Link Channel.
class _OutletCard extends StatelessWidget {
  final double scale;
  final OutletOption outlet;
  final String subtitle;
  final bool linked;
  final VoidCallback? onTap;

  const _OutletCard({
    required this.scale,
    required this.outlet,
    required this.subtitle,
    required this.onTap,
    this.linked = false,
  });

  static const _linkedGreen = Color(0xFF65A30D);

  @override
  Widget build(BuildContext context) {
    final iconSize = 22 * scale.clamp(0.9, 1.05);
    final label = outlet.label
        .replaceAll(' Page', '')
        .replaceAll(' Status', '');
    return Material(
      color: LightScreenTheme.surface,
      borderRadius: BorderRadius.circular(20 * scale),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(20 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44 * scale,
                height: 44 * scale,
                decoration: BoxDecoration(
                  color: outlet.tileColor,
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
                alignment: Alignment.center,
                child: outlet.iconAsset != null
                    ? FigmaSvgIcon(
                        outlet.iconAsset!,
                        size: iconSize,
                        color: Colors.white,
                      )
                    : FaIcon(outlet.icon, size: iconSize, color: Colors.white),
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4 * scale),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: linked ? _linkedGreen : LightScreenTheme.muted,
                  fontSize: LightScreenTheme.typeLabel,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
