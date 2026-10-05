import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/app_screen_header.dart';
import 'package:autobus/common_design/widgets/credits_pill.dart';
import 'package:flutter/material.dart';

/// Standard light shell: white header, optional credits pill, `#F3F3F7` body.
class LightScreenScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? leading;
  final Widget? trailing;
  final String? creditCategory;
  final double titleFontSize;
  final bool resizeToAvoidBottomInset;
  final Color? backgroundColor;

  const LightScreenScaffold({
    super.key,
    required this.title,
    required this.body,
    this.leading,
    this.trailing,
    this.creditCategory,
    this.titleFontSize = LightScreenTheme.headerTitleSize,
    this.resizeToAvoidBottomInset = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return Scaffold(
      backgroundColor: backgroundColor ?? LightScreenTheme.background,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppScreenHeader(
            scale: scale,
            title: title,
            titleFontSize: titleFontSize,
            leading: leading ?? AppScreenBackButton(scale: scale),
            trailing: trailing ??
                (creditCategory != null
                    ? CreditsPill(
                        scale: scale,
                        creditCategory: creditCategory!,
                      )
                    : null),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
