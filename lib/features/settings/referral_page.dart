import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

const _heroGradient = [Color(0xFF7F03B9), Color(0xFF2D0C51)];
const _accentTint = Color(0xFFF3E8FF);

/// Builds the public signup link that pre-fills [code] on useautobus.com.
String referralInviteLink(String code) =>
    '${AppConfig.publicWebsiteUrl}/signup?ref=${Uri.encodeQueryComponent(code)}';

/// Referral code from the signed-in user, or a preview code derived from the
/// username until the backend returns `referral_code`.
String referralCodeFor(Map<String, dynamic> user) {
  final fromApi = (user['referral_code'] ?? user['referralCode'])
      ?.toString()
      .trim();
  if (fromApi != null && fromApi.isNotEmpty) return fromApi.toUpperCase();

  final name = (user['username'] ?? user['fullname'] ?? 'AUTOBUS')
      .toString()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final prefix = (name.isEmpty ? 'AUTOBUS' : name).padRight(4, 'X');
  final id = (user['id'] ?? user['user_id'] ?? '').toString();
  final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
  final suffix = (digits.isEmpty ? '${name.hashCode.abs()}' : digits)
      .padLeft(4, '0');
  return '${prefix.substring(0, 4)}${suffix.substring(suffix.length - 4)}';
}

class ReferralPage extends StatelessWidget {
  const ReferralPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    final state = context.watch<AuthBloc>().state;
    final user = state is Authenticated
        ? Map<String, dynamic>.from(state.user)
        : <String, dynamic>{};
    final code = referralCodeFor(user);
    final link = referralInviteLink(code);

    return LightScreenScaffold(
      title: 'Refer & Earn',
      body: SingleChildScrollView(
        padding: LightScreenTheme.listPagePadding(scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReferralHero(scale: scale),
            SizedBox(height: LightScreenTheme.sectionGap * scale),
            _SectionLabel('Your referral code'),
            SizedBox(height: 8 * scale),
            _CodeCard(scale: scale, code: code),
            SizedBox(height: 12 * scale),
            _LinkRow(scale: scale, link: link),
            SizedBox(height: 16 * scale),
            _ShareButton(scale: scale, code: code, link: link),
            SizedBox(height: LightScreenTheme.sectionGap * scale),
            _SectionLabel('Your referrals'),
            SizedBox(height: 8 * scale),
            _StatsRow(
              scale: scale,
              invited: _intOf(user['referrals_invited']),
              joined: _intOf(user['referrals_joined']),
              rewards: user['referral_rewards']?.toString(),
            ),
            SizedBox(height: LightScreenTheme.sectionGap * scale),
            _SectionLabel('How it works'),
            SizedBox(height: 8 * scale),
            _HowItWorks(scale: scale),
            SizedBox(height: LightScreenTheme.sectionGap * scale),
            _SectionLabel('Invited friends'),
            SizedBox(height: 8 * scale),
            _InvitedEmpty(scale: scale),
          ],
        ),
      ),
    );
  }

  static int _intOf(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: LightScreenTheme.title,
        fontSize: LightScreenTheme.typeTitle,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _ReferralHero extends StatelessWidget {
  const _ReferralHero({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20 * scale),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _heroGradient,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10 * scale,
                    vertical: 4 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Rewards coming soon',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: LightScreenTheme.typeCaption,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: 12 * scale),
                Text(
                  'Invite businesses,\nget rewarded',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: LightScreenTheme.typeHeadline,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: 6 * scale),
                Text(
                  'Share your code. When someone signs up to Autobus with it, you earn a reward.',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: LightScreenTheme.typeLabel,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12 * scale),
          Container(
            width: 64 * scale,
            height: 64 * scale,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.card_giftcard_rounded,
              color: Colors.white,
              size: 32 * scale,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _copy(BuildContext context, String value, String what) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) showAppSnackBar(context, '$what copied');
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.scale, required this.code});

  final double scale;
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20 * scale, 16 * scale, 12 * scale, 16 * scale),
      decoration: BoxDecoration(
        color: _accentTint,
        borderRadius: BorderRadius.circular(15 * scale),
        border: Border.all(
          color: LightScreenTheme.accent.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              code,
              style: GoogleFonts.poppins(
                color: LightScreenTheme.accent,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _copy(context, code, 'Referral code'),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: LightScreenTheme.accent,
              padding: EdgeInsets.symmetric(horizontal: 14 * scale),
              shape: const StadiumBorder(),
            ),
            icon: Icon(Icons.copy_rounded, size: 16 * scale),
            label: Text(
              'Copy',
              style: GoogleFonts.poppins(
                fontSize: LightScreenTheme.typeLabel,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.scale, required this.link});

  final double scale;
  final String link;

  @override
  Widget build(BuildContext context) {
    final display = link.replaceFirst(RegExp(r'^https?://'), '');
    return Material(
      color: LightScreenTheme.surface,
      borderRadius: BorderRadius.circular(15 * scale),
      child: InkWell(
        borderRadius: BorderRadius.circular(15 * scale),
        onTap: () => _copy(context, link, 'Invite link'),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scale,
            vertical: 14 * scale,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15 * scale),
            border: Border.all(color: LightScreenTheme.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.link_rounded,
                size: 20 * scale,
                color: LightScreenTheme.muted,
              ),
              SizedBox(width: 10 * scale),
              Expanded(
                child: Text(
                  display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: LightScreenTheme.body,
                    fontSize: LightScreenTheme.typeLabel,
                  ),
                ),
              ),
              SizedBox(width: 8 * scale),
              Icon(
                Icons.copy_rounded,
                size: 18 * scale,
                color: LightScreenTheme.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.scale,
    required this.code,
    required this.link,
  });

  final double scale;
  final String code;
  final String link;

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        title: 'Join me on Autobus',
        text:
            'I use Autobus to run my business with AI. Sign up with my link and '
            'my code $code is filled in for you: $link',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48 * scale,
      child: ElevatedButton.icon(
        onPressed: _share,
        style: ElevatedButton.styleFrom(
          backgroundColor: LightScreenTheme.button,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12 * scale),
          ),
        ),
        icon: Icon(Icons.ios_share_rounded, size: 18 * scale),
        label: Text(
          'Share invite link',
          style: GoogleFonts.poppins(
            fontSize: LightScreenTheme.typeBody,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.scale,
    required this.invited,
    required this.joined,
    required this.rewards,
  });

  final double scale;
  final int invited;
  final int joined;
  final String? rewards;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('$invited', 'Invited'),
      ('$joined', 'Signed up'),
      ((rewards == null || rewards!.isEmpty) ? '—' : rewards!, 'Rewards'),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: 10 * scale),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 14 * scale),
              decoration: BoxDecoration(
                color: LightScreenTheme.surface,
                borderRadius: BorderRadius.circular(15 * scale),
              ),
              child: Column(
                children: [
                  Text(
                    items[i].$1,
                    style: GoogleFonts.poppins(
                      color: LightScreenTheme.title,
                      fontSize: LightScreenTheme.typeHeadline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2 * scale),
                  Text(
                    items[i].$2,
                    style: GoogleFonts.poppins(
                      color: LightScreenTheme.muted,
                      fontSize: LightScreenTheme.typeCaption,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.scale});

  final double scale;

  static const _steps = [
    (
      Icons.share_rounded,
      'Share your link or code',
      'Send it on WhatsApp, SMS or social media.',
    ),
    (
      Icons.person_add_alt_1_rounded,
      'They sign up on Autobus',
      'Your code fills in automatically from the link, or they type it at signup.',
    ),
    (
      Icons.card_giftcard_rounded,
      'You get rewarded',
      'Your reward lands in your account once their signup is complete.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: LightScreenTheme.surface,
        borderRadius: BorderRadius.circular(15 * scale),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 36 * scale,
                        height: 36 * scale,
                        decoration: const BoxDecoration(
                          color: _accentTint,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _steps[i].$1,
                          size: 18 * scale,
                          color: LightScreenTheme.accent,
                        ),
                      ),
                      if (i < _steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            margin: EdgeInsets.symmetric(vertical: 4 * scale),
                            color: LightScreenTheme.accent.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 12 * scale),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: 6 * scale,
                        bottom: i < _steps.length - 1 ? 16 * scale : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _steps[i].$2,
                            style: GoogleFonts.poppins(
                              color: LightScreenTheme.title,
                              fontSize: LightScreenTheme.typeBody,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 2 * scale),
                          Text(
                            _steps[i].$3,
                            style: GoogleFonts.poppins(
                              color: LightScreenTheme.muted,
                              fontSize: LightScreenTheme.typeCaption,
                              height: 1.4,
                            ),
                          ),
                        ],
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

class _InvitedEmpty extends StatelessWidget {
  const _InvitedEmpty({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 20 * scale,
        vertical: 24 * scale,
      ),
      decoration: BoxDecoration(
        color: LightScreenTheme.surface,
        borderRadius: BorderRadius.circular(15 * scale),
      ),
      child: Column(
        children: [
          Icon(
            Icons.groups_2_outlined,
            size: 36 * scale,
            color: LightScreenTheme.hint,
          ),
          SizedBox(height: 8 * scale),
          Text(
            'No invites yet',
            style: GoogleFonts.poppins(
              color: LightScreenTheme.title,
              fontSize: LightScreenTheme.typeBody,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 2 * scale),
          Text(
            'Businesses that sign up with your code will show here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: LightScreenTheme.muted,
              fontSize: LightScreenTheme.typeCaption,
            ),
          ),
        ],
      ),
    );
  }
}
