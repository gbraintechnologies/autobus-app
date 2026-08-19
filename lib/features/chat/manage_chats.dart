import 'package:autobus/barrel.dart';

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
  bool _subscriptionActive = false;

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
    });
    try {
      final api = context.read<ApiService>();
      final status = await api.getChatwootStatus();
      if (!mounted) return;

      setState(() {
        _loading = false;
        _chatwootConfigured = status['chatwoot_configured'] as bool? ?? false;
        _subscriptionActive = status['subscription_active'] as bool? ?? false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusError = e.toString();
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: ManageScreenStyle.homeDashboardBodyDecoration,
          ),
          SafeArea(
            child: Column(
              children: [
                const ManageScreenHeader(
                  title: 'Manage Inbox',
                  creditCategory: CreditCategory.llm,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 60),
                          Text(
                            'Welcome to Inbox',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Deliver instant, intelligent customer support with AI trained on your business data through linked social messaging channels.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 32),
                          if (_loading) ...[
                            const SizedBox(height: 8),
                            const Center(
                              child:                               const AutobusLoadingIndicator(size: 28),
                            ),
                            const SizedBox(height: 24),
                          ] else if (_statusError != null) ...[
                            _ChatwootMessagePanel(
                              backgroundColor: Colors.amber.withValues(
                                alpha: 0.12,
                              ),
                              borderColor: Colors.amber.withValues(alpha: 0.45),
                              icon: Icons.cloud_off_outlined,
                              iconColor: Colors.amber.shade300,
                              trailing: IconButton(
                                onPressed: _loadChannelIntegrationState,
                                icon: Icon(
                                  Icons.refresh,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  size: 22,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                              child: Text(
                                'Could not load Chatwoot status. Check your connection and try again.\n${_shortError(_statusError!)}',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ] else if (!_chatwootConfigured) ...[
                            _ChatwootMessagePanel(
                              backgroundColor: Colors.amber.withValues(
                                alpha: 0.12,
                              ),
                              borderColor: Colors.amber.withValues(alpha: 0.45),
                              icon: Icons.settings_suggest_outlined,
                              iconColor: Colors.amber.shade300,
                              child: Text(
                                'Chat linking is not enabled on this server (Chatwoot is not configured).',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ] else if (!_subscriptionActive) ...[
                            _ChatwootMessagePanel(
                              backgroundColor: Colors.amber.withValues(
                                alpha: 0.12,
                              ),
                              borderColor: Colors.amber.withValues(alpha: 0.45),
                              icon: Icons.lock_outline,
                              iconColor: Colors.amber.shade300,
                              child: Text(
                                'An active subscription is required to link messaging channels in Chatwoot.',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ] else
                            const SizedBox(height: 8),
                          const SizedBox(height: 40),
                          GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 1.0,
                            children: [
                              _ChatActionCard(
                                icon: Icons.link_outlined,
                                label: 'Link Channel',
                                onTap: () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (context) =>
                                          const ManageChannels(),
                                    ),
                                  ).then((_) {
                                    if (mounted) {
                                      _loadChannelIntegrationState();
                                    }
                                  });
                                },
                              ),
                              _ChatActionCard(
                                icon: Icons.mark_chat_unread_outlined,
                                label: 'Live Chats',
                                onTap: () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (context) =>
                                          const LiveChatsPage(),
                                    ),
                                  );
                                },
                              ),
                              _ChatActionCard(
                                icon: Icons.chat_bubble_outline,
                                label: 'All Chats',
                                onTap: () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (context) =>
                                          const AllChatsPage(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatwootMessagePanel extends StatelessWidget {
  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final Widget child;

  const _ChatwootMessagePanel({
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 1.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(child: child),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ChatActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ChatActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF3F1163), width: 1),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 14),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
