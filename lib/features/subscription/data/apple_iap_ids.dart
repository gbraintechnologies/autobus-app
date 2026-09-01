import 'package:flutter/foundation.dart';

/// Store consumable product IDs for App Store and Google Play.
///
/// Create the same IDs as Consumable products in both stores:
///   autobus.credits.20
///   autobus.credits.50
///   autobus.credits.150
///   autobus.credits.400
class AppleIapIds {
  static const String prefix = 'autobus';
  static const String androidPackageName = 'com.autobus.app';

  static const String credits20 = 'autobus.credits.20';
  static const String credits50 = 'autobus.credits.50';
  static const String credits150 = 'autobus.credits.150';
  static const String credits400 = 'autobus.credits.400';

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

  static const Set<String> creditProductIds = {
    credits20,
    credits50,
    credits150,
    credits400,
  };

  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  static bool get isIosApp {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  static bool get isAndroidApp {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }
}
