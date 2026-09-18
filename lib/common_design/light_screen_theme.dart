import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared tokens for the light Figma shell used across hub and detail screens.
class LightScreenTheme {
  LightScreenTheme._();

  static const background = Color(0xFFF3F3F7);
  static const surface = Color(0xFFF8FAFC);
  static const accent = Color(0xFF7F03B9);
  static const button = Color(0xFF2D0C51);
  static const title = Colors.black;
  static const border = Color(0xFFE2E8F0);
  static const muted = Color(0xFF64748B);
  static const body = Color(0xFF4D4D4D);
  static const hint = Color(0xFFC1BCBC);
  static const field = Color(0xFFFAFAFA);
  static const warning = Color(0xFFE27C00);

  /// Optical type scale. Poppins reads a bit larger/heavier than the comps,
  /// so these sit 1px under the Figma values.
  static const headerTitleSize = 15.0;
  static const typeDisplay = 22.0;
  static const typeHeadline = 18.0;
  static const typeTitle = 15.0;
  static const typeBody = 13.0;
  static const typeLabel = 12.0;
  static const typeCaption = 11.0;
  static const typeMicro = 10.0;
  static const pageHorizontal = 20.0;
  static const hubPageTop = 30.0;
  static const pageBottom = 32.0;
  static const listPageTop = 20.0;
  static const hubTitleGap = 16.0;
  static const hubToCards = 30.0;
  static const gridGap = 12.0;
  static const sectionGap = 20.0;
  static const rowGap = 10.0;

  static EdgeInsets hubPagePadding(double scale) => EdgeInsets.fromLTRB(
        pageHorizontal * scale,
        hubPageTop * scale,
        pageHorizontal * scale,
        pageBottom * scale,
      );

  static EdgeInsets listPagePadding(double scale) => EdgeInsets.fromLTRB(
        pageHorizontal * scale,
        listPageTop * scale,
        pageHorizontal * scale,
        pageBottom * scale,
      );

  static TextStyle hubTitle(double scale) => GoogleFonts.poppins(
        color: Colors.black,
        fontSize: typeTitle,
        fontWeight: FontWeight.w500,
        height: 1.3,
      );

  static TextStyle hubBody(double scale) => GoogleFonts.poppins(
        color: body,
        fontSize: typeLabel,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle listTitle(double scale) => GoogleFonts.poppins(
        color: Colors.black,
        fontSize: typeBody,
        fontWeight: FontWeight.w500,
      );

  static TextStyle listSubtitle(double scale) => GoogleFonts.poppins(
        color: muted,
        fontSize: typeCaption,
        fontWeight: FontWeight.w400,
      );

  static TextStyle emptyState(double scale) => GoogleFonts.poppins(
        color: body,
        fontSize: typeBody,
        fontWeight: FontWeight.w400,
      );
}

/// Phone status-bar / nav-bar overlay for the light Figma shell.
///
/// Android uses [statusBarIconBrightness]; iOS uses [statusBarBrightness]
/// (light = dark clock/battery glyphs on a light background).
class AppSystemUi {
  AppSystemUi._();

  static const light = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFFF3F3F7),
    systemNavigationBarIconBrightness: Brightness.dark,
  );
}
