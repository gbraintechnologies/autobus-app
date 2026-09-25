import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/features/subscription/add_payment_method_page.dart';
import 'package:autobus/icons/figma_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Saved payment methods — Figma [Payment method](`3548:94`).
class PaymentMethodPage extends StatelessWidget {
  const PaymentMethodPage({super.key});

  static const _nameColor = Color(0xFF161616);
  static const _detailColor = Color(0xFF0B3C5D);
  static const _cardFill = Color(0xFFF8FAFC);

  /// Demo rows matching the Figma frame until a payment-methods API exists.
  static const _methods = <_PaymentMethodItem>[
    _PaymentMethodItem(
      logoAsset: FigmaImages.mtnLogo,
      name: 'Cephas Ntiamoah',
      detail: '0546785064',
      logoRadius: 5.1,
    ),
    _PaymentMethodItem(
      logoAsset: FigmaImages.visaLogo,
      name: 'Cephas Ntiamoah',
      detail: '4567 8899 3434 7765',
      logoRadius: 7.5,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Payment method',
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                26 * scale,
                20 * scale,
                26 * scale,
                24 * scale,
              ),
              itemCount: _methods.length,
              separatorBuilder: (_, __) => SizedBox(height: 8 * scale),
              itemBuilder: (context, index) {
                return _PaymentMethodCard(
                  scale: scale,
                  item: _methods[index],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                35 * scale,
                8 * scale,
                35 * scale,
                24 * scale,
              ),
              child: _AddPaymentButton(
                scale: scale,
                onPressed: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddPaymentMethodPage(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodItem {
  final String logoAsset;
  final String name;
  final String detail;
  final double logoRadius;

  const _PaymentMethodItem({
    required this.logoAsset,
    required this.name,
    required this.detail,
    required this.logoRadius,
  });
}

class _PaymentMethodCard extends StatelessWidget {
  final double scale;
  final _PaymentMethodItem item;

  const _PaymentMethodCard({
    required this.scale,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86 * scale,
      padding: EdgeInsets.symmetric(horizontal: 22 * scale),
      decoration: BoxDecoration(
        color: PaymentMethodPage._cardFill,
        borderRadius: BorderRadius.circular(14 * scale),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(item.logoRadius * scale),
            child: Image.asset(
              item.logoAsset,
              width: 46 * scale,
              height: 36 * scale,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 20 * scale),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: PaymentMethodPage._nameColor,
                    fontSize: LightScreenTheme.typeBody,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  item.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: PaymentMethodPage._detailColor,
                    fontSize: LightScreenTheme.typeLabel,
                    fontWeight: FontWeight.w400,
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

class _AddPaymentButton extends StatelessWidget {
  final double scale;
  final VoidCallback onPressed;

  const _AddPaymentButton({
    required this.scale,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LightScreenTheme.button,
      borderRadius: BorderRadius.circular(30 * scale),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: double.infinity,
          height: 64 * scale,
          child: Center(
            child: Text(
              'Add payment method',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: LightScreenTheme.typeTitle,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
