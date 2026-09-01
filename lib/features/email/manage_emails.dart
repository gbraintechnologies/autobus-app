import 'package:autobus/barrel.dart';

class ManageEmails extends StatefulWidget {
  const ManageEmails({super.key});

  @override
  State<ManageEmails> createState() => _ManageEmailsState();
}

class _ManageEmailsState extends State<ManageEmails> {
  bool _profileRequested = false;
  bool _loading = true;
  String? _loadError;
  String _senderEmail = '';

  bool get _hasSenderEmail => _senderEmail.trim().isNotEmpty;

  String _shortError(String raw, {int max = 160}) {
    final t = raw.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  Future<void> _loadProfileEmail() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiService>();
      final user = await api.getUserProfile();
      if (!mounted) return;
      setState(() {
        _senderEmail = (user['sender_email'] ?? '').toString().trim();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e);
        _loading = false;
        _senderEmail = '';
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileRequested) return;
    _profileRequested = true;
    _loadProfileEmail();
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
                  title: 'Manage Messaging',
                  creditCategory: CreditCategory.email,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 60),
                          Text(
                            'Welcome to Messaging',
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
                            'Send emails for customer support, updates, promotions, and notifications — with your AI assistant.',
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
                          ] else if (_loadError != null) ...[
                            _EmailNoticePanel(
                              backgroundColor: Colors.amber.withValues(
                                alpha: 0.12,
                              ),
                              borderColor: Colors.amber.withValues(alpha: 0.45),
                              icon: Icons.cloud_off_outlined,
                              iconColor: Colors.amber.shade300,
                              trailing: IconButton(
                                onPressed: _loadProfileEmail,
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
                                'Could not load your from email.\n${_shortError(_loadError!)}',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ] else if (!_hasSenderEmail) ...[
                            _EmailNoticePanel(
                              backgroundColor: const Color(
                                0xFF581C87,
                              ).withValues(alpha: 0.1),
                              borderColor: const Color(
                                0xFF9333EA,
                              ).withValues(alpha: 0.5),
                              icon: Icons.warning_rounded,
                              iconColor: Colors.red.shade400,
                              trailing: TextButton(
                                onPressed: () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const ManageSenderEmailPage(),
                                    ),
                                  ).then((_) {
                                    if (mounted) _loadProfileEmail();
                                  });
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Add',
                                  style: GoogleFonts.montserrat(
                                    color: const Color(0xFFA855F7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Add a from email before sending, for example noreply@useautobus.com. Autobus sends on your behalf using this address.',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ] else if (_hasSenderEmail) ...[
                            _EmailNoticePanel(
                              backgroundColor: const Color(
                                0xFF14532D,
                              ).withValues(alpha: 0.18),
                              borderColor: const Color(
                                0xFF22C55E,
                              ).withValues(alpha: 0.45),
                              icon: Icons.mark_email_read_outlined,
                              iconColor: const Color(0xFF4ADE80),
                              trailing: TextButton(
                                onPressed: () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const ManageSenderEmailPage(),
                                    ),
                                  ).then((_) {
                                    if (mounted) _loadProfileEmail();
                                  });
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Change',
                                  style: GoogleFonts.montserrat(
                                    color: const Color(0xFFA855F7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Sending from $_senderEmail',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white.withValues(alpha: 0.85),
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
                              _EmailHubCard(
                                icon: Icons.auto_awesome_outlined,
                                title: 'Send Mails',
                                onTap: () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const SendCustomerEmailPage(),
                                    ),
                                  );
                                },
                              ),
                              _EmailHubCard(
                                icon: Icons.outbox_outlined,
                                title: 'Sent Emails',
                                onTap: () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const SentEmailsPage(),
                                    ),
                                  );
                                },
                              ),
                              _EmailHubCard(
                                icon: Icons.alternate_email,
                                title: 'From email',
                                onTap: () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const ManageSenderEmailPage(),
                                    ),
                                  ).then((_) {
                                    if (mounted) _loadProfileEmail();
                                  });
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

class _EmailNoticePanel extends StatelessWidget {
  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final Widget child;

  const _EmailNoticePanel({
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

class _EmailHubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _EmailHubCard({
    required this.icon,
    required this.title,
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
              title,
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
