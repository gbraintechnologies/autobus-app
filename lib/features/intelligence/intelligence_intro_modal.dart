import 'package:autobus/icons/home_figma_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:google_fonts/google_fonts.dart';

/// First-visit intro overlay for Manage Intelligence — Figma Frame 20 (3242:3503).
class IntelligenceIntroModal extends StatelessWidget {
  const IntelligenceIntroModal({super.key});

  static const _cardColor = Color(0xFFF3F3F7);
  static const _iconCircleColor = Color(0xFFF8FAFC);
  static const _infoColor = Color(0xFF2563EB);
  static const _designWidth = 357.0;

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      barrierDismissible: true,
      builder: (_) => const IntelligenceIntroModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (screenWidth - 44).clamp(280.0, _designWidth);
    final scale = cardWidth / _designWidth;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: (screenWidth - cardWidth) / 2),
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: cardWidth,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              19 * scale,
              59 * scale,
              19 * scale,
              40 * scale,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IntroIcon(scale: scale),
                SizedBox(height: 8 * scale),
                Text(
                  'Welcome to Business Chat Intelligence',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 20 * scale),
                Text(
                  'Upload files and index websites so your AI can answer using your business information.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                  ),
                ),
                SizedBox(height: 20 * scale),
                _IntroSection(
                  scale: scale,
                  label: 'Files',
                  body:
                      'Upload documents like PDFs, spreadsheets, and text files for your AI to learn from.',
                ),
                SizedBox(height: 20 * scale),
                _IntroSection(
                  scale: scale,
                  label: 'Websites',
                  body:
                      'Index your website so your AI stays up to date with your latest content.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroIcon extends StatelessWidget {
  final double scale;

  const _IntroIcon({required this.scale});

  @override
  Widget build(BuildContext context) {
    final size = 50 * scale.clamp(0.9, 1.1);
    return Material(
      color: IntelligenceIntroModal._iconCircleColor,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: HomeSfIcon(
            icon: SFIcons.sf_info_circle_fill,
            color: IntelligenceIntroModal._infoColor,
            size: 24 * scale.clamp(0.9, 1.1),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _IntroSection extends StatelessWidget {
  final double scale;
  final String label;
  final String body;

  const _IntroSection({
    required this.scale,
    required this.label,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: GoogleFonts.poppins(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
        children: [
          TextSpan(
            text: '$label : ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: body),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
