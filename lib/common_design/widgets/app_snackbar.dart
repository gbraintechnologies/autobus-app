import 'package:autobus/common_design/user_facing_error.dart';
import 'package:autobus/config/glob_navigator.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shows an error snackbar that stays visible on iOS (home indicator + keyboard).
void showAppSnackBar(
  BuildContext context,
  String message, {
  Color backgroundColor = Colors.red,
}) {
  FocusManager.instance.primaryFocus?.unfocus();

  final messenger =
      NavigationService.scaffoldMessengerKey.currentState ??
      ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final media = MediaQuery.maybeOf(context);
  final keyboard = media?.viewInsets.bottom ?? 0;
  final safe = media?.viewPadding.bottom ?? 0;
  final bottom = (keyboard > 0 ? keyboard : safe) + 16;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.montserrat(color: Colors.white),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottom),
        duration: const Duration(seconds: 4),
      ),
    );
}

/// Shows [userFacingError] so raw backend text never reaches the snackbar.
void showAppErrorSnackBar(
  BuildContext context,
  Object error, {
  String? action,
}) {
  showAppSnackBar(context, userFacingError(error, action: action));
}
