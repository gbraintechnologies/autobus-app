import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/features/chat/manage_chats.dart';
import 'package:autobus/features/customers/manage_customers.dart';
import 'package:autobus/features/home/home.dart';
import 'package:autobus/features/intelligence/intelligence_my_ai_page.dart';
import 'package:autobus/features/intelligence/manage_intelligence.dart';
import 'package:autobus/features/notifications/notifications_inbox.dart';
import 'package:autobus/features/products/manage_products.dart';
import 'package:autobus/features/reports/manage_reports.dart';
import 'package:flutter/material.dart';

/// Shared bottom-nav actions. Screens opened from here are pushed on
/// [shellKey] so the bar stays in place above them.
class AppShellNavigation {
  AppShellNavigation._();

  static final shellKey = GlobalKey<NavigatorState>();
  static final observer = _ShellObserver();
  static final activeTab = ValueNotifier<AppNavTab>(AppNavTab.home);
  static final homeVisible = ValueNotifier<bool>(true);
  static final shellCanPop = ValueNotifier<bool>(false);
  static final revision = ValueNotifier<int>(0);

  static const homeRouteName = 'Home';
  static const customersRouteName = 'ManageCustomers';
  static const productsRouteName = 'ManageProducts';
  static const notificationsRouteName = 'NotificationsInbox';
  static const messagesRouteName = 'IncomingMessages';
  static const analyticsRouteName = 'ManageReports';
  static const intelligenceRouteName = 'ManageIntelligence';

  static bool _isCurrentRoute(BuildContext context, String name) {
    return ModalRoute.of(context)?.settings.name == name;
  }

  static void onTabSelected(BuildContext context, AppNavTab tab) {
    switch (tab) {
      case AppNavTab.home:
        goHome(context);
      case AppNavTab.people:
        _openTab(
          context,
          const ManageCustomers(),
          customersRouteName,
          tab,
        );
      case AppNavTab.shop:
        _openTab(
          context,
          const ManageProducts(),
          productsRouteName,
          tab,
        );
      case AppNavTab.notifications:
        _openTab(
          context,
          const NotificationsInboxPage(),
          notificationsRouteName,
          tab,
        );
    }
  }

  static void openMessages(BuildContext context) {
    _revealOrPush(context, const ManageChats(), messagesRouteName);
  }

  static void _openTab(
    BuildContext context,
    Widget page,
    String name,
    AppNavTab tab,
  ) {
    activeTab.value = tab;
    _revealOrPush(context, page, name);
  }

  static void _revealOrPush(BuildContext context, Widget page, String name) {
    final nav = shellKey.currentState ?? Navigator.of(context);
    if (_topRouteName(nav) == name) return;

    var found = false;
    nav.popUntil((route) {
      if (route.settings.name == name) {
        found = true;
        return true;
      }
      return route.isFirst;
    });
    if (found) return;

    nav.push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: (_) => page,
      ),
    );
  }

  static String? _topRouteName(NavigatorState nav) {
    String? name;
    nav.popUntil((route) {
      name = route.settings.name;
      return true;
    });
    return name;
  }

  static void goHome(BuildContext context) {
    activeTab.value = AppNavTab.home;
    final shell = shellKey.currentState;
    if (shell != null) {
      if (shell.canPop()) {
        shell.popUntil((route) => route.isFirst);
      }
      return;
    }
    if (_isCurrentRoute(context, homeRouteName)) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: homeRouteName),
        builder: (_) => const Home(),
      ),
      (route) => false,
    );
  }

  static void resetToHome() {
    activeTab.value = AppNavTab.home;
    final shell = shellKey.currentState;
    if (shell != null && shell.canPop()) {
      shell.popUntil((route) => route.isFirst);
    }
  }

  static void goAnalytics(BuildContext context) {
    _revealOrPush(context, const ManageReports(), analyticsRouteName);
  }

  static void openIntelligence(BuildContext context) {
    _revealOrPush(
      context,
      const ManageIntelligence(),
      intelligenceRouteName,
    );
  }

  static void openChatbot(BuildContext context) {
    _revealOrPush(
      context,
      const IntelligenceMyAiPage(),
      'IntelligenceMyAi',
    );
  }
}

class _ShellObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _sync(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _sync(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _sync(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _sync(newRoute);
  }

  void _sync(Route<dynamic>? route) {
    final name = route?.settings.name;
    final atHome = route == null || route.isFirst;
    AppShellNavigation.homeVisible.value = atHome;
    AppShellNavigation.shellCanPop.value = route != null && !route.isFirst;
    final tab = _tabFor(name);
    if (tab != null) {
      AppShellNavigation.activeTab.value = tab;
    } else if (atHome) {
      AppShellNavigation.activeTab.value = AppNavTab.home;
    }
    AppShellNavigation.revision.value++;
  }

  AppNavTab? _tabFor(String? name) {
    switch (name) {
      case AppShellNavigation.homeRouteName:
        return AppNavTab.home;
      case AppShellNavigation.customersRouteName:
        return AppNavTab.people;
      case AppShellNavigation.productsRouteName:
        return AppNavTab.shop;
      case AppShellNavigation.notificationsRouteName:
        return AppNavTab.notifications;
      default:
        return null;
    }
  }
}
