import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_hub_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/icons/home_figma_icons.dart';

class ManageChats extends StatefulWidget {
  const ManageChats({super.key});

  @override
  State<ManageChats> createState() => _ManageChatsState();
}

class _ManageChatsState extends State<ManageChats> {
  bool _loadRequested = false;
  bool _loading = true;
  String? _statusError;

  bool _chatwootConfigured = false;
  bool _chatwootProvisioned = false;
  bool _subscriptionActive = false;

  /// Inbox total from Chatwoot when fetched; `null` if not fetched or fetch failed.
  int? _linkedInboxTotal;
  bool _inboxesFetchFailed = false;

  String _shortError(String raw, {int max = 160}) {
    final t = raw.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  Future<void> _loadChannelIntegrationState() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _statusError = null;
      _inboxesFetchFailed = false;
    });
    try {
      final api = context.read<ApiService>();
      final status = await api.getChatwootStatus();
      if (!mounted) return;

      final configured = status['chatwoot_configured'] as bool? ?? false;
      final provisioned = status['chatwoot_provisioned'] as bool? ?? false;
      final subActive = status['subscription_active'] as bool? ?? false;

      int? inboxTotal;
      var inboxFailed = false;

      if (configured && provisioned && subActive) {
        try {
          inboxTotal = await api.getChatwootInboxTotal();
        } catch (_) {
          inboxFailed = true;
        }
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _chatwootConfigured = configured;
        _chatwootProvisioned = provisioned;
        _subscriptionActive = subActive;
        _linkedInboxTotal = inboxFailed ? null : inboxTotal;
        _inboxesFetchFailed = inboxFailed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusError = userFacingError(e, fallback: AppUserMessages.load);
        _linkedInboxTotal = null;
        _inboxesFetchFailed = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadRequested) return;
    _loadRequested = true;
    _loadChannelIntegrationState();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Manage Inbox',
      creditCategory: CreditCategory.llm,
      body: SingleChildScrollView(
        padding: LightScreenTheme.hubPagePadding(scale),
        child: Column(
          children: [
            Text(
              'Welcome to Inbox',
              textAlign: TextAlign.center,
              style: LightScreenTheme.hubTitle(scale),
            ),
            SizedBox(height: LightScreenTheme.hubTitleGap * scale),
            Text(
              'Open live chats, review conversations, and stay on top of customer messages.',
              textAlign: TextAlign.center,
              style: LightScreenTheme.hubBody(scale).copyWith(
                color: const Color(0xFF4E4E4E),
              ),
            ),
            SizedBox(height: LightScreenTheme.hubToCards * scale),
            if (_loading) ...[
              Center(
                child: CircularProgressIndicator(color: LightScreenTheme.accent),
              ),
              SizedBox(height: 24 * scale),
            ] else if (_statusError != null) ...[
              _ChatwootMessagePanel(
                scale: scale,
                backgroundColor: LightScreenTheme.warning.withValues(alpha: 0.12),
                borderColor: LightScreenTheme.warning.withValues(alpha: 0.45),
                icon: HomeFigmaIcons.cloudOff,
                iconColor: LightScreenTheme.warning,
                trailing: IconButton(
                  onPressed: _loadChannelIntegrationState,
                  icon: HomeSfIcon(
                    icon: HomeFigmaIcons.refresh,
                    color: LightScreenTheme.accent,
                    size: 22 * scale,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: 32 * scale,
                    minHeight: 32 * scale,
                  ),
                ),
                child: Text(
                  'Could not load Chatwoot status. Check your connection and try again.\n${_shortError(_statusError!)}',
                  style: LightScreenTheme.hubBody(scale).copyWith(fontSize: 12),
                ),
              ),
              SizedBox(height: 16 * scale),
            ] else if (!_chatwootConfigured) ...[
              _ChatwootMessagePanel(
                scale: scale,
                backgroundColor: LightScreenTheme.warning.withValues(alpha: 0.12),
                borderColor: LightScreenTheme.warning.withValues(alpha: 0.45),
                icon: HomeFigmaIcons.settings,
                iconColor: LightScreenTheme.warning,
                child: Text(
                  'Chat linking is not enabled on this server (Chatwoot is not configured).',
                  style: LightScreenTheme.hubBody(scale).copyWith(fontSize: 12),
                ),
              ),
              SizedBox(height: 16 * scale),
            ] else if (!_chatwootProvisioned) ...[
              _ChatwootMessagePanel(
                scale: scale,
                backgroundColor: LightScreenTheme.accent.withValues(alpha: 0.08),
                borderColor: LightScreenTheme.accent.withValues(alpha: 0.35),
                icon: HomeFigmaIcons.warning,
                iconColor: LightScreenTheme.accent,
                child: Text(
                  'No Chatwoot workspace is linked to your account yet. An active subscription provisions your workspace.',
                  style: LightScreenTheme.hubBody(scale).copyWith(fontSize: 12),
                ),
              ),
              SizedBox(height: 16 * scale),
            ] else if (!_subscriptionActive) ...[
              _ChatwootMessagePanel(
                scale: scale,
                backgroundColor: LightScreenTheme.warning.withValues(alpha: 0.12),
                borderColor: LightScreenTheme.warning.withValues(alpha: 0.45),
                icon: HomeFigmaIcons.lock,
                iconColor: LightScreenTheme.warning,
                child: Text(
                  'An active subscription is required to link messaging channels in Chatwoot.',
                  style: LightScreenTheme.hubBody(scale).copyWith(fontSize: 12),
                ),
              ),
              SizedBox(height: 16 * scale),
            ] else if (_inboxesFetchFailed) ...[
              _ChatwootMessagePanel(
                scale: scale,
                backgroundColor: LightScreenTheme.warning.withValues(alpha: 0.12),
                borderColor: LightScreenTheme.warning.withValues(alpha: 0.45),
                icon: HomeFigmaIcons.cloudOff,
                iconColor: LightScreenTheme.warning,
                trailing: IconButton(
                  onPressed: _loadChannelIntegrationState,
                  icon: HomeSfIcon(
                    icon: HomeFigmaIcons.refresh,
                    color: LightScreenTheme.accent,
                    size: 22 * scale,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: 32 * scale,
                    minHeight: 32 * scale,
                  ),
                ),
                child: Text(
                  'Could not load your Chatwoot inboxes. Pull to refresh after reconnecting.',
                  style: LightScreenTheme.hubBody(scale).copyWith(fontSize: 12),
                ),
              ),
              SizedBox(height: 16 * scale),
            ] else if ((_linkedInboxTotal ?? 0) == 0) ...[
              _ChatwootMessagePanel(
                scale: scale,
                backgroundColor: LightScreenTheme.accent.withValues(alpha: 0.08),
                borderColor: LightScreenTheme.accent.withValues(alpha: 0.35),
                icon: HomeFigmaIcons.warning,
                iconColor: LightScreenTheme.accent,
                child: Text(
                  'You have not linked any messaging channel in Chatwoot yet. Use Link Channel to add WhatsApp, Facebook, and other inboxes.',
                  style: LightScreenTheme.hubBody(scale).copyWith(fontSize: 12),
                ),
              ),
              SizedBox(height: 16 * scale),
            ],
            LightHubGrid(
              scale: scale,
              children: [
                LightHubCard(
                  scale: scale,
                  title: 'Link Channel',
                  subtitle: 'Connect socials',
                  icon: HomeFigmaIcons.linkChannel,
                  iconGradient: HomeFigmaIcons.linkChannelGradient,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => const ManageChannels(),
                      ),
                    ).then((_) {
                      if (mounted) {
                        _loadChannelIntegrationState();
                      }
                    });
                  },
                ),
                LightHubCard(
                  scale: scale,
                  title: 'Live Chats',
                  subtitle: 'Live chat from socials',
                  icon: HomeFigmaIcons.liveChats,
                  iconGradient: HomeFigmaIcons.liveChatsGradient,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => const LiveChatsPage(),
                      ),
                    );
                  },
                ),
                LightHubCard(
                  scale: scale,
                  title: 'All Chats',
                  subtitle: 'All chats from socials',
                  icon: HomeFigmaIcons.allChats,
                  iconGradient: HomeFigmaIcons.allChatsGradient,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => const AllChatsPage(),
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

class _ChatwootMessagePanel extends StatelessWidget {
  final double scale;
  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final Widget child;

  const _ChatwootMessagePanel({
    required this.scale,
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 1.2),
        borderRadius: BorderRadius.circular(20 * scale),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSfIcon(icon: icon, color: iconColor, size: 22 * scale),
          SizedBox(width: 12 * scale),
          Expanded(child: child),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
