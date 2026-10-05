import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/app_snackbar.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/features/subscription/add_mobile_money_page.dart';
import 'package:autobus/icons/figma_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Choose payment type — Figma [Add payment method](`3548:1400`).
class AddPaymentMethodPage extends StatelessWidget {
  const AddPaymentMethodPage({super.key});

  static const _labelColor = Color(0xFF161616);
  static const _cardFill = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Add payment method',
      backgroundColor: Colors.white,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          26 * scale,
          20 * scale,
          26 * scale,
          24 * scale,
        ),
        children: [
          _AddPaymentOptionCard(
            scale: scale,
            label: 'Mobile money',
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddMobileMoneyPage(),
                ),
              );
            },
          ),
          SizedBox(height: 8 * scale),
          _AddPaymentOptionCard(
            scale: scale,
            label: 'Card',
            onTap: () {
              showAppSnackBar(
                context,
                'Card setup is coming soon.',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AddPaymentOptionCard extends StatelessWidget {
  final double scale;
  final String label;
  final VoidCallback onTap;

  const _AddPaymentOptionCard({
    required this.scale,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AddPaymentMethodPage._cardFill,
      borderRadius: BorderRadius.circular(14 * scale),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 86 * scale,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 25 * scale),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: AddPaymentMethodPage._labelColor,
                      fontSize: LightScreenTheme.typeBody,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                FigmaSvgIcon(
                  FigmaIcons.chevronDown,
                  size: 24 * scale,
                  color: Colors.black,
                  chevronRight: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
