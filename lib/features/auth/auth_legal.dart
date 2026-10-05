import 'package:autobus/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openAuthLegalUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await canLaunchUrl(uri)) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Inline "By logging in/signing up, you agree to Terms and Privacy" notice.
class AuthLegalNotice extends StatelessWidget {
  const AuthLegalNotice({
    super.key,
    required this.prefix,
    required this.textColor,
    required this.linkColor,
    this.fontSize = 12,
    this.textAlign = TextAlign.center,
  });

  final String prefix;
  final Color textColor;
  final Color linkColor;
  final double fontSize;
  final TextAlign textAlign;

  TextStyle get _base => GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.4,
      );

  TextStyle get _link => _base.copyWith(
        fontWeight: FontWeight.w600,
        color: linkColor,
        decoration: TextDecoration.underline,
        decorationColor: linkColor,
      );

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: _base,
        children: [
          TextSpan(text: prefix),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => openAuthLegalUrl(AppConfig.termsOfServiceUrl),
              child: Text('Terms and Conditions', style: _link),
            ),
          ),
          const TextSpan(text: ' and '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => openAuthLegalUrl(AppConfig.privacyPolicyUrl),
              child: Text('Privacy Policy', style: _link),
            ),
          ),
        ],
      ),
      textAlign: textAlign,
    );
  }
}
