import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/features/home/home.dart';
import 'package:autobus/features/intelligence/intelligence_my_ai_page.dart';
import 'package:autobus/features/intelligence/manage_intelligence.dart';
import 'package:autobus/features/reports/manage_reports.dart';
import 'package:flutter/material.dart';

/// Shared bottom-nav actions for every [AppShellScaffold] screen.
class AppShellNavigation {
  AppShellNavigation._();

  static const homeRouteName = 'Home';
  static const analyticsRouteName = 'ManageReports';
  static const intelligenceRouteName = 'ManageIntelligence';

  static bool _isCurrentRoute(BuildContext context, String name) {
    return ModalRoute.of(context)?.settings.name == name;
  }

  static void onTabSelected(BuildContext context, AppNavTab tab) {
    if (tab == AppNavTab.home) {
      goHome(context);
      return;
    }
    goAnalytics(context);
  }

  static void goHome(BuildContext context) {
    if (_isCurrentRoute(context, homeRouteName)) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: homeRouteName),
        builder: (_) => const Home(),
      ),
      (route) => false,
    );
  }

  static void goAnalytics(BuildContext context) {
    if (_isCurrentRoute(context, analyticsRouteName)) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: analyticsRouteName),
        builder: (_) => const ManageReports(),
      ),
      (route) => false,
    );
  }

  static void openIntelligence(BuildContext context) {
    if (_isCurrentRoute(context, intelligenceRouteName)) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: intelligenceRouteName),
        builder: (_) => const ManageIntelligence(),
      ),
    );
  }

  static void openChatbot(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const IntelligenceMyAiPage(),
      ),
    );
  }
}
