import 'package:autobus/common_design/widgets/credit_avatar.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual baseline for hub screens opened from Home (matches inbox / messaging hubs).
class ManageScreenStyle {
  ManageScreenStyle._();

  static const Color backgroundStart = Color(0xFF160A2C);
  static const Color backgroundEnd = Color(0xFF0C0418);
  static const Color headerRingBorder = Color.fromRGBO(255, 255, 255, 0.15);

  /// Same vertical gradient as the [Home] dashboard background.
  static const BoxDecoration homeDashboardBodyDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF130522), Color(0xFF000000)],
    ),
  );

  static BoxDecoration bodyGradientDecoration() => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [backgroundStart, backgroundEnd],
    ),
  );

  static TextStyle headerTitleStyle() => GoogleFonts.poppins(
    color: Colors.white,
    fontSize: 22,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.2,
  );
}

class ManageScreenHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  /// When set (and [trailing] is null), shows a credit chip for this category.
  final String? creditCategory;
  final VoidCallback? onBackPressed;
  final EdgeInsetsGeometry padding;

  const ManageScreenHeader({
    super.key,
    required this.title,
    this.trailing,
    this.creditCategory,
    this.onBackPressed,
    this.padding = const EdgeInsets.fromLTRB(24, 24, 24, 0),
  });

  @override
  Widget build(BuildContext context) {
    final trailingWidget =
        trailing ??
        (creditCategory != null
            ? CreditAvatar(creditCategory: creditCategory!)
            : const SizedBox(width: 48, height: 48));

    return Padding(
      padding: padding,
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            ManageScreenBackButton(onPressed: onBackPressed),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: ManageScreenStyle.headerTitleStyle(),
              ),
            ),
            const SizedBox(width: 8),
            trailingWidget,
          ],
        ),
      ),
    );
  }
}

class ManageScreenBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const ManageScreenBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onPressed ?? () => Navigator.of(context).maybePop(),
        child: Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ManageScreenStyle.headerRingBorder),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
