import 'package:flutter/foundation.dart';

/// App Store Connect product ID helpers.
///
/// Create one subscription group in App Store Connect and add auto-renewable
/// products whose IDs match:
///   autobus.{planslug}.monthly
///   autobus.{planslug}.yearly
///
/// Example for plans named Basic / Standard / Enterprise:
///   autobus.basic.monthly, autobus.basic.yearly
///   autobus.standard.monthly, autobus.standard.yearly
///   autobus.enterprise.monthly, autobus.enterprise.yearly
class AppleIapIds {
  static const String prefix = 'autobus';

  static String slug(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static Map<String, String> forPlanName(String name) {
    final s = slug(name);
    return {
      'monthly': '$prefix.$s.monthly',
      'annual': '$prefix.$s.yearly',
    };
  }

  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// iPhone / iPad app only. Used to skip in-app IAP until App Store review completes.
  static bool get isIosApp {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS;
  }
}
