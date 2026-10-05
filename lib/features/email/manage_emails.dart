import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_hub_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/icons/home_figma_icons.dart';
/// Manage Messaging hub — Figma ANALYTICS frame 3240:3170.
class ManageEmails extends StatefulWidget {
  const ManageEmails({super.key});

  @override
  State<ManageEmails> createState() => _ManageEmailsState();
}

class _ManageEmailsState extends State<ManageEmails> {
  static const _surfaceColor = Color(0xFFF8FAFC);
  static const _accentColor = Color(0xFF7F03B9);
  static const _mutedColor = Color(0xFF64748B);
  static const _bodyColor = Color(0xFF4D4D4D);
  static const _warningColor = Color(0xFFE27C00);

  bool _profileRequested = false;
  bool _loading = true;
  String? _loadError;
  String _profileEmail = '';

  bool get _hasSenderEmail => _profileEmail.trim().isNotEmpty;

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
        _profileEmail = (user['email'] ?? '').toString().trim();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e, fallback: AppUserMessages.load);
        _loading = false;
        _profileEmail = '';
      });
    }
  }

  Future<void> _openFromEmail() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const FromEmailPage()),
    );
    if (mounted) await _loadProfileEmail();
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
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Manage messaging',
      creditCategory: CreditCategory.email,
      body: RefreshIndicator(
        color: LightScreenTheme.accent,
        onRefresh: _loadProfileEmail,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: LightScreenTheme.hubPagePadding(scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome to Messaging',
                textAlign: TextAlign.center,
                style: LightScreenTheme.hubTitle(scale),
              ),
              SizedBox(height: LightScreenTheme.hubTitleGap * scale),
              Text(
                'Send emails to customers for support, updates, promotions, and notifications — with your AI assistant.',
                textAlign: TextAlign.center,
                style: LightScreenTheme.hubBody(scale),
              ),
              SizedBox(height: LightScreenTheme.hubToCards * scale),
                    if (_loading)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12 * scale),
                        child: Center(
                          child: CircularProgressIndicator(color: _accentColor),
                        ),
                      )
                    else if (_loadError != null)
                      _MessagingNoticeCard(
                        scale: scale,
                        message:
                            'Could not verify your profile email.\n${_shortError(_loadError!)}',
                        trailing: IconButton(
                          onPressed: _loadProfileEmail,
                          icon: HomeSfIcon(
                            icon: HomeFigmaIcons.refresh,
                            color: _mutedColor,
                            size: 22 * scale,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: 32 * scale,
                            minHeight: 32 * scale,
                          ),
                        ),
                      )
                    else if (!_hasSenderEmail)
                      _MessagingNoticeCard(
                        scale: scale,
                        message:
                            'You have not linked a sender address yet. Add an email on your profile so customers can recognize your messages.',
                        trailing: TextButton(
                          onPressed: _openFromEmail,
                          style: TextButton.styleFrom(
                            foregroundColor: _accentColor,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Add',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (!_loading) ...[
                      SizedBox(height: LightScreenTheme.sectionGap * scale),
                      LightHubGrid(
                        scale: scale,
                        children: [
                          _MessagingHubCard(
                            scale: scale,
                            title: 'Send Mails',
                            subtitle: 'Send to customers',
                            icon: HomeFigmaIcons.sendMail,
                            gradient: HomeFigmaIcons.sendMailGradient,
                            onTap: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const SendCustomerEmailPage(),
                                ),
                              );
                            },
                          ),
                          _MessagingHubCard(
                            scale: scale,
                            title: 'Sent Emails',
                            subtitle: 'View sent mails',
                            icon: HomeFigmaIcons.sentEmails,
                            gradient: HomeFigmaIcons.sentEmailsGradient,
                            onTap: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const SentEmailsPage(),
                                ),
                              );
                            },
                          ),
                          _MessagingHubCard(
                            scale: scale,
                            title: 'From Email',
                            subtitle: _hasSenderEmail
                                ? _profileEmail
                                : 'Add a from email',
                            icon: HomeFigmaIcons.fromEmail,
                            gradient: HomeFigmaIcons.fromEmailGradient,
                            onTap: _openFromEmail,
                          ),
                        ],
                      ),
                    ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagingNoticeCard extends StatelessWidget {
  final double scale;
  final String message;
  final Widget? trailing;

  const _MessagingNoticeCard({
    required this.scale,
    required this.message,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _ManageEmailsState._surfaceColor,
        borderRadius: BorderRadius.circular(20 * scale),
        border: Border.all(color: Colors.black, width: 1),
      ),
      padding: EdgeInsets.fromLTRB(20 * scale, 20 * scale, 16 * scale, 20 * scale),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (trailing != null)
            Positioned(
              top: 0,
              right: 0,
              child: trailing!,
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeSfIcon(
                icon: HomeFigmaIcons.warning,
                color: _ManageEmailsState._warningColor,
                size: 28 * scale.clamp(0.9, 1.05),
              ),
              SizedBox(height: 12 * scale),
              Text(
                message,
                style: GoogleFonts.poppins(
                  color: _ManageEmailsState._bodyColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessagingHubCard extends StatelessWidget {
  final double scale;
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _MessagingHubCard({
    required this.scale,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ManageEmailsState._surfaceColor,
      borderRadius: BorderRadius.circular(20 * scale),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20 * scale),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16 * scale,
            16 * scale,
            16 * scale,
            14 * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40 * scale,
                height: 40 * scale,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
                alignment: Alignment.center,
                child: HomeSfIcon(
                  icon: icon,
                  size: 20 * scale.clamp(0.9, 1.05),
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12 * scale),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      SizedBox(height: 6 * scale),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: _ManageEmailsState._mutedColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
